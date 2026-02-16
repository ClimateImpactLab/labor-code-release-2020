# ============================================================
# GLOBAL Figure: Robustness to alternative functional forms
# 4 columns: 2nd poly | 3rd poly | 4th poly | Restricted cubic spline
# 2 rows:    Low-risk (top) | High-risk (bottom)
#
# Each panel overlays:
#   (1) Response function (RF) curve + OPTIONAL 95% CI ribbon
#   (2) Binned estimates (points) + OPTIONAL 95% CI error bars (+ optional connecting line)
#
# Spec used for bin overlay:
#   - Cold tail: below 9°C (below9)
#   - Interior bins: 9–12, 12–15, ..., 39–42 (b3C_9 ... b3C_39)
#   - Upper tail: above 42°C (above42)
#   - Reference bin in regression: 27–30°C (b3C_27 omitted)  => ref = 27
#
#  CI Cap:
#   We CAP plotted CIs at ±CI_CAP minutes for readability.
#   This only affects displayed ribbons/error bars, not the estimates.
# ============================================================

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

# ------------------------------------------------------------
# Paths 
# ------------------------------------------------------------

user <- Sys.info()[["user"]]
source(paste0("/project/cil/home_dirs/", user, "/repos/labor-code-release-2020/0_subroutines/paths.R"))


# ------------------------------------------------------------
# Safe rectangle helper (cowplot-stable across versions)
# ------------------------------------------------------------
draw_rect_safe <- function(x, y, width, height, fill, color, size = 0.8) {
  cowplot::draw_grob(
    grid::rectGrob(
      x = x, y = y,
      width = width, height = height,
      gp = grid::gpar(fill = fill, col = color, lwd = size)
    )
  )
}

# ============================================================
# SETTINGS
# ============================================================

GRID   <- "full_response"
ORDERS <- c(2, 3, 4)

# ---- Bin overlay spec ----
coldcut <- 9
ref_lb  <- 27  # reference bin lower bound: 27–30

# Inputs
rf_poly_dir    <- glue("{DIR_RF}/uninteracted_polynomials")
rf_spline_path <- glue("{DIR_RF}/uninteracted_reg_comlohi/uninteracted_reg_comlohi_full_response_agnonag_2026.csv")

# Bins overlay coefficients from Stata extraction
bins_coef_path <- glue("{DIR_RF}/uninteracted_bins/uninteracted_bins_coefs_3C_coldle{coldcut}_ref{ref_lb}.csv")

# Output
outdir  <- glue("{DIR_FIG}/functional_form_comparison")
dir.create(outdir, showWarnings = FALSE, recursive = TRUE)

############################################
###  CHANGE: SET CI OPTION TRUE OR FAlSE ###
############################################

PLOT_CI <- TRUE   # set FALSE for "NO CI" version

outfile <- if (PLOT_CI) {
  file.path(outdir, glue("figure_D1_functional_form.pdf"))
} else {
  file.path(outdir, glue("figure_D1_functional_form_NO_CI.pdf"))
}

# X window
X_HARD_MIN <- -5
X_HARD_MAX <- 47

# ------------------------------------------------------------
# Y AXIS: FORCE fixed window + fixed ticks
# ------------------------------------------------------------
Y_HARD_MIN <- -150
Y_HARD_MAX <-  150
Y_BREAK_BY <-   50
y_breaks   <- seq(Y_HARD_MIN, Y_HARD_MAX, by = Y_BREAK_BY)

# Plot-only CI cap (still applied to the ribbon/error bars)
# Confidence intervals going above/below +150/-150 mins worked are not plotted. 
CAP_CI <- TRUE
CI_CAP <- 150

# Pull tails: defining midpoints of cold and hot tails ()
PULL_TAILS_IN <- TRUE
TAIL_LOW  <- coldcut - 1.5   # show cold tail just left of first interior midpoint (9–12 midpoint is 10.5)
TAIL_HIGH <- 43.5            #  midpoint hot tail 43.5

# Bin styling
BIN_POINT_SIZE <- 1.0
BIN_LINE_ON    <- TRUE
BIN_LINE_ALPHA <- 0.55
BIN_LINE_LWD   <- 1.35
BIN_CI_LWD     <- 0.30

# ============================================================
# LAYOUT TUNING
# ============================================================

PANEL_MARGIN  <- margin(t = 12, r = 10, b = 10, l = 40)
PANEL_SPACING <- 0

RISK_BOX_X <- 0.010
Y_TITLE_X  <- 0.040
RISK_BOX_W <- 0.028
RISK_BOX_H <- 0.32

X_LABEL_Y  <- 0.006

# ============================================================
# STYLING
# ============================================================

COL_TEXT <- "#243447"

# RF curve + ribbon
COL_LINE <- "#0B1F5B"
COL_RIB  <- scales::alpha("#2E86FF", 0.18)

# Bin points + CI
COL_BIN_PT <- "#2FA7B0"
COL_BIN_CI <- scales::alpha(COL_BIN_PT, 0.55)
COL_BIN_LN <- scales::alpha(COL_BIN_PT, BIN_LINE_ALPHA)

# Zero line
COL_ZERO   <- "#8B0000"
LTYPE_ZERO <- "44"

# Headers
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

# ============================================================
# HELPERS: read + validate RF files
# ============================================================

read_rf_file <- function(path, model_label) {
  if (!file.exists(path)) stop("Missing RF file: ", path)
  
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

# ============================================================
# LOAD: Response functions (polys + spline)
# ============================================================

read_poly_rf <- function(order) {
  f <- glue("{rf_poly_dir}/uninteracted_polynomials_{order}_{GRID}.csv")
  read_rf_file(f, model_label = paste0(order, "2poly") ) # placeholder: overwritten below
}

# ### CHANGE: keep your original labels exactly
read_poly_rf <- function(order) {
  f <- glue("{rf_poly_dir}/uninteracted_polynomials_{order}_{GRID}.csv")
  read_rf_file(f, model_label = paste0(order, "poly"))
}

RF_poly   <- purrr::map_dfr(ORDERS, read_poly_rf)
RF_spline <- read_rf_file(rf_spline_path, model_label = "spline")

RF_all <- bind_rows(RF_poly, RF_spline) %>%
  to_long_risk() %>%
  mutate(model = factor(model, levels = c("2poly","3poly","4poly","spline"))) %>%
  filter(temp >= X_HARD_MIN, temp <= X_HARD_MAX)

# ============================================================
# LOAD: Bin coefficients -> long + CIs
# ============================================================

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

# ============================================================
# Cosmetic: pull tails inward — APPLY ONLY TO BIN POINTS
# ============================================================

if (PULL_TAILS_IN) {
  bins_long <- bins_long %>%
    mutate(temp_mid = case_when(
      abs(temp_mid - (coldcut - 6)) < 1e-9 ~ TAIL_LOW,   # below9 plotted at 7.5
      abs(temp_mid - 45) < 1e-9           ~ TAIL_HIGH,  # above42 plotted at 43.5
      TRUE ~ temp_mid
    ))
}

# ============================================================
# Filtering left tail of bins (large coef - very low data support)
# ============================================================

bins_long <- bins_long %>% filter(temp_mid >= (coldcut - 1.5))

# ============================================================
# Plot-only CI truncation (ONLY if plotting CI)
# ============================================================

# ### CHANGE: wrap in if (PLOT_CI)
if (PLOT_CI) {
  if (CAP_CI) {
    RF_all <- RF_all %>%
      mutate(
        ymin_plot = pmax(ymin, -CI_CAP),
        ymax_plot = pmin(ymax,  CI_CAP)
      )
    
    bins_long <- bins_long %>%
      mutate(
        ci_lo_plot = pmax(ci_lo, -CI_CAP),
        ci_hi_plot = pmin(ci_hi,  CI_CAP)
      )
  } else {
    RF_all <- RF_all %>% mutate(ymin_plot = ymin, ymax_plot = ymax)
    bins_long <- bins_long %>% mutate(ci_lo_plot = ci_lo, ci_hi_plot = ci_hi)
  }
}

# ============================================================
# FIXED y-lims (force -150..150)
# ============================================================

y_common <- c(Y_HARD_MIN, Y_HARD_MAX)
x_breaks <- pretty_breaks(n = 6)(c(X_HARD_MIN, X_HARD_MAX))

# ============================================================
# Panel builder
# ============================================================

axis_theme <- theme(
  panel.grid.minor   = element_blank(),
  panel.grid.major.x = element_blank(),
  panel.grid.major.y = element_line(linewidth = 0.2, alpha = 0.25),
  axis.ticks         = element_line(color = COL_TEXT),
  axis.ticks.length  = unit(3, "pt"),
  axis.line.x        = element_line(color = COL_TEXT),
  axis.line.y        = element_line(color = COL_TEXT),
  plot.margin        = PANEL_MARGIN
)

make_panel <- function(risk_level, model_level, show_y_axis = FALSE) {
  
  P <- RF_all %>%
    filter(risk == risk_level, model == model_level) %>%
    arrange(temp)
  
  B <- bins_long %>%
    filter(risk == risk_level) %>%
    arrange(temp_mid)
  
  ggplot() +
    geom_hline(yintercept = 0, color = COL_ZERO, linetype = LTYPE_ZERO, linewidth = 0.55) +
    
    # ### CHANGE: optional RF ribbon
    { if (PLOT_CI) geom_ribbon(
      data = P %>% filter(is.finite(ymin_plot), is.finite(ymax_plot)),
      aes(x = temp, ymin = ymin_plot, ymax = ymax_plot),
      fill = COL_RIB, color = NA
    ) } +
    
    geom_line(
      data = if (PLOT_CI) P else P,
      aes(x = temp, y = yhat),
      color = COL_LINE, linewidth = 1.05
    ) +
    
    { if (BIN_LINE_ON) geom_line(
      data = B,
      aes(x = temp_mid, y = beta),
      linewidth = BIN_LINE_LWD,
      color = COL_BIN_LN
    ) } +
    
    # ### CHANGE: optional bin error bars
    { if (PLOT_CI) geom_errorbar(
      data = B,
      aes(x = temp_mid, ymin = ci_lo_plot, ymax = ci_hi_plot),
      width = 0.55, linewidth = BIN_CI_LWD,
      color = COL_BIN_CI
    ) } +
    
    geom_point(
      data = B,
      aes(x = temp_mid, y = beta),
      size = BIN_POINT_SIZE,
      color = COL_BIN_PT
    ) +
    
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

# ============================================================
# Build 2x4 grid
# ============================================================

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

grid_panels <- grid_panels & theme(panel.spacing = unit(PANEL_SPACING, "lines"))

# ============================================================
# Headers + side labels 
# ============================================================

# ### CHANGE: title reflects CI option (small change only)
title_txt <- if (PLOT_CI) {
  "Robustness to Alternative Functional Forms"
} else {
  "Robustness to Alternative Functional Forms (No Confidence Intervals)"
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
message("✔ Saved: ", outfile)
