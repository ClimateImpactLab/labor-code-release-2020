################################################################################
# FILE:    03_empshare_reg_figure_E1.R
#
# PURPOSE:
#   Replicate Figure E.1 from the labor paper.
#
#   Figure E.1 compares predicted agriculture employment shares across
#   alternative regression specifications corresponding to Table E.1.
#
#   This script is self-contained:
#     - re-loads and cleans the raw merged dataset
#     - re-estimates all regression specifications internally in R
#     - doesn't rely on Stata .ster files or prediction grids
#
# DEPENDENT VARIABLE:
#   - industry_share10
#     (share of workers in agriculture - updated high-risk definition)
#
# REGRESSION SPECIFICATIONS:
#   (1) No fixed effects
#   (2) Year fixed effects
#   (3) Continent fixed effects
#   (4) Continent + year fixed effects
#   (5) Country fixed effects
#   (6) Country + year fixed effects (1980–2010 panel)
#
# FIGURE LOGIC:
#   - All models are evaluated on the same sample:
#       the last available census year per ADM1
#   - For k = 2,...,6:
#       x-axis: predictions from Spec (1)
#       y-axis: predictions from Spec (k)
#   - A 45-degree reference line highlights deviations
#
# INPUT:
#   - EMP_SHARE_DIR/data/emp_inc_clim_merged_new.csv
#
# OUTPUT:
#   - labor-code-release-2020/output/employment_shares/figures/
#       figure_E1_newrisk.pdf
#
# NOTES:
#   - Produces the figure counterpart to
#     02_empshare_reg_table_E1.do using the same specifications
#
################################################################################

###############################
# 0. PACKAGES & PATHS
###############################

library(tidyverse)
library(fixest)
library(grid)
library(gridExtra)

# paths
user <- Sys.info()[["user"]]
source(paste0("/project/cil/home_dirs/", user, "/repos/labor-code-release-2020/0_subroutines/paths.R"))


# root data directory 
EMP_SHARE_DIR <- paste0(ROOT_INT_DATA, "/employment_shares_data")


# Output directory in replication repo
OUT_DIR <- paste0(DIR_OUTPUT, "/employment_shares/figures")

if (!dir.exists(OUT_DIR)) {
  dir.create(OUT_DIR, recursive = TRUE)
}

data_path <- file.path(
  EMP_SHARE_DIR, "data", "emp_inc_clim_merged_new.csv"
)

fig_path <- file.path(
  OUT_DIR, "figure_E1_newrisk.pdf"
)

###############################
# 1. LOAD DATA & CLEANING
###############################

df_raw <- read_csv(data_path, show_col_types = FALSE)

df <- df_raw %>%
  # Drop artificial / invalid geographies
  filter(
    geolev1 != 1,
    country != "NA",
    !(geolev1 %% 100 %in% c(98, 99) & geolev1 != 192099),
    geolev1 != 231017
  ) %>%
  # Valid income + census years only
  filter(
    !is.na(gdppc_adm1_pwt_downscaled_13br),
    !is.na(total_pop),
    year <= 2010
  ) %>%
  # Agriculture share (updated high-risk definition)
  mutate(
    ind_highrisk_share = industry_share10,
    log_inc = log_gdppc_adm1_pwt_ds_15ma
  )

###############################
# 2. BUILD ESTIMATION SAMPLES
###############################

# Last census per ADM1
df_last <- df %>%
  group_by(geolev1) %>%
  mutate(max_year = max(year, na.rm = TRUE)) %>%
  ungroup() %>%
  filter(year == max_year)

# Full panel for spec (6)
df_full <- df %>%
  filter(year >= 1980, year <= 2010)

cat("Last-census sample N:", nrow(df_last), "\n")
cat("Full panel sample N:", nrow(df_full), "\n")

###############################
# 3. ESTIMATE REGRESSIONS
###############################

regressors <-
  "log_inc +
   tavg_1_pop_MA_30yr +
   tavg_2_pop_MA_30yr +
   tavg_3_pop_MA_30yr +
   tavg_4_pop_MA_30yr"

m1 <- feols(
  as.formula(paste("ind_highrisk_share ~", regressors)),
  data = df_last
)

m2 <- feols(
  as.formula(paste("ind_highrisk_share ~", regressors, "| year")),
  data = df_last
)

m3 <- feols(
  as.formula(paste("ind_highrisk_share ~", regressors, "| continent")),
  data = df_last
)

m4 <- feols(
  as.formula(paste("ind_highrisk_share ~", regressors, "| continent + year")),
  data = df_last
)

m5 <- feols(
  as.formula(paste("ind_highrisk_share ~", regressors, "| country")),
  data = df_last
)

m6 <- feols(
  as.formula(paste("ind_highrisk_share ~", regressors, "| country + year")),
  data = df_full
)

###############################
# 4. PREDICTIONS (LAST CENSUS)
###############################

pred_df <- df_last %>%
  select(geolev1, country, continent, year) %>%
  mutate(
    pred_1 = predict(m1, newdata = df_last),
    pred_2 = predict(m2, newdata = df_last),
    pred_3 = predict(m3, newdata = df_last),
    pred_4 = predict(m4, newdata = df_last),
    pred_5 = predict(m5, newdata = df_last),
    pred_6 = predict(m6, newdata = df_last)
  )

###############################
# 5. RESHAPE FOR FIGURE
###############################

plot_df <- pred_df %>%
  pivot_longer(
    cols = starts_with("pred_"),
    names_to = "spec",
    values_to = "pred"
  ) %>%
  filter(spec != "pred_1") %>%
  mutate(
    spec = factor(
      spec,
      levels = paste0("pred_", 2:6),
      labels = c(
        "Spec. 2: Year FE",
        "Spec. 3: Continent FE",
        "Spec. 4: Continent + year FE",
        "Spec. 5: Country FE",
        "Spec. 6: Country + year FE"
      )
    )
  ) %>%
  left_join(
    pred_df %>% select(geolev1, pred_1),
    by = "geolev1"
  )

###############################
# 6. PLOT FIGURE E.1
###############################

# Place a single 45-degree annotation in a fixed position on one panel
spec_annot <- "Spec. 2: Year FE"
annot_df <- tibble(
  spec = factor(spec_annot, levels = levels(plot_df$spec)),
  x_text = 0.955,
  y_text = 0.985,
  label = "45° line"
)

# Draw 45-degree line across each panel's observed x-range (clipped to [0,1])
# so it stays visible and does not run all the way to (1.00, 1.00) unless data do.
line_df <- plot_df %>%
  group_by(spec) %>%
  summarize(
    line_min = pmax(0, min(pred_1, na.rm = TRUE)),
    line_max = pmin(1, max(pred_1, na.rm = TRUE)),
    .groups = "drop"
  )

fig_core <- ggplot(plot_df, aes(x = pred_1, y = pred)) +
  geom_point(alpha = 0.72, size = 0.95, color = "#4C9ED9") +
  geom_segment(
    data = line_df,
    aes(
      x = line_min, y = line_min,
      xend = line_max, yend = line_max
    ),
    inherit.aes = FALSE,
    color = "darkred",
    linewidth = 0.8
  ) +
  facet_wrap(~ spec, nrow = 2) +
  coord_equal(xlim = c(0, 1), ylim = c(0, 1), expand = FALSE) +
  geom_label(
    data = annot_df,
    aes(x = x_text, y = y_text, label = label),
    inherit.aes = FALSE,
    hjust = 1,
    vjust = 1,
    size = 3,
    label.size = 0,
    fill = scales::alpha("white", 0.85),
    color = "black",
    fontface = "plain"
  ) +
  scale_x_continuous(
    limits = c(0, 1),
    breaks = seq(0, 1, 0.25),
    minor_breaks = seq(0, 1, 0.125),
    labels = scales::label_number(accuracy = 0.01),
    expand = expansion(mult = c(0, 0))
  ) +
  scale_y_continuous(
    limits = c(0, 1),
    breaks = seq(0, 1, 0.25),
    minor_breaks = seq(0, 1, 0.125),
    labels = scales::label_number(accuracy = 0.01),
    expand = expansion(mult = c(0, 0))
  ) +
  labs(
    x = "Predicted high-risk share (Spec. 1: No FE)",
    y = "Predicted high-risk share"
    #title = "Predicted high-risk share:\nAlternative specifications vs Spec. 1"
  ) +
  theme_bw(base_size = 11) +
  theme(
    panel.border = element_rect(color = "#BDBDBD", fill = NA, linewidth = 0.5),
    panel.background = element_rect(fill = "white", color = NA),
    plot.background = element_rect(fill = "white", color = NA),
    panel.grid.major = element_line(color = "#DADADA", linewidth = 0.45),
    panel.grid.minor = element_line(color = "#EFEFEF", linewidth = 0.30),
    panel.spacing.y = unit(1.15, "lines"),
    panel.spacing.x = unit(1.60, "lines"),
    
    strip.background = element_rect(
      fill = "#DCEAF7",
      color = "#B7CCE2",
      linewidth = 0.5
    ),
    strip.text = element_text(face = "bold", color = "#2F2F2F", size = 10),
    
    axis.title.x = element_text(face = "bold", size = 11, margin = margin(t = 4)),
    axis.title.y = element_text(face = "bold", size = 11, margin = margin(r = 8)),
    axis.text = element_text(color = "#3A3A3A"),
    axis.ticks = element_line(color = "#7A7A7A"),
    
    plot.title = element_text(face = "bold", hjust = 0.5),
    plot.margin = margin(t = 6, r = 6, b = 2, l = 6)
  )

fig_E1 <- fig_core

ggsave(
  filename = fig_path,
  plot     = fig_E1,
  width    = 10,
  height   = 6
)

cat("Saved Figure E.1 replication to:\n", fig_path, "\n")
