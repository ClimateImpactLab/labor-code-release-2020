#-------------------------------------------------------------------------------
# region_rf_lowhigh_appendix.r
#-------------------------------------------------------------------------------
# PURPOSE
#   Plot regional low/high temperature responses against the global response
#
# STEPS
#   1. Read regional response CSVs, the global response CSV, and temperature bins
#   2. Reshape response and histogram data for all, low-risk, and high-risk workers
#   3. Draw one appendix figure per region
#   4. Save regional PDF figures
#
# INPUTS
#   Regional low/high response CSVs under ${DIR_RF}
#   Global low/high response CSV under ${DIR_RF}
#   Regional low/high temperature bins under ${DIR_OUTPUT}
#
# OUTPUTS
#   Regional low/high appendix figures under ${DIR_FIG}
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# Initialize
#-------------------------------------------------------------------------------

rm(list = ls())

library(dplyr)
library(tidyr)
library(ggplot2)
library(patchwork)
library(readr)
library(glue)
library(data.table)
library(parallel)

user <- "mdefranciosi"

source(paste0("/project/cil/home_dirs/", user, "/repos/labor-code-release-2020/0_subroutines/paths.R"))
source(paste0("/project/cil/home_dirs/", user, "/repos/labor-code-release-2020/2_analysis/0_subroutines/functions.R"))

#-------------------------------------------------------------------------------
# Output folder
#-------------------------------------------------------------------------------

outpath <- glue("{DIR_FIG}/region_rf_plots")
dir.create(outpath, showWarnings = FALSE, recursive = TRUE)

format <- "pdf"

#-------------------------------------------------------------------------------
# Options
#-------------------------------------------------------------------------------

fraction_hist <- "YES"
fraction_hist <- toupper(fraction_hist)

weight_hist <- "YES"
weight_hist <- toupper(weight_hist)

plot_ci_beyond_cap <- "YES"
plot_ci_beyond_cap <- toupper(plot_ci_beyond_cap)

zero_line_color <- "grey40"

risk_list <- c("comm", "low", "high")

hist_risk_names <- c(
  comm = "comm",
  low  = "lowrisk",
  high = "highrisk"
)

risk_labels <- c(
  comm = "All workers",
  low  = "Low-risk workers",
  high = "High-risk workers"
)

region_table <- tibble::tibble(
  region_code = c("EuropeUS", "LatinAmerica", "SouthAsia"),
  region_name = c("Europe & US", "Latin America", "South Asia")
)

region_knots <- tibble::tibble(
  region_code = c("EuropeUS", "LatinAmerica", "SouthAsia"),
  k1 = c(14, 26, 28),
  k2 = c(20, 29, 33),
  k3 = c(28, 34, 41)
)

region_y_limits <- tibble::tibble(
  region_code = c("EuropeUS", "LatinAmerica", "SouthAsia"),
  stop_ci_at = c(-300, -150, -200),
  y_top = c(300, 50, 100)
)

#-------------------------------------------------------------------------------
# File paths
#-------------------------------------------------------------------------------

rf_region_path <- function(region_code) {
  glue("{DIR_RF}/uninteracted_reg_region/{region_code}/rf_{region_code}_full_ag.csv")
}

rf_global_path <- glue(
  "{DIR_RF}/uninteracted_reg_comlohi/",
  "uninteracted_reg_comlohi_full_response_2026_272841.csv"
)

td_region_path <- function(region_code) {
  glue("{DIR_OUTPUT}/temp_dist/region_highrisk/{region_code}_temp_dist_highrisk_05.csv")
}

#-------------------------------------------------------------------------------
# Reshape helpers
#-------------------------------------------------------------------------------

reshape_rf <- function(name, df) {
  df %>%
    select(
      temp,
      yhat    = paste0("yhat_", name),
      lowerci = paste0("lowerci_", name),
      upperci = paste0("upperci_", name)
    ) %>%
    mutate(risk = name)
}

reshape_hist <- function(risk_name, df, var_prefix) {

  hist_name <- hist_risk_names[[risk_name]]

  df %>%
    select(
      temp,
      weight = paste0(var_prefix, "_", hist_name)
    ) %>%
    mutate(risk = risk_name)
}

safe_apply <- function(names, FUN, ..., mc.cores = 1) {

  if (mc.cores > 1) {
    out <- try(mclapply(names, FUN, ..., mc.cores = mc.cores), silent = TRUE)

    ok <- !inherits(out, "try-error") &&
      is.list(out) &&
      length(out) == length(names) &&
      all(vapply(out, is.data.frame, logical(1)))

    if (ok) return(out)

    warning("Parallel apply failed; falling back to serial lapply().")
  }

  lapply(names, FUN, ...)
}

make_ci_cols <- function(df) {

  if (plot_ci_beyond_cap == "YES") {
    df <- df %>%
      mutate(
        lowerci_plot = pmax(lowerci, stop_ci_at),
        upperci_plot = upperci
      )
  } else if (plot_ci_beyond_cap == "NO") {
    df <- df %>%
      mutate(
        lowerci_plot = ifelse(lowerci < stop_ci_at, NA, lowerci),
        upperci_plot = ifelse(lowerci < stop_ci_at, NA, upperci)
      )
  } else {
    stop("plot_ci_beyond_cap must be YES or NO.")
  }

  df
}

#-------------------------------------------------------------------------------
# Main loop
#-------------------------------------------------------------------------------

for (i in seq_len(nrow(region_table))) {

  region_code <- region_table$region_code[i]
  region_name <- region_table$region_name[i]

  ylim_sub <- region_y_limits %>%
    filter(.data$region_code == .env$region_code)

  if (nrow(ylim_sub) != 1) {
    stop(glue("Missing or duplicated y-limits for region = {region_code}"), call. = FALSE)
  }

  stop_ci_at <- ylim_sub$stop_ci_at
  y_top      <- ylim_sub$y_top

  kn <- region_knots %>%
    filter(.data$region_code == .env$region_code)
  knots_subtitle <- glue("Region-specific knots: k1 = {kn$k1}, k2 = {kn$k2}, k3 = {kn$k3}")

  message("--------------------------------------------------")
  message("region = ", region_code, " (", region_name, ")")
  message("--------------------------------------------------")

  rf_region_file <- rf_region_path(region_code)
  rf_global_file <- rf_global_path
  td_file        <- td_region_path(region_code)

  if (!file.exists(rf_region_file)) stop(glue("Missing region response file: {rf_region_file}"), call. = FALSE)
  if (!file.exists(rf_global_file)) stop(glue("Missing global response file: {rf_global_file}"), call. = FALSE)
  if (!file.exists(td_file)) stop(glue("Missing temperature-bin file: {td_file}"), call. = FALSE)

  rf_region <- read_csv(rf_region_file, show_col_types = FALSE)
  rf_global <- read_csv(rf_global_file, show_col_types = FALSE)
  temp_dist <- read_csv(td_file, show_col_types = FALSE)

  #-------------------------------------------------------------------------------
  # Response functions
  #-------------------------------------------------------------------------------

  rf_region_long <- rbindlist(
    safe_apply(risk_list, reshape_rf, df = rf_region, mc.cores = 3),
    use.names = TRUE
  ) %>%
    mutate(
      risk = factor(risk, levels = risk_list),
      source = "Region response"
    ) %>%
    make_ci_cols()

  rf_global_long <- rbindlist(
    safe_apply(risk_list, reshape_rf, df = rf_global, mc.cores = 3),
    use.names = TRUE
  ) %>%
    mutate(
      risk = factor(risk, levels = risk_list),
      source = "Global response"
    ) %>%
    make_ci_cols()

  #-------------------------------------------------------------------------------
  # Histograms
  #-------------------------------------------------------------------------------

  if (fraction_hist == "YES" & weight_hist == "YES") {

    hist_df <- bind_rows(
      reshape_hist("comm", temp_dist, "frac_pop_wgt"),
      rbindlist(
        safe_apply(
          c("low", "high"),
          reshape_hist,
          df = temp_dist,
          var_prefix = "frac_risk_wgt",
          mc.cores = 2
        ),
        use.names = TRUE
      )
    )

  } else if (fraction_hist == "NO" & weight_hist == "YES") {

    hist_df <- bind_rows(
      reshape_hist("comm", temp_dist, "pop_wgt"),
      rbindlist(
        safe_apply(
          c("low", "high"),
          reshape_hist,
          df = temp_dist,
          var_prefix = "risk_wgt",
          mc.cores = 2
        ),
        use.names = TRUE
      )
    )

  } else if (fraction_hist == "YES" & weight_hist == "NO") {

    hist_df <- rbindlist(
      safe_apply(
        risk_list,
        reshape_hist,
        df = temp_dist,
        var_prefix = "frac_no_wgt",
        mc.cores = 3
      ),
      use.names = TRUE
    )

  } else if (fraction_hist == "NO" & weight_hist == "NO") {

    hist_df <- rbindlist(
      safe_apply(
        risk_list,
        reshape_hist,
        df = temp_dist,
        var_prefix = "no_wgt",
        mc.cores = 3
      ),
      use.names = TRUE
    )

  } else {
    stop("fraction_hist and weight_hist must each be YES or NO.")
  }

  hist_df <- hist_df %>%
    mutate(risk = factor(risk, levels = risk_list))

  support_df <- hist_df %>%
    filter(weight > 0) %>%
    group_by(risk) %>%
    summarise(
      support_min = min(temp, na.rm = TRUE),
      support_max = max(temp, na.rm = TRUE),
      .groups = "drop"
    )

  #-------------------------------------------------------------------------------
  # Print checks
  #-------------------------------------------------------------------------------

  cat("\nfraction_hist =", fraction_hist, "\n")
  cat("weight_hist   =", weight_hist, "\n")
  cat("stop_ci_at    =", stop_ci_at, "\n")
  cat("y_top         =", y_top, "\n")

  cat("\ntemperature-bin summary\n")
  print(
    hist_df %>%
      group_by(risk) %>%
      summarise(
        n_pos = sum(weight > 0, na.rm = TRUE),
        min_temp = min(temp[weight > 0], na.rm = TRUE),
        p01 = quantile(temp[weight > 0], 0.01, na.rm = TRUE),
        p05 = quantile(temp[weight > 0], 0.05, na.rm = TRUE),
        p50 = quantile(temp[weight > 0], 0.50, na.rm = TRUE),
        p95 = quantile(temp[weight > 0], 0.95, na.rm = TRUE),
        p99 = quantile(temp[weight > 0], 0.99, na.rm = TRUE),
        max_temp = max(temp[weight > 0], na.rm = TRUE),
        total_weight = sum(weight, na.rm = TRUE),
        max_bin = max(weight, na.rm = TRUE),
        .groups = "drop"
      )
  )

  cat("\nregion response summary\n")
  print(
    rf_region_long %>%
      left_join(support_df, by = "risk") %>%
      group_by(risk) %>%
      summarise(
        rf_min_temp = min(temp, na.rm = TRUE),
        rf_max_temp = max(temp, na.rm = TRUE),
        yhat_min = min(yhat, na.rm = TRUE),
        yhat_max = max(yhat, na.rm = TRUE),
        ci_min = min(lowerci, na.rm = TRUE),
        ci_max = max(upperci, na.rm = TRUE),
        support_min = min(support_min, na.rm = TRUE),
        support_max = max(support_max, na.rm = TRUE),
        .groups = "drop"
      )
  )

  #-------------------------------------------------------------------------------
  # Plot limits
  #-------------------------------------------------------------------------------

  x_tmp <- hist_df %>%
    filter(weight > 0) %>%
    summarise(
      xmin = quantile(temp, 0.05, na.rm = TRUE) - 5,
      xmax = quantile(temp, 0.95, na.rm = TRUE) + 5
    )

  x_limits <- c(x_tmp$xmin, x_tmp$xmax)

  x_limits <- c(
    max(min(rf_global$temp, rf_region$temp, na.rm = TRUE), x_limits[1]),
    min(max(rf_global$temp, rf_region$temp, na.rm = TRUE), x_limits[2])
  )

  if (x_limits[1] >= x_limits[2]) {
    stop(
      glue(
        "Bad x limits for {region_code}: xmin={x_limits[1]}, xmax={x_limits[2]}. ",
        "This usually means histogram temps are not on the same scale as response temps."
      ),
      call. = FALSE
    )
  }

  cat("\nx limits used:", x_limits[1], x_limits[2], "\n")

  x_breaks <- sort(unique(c(-20, scales::pretty_breaks(n = 8)(x_limits))))
  x_breaks <- x_breaks[x_breaks >= x_limits[1] & x_breaks <= x_limits[2]]

  hist_max_global <- max(hist_df$weight, na.rm = TRUE)
  if (!is.finite(hist_max_global) || hist_max_global <= 0) hist_max_global <- 1

  #-------------------------------------------------------------------------------
  # Plot
  #-------------------------------------------------------------------------------

  make_strip <- function(r, is_leftmost = FALSE, tag_letter = "A") {

    d_region <- rf_region_long %>% filter(risk == r)
    d_global <- rf_global_long %>% filter(risk == r)
    h_sub    <- hist_df %>% filter(risk == r)
    s_sub    <- support_df %>% filter(risk == r)

    if (fraction_hist == "YES") {
      hist_max <- max(h_sub$weight, na.rm = TRUE)
    } else {
      hist_max <- hist_max_global
    }

    if (!is.finite(hist_max) || hist_max <= 0) hist_max <- 1

    label_x <- x_limits[1] + 0.05 * diff(x_limits)
    label_y <- y_top - 0.12 * (y_top - stop_ci_at)

    p <- ggplot() +
      geom_hline(
        yintercept = 0,
        linetype = "dashed",
        linewidth = 0.5,
        color = zero_line_color
      ) +
      geom_vline(
        data = s_sub,
        aes(xintercept = support_min),
        linetype = "dotted",
        linewidth = 0.5,
        color = "grey40"
      ) +
      geom_vline(
        data = s_sub,
        aes(xintercept = support_max),
        linetype = "dotted",
        linewidth = 0.5,
        color = "grey40"
      ) +
      geom_ribbon(
        data = d_global,
        aes(x = temp, ymin = lowerci_plot, ymax = upperci_plot),
        alpha = 0.10,
        fill = "#1B6CA8",
        colour = NA
      ) +
      geom_line(
        data = d_global,
        aes(x = temp, y = yhat, colour = "Global response"),
        linewidth = 0.8,
        alpha = 0.7
      ) +
      geom_ribbon(
        data = d_region,
        aes(x = temp, ymin = lowerci_plot, ymax = upperci_plot),
        alpha = 0.20,
        fill = "#5E4987",
        colour = NA
      ) +
      geom_line(
        data = d_region,
        aes(x = temp, y = yhat, colour = "Region response"),
        linewidth = 1
      ) +
      annotate(
        "text",
        x = label_x,
        y = label_y,
        label = risk_labels[[as.character(r)]],
        hjust = 0,
        vjust = 0,
        fontface = "bold",
        size = 3.5
      ) +
      scale_colour_manual(
        values = c(
          "Global response" = "#1B6CA8",
          "Region response" = "#5E4987"
        )
      ) +
      scale_y_continuous(
        limits = c(stop_ci_at, y_top),
        expand = c(0, 0)
      ) +
      scale_x_continuous(
        breaks = x_breaks,
        limits = x_limits,
        expand = c(0, 0),
        minor_breaks = NULL
      ) +
      labs(
        x = NULL,
        y = if (is_leftmost) "Minutes worked" else NULL,
        tag = tag_letter,
        colour = NULL
      ) +
      theme_minimal(base_size = 12) +
      theme(
        panel.grid = element_blank(),
        legend.position = "bottom",
        legend.title = element_blank(),
        legend.background = element_blank(),
        legend.key = element_blank(),
        legend.text = element_text(size = 8),
        plot.tag.position = c(ifelse(is_leftmost, 0.09, -0.03), 0.98),
        plot.tag = element_text(size = 14, hjust = 0, vjust = 1, face = "bold"),
        axis.line = element_blank(),
        axis.line.y = element_line(color = "black", linewidth = 0.4),
        axis.ticks.y = element_line(color = "black", linewidth = 0.4),
        axis.ticks.length = unit(3, "pt"),
        axis.text.x = element_blank(),
        axis.ticks.x = element_blank(),
        axis.title.y = element_text(margin = margin(r = 8), face = "bold"),
        plot.margin = margin(t = 2, r = 6, b = 0, l = 6)
      )

    gap <- plot_spacer() +
      theme(plot.margin = margin(0, 0, 0, 0))

    q <- ggplot(h_sub, aes(x = temp, y = weight)) +
      geom_vline(
        data = s_sub,
        aes(xintercept = support_min),
        linetype = "dotted",
        linewidth = 0.5,
        color = "grey40"
      ) +
      geom_vline(
        data = s_sub,
        aes(xintercept = support_max),
        linetype = "dotted",
        linewidth = 0.5,
        color = "grey40"
      ) +
      geom_col(fill = "grey50") +
      scale_y_continuous(
        limits = c(0, hist_max),
        expand = c(0, 0)
      ) +
      scale_x_continuous(
        breaks = x_breaks,
        limits = x_limits,
        expand = c(0, 0),
        minor_breaks = NULL
      ) +
      labs(x = NULL, y = NULL) +
      theme_minimal(base_size = 12) +
      theme(
        panel.grid = element_blank(),
        legend.position = "none",
        axis.line = element_blank(),
        axis.line.y = element_line(color = "black", linewidth = 0.4),
        axis.ticks = element_line(color = "black", linewidth = 0.4),
        axis.ticks.length = unit(3, "pt"),
        axis.text.y = element_blank(),
        axis.ticks.y = element_blank(),
        plot.margin = margin(t = 0, r = 6, b = 0, l = 6)
      )

    (p / gap / q) + plot_layout(heights = c(2, 0.10, 1))
  }

  strips <- lapply(seq_along(risk_list), function(j) {
    make_strip(
      r = risk_list[j],
      is_leftmost = (j == 1),
      tag_letter = LETTERS[j]
    )
  })

  spacer_width <- 0.03

  fig <- (
    strips[[1]] | plot_spacer() |
      strips[[2]] | plot_spacer() |
      strips[[3]]
  ) +
    plot_layout(
      widths = c(1, spacer_width, 1, spacer_width, 1),
      guides = "collect"
    ) +
    plot_annotation(
      title = glue("Region and Global Labor Supply-Temperature Response: {region_name}"),
      subtitle = knots_subtitle,
      caption = "Temperature (°C)"
    ) &
    theme(
      plot.title = element_text(hjust = 0.5, face = "bold", size = 12),
      plot.subtitle = element_text(hjust = 0.5, size = 10),
      plot.caption = element_text(hjust = 0.58, face = "bold", size = 12, margin = margin(t = 8)),
      legend.position = "bottom",
      legend.title = element_blank()
    )

  outfile <- glue("{outpath}/rf_comlohi_{region_code}_{tolower(fraction_hist)}frac_{tolower(weight_hist)}wgt.{format}")

  ggsave(outfile, plot = fig, width = 10, height = 4.8)
  print(fig)
  cat("Saved:", outfile, "\n")
}
