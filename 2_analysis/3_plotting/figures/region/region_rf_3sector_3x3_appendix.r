#-------------------------------------------------------------------------------
# region_rf_3sector_3x3_appendix.R
#-------------------------------------------------------------------------------
#
# PURPOSE
#   Plot a 3 x 3 regional temperature-response figure for the 3-sector model
#
# STEPS
#   1. Read regional response CSVs and temperature-distribution CSVs
#   2. Reshape response and histogram data for low-risk, agriculture, and non-ag
#   3. Draw one row per region and one column per sector
#   4. Save the combined PDF figure
#
# INPUTS
#   Region 3-sector response CSVs under ${DIR_RF}
#   Region 3-sector temperature-distribution CSVs under ${DIR_OUTPUT}
#
# OUTPUTS
#   3 x 3 regional 3-sector response figure under ${DIR_FIG}
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# Initialize
#-------------------------------------------------------------------------------

rm(list = ls())

library(dplyr)
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

outpath <- glue("{DIR_FIG}/region_rf_plots_3sector")
dir.create(outpath, showWarnings = FALSE, recursive = TRUE)

format <- "pdf"

#-------------------------------------------------------------------------------
# Options
#-------------------------------------------------------------------------------

FRACTION_HIST <- "YES"
FRACTION_HIST <- toupper(FRACTION_HIST)

WEIGHT_HIST <- "YES"  # "YES" = weighted, "NO" = unweighted
WEIGHT_HIST <- toupper(WEIGHT_HIST)

ZERO_LINE_COLOR <- "grey40"

risk_list <- c("low", "ag", "nonag")

risk_labels <- c(
  low   = "Services",
  ag    = "Ag., Forestry,\nFishing",
  nonag = "Manuf., Construction,\nMining"
)

region_table <- tibble::tibble(
  REG   = c("EuropeUS", "LatinAmerica", "SouthAsia"),
  cname = c("U.S. & Europe", "Latin America", "India")
)

region_y_limits <- tibble::tibble(
  REG        = c("EuropeUS", "LatinAmerica", "SouthAsia"),
  STOP_CI_AT = c(-300, -20, -200),
  Y_TOP      = c(300, 20, 100),
  Y_BREAK_BY = c(NA_real_, 10, NA_real_)
)

#-------------------------------------------------------------------------------
# File paths
#-------------------------------------------------------------------------------

rf_region_path <- function(REG) {
  glue("{DIR_RF}/uninteracted_reg_region_3sector/{REG}/rf_{REG}_full_3sector_ag.csv")
}

td_region_path <- function(REG) {
  glue("{DIR_OUTPUT}/temp_dist/region/{REG}_temp_dist_sector_1.csv")
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

reshape_hist <- function(name, df, var_prefix) {
  df %>%
    select(
      temp,
      weight = paste0(var_prefix, "_", name)
    ) %>%
    mutate(risk = name)
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

build_hist_df <- function(temp_dist) {

  if (FRACTION_HIST == "YES" & WEIGHT_HIST == "YES") {
    var_prefix <- "frac_risk_wgt"
  } else if (FRACTION_HIST == "NO" & WEIGHT_HIST == "YES") {
    var_prefix <- "risk_wgt"
  } else if (FRACTION_HIST == "YES" & WEIGHT_HIST == "NO") {
    var_prefix <- "frac_no_wgt"
  } else if (FRACTION_HIST == "NO" & WEIGHT_HIST == "NO") {
    var_prefix <- "no_wgt"
  } else {
    stop("FRACTION_HIST and WEIGHT_HIST must each be YES or NO.")
  }

  rbindlist(
    safe_apply(
      risk_list,
      reshape_hist,
      df = temp_dist,
      var_prefix = var_prefix,
      mc.cores = length(risk_list)
    ),
    use.names = TRUE
  ) %>%
    mutate(risk = factor(risk, levels = risk_list))
}

make_header_plot <- function(label, hjust = 0.5, size = 4.2) {
  ggplot() +
    annotate(
      "text",
      x = ifelse(hjust == 0, 0, 0.5),
      y = 0.5,
      label = label,
      hjust = hjust,
      vjust = 0.5,
      fontface = "bold",
      size = size,
      lineheight = 0.95
    ) +
    xlim(0, 1) +
    ylim(0, 1) +
    theme_void() +
    theme(plot.margin = margin(t = 0, r = 6, b = -2, l = 0))
}

make_vertical_label_plot <- function(label, fontface = "plain", size = 4.2) {
  ggplot() +
    annotate(
      "text",
      x = 0.5,
      y = 0.5,
      label = label,
      angle = 90,
      hjust = 0.5,
      vjust = 0.5,
      fontface = fontface,
      size = size
    ) +
    xlim(0, 1) +
    ylim(0, 1) +
    theme_void() +
    theme(plot.margin = margin(0, 0, 0, 0))
}

#-------------------------------------------------------------------------------
# Region rows
#-------------------------------------------------------------------------------

make_region_row <- function(REG, cname) {

  ylim_sub <- region_y_limits %>% filter(REG == !!REG)

  if (nrow(ylim_sub) != 1) {
    stop(glue("Missing or duplicated y-limits for REG = {REG}"), call. = FALSE)
  }

  STOP_CI_AT <- ylim_sub$STOP_CI_AT
  Y_TOP      <- ylim_sub$Y_TOP
  Y_BREAK_BY <- ylim_sub$Y_BREAK_BY
  y_breaks   <- if (is.na(Y_BREAK_BY)) {
    waiver()
  } else {
    seq(STOP_CI_AT, Y_TOP, by = Y_BREAK_BY)
  }

  rf_region_file <- rf_region_path(REG)
  td_file        <- td_region_path(REG)

  if (!file.exists(rf_region_file)) stop(glue("Missing response file: {rf_region_file}"), call. = FALSE)
  if (!file.exists(td_file)) stop(glue("Missing temp-dist file: {td_file}"), call. = FALSE)

  message("--------------------------------------------------")
  message("REG = ", REG, " (", cname, ")")
  message("--------------------------------------------------")

  rf_region <- read_csv(rf_region_file, show_col_types = FALSE)
  temp_dist <- read_csv(td_file, show_col_types = FALSE)

  rf_region_long <- rbindlist(
    safe_apply(risk_list, reshape_rf, df = rf_region, mc.cores = length(risk_list)),
    use.names = TRUE
  ) %>%
    mutate(risk = factor(risk, levels = risk_list))

  hist_df <- build_hist_df(temp_dist)

  x_tmp <- hist_df %>%
    filter(weight > 0) %>%
    summarise(
      xmin = min(temp, na.rm = TRUE),
      xmax = max(temp, na.rm = TRUE)
    )

  x_limits <- c(x_tmp$xmin - 1, x_tmp$xmax + 1)

  if (x_limits[1] >= x_limits[2]) {
    stop(
      glue(
        "Bad x limits for {REG}: xmin={x_limits[1]}, xmax={x_limits[2]}. ",
        "This usually means histogram temps are not on the same scale as RF temps."
      ),
      call. = FALSE
    )
  }

  if (REG %in% c("LatinAmerica", "SouthAsia")) {
    x_breaks <- seq(
      floor(x_limits[1] / 5) * 5,
      ceiling(x_limits[2] / 5) * 5,
      by = 5
    )
  } else {
    x_breaks <- scales::pretty_breaks(n = 5)(x_limits)
  }
  x_breaks <- x_breaks[x_breaks >= x_limits[1] & x_breaks <= x_limits[2]]

  make_cell <- function(r, is_leftmost = FALSE) {

    d_region <- rf_region_long %>% filter(risk == r)
    h_sub    <- hist_df %>% filter(risk == r)

    hist_max <- max(h_sub$weight, na.rm = TRUE)
    if (!is.finite(hist_max) || hist_max <= 0) hist_max <- 1

    p <- ggplot() +
      geom_hline(
        yintercept = 0,
        linetype = "dashed",
        linewidth = 0.4,
        color = ZERO_LINE_COLOR
      ) +
      geom_ribbon(
        data = d_region,
        aes(x = temp, ymin = lowerci, ymax = upperci),
        alpha = 0.20,
        fill = "#5E4987",
        colour = NA
      ) +
      geom_line(
        data = d_region,
        aes(x = temp, y = yhat),
        linewidth = 0.9,
        color = "#5E4987"
      ) +
      scale_y_continuous(
        breaks = y_breaks,
        expand = c(0, 0)
      ) +
      scale_x_continuous(
        breaks = x_breaks,
        expand = c(0, 0),
        minor_breaks = NULL
      ) +
      coord_cartesian(
        xlim = x_limits,
        ylim = c(STOP_CI_AT, Y_TOP),
        expand = FALSE,
        clip = "on"
      ) +
      labs(
        x = NULL,
        y = NULL
      ) +
      theme_minimal(base_size = 10) +
      theme(
        panel.grid = element_blank(),
        legend.position = "none",
        axis.line = element_blank(),
        axis.line.y = element_line(color = "black", linewidth = 0.4),
        axis.ticks.y = element_line(color = "black", linewidth = 0.4),
        axis.ticks.length = unit(3, "pt"),
        axis.text.x = element_blank(),
        axis.ticks.x = element_blank(),
        axis.title.y = element_blank(),
        plot.margin = margin(t = 0, r = 5, b = -2, l = 5)
      )

    q <- ggplot(h_sub, aes(x = temp, y = weight)) +
      geom_col(fill = "grey50", width = 1) +
      scale_y_continuous(limits = c(0, hist_max), expand = c(0, 0)) +
      scale_x_continuous(
        breaks = x_breaks,
        expand = c(0, 0),
        minor_breaks = NULL
      ) +
      coord_cartesian(xlim = x_limits, expand = FALSE) +
      labs(x = NULL, y = NULL) +
      theme_minimal(base_size = 10) +
      theme(
        panel.grid = element_blank(),
        legend.position = "none",
        axis.line = element_blank(),
        axis.line.y = element_line(color = "black", linewidth = 0.4),
        axis.ticks = element_line(color = "black", linewidth = 0.4),
        axis.ticks.length = unit(3, "pt"),
        axis.text.y = element_blank(),
        axis.ticks.y = element_blank(),
        axis.text.x = element_text(color = "black", size = 8),
        axis.ticks.x = element_line(color = "black", linewidth = 0.4),
        plot.margin = margin(t = -2, r = 5, b = 0, l = 5)
      )

    (p / q) + plot_layout(heights = c(2.0, 0.8))
  }

  wrap_plots(
    lapply(seq_along(risk_list), function(j) make_cell(risk_list[j], is_leftmost = (j == 1))),
    ncol = length(risk_list)
  )
}

#-------------------------------------------------------------------------------
# Combined figure
#-------------------------------------------------------------------------------

sector_header <- wrap_plots(
  plot_spacer(),
  plot_spacer(),
  wrap_plots(
    lapply(risk_list, function(r) make_header_plot(risk_labels[[r]], hjust = 0.5, size = 5.0)),
    ncol = length(risk_list)
  ),
  ncol = 3,
  widths = c(0.14, 0.14, 3)
)

region_rows <- lapply(seq_len(nrow(region_table)), function(i) {
  wrap_plots(
    make_vertical_label_plot(
      region_table$cname[i],
      fontface = "bold",
      size = 5.0
    ),
    make_vertical_label_plot(
      "Minutes worked",
      fontface = "plain",
      size = 4.7
    ),
    make_region_row(
      REG = region_table$REG[i],
      cname = region_table$cname[i]
    ),
    ncol = 3,
    widths = c(0.14, 0.14, 3)
  )
})

fig_3x3 <- (
  sector_header /
    region_rows[[1]] /
    region_rows[[2]] /
    region_rows[[3]]
) +
  plot_layout(heights = c(0.24, 1, 1, 1)) +
  plot_annotation(
    caption = "Temperature (°C)"
  ) &
  theme(
    plot.caption = element_text(hjust = 0.52, face = "plain", size = 13, margin = margin(t = 8))
  )

outfile <- glue("{outpath}/rf_3sector_regions_3x3_{tolower(FRACTION_HIST)}frac_{tolower(WEIGHT_HIST)}wgt.{format}")

ggsave(outfile, plot = fig_3x3, width = 10, height = 8.5)
print(fig_3x3)
cat("Saved:", outfile, "\n")
