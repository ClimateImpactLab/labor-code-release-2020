#-------------------------------------------------------------------------------
# 03_empshare_reg_figure_E1.r
#-------------------------------------------------------------------------------
# PURPOSE
#   Recreate Figure E.1 using the agriculture-only high-risk definition
#
# STEPS
#   1. Load and clean the ADM1 employment-share data
#   2. Estimate the six Table E.1 specifications
#   3. Predict agriculture employment shares on the last-census sample
#   4. Plot each specification against the no-FE specification
#
# INPUTS
#   Employment-share data from ${ROOT_INT_DATA}/employment_shares_data/data
#
# OUTPUTS
#   Figure E.1 PDF under ${DIR_OUTPUT}/employment_shares/figures
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# Packages and paths
#-------------------------------------------------------------------------------

library(tidyverse)
library(fixest)
library(grid)
library(gridExtra)

user <- Sys.info()[["user"]]

source(
  paste0(
    "/project/cil/home_dirs/",
    user,
    "/repos/labor-code-release-2020/0_subroutines/paths.R"
  )
)

EMP_SHARE_DIR <- paste0(ROOT_INT_DATA, "/employment_shares_data")
OUT_DIR <- paste0(DIR_OUTPUT, "/employment_shares/figures")

if (!dir.exists(OUT_DIR)) {
  dir.create(OUT_DIR, recursive = TRUE)
}

data_path <- file.path(
  EMP_SHARE_DIR,
  "data",
  "emp_inc_clim_merged_new.csv"
)

fig_path <- file.path(
  OUT_DIR,
  "figure_E1_newrisk.pdf"
)

#-------------------------------------------------------------------------------
# Load and clean data
#-------------------------------------------------------------------------------

df_raw <- read_csv(data_path, show_col_types = FALSE)

df <- df_raw %>%
  # Drop artificial geographies, missing inputs, and post-2010 rows
  filter(
    geolev1 != 1,
    country != "NA",
    !(geolev1 %% 100 %in% c(98, 99) & geolev1 != 192099),
    geolev1 != 231017,
    !is.na(gdppc_adm1_pwt_downscaled_13br),
    !is.na(total_pop),
    year <= 2010
  ) %>%
  mutate(
    # industry_share10 is the agriculture share used for the revised high-risk group
    ind_highrisk_share = industry_share10,
    log_inc = log_gdppc_adm1_pwt_ds_15ma
  )

#-------------------------------------------------------------------------------
# Build samples
#-------------------------------------------------------------------------------

df_last <- df %>%
  group_by(geolev1) %>%
  mutate(max_year = max(year, na.rm = TRUE)) %>%
  ungroup() %>%
  filter(year == max_year)

# Spec 6 uses the 1980-2010 panel; the other specs use the last census per ADM1
df_full <- df %>%
  filter(year >= 1980, year <= 2010)

cat("Last-census sample N:", nrow(df_last), "\n")
cat("Full panel sample N:", nrow(df_full), "\n")

#-------------------------------------------------------------------------------
# Estimate regressions
#-------------------------------------------------------------------------------

regressors <- paste(
  "log_inc",
  "tavg_1_pop_MA_30yr",
  "tavg_2_pop_MA_30yr",
  "tavg_3_pop_MA_30yr",
  "tavg_4_pop_MA_30yr",
  sep = " + "
)

# Column 1: no fixed effects
m1 <- feols(
  as.formula(paste("ind_highrisk_share ~", regressors)),
  data = df_last
)

# Column 2: year fixed effects
m2 <- feols(
  as.formula(paste("ind_highrisk_share ~", regressors, "| year")),
  data = df_last
)

# Column 3: continent fixed effects
m3 <- feols(
  as.formula(paste("ind_highrisk_share ~", regressors, "| continent")),
  data = df_last
)

# Column 4: continent and year fixed effects
m4 <- feols(
  as.formula(paste("ind_highrisk_share ~", regressors, "| continent + year")),
  data = df_last
)

# Column 5: country fixed effects
m5 <- feols(
  as.formula(paste("ind_highrisk_share ~", regressors, "| country")),
  data = df_last
)

# Column 6: country and year fixed effects on the 1980-2010 panel
m6 <- feols(
  as.formula(paste("ind_highrisk_share ~", regressors, "| country + year")),
  data = df_full
)

#-------------------------------------------------------------------------------
# Predict on the last-census sample
#-------------------------------------------------------------------------------

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

plot_df <- pred_df %>%
  select(geolev1, pred_1, pred_2, pred_3, pred_4, pred_5, pred_6) %>%
  pivot_longer(
    cols = pred_2:pred_6,
    names_to = "spec",
    values_to = "pred"
  ) %>%
  mutate(
    # Column number in Table E.1
    column = as.integer(str_remove(spec, "pred_")),
    spec = factor(
      spec,
      levels = paste0("pred_", 2:6)
    )
  )

#-------------------------------------------------------------------------------
# Plot Figure E.1
#-------------------------------------------------------------------------------

make_panel <- function(data, col_num, show_x = FALSE, annotate = FALSE) {

  df_panel <- data %>%
    filter(column == col_num)

  p <- ggplot(df_panel, aes(x = pred_1, y = pred)) +
    geom_point(
      color = "#4C9ED9",
      alpha = 0.80,
      size = 1.7
    ) +
    geom_abline(
      intercept = 0,
      slope = 1,
      color = "red",
      linewidth = 0.6
    ) +
    # Keep every panel on the same 0-1 scale
    coord_equal(
      xlim = c(0, 1),
      ylim = c(0, 1),
      expand = FALSE
    ) +
    scale_x_continuous(
      breaks = seq(0, 1, 0.25),
      minor_breaks = seq(0, 1, 0.125),
      labels = scales::label_number(accuracy = 0.01)
    ) +
    scale_y_continuous(
      breaks = seq(0, 1, 0.25),
      minor_breaks = seq(0, 1, 0.125),
      labels = scales::label_number(accuracy = 0.01)
    ) +
    labs(
      x = if (show_x) {
        "Predicted share of high-risk workers\n(Table E.1, Column 1)"
      } else {
        NULL
      },
      y = paste0(
        "Predicted share of high-risk workers\n",
        "(Table E.1, Column ", col_num, ")"
      )
    ) +
    theme_bw(base_size = 13) +
    theme(
      panel.border = element_blank(),
      panel.background = element_rect(fill = "white", color = NA),
      plot.background = element_rect(fill = "white", color = NA),

      panel.grid.major = element_line(color = "#E6E6E6", linewidth = 0.6),
      panel.grid.minor = element_line(color = "#F0F0F0", linewidth = 0.4),

      axis.title = element_text(face = "bold", color = "black"),
      axis.title.x = element_text(margin = margin(t = 4)),
      axis.title.y = element_text(margin = margin(r = 8)),
      axis.text = element_text(color = "#3A3A3A"),
      axis.ticks = element_blank(),

      plot.margin = margin(t = 8, r = 12, b = 8, l = 12)
    )

  if (annotate) {
    p <- p +
      # Label the 45-degree line once, in the first panel
      annotate(
        "text",
        x = 0.54,
        y = 0.95,
        label = "45° line",
        size = 3.5
      ) +
      annotate(
        "curve",
        x = 0.59,
        y = 0.91,
        xend = 0.72,
        yend = 0.72,
        curvature = 0.35,
        arrow = arrow(length = unit(0.15, "cm")),
        linewidth = 0.4
      )
  }

  return(p)
}

p2 <- make_panel(plot_df, col_num = 2, show_x = FALSE, annotate = TRUE)
p3 <- make_panel(plot_df, col_num = 3, show_x = FALSE)
p4 <- make_panel(plot_df, col_num = 4, show_x = FALSE)
p5 <- make_panel(plot_df, col_num = 5, show_x = TRUE)
p6 <- make_panel(plot_df, col_num = 6, show_x = TRUE)

blank <- nullGrob()

fig_E1 <- arrangeGrob(
  p2, p3,
  p4, p5,
  p6, blank,
  ncol = 2,
  widths = c(1, 1),
  heights = c(1, 1, 1)
)

ggsave(
  filename = fig_path,
  plot = fig_E1,
  width = 8.5,
  height = 10.5
)

cat("Saved Figure E.1 replication to:\n", fig_path, "\n")
