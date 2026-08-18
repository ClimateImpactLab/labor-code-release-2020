#-------------------------------------------------------------------------------
# figureD1_functional_form_comparison.R
#-------------------------------------------------------------------------------
# PURPOSE
#   Plot the main temperature response under different functional forms
#
# STEPS
#   1. Read polynomial and spline response functions
#   2. Read binned estimates
#   3. Plot low-risk and high-risk workers by model type
#   4. Save the appendix figure
#
# INPUTS
#   Polynomial response CSVs under ${DIR_RF}/uninteracted_polynomials
#   Spline response CSV under ${DIR_RF}/uninteracted_reg_comlohi
#   Binned estimate CSV under ${DIR_RF}/uninteracted_bins
#
# OUTPUTS
#   Functional-form comparison figures under ${DIR_FIG}
#-------------------------------------------------------------------------------

rm(list = ls())
suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(ggplot2)
  library(glue)
  library(patchwork)
  library(cowplot)
  library(scales)
  library(grid)
  library(purrr)
})

#-------------------------------------------------------------------------------
# Paths
#-------------------------------------------------------------------------------

user <- Sys.info()[["user"]]
source(paste0("/project/cil/home_dirs/", user, "/repos/labor-code-release-2020/0_subroutines/paths.R"))


#-------------------------------------------------------------------------------
# Rectangle helper
#-------------------------------------------------------------------------------
draw_rect_safe <- function(x, y, width, height, fill, color, size = 0.8) {
  cowplot::draw_grob(
    grid::rectGrob(
      x = x, y = y,
      width = width, height = height,
      gp = grid::gpar(fill = fill, col = color, lwd = size)
    )
  )
}

#-------------------------------------------------------------------------------
# Settings
#-------------------------------------------------------------------------------

GRID   <- "full_response"
ORDERS <- c(2, 3, 4)

# Binned model choices
coldcut <- 9
ref_lb  <- 27  # reference bin lower bound: 27–30

rf_poly_dir    <- glue("{DIR_RF}/uninteracted_polynomials")
rf_spline_path <- glue("{DIR_RF}/uninteracted_reg_comlohi/uninteracted_reg_comlohi_full_response_2026_272841.csv")

bins_coef_path <- glue("{DIR_RF}/uninteracted_bins/uninteracted_bins_coefs_3C_coldle{coldcut}_ref{ref_lb}.csv")

outdir  <- glue("{DIR_FIG}/functional_form_comparison")
dir.create(outdir, showWarnings = FALSE, recursive = TRUE)

PLOT_CI <- TRUE

outfile <- if (PLOT_CI) {
  file.path(outdir, glue("figure_D1_functional_form.pdf"))
} else {
  file.path(outdir, glue("figure_D1_functional_form_NO_CI.pdf"))
}

outfile_no_bin_verticals <- if (PLOT_CI) {
  file.path(outdir, glue("figure_D1_functional_form_no_bin_verticals.pdf"))
} else {
  file.path(outdir, glue("figure_D1_functional_form_NO_CI_no_bin_verticals.pdf"))
}

outfile_step_with_ci <- file.path(outdir, glue("figure_D1_functional_form_step_thick_CI.pdf"))
outfile_step_no_ci   <- file.path(outdir, glue("figure_D1_functional_form_step_thick_NO_CI.pdf"))

# Temperature window
X_HARD_MIN <- -5
X_HARD_MAX <- 47

# Y-axis window
Y_HARD_MIN <- -150
Y_HARD_MAX <-  150
Y_BREAK_BY <-   50
y_breaks   <- seq(Y_HARD_MIN, Y_HARD_MAX, by = Y_BREAK_BY)

# Keep very wide confidence intervals inside the plotted y range
cap_ci <- TRUE
ci_cap <- 150

# Place the tail bins near the edge of the main temperature range
PULL_TAILS_IN <- TRUE
TAIL_LOW  <- coldcut - 1.5   # show cold tail just left of first interior midpoint (9–12 midpoint is 10.5)
TAIL_HIGH <- 43.5            #  midpoint hot tail 43.5

# Bin styling
BIN_POINT_SIZE <- 1.0
BIN_STEP_ON    <- TRUE
BIN_LINE_ALPHA <- 0.55
BIN_LINE_LWD   <- 1.35
BIN_CI_LWD     <- 0.30

#-------------------------------------------------------------------------------
# Layout
#-------------------------------------------------------------------------------

panel_margin <- margin(t = 12, r = 10, b = 10, l = 40)
panel_spacing <- 0

RISK_BOX_X <- 0.025
Y_TITLE_X  <- 0.075
RISK_BOX_W <- 0.028
RISK_BOX_H <- 0.32

X_LABEL_Y  <- 0.025

#-------------------------------------------------------------------------------
# Style
#-------------------------------------------------------------------------------

COL_TEXT <- "#243447"

COL_LINE <- "#0B1F5B"
COL_RIB  <- scales::alpha("#2E86FF", 0.18)

COL_BIN_PT <- "#2FA7B0"
COL_BIN_CI <- scales::alpha(COL_BIN_PT, 0.55)
COL_BIN_LN <- scales::alpha(COL_BIN_PT, BIN_LINE_ALPHA)

COL_ZERO   <- "#8B0000"
LTYPE_ZERO <- "44"

HDR_BORDER    <- "#243447"
HDR_FILL_TOP  <- "#DCE7F5"
HDR_FILL_SIDE <- "#E6EEF7"

HDR_SIZE_TOP  <- 11
HDR_SIZE_SIDE <- 11
TITLE_SIZE    <- 15
AXIS_SIZE     <- 12

col_titles <- c(
  "Second-order polynomial",
  "Third-order polynomial",
  "Fourth-order polynomial",
  "Restricted cubic spline"
)

#-------------------------------------------------------------------------------
# Read helpers
#-------------------------------------------------------------------------------

read_rf_file <- function(path, model_label) {
  if (!file.exists(path)) stop("Missing response file: ", path)
  
  df <- read_csv(path, show_col_types = FALSE)
  
  needed <- c(
    "temp",
    "yhat_low","lowerci_low","upperci_low",
    "yhat_high","lowerci_high","upperci_high"
  )
  missing <- setdiff(needed, names(df))
  if (length(missing) > 0) {
    stop("Missing columns in: ", path, "\nMissing: ", paste(missing, collapse = ", "))
  }
  
  df %>% mutate(model = model_label)
}

to_long_risk <- function(df) {
  df %>%
    pivot_longer(
      cols = matches("^(yhat|lowerci|upperci)_(low|high)$"),
      names_to = c(".value", "risk"),
      names_pattern = "^(yhat|lowerci|upperci)_(low|high)$"
    ) %>%
    mutate(
      risk = factor(risk, levels = c("low","high")),
      ymin = pmin(lowerci, upperci),
      ymax = pmax(lowerci, upperci)
    )
}

#-------------------------------------------------------------------------------
# Read response functions
#-------------------------------------------------------------------------------

read_poly_rf <- function(order) {
  f <- glue("{rf_poly_dir}/uninteracted_polynomials_nochn_{order}_{GRID}.csv")
  read_rf_file(f, model_label = paste0(order, "poly"))
}

RF_poly   <- purrr::map_dfr(ORDERS, read_poly_rf)
RF_spline <- read_rf_file(rf_spline_path, model_label = "spline")

RF_all <- bind_rows(RF_poly, RF_spline) %>%
  to_long_risk() %>%
  mutate(model = factor(model, levels = c("2poly","3poly","4poly","spline"))) %>%
  filter(temp >= X_HARD_MIN, temp <= X_HARD_MAX)

#-------------------------------------------------------------------------------
# Read binned estimates
#-------------------------------------------------------------------------------

bins_raw <- read_csv(bins_coef_path, show_col_types = FALSE) %>%
  mutate(
    bin_code = as.character(bin_code),
    ord      = as.numeric(ord),
    is_ref   = as.integer(is_ref),
    temp_mid = as.numeric(temp_mid)
  )

bins_long <- bins_raw %>%
  transmute(
    bin_code, temp_mid, ord, is_ref,
    beta_low  = low,  se_low  = se_low,
    beta_high = high, se_high = se_high
  ) %>%
  pivot_longer(
    cols = c(beta_low, beta_high, se_low, se_high),
    names_to = c(".value", "risk"),
    names_pattern = "^(beta|se)_(low|high)$"
  ) %>%
  mutate(
    risk  = factor(risk, levels = c("low","high")),
    ci_lo = ifelse(!is.na(se), beta - 1.96 * se, NA_real_),
    ci_hi = ifelse(!is.na(se), beta + 1.96 * se, NA_real_)
  )

# Binned regressions estimate one effect for each temperature interval
bins_bounds <- bins_long %>%
  mutate(
    bin_num = suppressWarnings(as.numeric(bin_code)),
    bin_lb = case_when(
      bin_code == glue("below{coldcut}") ~ ifelse(PULL_TAILS_IN, coldcut - 3, X_HARD_MIN),
      bin_code == "above42"              ~ 42,
      TRUE                               ~ bin_num
    ),
    bin_ub = case_when(
      bin_code == glue("below{coldcut}") ~ coldcut,
      bin_code == "above42"              ~ X_HARD_MAX,
      TRUE                               ~ bin_num + 3
    )
  ) %>%
  filter(is.finite(bin_lb), is.finite(bin_ub), bin_ub >= X_HARD_MIN, bin_lb <= X_HARD_MAX) %>%
  mutate(
    bin_lb = pmax(bin_lb, X_HARD_MIN),
    bin_ub = pmin(bin_ub, X_HARD_MAX)
  )

bins_step <- bins_bounds %>%
  arrange(risk, bin_lb, bin_ub) %>%
  group_by(risk) %>%
  group_modify(~ bind_rows(
    .x %>% transmute(temp = bin_lb, beta),
    .x %>% slice_max(bin_ub, n = 1, with_ties = FALSE) %>%
      transmute(temp = bin_ub, beta)
  )) %>%
  ungroup()

bins_bounds_full_coldtail <- bins_bounds %>%
  mutate(
    bin_lb = if_else(bin_code == glue("below{coldcut}"), X_HARD_MIN, bin_lb)
  )

bins_step_full_coldtail <- bins_bounds_full_coldtail %>%
  arrange(risk, bin_lb, bin_ub) %>%
  group_by(risk) %>%
  group_modify(~ bind_rows(
    .x %>% transmute(temp = bin_lb, beta),
    .x %>% slice_max(bin_ub, n = 1, with_ties = FALSE) %>%
      transmute(temp = bin_ub, beta)
  )) %>%
  ungroup()

#-------------------------------------------------------------------------------
# Move tail-bin points
#-------------------------------------------------------------------------------

if (PULL_TAILS_IN) {
  bins_long <- bins_long %>%
    mutate(temp_mid = case_when(
      abs(temp_mid - (coldcut - 6)) < 1e-9 ~ TAIL_LOW,   # below9 plotted at 7.5
      abs(temp_mid - 45) < 1e-9           ~ TAIL_HIGH,  # above42 plotted at 43.5
      TRUE ~ temp_mid
    ))
}

#-------------------------------------------------------------------------------
# Drop the far-left bin point
#-------------------------------------------------------------------------------

bins_long <- bins_long %>% filter(temp_mid >= (coldcut - 1.5))

#-------------------------------------------------------------------------------
# Plot confidence intervals
#-------------------------------------------------------------------------------

if (cap_ci) {
  RF_all <- RF_all %>%
    mutate(
      ymin_plot = pmax(ymin, -ci_cap),
      ymax_plot = pmin(ymax,  ci_cap)
    )

  bins_long <- bins_long %>%
    mutate(
      ci_lo_plot = pmax(ci_lo, -ci_cap),
      ci_hi_plot = pmin(ci_hi,  ci_cap)
    )
} else {
  RF_all <- RF_all %>% mutate(ymin_plot = ymin, ymax_plot = ymax)
  bins_long <- bins_long %>% mutate(ci_lo_plot = ci_lo, ci_hi_plot = ci_hi)
}

#-------------------------------------------------------------------------------
# Axis breaks
#-------------------------------------------------------------------------------

y_common <- c(Y_HARD_MIN, Y_HARD_MAX)
x_breaks <- pretty_breaks(n = 6)(c(X_HARD_MIN, X_HARD_MAX))

#-------------------------------------------------------------------------------
# Panel builder
#-------------------------------------------------------------------------------

axis_theme <- theme(
  panel.grid.minor   = element_blank(),
  panel.grid.major.x = element_blank(),
  panel.grid.major.y = element_line(linewidth = 0.2, color = scales::alpha(COL_TEXT, 0.25)),
  axis.ticks         = element_line(color = COL_TEXT),
  axis.ticks.length  = unit(3, "pt"),
  axis.line.x        = element_line(color = COL_TEXT),
  axis.line.y        = element_line(color = COL_TEXT),
  plot.margin        = panel_margin
)

make_panel <- function(risk_level, model_level, show_y_axis = FALSE,
                       show_bin_verticals = TRUE, plot_ci = PLOT_CI,
                       bin_bounds_df = bins_bounds, bin_step_df = bins_step,
                       show_bin_points = TRUE) {
  
  P <- RF_all %>%
    filter(risk == risk_level, model == model_level) %>%
    arrange(temp)
  
  B <- bins_long %>%
    filter(risk == risk_level) %>%
    arrange(temp_mid)
  
  ggplot() +
    geom_hline(yintercept = 0, color = COL_ZERO, linetype = LTYPE_ZERO, linewidth = 0.55) +
    
    { if (plot_ci) geom_ribbon(
      data = P %>% filter(is.finite(ymin_plot), is.finite(ymax_plot)),
      aes(x = temp, ymin = ymin_plot, ymax = ymax_plot),
      fill = COL_RIB, color = NA
    ) } +
    
    geom_line(
      data = P,
      aes(x = temp, y = yhat),
      color = COL_LINE, linewidth = 1.05
    ) +
    
    { if (BIN_STEP_ON && show_bin_verticals) geom_step(
      data = bin_step_df %>% filter(risk == risk_level),
      aes(x = temp, y = beta),
      direction = "hv",
      linewidth = BIN_LINE_LWD,
      color = COL_BIN_LN
    ) } +

    { if (BIN_STEP_ON && !show_bin_verticals) geom_segment(
      data = bin_bounds_df %>% filter(risk == risk_level),
      aes(x = bin_lb, xend = bin_ub, y = beta, yend = beta),
      linewidth = BIN_LINE_LWD,
      color = COL_BIN_LN,
      lineend = "butt"
    ) } +
    
    { if (plot_ci) geom_errorbar(
      data = B,
      aes(x = temp_mid, ymin = ci_lo_plot, ymax = ci_hi_plot),
      width = 0.55, linewidth = BIN_CI_LWD,
      color = COL_BIN_CI
    ) } +
    
    { if (show_bin_points) geom_point(
      data = B,
      aes(x = temp_mid, y = beta),
      size = BIN_POINT_SIZE,
      color = COL_BIN_PT
    ) } +
    
    scale_x_continuous(breaks = x_breaks, expand = c(0, 0)) +
    
    scale_y_continuous(
      breaks = y_breaks,
      limits = c(Y_HARD_MIN, Y_HARD_MAX),
      expand = c(0, 0)
    ) +
    
    coord_cartesian(
      xlim = c(X_HARD_MIN, X_HARD_MAX),
      ylim = y_common,
      expand = FALSE
    ) +
    
    labs(x = NULL, y = NULL) +
    theme_minimal(base_size = AXIS_SIZE) +
    axis_theme +
    theme(
      text = element_text(color = COL_TEXT),
      axis.text.y  = if (show_y_axis) element_text(color = COL_TEXT) else element_blank(),
      axis.ticks.y = if (show_y_axis) element_line(color = COL_TEXT) else element_blank()
    )
}

#-------------------------------------------------------------------------------
# Build 2 x 4 figure
#-------------------------------------------------------------------------------

p_low <- list(
  make_panel("low",  "2poly",  TRUE),
  make_panel("low",  "3poly",  FALSE),
  make_panel("low",  "4poly",  FALSE),
  make_panel("low",  "spline", FALSE)
)

p_high <- list(
  make_panel("high", "2poly",  TRUE),
  make_panel("high", "3poly",  FALSE),
  make_panel("high", "4poly",  FALSE),
  make_panel("high", "spline", FALSE)
)

grid_panels <- (p_low[[1]] | p_low[[2]] | p_low[[3]] | p_low[[4]]) /
  (p_high[[1]]| p_high[[2]]| p_high[[3]]| p_high[[4]])

grid_panels <- grid_panels & theme(panel.spacing = unit(panel_spacing, "lines"))

#-------------------------------------------------------------------------------
# Headers and side labels
#-------------------------------------------------------------------------------

title_txt <- if (PLOT_CI) {
  "Alternative Functional Forms"
} else {
  "Alternative Functional Forms (No Confidence Intervals)"
}

title_bar <- cowplot::ggdraw() +
  cowplot::draw_label(
    title_txt,
    x = 0.5, y = 0.5,
    hjust = 0.5, vjust = 0.5,
    fontface = "bold", size = TITLE_SIZE, color = COL_TEXT
  )

TOP_Y     <- 0.50
TOP_BOX_W <- 0.23
TOP_BOX_H <- 0.78
TOP_LWD   <- 0.95

header <- cowplot::ggdraw() +
  draw_rect_safe(x = 1/8, y = TOP_Y, width = TOP_BOX_W, height = TOP_BOX_H,
                 fill = HDR_FILL_TOP, color = HDR_BORDER, size = TOP_LWD) +
  draw_rect_safe(x = 3/8, y = TOP_Y, width = TOP_BOX_W, height = TOP_BOX_H,
                 fill = HDR_FILL_TOP, color = HDR_BORDER, size = TOP_LWD) +
  draw_rect_safe(x = 5/8, y = TOP_Y, width = TOP_BOX_W, height = TOP_BOX_H,
                 fill = HDR_FILL_TOP, color = HDR_BORDER, size = TOP_LWD) +
  draw_rect_safe(x = 7/8, y = TOP_Y, width = TOP_BOX_W, height = TOP_BOX_H,
                 fill = HDR_FILL_TOP, color = HDR_BORDER, size = TOP_LWD) +
  cowplot::draw_label(col_titles[1], x = 1/8, y = TOP_Y,
                      fontface = "bold", size = HDR_SIZE_TOP + 2, color = HDR_BORDER) +
  cowplot::draw_label(col_titles[2], x = 3/8, y = TOP_Y,
                      fontface = "bold", size = HDR_SIZE_TOP + 2, color = HDR_BORDER) +
  cowplot::draw_label(col_titles[3], x = 5/8, y = TOP_Y,
                      fontface = "bold", size = HDR_SIZE_TOP + 2, color = HDR_BORDER) +
  cowplot::draw_label(col_titles[4], x = 7/8, y = TOP_Y,
                      fontface = "bold", size = HDR_SIZE_TOP + 2, color = HDR_BORDER)

annotated <- (header / grid_panels) + patchwork::plot_layout(heights = c(0.07, 1))

body <- cowplot::ggdraw(annotated) +
  draw_rect_safe(x = RISK_BOX_X, y = 0.74, width = RISK_BOX_W, height = RISK_BOX_H,
                 fill = HDR_FILL_SIDE, color = HDR_BORDER, size = 0.95) +
  draw_rect_safe(x = RISK_BOX_X, y = 0.27, width = RISK_BOX_W, height = RISK_BOX_H,
                 fill = HDR_FILL_SIDE, color = HDR_BORDER, size = 0.95) +
  cowplot::draw_label("Low-risk workers", x = RISK_BOX_X, y = 0.74,
                      angle = 90, fontface = "bold",
                      size = HDR_SIZE_SIDE + 2, color = HDR_BORDER) +
  cowplot::draw_label("High-risk workers", x = RISK_BOX_X, y = 0.27,
                      angle = 90, fontface = "bold",
                      size = HDR_SIZE_SIDE + 2, color = HDR_BORDER) +
  cowplot::draw_label("Daily Temperature (°C)", x = 0.52, y = X_LABEL_Y,
                      fontface = "bold", size = 12, color = COL_TEXT) +
  cowplot::draw_label("Minutes worked", x = Y_TITLE_X, y = 0.52,
                      angle = 90, fontface = "bold", size = 12, color = COL_TEXT)

final <- (title_bar / body) + patchwork::plot_layout(heights = c(0.08, 1))

ggsave(outfile, plot = final, width = 12.5, height = 6.5, device = "pdf")
message("Saved: ", outfile)

ggsave(outfile_step_with_ci, plot = final, width = 12.5, height = 6.5, device = "pdf")
message("Saved: ", outfile_step_with_ci)

p_low_step_no_ci <- list(
  make_panel("low",  "2poly",  TRUE,  show_bin_verticals = TRUE, plot_ci = FALSE,
             bin_bounds_df = bins_bounds_full_coldtail, bin_step_df = bins_step_full_coldtail,
             show_bin_points = FALSE),
  make_panel("low",  "3poly",  FALSE, show_bin_verticals = TRUE, plot_ci = FALSE,
             bin_bounds_df = bins_bounds_full_coldtail, bin_step_df = bins_step_full_coldtail,
             show_bin_points = FALSE),
  make_panel("low",  "4poly",  FALSE, show_bin_verticals = TRUE, plot_ci = FALSE,
             bin_bounds_df = bins_bounds_full_coldtail, bin_step_df = bins_step_full_coldtail,
             show_bin_points = FALSE),
  make_panel("low",  "spline", FALSE, show_bin_verticals = TRUE, plot_ci = FALSE,
             bin_bounds_df = bins_bounds_full_coldtail, bin_step_df = bins_step_full_coldtail,
             show_bin_points = FALSE)
)

p_high_step_no_ci <- list(
  make_panel("high", "2poly",  TRUE,  show_bin_verticals = TRUE, plot_ci = FALSE,
             bin_bounds_df = bins_bounds_full_coldtail, bin_step_df = bins_step_full_coldtail,
             show_bin_points = FALSE),
  make_panel("high", "3poly",  FALSE, show_bin_verticals = TRUE, plot_ci = FALSE,
             bin_bounds_df = bins_bounds_full_coldtail, bin_step_df = bins_step_full_coldtail,
             show_bin_points = FALSE),
  make_panel("high", "4poly",  FALSE, show_bin_verticals = TRUE, plot_ci = FALSE,
             bin_bounds_df = bins_bounds_full_coldtail, bin_step_df = bins_step_full_coldtail,
             show_bin_points = FALSE),
  make_panel("high", "spline", FALSE, show_bin_verticals = TRUE, plot_ci = FALSE,
             bin_bounds_df = bins_bounds_full_coldtail, bin_step_df = bins_step_full_coldtail,
             show_bin_points = FALSE)
)

grid_panels_step_no_ci <- (
  p_low_step_no_ci[[1]] |
    p_low_step_no_ci[[2]] |
    p_low_step_no_ci[[3]] |
    p_low_step_no_ci[[4]]
) / (
  p_high_step_no_ci[[1]] |
    p_high_step_no_ci[[2]] |
    p_high_step_no_ci[[3]] |
    p_high_step_no_ci[[4]]
)

grid_panels_step_no_ci <- grid_panels_step_no_ci &
  theme(panel.spacing = unit(panel_spacing, "lines"))

annotated_step_no_ci <- (header / grid_panels_step_no_ci) +
  patchwork::plot_layout(heights = c(0.07, 1))

body_step_no_ci <- cowplot::ggdraw() +
  cowplot::draw_plot(annotated_step_no_ci, x = 0.045, y = 0.055, width = 0.95, height = 0.925) +
  draw_rect_safe(x = RISK_BOX_X, y = 0.74, width = RISK_BOX_W, height = RISK_BOX_H,
                 fill = HDR_FILL_SIDE, color = HDR_BORDER, size = 0.95) +
  draw_rect_safe(x = RISK_BOX_X, y = 0.27, width = RISK_BOX_W, height = RISK_BOX_H,
                 fill = HDR_FILL_SIDE, color = HDR_BORDER, size = 0.95) +
  cowplot::draw_label("Low-risk workers", x = RISK_BOX_X, y = 0.74,
                      angle = 90, fontface = "bold",
                      size = HDR_SIZE_SIDE + 2, color = HDR_BORDER) +
  cowplot::draw_label("High-risk workers", x = RISK_BOX_X, y = 0.27,
                      angle = 90, fontface = "bold",
                      size = HDR_SIZE_SIDE + 2, color = HDR_BORDER) +
  cowplot::draw_label("Daily Temperature (°C)", x = 0.52, y = X_LABEL_Y,
                      fontface = "bold", size = 12, color = COL_TEXT) +
  cowplot::draw_label("Minutes worked", x = Y_TITLE_X, y = 0.52,
                      angle = 90, fontface = "bold", size = 12, color = COL_TEXT)

final_step_no_ci <- body_step_no_ci

ggsave(outfile_step_no_ci, plot = final_step_no_ci,
       width = 12.5, height = 6.5, device = "pdf")
message("Saved: ", outfile_step_no_ci)

p_low_no_bin_verticals <- list(
  make_panel("low",  "2poly",  TRUE,  show_bin_verticals = FALSE),
  make_panel("low",  "3poly",  FALSE, show_bin_verticals = FALSE),
  make_panel("low",  "4poly",  FALSE, show_bin_verticals = FALSE),
  make_panel("low",  "spline", FALSE, show_bin_verticals = FALSE)
)

p_high_no_bin_verticals <- list(
  make_panel("high", "2poly",  TRUE,  show_bin_verticals = FALSE),
  make_panel("high", "3poly",  FALSE, show_bin_verticals = FALSE),
  make_panel("high", "4poly",  FALSE, show_bin_verticals = FALSE),
  make_panel("high", "spline", FALSE, show_bin_verticals = FALSE)
)

grid_panels_no_bin_verticals <- (
  p_low_no_bin_verticals[[1]] |
    p_low_no_bin_verticals[[2]] |
    p_low_no_bin_verticals[[3]] |
    p_low_no_bin_verticals[[4]]
) / (
  p_high_no_bin_verticals[[1]] |
    p_high_no_bin_verticals[[2]] |
    p_high_no_bin_verticals[[3]] |
    p_high_no_bin_verticals[[4]]
)

grid_panels_no_bin_verticals <- grid_panels_no_bin_verticals &
  theme(panel.spacing = unit(panel_spacing, "lines"))

annotated_no_bin_verticals <- (header / grid_panels_no_bin_verticals) +
  patchwork::plot_layout(heights = c(0.07, 1))

body_no_bin_verticals <- cowplot::ggdraw(annotated_no_bin_verticals) +
  draw_rect_safe(x = RISK_BOX_X, y = 0.74, width = RISK_BOX_W, height = RISK_BOX_H,
                 fill = HDR_FILL_SIDE, color = HDR_BORDER, size = 0.95) +
  draw_rect_safe(x = RISK_BOX_X, y = 0.27, width = RISK_BOX_W, height = RISK_BOX_H,
                 fill = HDR_FILL_SIDE, color = HDR_BORDER, size = 0.95) +
  cowplot::draw_label("Low-risk workers", x = RISK_BOX_X, y = 0.74,
                      angle = 90, fontface = "bold",
                      size = HDR_SIZE_SIDE + 2, color = HDR_BORDER) +
  cowplot::draw_label("High-risk workers", x = RISK_BOX_X, y = 0.27,
                      angle = 90, fontface = "bold",
                      size = HDR_SIZE_SIDE + 2, color = HDR_BORDER) +
  cowplot::draw_label("Daily Temperature (°C)", x = 0.52, y = X_LABEL_Y,
                      fontface = "bold", size = 12, color = COL_TEXT) +
  cowplot::draw_label("Minutes worked", x = Y_TITLE_X, y = 0.52,
                      angle = 90, fontface = "bold", size = 12, color = COL_TEXT)

final_no_bin_verticals <- (title_bar / body_no_bin_verticals) +
  patchwork::plot_layout(heights = c(0.08, 1))

ggsave(outfile_no_bin_verticals, plot = final_no_bin_verticals,
       width = 12.5, height = 6.5, device = "pdf")
message("Saved: ", outfile_no_bin_verticals)
