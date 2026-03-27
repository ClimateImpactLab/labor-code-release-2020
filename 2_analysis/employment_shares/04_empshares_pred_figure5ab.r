################################################################################
# FILE:    04_empshares_pred_figure5ab.R
#
# PURPOSE:
#   Replicate Figure 5, Panels A and B, as separate PDF files.
#
#   Panel A plots agriculture employment share against log income.
#   Panel B plots agriculture employment share against long-run temperature.
#
#   Each panel combines:
#     - raw data scatter
#     - fitted prediction curve
#     - 95% confidence interval
#     - histogram of the x-variable
#
# INPUTS:
#   - EMP_SHARE_DIR/data/emp_inc_clim_merged_new.csv
#   - EMP_SHARE_DIR/data/shp/world_geolev1_2019/geolev1_names.csv
#   - output/employment_shares/yhat_values/
#       log_inc_poly4_2025_newrisk_TempPredMinMax.csv
#       log_inc_poly4_2025_newrisk_IncPred.csv
#
# OUTPUTS:
#   - output/employment_shares/figures/figure5_panelA.pdf
#   - output/employment_shares/figures/figure5_panelB.pdf
#
# NOTES:
#   - Uses prediction grids produced upstream by 01_empshares_reg_predict.do
#   - Highlights a small set of selected ADM1 observations
#   - Restricts the temperature panel to the 0 to 30 C plotting range
#
################################################################################

library(dplyr)
library(readr)
library(ggplot2)
library(patchwork)

## 0) PATHS --------------------------------------------------

# paths
user <- Sys.info()[["user"]]
source(paste0("/project/cil/home_dirs/", user, "/repos/labor-code-release-2020/0_subroutines/paths.R"))


# root data directory 
EMP_SHARE_DIR <- paste0(ROOT_INT_DATA, "/employment_shares_data")

data_path <- file.path(
  EMP_SHARE_DIR, "data", "emp_inc_clim_merged_new.csv"
)

geo_name_data_path <- file.path(
  EMP_SHARE_DIR, "data", "shp", "world_geolev1_2019", "geolev1_names.csv"
)

out_root <- file.path(DIR_REPO_LABOR, "output", "employment_shares")
yhat_dir <- file.path(out_root, "yhat_values")

fig_out_dir <- file.path(out_root, "figures")
dir.create(fig_out_dir, showWarnings = FALSE, recursive = TRUE)

# Baseline no-FE prediction grids used for Figure 5
model_stem <- "log_inc_poly4_2025_newrisk"
temp_pred_path <- file.path(yhat_dir, paste0(model_stem, "_TempPredMinMax.csv"))
inc_pred_path  <- file.path(yhat_dir, paste0(model_stem, "_IncPred.csv"))

# Hard-stop if any required input is missing
if (!file.exists(temp_pred_path)) stop("Missing temp prediction CSV: ", temp_pred_path)
if (!file.exists(inc_pred_path))  stop("Missing income prediction CSV: ", inc_pred_path)
if (!file.exists(data_path))      stop("Missing raw data CSV: ", data_path)
if (!file.exists(geo_name_data_path)) stop("Missing geolev1 names CSV: ", geo_name_data_path)

## 1) STYLE --------------------------------------------------

col_nofe_line <- "#2D2D2D"
col_nofe_fill <- "#A9A9A9"
col_pt        <- "#2FA4E7"
col_pt_hi     <- "#000000"

curve_linewidth      <- 0.55
scatter_point_size   <- 1.15
scatter_point_alpha  <- 0.9
highlight_point_size <- 2.2
ci_alpha             <- 0.28

axis_title_size      <- 20
axis_text_size       <- 13
axis_tick_linewidth  <- 0.7
axis_tick_length_cm  <- 0.18

# Relative heights of scatter panel and histogram panel
panel_heights <- c(4, 1)

theme_scatter_A <- function() {
  theme_classic(base_size = 11) +
    theme(
      axis.title = element_text(face = "plain", color = "black", size = axis_title_size),
      axis.text  = element_text(color = "black", size = axis_text_size),
      axis.line  = element_line(color = "black", linewidth = 0.4),
      axis.ticks = element_line(color = "black", linewidth = axis_tick_linewidth),
      axis.ticks.length = grid::unit(axis_tick_length_cm, "cm"),
      plot.margin = margin(t = 6, r = 10, b = 4, l = 10)
    )
}

theme_scatter_B <- function() {
  theme_classic(base_size = 11) +
    theme(
      axis.title.x = element_text(face = "plain", color = "black", size = axis_title_size),
      axis.title.y = element_blank(),
      axis.text    = element_text(color = "black", size = axis_text_size),
      axis.line    = element_line(color = "black", linewidth = 0.4),
      axis.ticks   = element_line(color = "black", linewidth = axis_tick_linewidth),
      axis.ticks.length = grid::unit(axis_tick_length_cm, "cm"),
      plot.margin  = margin(t = 6, r = 10, b = 4, l = 10)
    )
}

theme_hist_min <- function() {
  theme_classic(base_size = 11) +
    theme(
      axis.title.x = element_text(face = "plain", color = "black", size = axis_title_size),
      axis.text.x  = element_blank(),
      axis.line.x  = element_blank(),
      axis.ticks.x = element_blank(),
      axis.ticks.length.x = grid::unit(0, "cm"),
      axis.title.y = element_blank(),
      axis.text.y  = element_blank(),
      axis.ticks.y = element_blank(),
      axis.line.y  = element_blank(),
      plot.margin  = margin(t = 0, r = 10, b = 8, l = 10)
    )
}

## 2) LOAD + CLEAN DATA --------------------------------------

# Load raw merged data and ADM1/country names
df_raw <- read_csv(data_path, show_col_types = FALSE)

geo_names <- read_csv(geo_name_data_path, show_col_types = FALSE) %>%
  rename(
    geolev1      = GEOLEVEL1,
    geo_name     = ADMIN_NAME,
    country_name = CNTRY_NAME
  )

# Add human-readable names for possible highlighting/debugging
df_raw <- left_join(
  df_raw,
  geo_names[, c("geolev1", "geo_name", "country_name")],
  by = "geolev1"
) %>%
  mutate(
    geo_full_name = paste0(geo_name, ", ", country_name)
  )

# Rebuild the last-census plotting sample from raw data using the same
# core restrictions as the employment-share estimation files
df <- df_raw %>%
  filter(geolev1 != 1) %>%
  filter(country != "NA") %>%
  filter(gdppc_adm1_pwt_downscaled_13br != "NA") %>%
  mutate(geolev1_mod100 = geolev1 %% 100L) %>%
  filter(
    !(geolev1_mod100 %in% c(98L, 99L) & geolev1 != 192099L),
    geolev1 != 231017L
  ) %>%
  select(-geolev1_mod100) %>%
  filter(!is.na(total_pop)) %>%
  filter(year <= 2010) %>%
  group_by(geolev1) %>%
  filter(year == max(year, na.rm = TRUE)) %>%
  ungroup()

# Flag selected ADM1s to highlight in the scatterplots
df <- df %>%
  mutate(
    highlight_point = if_else(
      geolev1 %in% c(768003L, 356027L, 76035L, 840017L),
      1L, 0L
    )
  )

# Log income is already stored in log form in the raw data
if (!("log_gdppc_adm1_pwt_ds_15ma" %in% names(df))) {
  stop("Expected log income variable log_gdppc_adm1_pwt_ds_15ma not found.")
}

df <- df %>%
  mutate(
    log_inc = log_gdppc_adm1_pwt_ds_15ma
  )

# Handle capitalization differences in the long-run temperature variable name
temp_var <- case_when(
  "tavg_1_pop_MA_30yr" %in% names(df) ~ "tavg_1_pop_MA_30yr",
  "tavg_1_pop_ma_30yr" %in% names(df) ~ "tavg_1_pop_ma_30yr",
  TRUE ~ NA_character_
)

if (is.na(temp_var)) {
  stop("No temperature variable tavg_1_pop_*_30yr found.")
}

# Express agriculture share in percentage points for plotting
if (!("industry_share10" %in% names(df))) {
  stop("industry_share10 not found in raw data.")
}

df <- df %>%
  mutate(
    share_ag = 100 * industry_share10
  )

# Full plotting sample for income panel
df_inc <- df

# Restrict temperature panel to the plotting range used in the figure
df_temp <- df %>%
  filter(.data[[temp_var]] >= 0, .data[[temp_var]] <= 30)

# Highlighted subsets used for over-plotting black points
df_hi_inc  <- df_inc  %>% filter(highlight_point == 1)
df_hi_temp <- df_temp %>% filter(highlight_point == 1)

## 3) LOAD PREDICTION GRIDS ---------------------------------

# These prediction grids were produced upstream by 01_empshares_reg_predict.do.
# Convert fitted values and confidence bounds from shares to percentages to
# match the plotting scale used for the raw data.

yhat_temp <- read_csv(temp_pred_path, show_col_types = FALSE) %>%
  mutate(
    yhat_pct = 100 * yhat,
    ymin_pct = 100 * lowerci_hi,
    ymax_pct = 100 * upperci_hi
  ) %>%
  filter(temp >= 0, temp <= 30)

yhat_inc <- read_csv(inc_pred_path, show_col_types = FALSE) %>%
  mutate(
    yhat_pct = 100 * yhat,
    ymin_pct = 100 * lowerci_hi,
    ymax_pct = 100 * upperci_hi
  )

# Clip ribbons to the feasible plotting range [0, 100].
# For the fitted line itself, keep only in-range predictions so extreme values
# outside the visible panel do not distort the plotted line.

yhat_inc_ribbon <- yhat_inc %>%
  mutate(
    ymin_clip = pmax(ymin_pct, 0),
    ymax_clip = pmin(ymax_pct, 100)
  )

yhat_inc_line <- yhat_inc %>%
  filter(yhat_pct >= 0, yhat_pct <= 100)

yhat_temp_ribbon <- yhat_temp %>%
  mutate(
    ymin_clip = pmax(ymin_pct, 0),
    ymax_clip = pmin(ymax_pct, 100)
  )

yhat_temp_line <- yhat_temp %>%
  filter(yhat_pct >= 0, yhat_pct <= 100)

## 4) AXIS LIMITS --------------------------------------------

# Keep the top scatter and bottom histogram aligned within each panel
inc_xlim  <- range(c(df_inc$log_inc, yhat_inc$inc_log), na.rm = TRUE)
temp_xlim <- c(0, 30)
x_expand  <- expansion(mult = c(0.01, 0.01))

## 5) BUILD PANELS -------------------------------------------

# Panel A: agriculture share vs log income
p_inc_scatter <- ggplot() +
  geom_point(
    data = df_inc,
    mapping = aes(x = log_inc, y = share_ag),
    alpha = scatter_point_alpha,
    size  = scatter_point_size,
    color = col_pt
  ) +
  geom_ribbon(
    data = yhat_inc_ribbon,
    mapping = aes(x = inc_log, ymin = ymin_clip, ymax = ymax_clip),
    fill = col_nofe_fill,
    alpha = ci_alpha,
    inherit.aes = FALSE
  ) +
  geom_line(
    data = yhat_inc_line,
    mapping = aes(x = inc_log, y = yhat_pct),
    color = col_nofe_line,
    linewidth = curve_linewidth,
    inherit.aes = FALSE
  ) +
  geom_point(
    data = df_hi_inc,
    mapping = aes(x = log_inc, y = share_ag),
    color = col_pt_hi,
    size  = highlight_point_size,
    alpha = 0.95
  ) +
  scale_x_continuous(limits = inc_xlim, expand = x_expand) +
  scale_y_continuous(limits = c(0, 100), expand = expansion(mult = c(0, 0))) +
  labs(
    x = NULL,
    y = "High-risk share (%)"
  ) +
  theme_scatter_A()

p_inc_hist <- ggplot(df_inc, aes(x = log_inc)) +
  geom_histogram(
    bins = 30,
    fill = col_pt,
    color = NA
  ) +
  scale_x_continuous(limits = inc_xlim, expand = x_expand) +
  labs(
    x = "Log GDP per capita (2019 US$ PPP)",
    y = NULL
  ) +
  theme_hist_min()

panel_a <- p_inc_scatter / p_inc_hist +
  plot_layout(heights = panel_heights)

# Panel B: agriculture share vs long-run temperature
p_temp_scatter <- ggplot() +
  geom_point(
    data = df_temp,
    mapping = aes(x = .data[[temp_var]], y = share_ag),
    alpha = scatter_point_alpha,
    size  = scatter_point_size,
    color = col_pt
  ) +
  geom_ribbon(
    data = yhat_temp_ribbon,
    mapping = aes(x = temp, ymin = ymin_clip, ymax = ymax_clip),
    fill = col_nofe_fill,
    alpha = ci_alpha,
    inherit.aes = FALSE
  ) +
  geom_line(
    data = yhat_temp_line,
    mapping = aes(x = temp, y = yhat_pct),
    color = col_nofe_line,
    linewidth = curve_linewidth,
    inherit.aes = FALSE
  ) +
  geom_point(
    data = df_hi_temp,
    mapping = aes(x = .data[[temp_var]], y = share_ag),
    color = col_pt_hi,
    size  = highlight_point_size,
    alpha = 0.95
  ) +
  scale_x_continuous(limits = temp_xlim, expand = x_expand) +
  scale_y_continuous(limits = c(0, 100), expand = expansion(mult = c(0, 0))) +
  labs(
    x = NULL,
    y = NULL
  ) +
  theme_scatter_B()

p_temp_hist <- ggplot(df_temp, aes(x = .data[[temp_var]])) +
  geom_histogram(
    bins = 30,
    fill = col_pt,
    color = NA
  ) +
  scale_x_continuous(limits = temp_xlim, expand = x_expand) +
  labs(
    x = "Long-run average daily maximum temperature (\u00b0C)",
    y = NULL
  ) +
  theme_hist_min()

panel_b <- p_temp_scatter / p_temp_hist +
  plot_layout(heights = panel_heights)

## 6) SAVE ----------------------------------------------------

# Save each panel separately 
#(downstream edits in illustrator for final figure 5)

panel_width  <- 8.3
panel_height <- 6.0

out_file_a <- file.path(fig_out_dir, "figure5_panelA.pdf")
out_file_b <- file.path(fig_out_dir, "figure5_panelB.pdf")

ggsave(out_file_a, panel_a, width = panel_width, height = panel_height)
ggsave(out_file_b, panel_b, width = panel_width, height = panel_height)

message("Saved: ", out_file_a)
message("Saved: ", out_file_b)