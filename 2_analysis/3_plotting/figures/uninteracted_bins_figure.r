# ============================================================
# GLOBAL Binned Temperature–Labor Response Plots
#
# Produces global 3°C-bin coefficient figures (Low vs High Risk):
#   • Top panel: binned coefficients (points + line + 95% CI)
#   • Bottom panel: weighted temperature distribution (histogram)
#   • Two columns: Low-risk | High-risk
#
# MAIN SPECIFICATION:
#   Cold tail ≤ 9°C, reference bin 27–30°C (ref27)
#
# OPTIONAL SPECS:
#   • Baseline new risk (original 3°C bins)
#   • Baseline old risk
#   • Cold tail ≤ 9°C, reference 24–27°C
#
# Author: Marine de Franciosi
# Last modified: 12/17/2025
# ============================================================


rm(list = ls())
suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tidyr)
  library(ggplot2)
  library(glue)
  library(patchwork)
  library(scales)
})

# ------------------------------------------------------------
# Paths
# ------------------------------------------------------------

user <- Sys.info()[["user"]]
source(paste0("/project/cil/home_dirs/", user, "/repos/labor-code-release-2020/0_subroutines/paths.R"))
source(paste0("/project/cil/home_dirs/", user, "/repos/labor-code-release-2020/2_analysis/0_subroutines/functions.R"))



# ------------------------------------------------------------
# USER SWITCHES (set TRUE/FALSE)
# ------------------------------------------------------------
PLOT_MAIN_COLDLE9_REF27  <- TRUE   # <-- MAIN
PLOT_COLDLE9_REF24       <- FALSE

PLOT_BASELINE_NEW_RISK   <- FALSE
PLOT_BASELINE_OLD_RISK   <- FALSE

# ------------------------------------------------------------
# Inputs 
# ------------------------------------------------------------

# Coefs
COEFS_BASELINE_NEW   <- glue(DIR_RF,     "/uninteracted_bins/uninteracted_bins_coefs_3C_highrisk.csv")
COEFS_BASELINE_OLD   <- glue(DIR_RF,     "/uninteracted_bins/uninteracted_bins_coefs_3C_highrisk_old.csv")
COEFS_COLDLE9_REF24  <- glue(DIR_RF,     "/uninteracted_bins/uninteracted_bins_coefs_3C_coldle9_ref24.csv")
COEFS_COLDLE9_REF27  <- glue(DIR_RF,     "/uninteracted_bins/uninteracted_bins_coefs_3C_coldle9_ref27.csv")

# Temp support
SUPPORT_BASELINE_NEW <- glue(DIR_OUTPUT, "/temp_dist/temp_support_bins/temp_support_global_weighted_risk.csv")
SUPPORT_BASELINE_OLD <- glue(DIR_OUTPUT, "/temp_dist/temp_support_bins/temp_support_global_weighted_old_risk.csv")
SUPPORT_COLDLE9      <- glue(DIR_OUTPUT, "/temp_dist/temp_support_bins/temp_support_global_weighted_risk_coldle9.csv")

# ------------------------------------------------------------
# Output folder
# ------------------------------------------------------------
outdir <- file.path(DIR_FIG, "uninteracted_bins_plot")
dir.create(outdir, showWarnings = FALSE, recursive = TRUE)

# ------------------------------------------------------------
# Style helpers
# ------------------------------------------------------------
weight_col <- "wshare"

axis_theme <- theme(
  panel.grid.minor   = element_blank(),
  panel.grid.major.x = element_blank(),
  axis.line.x        = element_line(colour = "black", linewidth = 0.25),
  axis.line.y        = element_line(colour = "black", linewidth = 0.25)
)

coef_panel <- function(df, risk_level, y_lab, x_breaks, x_limits, y_limits, bw) {
  d <- df %>% filter(risk == risk_level) %>% arrange(temp_mid)
  
  ggplot(d, aes(x = temp_mid, y = beta)) +
    geom_hline(yintercept = 0, linewidth = 0.85, linetype = "dashed", color = "dodgerblue4") +
    geom_errorbar(aes(ymin = ci_lo, ymax = ci_hi),
                  width = bw * 0.25, size = 0.20, color = "dodgerblue4", alpha = 0.65) +
    geom_point(size = 2, color = "navyblue") +
    geom_line(linewidth = 0.55, color = "navyblue") +
    scale_x_continuous(breaks = x_breaks, limits = x_limits, expand = c(0,0)) +
    scale_y_continuous(limits = y_limits, expand = c(0,0)) +
    labs(x = NULL, y = y_lab) +
    theme_minimal(base_size = 10) + axis_theme +
    theme(
      axis.title.y = element_text(face = "bold"),
      axis.text.x  = element_text(face = "bold"),
      axis.text.y  = element_text(face = "bold")
    )
}

hist_panel <- function(df_bins, risk_level, x_breaks, x_limits, bw, y_label_left) {
  h <- df_bins %>% filter(risk == risk_level) %>% arrange(temp_mid)
  
  ggplot(h, aes(x = temp_mid, y = .data[[weight_col]])) +
    geom_col(width = bw * 0.9, fill = "dodgerblue3") +
    scale_y_continuous(labels = percent_format(accuracy = 1), expand = c(0,0)) +
    scale_x_continuous(breaks = x_breaks, limits = x_limits, expand = c(0,0)) +
    labs(x = "Temperature (°C)", y = y_label_left) +
    theme_minimal(base_size = 10) + axis_theme +
    theme(
      axis.title.x = element_text(face = "bold"),
      axis.title.y = element_text(face = "bold"),
      axis.text.x  = element_text(face = "bold"),
      axis.text.y  = element_text(face = "bold")
    )
}

label_panel <- function(text) {
  ggplot() +
    annotate("text", x = 0.5, y = 0.5, label = text, fontface = "bold", size = 3.5) +
    theme_void()
}

# ------------------------------------------------------------
# Data prep
# ------------------------------------------------------------
prep_coefs <- function(coefs_path) {
  coefs_raw <- read_csv(coefs_path, show_col_types = FALSE)
  
  coefs_raw %>%
    mutate(
      bin_code = as.character(bin_code),
      is_ref   = as.integer(is_ref),
      ord      = as.numeric(ord),
      temp_mid = as.numeric(temp_mid)
    ) %>%
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
      risk  = recode(risk, low = "Low-risk", high = "High-risk"),
      ci_lo = ifelse(!is.na(se), beta - 1.96 * se, NA_real_),
      ci_hi = ifelse(!is.na(se), beta + 1.96 * se, NA_real_),
      risk  = factor(risk, levels = c("Low-risk", "High-risk"))
    ) %>%
    arrange(ord, risk)
}

prep_support <- function(support_path) {
  read_csv(support_path, show_col_types = FALSE) %>%
    filter(risk %in% c("Low-risk", "High-risk")) %>%
    mutate(
      risk = factor(risk, levels = c("Low-risk", "High-risk")),
      temp_mid = as.numeric(temp_mid)
    )
}

# Tail rules + filtering differences between baseline and coldtail
apply_rules <- function(coefs_plot, bins,
                        mode = c("baseline", "coldtail"),
                        coldcut = NULL) {
  mode <- match.arg(mode)
  
  # pull in upper tail
  bins$temp_mid[bins$temp_mid == 45] <- 43.5
  coefs_plot$temp_mid[coefs_plot$temp_mid == 45] <- 43.5
  
  if (mode == "baseline") {
    # pull in baseline left tail (-5 -> -1.5) if encoded that way
    bins$temp_mid[bins$temp_mid == -5] <- -1.5
    coefs_plot$temp_mid[coefs_plot$temp_mid == -5] <- -1.5
    
    # and always display from -1.5 onward
    bins <- bins %>% filter(temp_mid >= -1.5)
    coefs_plot <- coefs_plot %>% filter(temp_mid >= -1.5)
  }
  
  if (mode == "coldtail") {
    stopifnot(!is.null(coldcut))
    
    # cold tail midpoint coded as coldcut-6 -> display at coldcut-1.5
    bins$temp_mid[abs(bins$temp_mid - (coldcut - 6)) < 1e-9] <- coldcut - 1.5
    coefs_plot$temp_mid[abs(coefs_plot$temp_mid - (coldcut - 6)) < 1e-9] <- coldcut - 1.5
    
    # always display from coldcut-1.5 onward
    bins <- bins %>% filter(temp_mid >= (coldcut - 1.5))
    coefs_plot <- coefs_plot %>% filter(temp_mid >= (coldcut - 1.5))
  }
  
  list(coefs_plot = coefs_plot, bins = bins)
}

# ------------------------------------------------------------
# Render one spec
# ------------------------------------------------------------
render_spec <- function(spec_name, coefs_path, support_path, outfile, title,
                        mode = c("baseline", "coldtail"),
                        coldcut = NULL) {
  mode <- match.arg(mode)
  
  message("---- Rendering: ", spec_name)
  message("  coefs  : ", coefs_path)
  message("  support: ", support_path)
  message("  out    : ", outfile)
  
  # load
  coefs_plot <- prep_coefs(coefs_path)
  bins <- prep_support(support_path)
  
  # apply tail rules + display filtering
  tmp <- apply_rules(coefs_plot, bins, mode = mode, coldcut = coldcut)
  coefs_plot <- tmp$coefs_plot
  bins <- tmp$bins
  
  message("  min shown temp_mid = ", min(bins$temp_mid, na.rm = TRUE))
  
  # x grid from support mids
  mids <- sort(unique(bins$temp_mid))
  bw <- if (length(mids) > 1) min(diff(mids)) else 3
  x_limits <- c(min(mids) - bw/2, max(mids) + bw/2)
  x_breaks <- mids
  
  # shared y limits across risks
  yr <- range(coefs_plot$ci_lo, coefs_plot$ci_hi, na.rm = TRUE)
  pad <- 0.05 * diff(yr); if (!is.finite(pad)) pad <- 1
  y_limits <- c(yr[1] - pad, yr[2] + pad)
  
  # panels
  p_tl <- coef_panel(coefs_plot, "Low-risk",  y_lab = "Minutes Worked",
                     x_breaks, x_limits, y_limits, bw)
  p_tr <- coef_panel(coefs_plot, "High-risk", y_lab = NULL,
                     x_breaks, x_limits, y_limits, bw)
  
  p_bl <- hist_panel(bins, "Low-risk",  x_breaks, x_limits, bw,
                     y_label_left = "Weighted Share of Observations")
  p_br <- hist_panel(bins, "High-risk", x_breaks, x_limits, bw,
                     y_label_left = NULL)
  
  labs_row <- label_panel("A Low Risk") + label_panel("B High Risk") + plot_layout(ncol = 2)
  
  plot_global <- (labs_row /
                    (p_tl + p_tr + plot_layout(ncol = 2)) /
                    (p_bl + p_br + plot_layout(ncol = 2))) +
    plot_layout(heights = c(0.10, 1.9, 1)) +
    plot_annotation(
      title = title,
      theme = theme(
        plot.title  = element_text(hjust = 0.5, face = "bold", size = 12),
        plot.margin = margin(t = 6, r = 6, b = 6, l = 6)
      )
    )
  
  ggsave(outfile, plot = plot_global, width = 10.5, height = 7.2, device = "pdf")
  message("Saved: ", outfile)
}

# ------------------------------------------------------------
# Spec list
# ------------------------------------------------------------
specs <- list()

# MAIN: coldle9 ref27
if (PLOT_MAIN_COLDLE9_REF27) {
  specs <- append(specs, list(list(
    name   = "MAIN_coldle9_ref27",
    coefs  = COEFS_COLDLE9_REF27,
    supp   = SUPPORT_COLDLE9,
    out    = file.path(outdir, "binned_reg_global_MAIN_coldle9_ref27.pdf"),
    title  = "Effects of Daily Temperature on Weekly Minutes\nWorked (Temp. Bins Regression) - Global New Risk\nCold tail: < 9°C, Reference Bin: [27°C-30°C]",
    mode   = "coldtail",
    coldcut = 9
  )))
}

# Optional: coldle9 ref24
if (PLOT_COLDLE9_REF24) {
  specs <- append(specs, list(list(
    name   = "coldle9_ref24",
    coefs  = COEFS_COLDLE9_REF24,
    supp   = SUPPORT_COLDLE9,
    out    = file.path(outdir, "binned_reg_global_coldle9_ref24.pdf"),
    title  = "Effects of Daily Temperature on Weekly Minutes\nWorked (Temp. Bins Regression) - Global New Risk\nCold tail: < 9°C, Reference Bin: [24°C-27°C]",
    mode   = "coldtail",
    coldcut = 9
  )))
}

# Optional: baseline new risk
if (PLOT_BASELINE_NEW_RISK) {
  specs <- append(specs, list(list(
    name   = "baseline_new_risk",
    coefs  = COEFS_BASELINE_NEW,
    supp   = SUPPORT_BASELINE_NEW,
    out    = file.path(outdir, "binned_reg_global_baseline_new_risk.pdf"),
    title  = "Effects of Daily Temperature on Weekly Minutes\nWorked (Temp. Bins Regression) - Global New Risk (baseline bins)",
    mode   = "baseline",
    coldcut = NULL
  )))
}

# Optional: baseline old risk
if (PLOT_BASELINE_OLD_RISK) {
  specs <- append(specs, list(list(
    name   = "baseline_old_risk",
    coefs  = COEFS_BASELINE_OLD,
    supp   = SUPPORT_BASELINE_OLD,
    out    = file.path(outdir, "binned_reg_global_baseline_old_risk.pdf"),
    title  = "Effects of Daily Temperature on Weekly Minutes\nWorked (Temp. Bins Regression) - Global Old Risk (baseline bins)",
    mode   = "baseline",
    coldcut = NULL
  )))
}

if (length(specs) == 0) stop("No specs selected. Set at least one PLOT_* switch to TRUE.")

# ------------------------------------------------------------
# Run
# ------------------------------------------------------------
for (s in specs) {
  render_spec(
    spec_name   = s$name,
    coefs_path  = s$coefs,
    support_path= s$supp,
    outfile     = s$out,
    title       = s$title,
    mode        = s$mode,
    coldcut     = s$coldcut
  )
}
