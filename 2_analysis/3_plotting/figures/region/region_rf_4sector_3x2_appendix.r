#-------------------------------------------------------------------------------
# region_rf_4sector_3x2_appendix.R
#-------------------------------------------------------------------------------
#
# PURPOSE
#   Plot a 3 x 2 regional temperature-response figure for the 4-sector model
#
# STEPS
#   1. Choose the 4-sector response folder
#   2. Read regional response CSVs and temperature-distribution CSVs
#   3. Reshape response and histogram data for manufacturing and construction/mining
#   4. Draw one row per region and one column per sector
#   5. Save the combined PDF figure
#
# INPUTS
#   Region 4-sector response CSVs under ${DIR_RF}
#   Region 4-sector temperature-distribution CSVs under ${DIR_OUTPUT}
#
# OUTPUTS
#   3 x 2 regional 4-sector response figure under ${DIR_FIG}
#-------------------------------------------------------------------------------

rm(list = ls())

library(dplyr)
library(ggplot2)
library(patchwork)
library(readr)
library(glue)
library(data.table)

user <- "mdefranciosi"

source(paste0(
  "/project/cil/home_dirs/", user,
  "/repos/labor-code-release-2020/0_subroutines/paths.R"
))
source(paste0(
  "/project/cil/home_dirs/", user,
  "/repos/labor-code-release-2020/2_analysis/0_subroutines/functions.R"
))

#-------------------------------------------------------------------------------
# Output folder and options
#-------------------------------------------------------------------------------

MODEL_VARIANT <- Sys.getenv("MODEL_VARIANT", unset = "standard")

if (!MODEL_VARIANT %in% c("standard", "temp_split")) {
  stop("MODEL_VARIANT must be 'standard' or 'temp_split'.", call. = FALSE)
}

if (MODEL_VARIANT == "temp_split") {
  model_dir <- "uninteracted_reg_region_4sector_temp_split"
  file_suffix <- "4sector_temp_split"
  plot_dir <- "region_rf_plots_4sector_temp_split"
} else {
  model_dir <- "uninteracted_reg_region_4sector"
  file_suffix <- "4sector"
  plot_dir <- "region_rf_plots_4sector"
}

outpath <- glue("{DIR_FIG}/{plot_dir}")
dir.create(outpath, showWarnings = FALSE, recursive = TRUE)

format <- "pdf"

FRACTION_HIST <- "YES"
WEIGHT_HIST <- "YES"
ZERO_LINE_COLOR <- "grey40"

risk_list <- c("mt", "cm")

risk_labels <- c(
  mt = "Manufacturing",
  cm = "Construction &\nMining"
)

region_table <- tibble::tibble(
  REG   = c("EuropeUS", "LatinAmerica", "SouthAsia"),
  cname = c("U.S.", "Latin America", "India")
)

# Use tighter U.S. and India y-axes because this figure leaves out agriculture
region_y_limits <- tibble::tibble(
  REG        = c("EuropeUS", "LatinAmerica", "SouthAsia"),
  STOP_CI_AT = c(-150, -20, -100),
  Y_TOP      = c(100, 20, 150),
  Y_BREAK_BY = c(50, 10, 50)
)

#-------------------------------------------------------------------------------
# Input paths
#-------------------------------------------------------------------------------

rf_region_path <- function(REG) {
  glue(
    "{DIR_RF}/{model_dir}/",
    "{REG}/rf_{REG}_full_{file_suffix}.csv"
  )
}

td_region_path <- function(REG) {
  glue(
    "{DIR_OUTPUT}/temp_dist/region_4sector/",
    "{REG}_temp_dist_4sector.csv"
  )
}

#-------------------------------------------------------------------------------
# Reshape helpers
#-------------------------------------------------------------------------------

reshape_rf <- function(name, df) {
  df %>%
    transmute(
      temp,
      yhat = .data[[paste0("yhat_", name)]],
      lowerci = .data[[paste0("lowerci_", name)]],
      upperci = .data[[paste0("upperci_", name)]],
      risk = name
    )
}

reshape_hist <- function(name, df, var_prefix) {
  df %>%
    transmute(
      temp,
      weight = .data[[paste0(var_prefix, "_", name)]],
      risk = name
    )
}

build_hist_df <- function(temp_dist) {
  if (FRACTION_HIST == "YES" && WEIGHT_HIST == "YES") {
    var_prefix <- "frac_risk_wgt"
  } else if (FRACTION_HIST == "NO" && WEIGHT_HIST == "YES") {
    var_prefix <- "risk_wgt"
  } else if (FRACTION_HIST == "YES" && WEIGHT_HIST == "NO") {
    var_prefix <- "frac_no_wgt"
  } else if (FRACTION_HIST == "NO" && WEIGHT_HIST == "NO") {
    var_prefix <- "no_wgt"
  } else {
    stop("FRACTION_HIST and WEIGHT_HIST must each be YES or NO.")
  }

  rbindlist(
    lapply(
      risk_list,
      reshape_hist,
      df = temp_dist,
      var_prefix = var_prefix
    ),
    use.names = TRUE
  ) %>%
    mutate(risk = factor(risk, levels = risk_list))
}

make_header_plot <- function(label, size = 5.0) {
  ggplot() +
    annotate(
      "text",
      x = 0.5,
      y = 0.5,
      label = label,
      hjust = 0.5,
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
  Y_TOP <- ylim_sub$Y_TOP
  Y_BREAK_BY <- ylim_sub$Y_BREAK_BY

  y_breaks <- if (is.na(Y_BREAK_BY)) {
    waiver()
  } else {
    seq(STOP_CI_AT, Y_TOP, by = Y_BREAK_BY)
  }

  rf_region_file <- rf_region_path(REG)
  td_file <- td_region_path(REG)

  if (!file.exists(rf_region_file)) {
    stop(glue("Missing response file: {rf_region_file}"), call. = FALSE)
  }
  if (!file.exists(td_file)) {
    stop(glue("Missing temp-dist file: {td_file}"), call. = FALSE)
  }

  message("--------------------------------------------------")
  message("REG = ", REG, " (", cname, ")")
  message("--------------------------------------------------")

  rf_region <- read_csv(rf_region_file, show_col_types = FALSE)
  temp_dist <- read_csv(td_file, show_col_types = FALSE)

  rf_region_long <- rbindlist(
    lapply(risk_list, reshape_rf, df = rf_region),
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

  if (
    any(!is.finite(x_limits)) ||
    x_limits[1] >= x_limits[2]
  ) {
    stop(
      glue("Bad histogram-derived x limits for {REG}."),
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
  x_breaks <- x_breaks[
    x_breaks >= x_limits[1] & x_breaks <= x_limits[2]
  ]

  make_cell <- function(r) {
    d_region <- rf_region_long %>% filter(risk == r)
    h_sub <- hist_df %>% filter(risk == r)

    hist_max <- max(h_sub$weight, na.rm = TRUE)
    if (!is.finite(hist_max) || hist_max <= 0) {
      hist_max <- 1
    }

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
      labs(x = NULL, y = NULL) +
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
      scale_y_continuous(
        limits = c(0, hist_max),
        expand = c(0, 0)
      ) +
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
    lapply(risk_list, make_cell),
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
    lapply(risk_list, function(r) make_header_plot(risk_labels[[r]])),
    ncol = length(risk_list)
  ),
  ncol = 3,
  widths = c(0.14, 0.14, 2)
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
    widths = c(0.14, 0.14, 2)
  )
})

fig_3x2 <- (
  sector_header /
    region_rows[[1]] /
    region_rows[[2]] /
    region_rows[[3]]
) +
  plot_layout(heights = c(0.24, 1, 1, 1)) +
  plot_annotation(caption = "Temperature (°C)") &
  theme(
    plot.caption = element_text(
      hjust = 0.53,
      face = "plain",
      size = 13,
      margin = margin(t = 8)
    )
  )

outfile <- glue(
  "{outpath}/rf_{file_suffix}_regions_3x2_",
  "{tolower(FRACTION_HIST)}frac_{tolower(WEIGHT_HIST)}wgt.{format}"
)

ggsave(
  outfile,
  plot = fig_3x2,
  width = 7.2,
  height = 8.5,
  bg = "white"
)
print(fig_3x2)
cat("Saved:", outfile, "\n")
