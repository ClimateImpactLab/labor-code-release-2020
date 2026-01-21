#############
# INITIALIZE
#############

rm(list = ls())

library(dplyr)
library(ggplot2)
library(patchwork)
library(readr)
library(glue)
library(data.table)
library(cowplot)
library(parallel)

local_machine <- 1
source('/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/0_subroutines/paths.R')
source('/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/2_analysis/0_subroutines/functions.R')

#################
# DEFINE OUTPATH
#################

outpath <- glue("{DIR_FIG}/overlay_agri_high")
dir.create(outpath, showWarnings = FALSE, recursive = TRUE)

outname <- "overlay_272841_real_allworkers"
format  <- "pdf"

#############
# GET DATA
#############

# Response function
rf <- read_csv(glue(
  "{DIR_RF}/uninteracted_reg_comlohi/",
  "uninteracted_reg_comlohi_full_response_2026_272841.csv"
))

# Temperature distribution (global)
temp_dist <- read_csv(
  glue("{DIR_OUTPUT}/temp_dist/Dec2025/global_temp_dist.csv")
)

########################################
# LABELS (kept in one place)
########################################

label_high <- "High risk = Agri"
label_low  <- "Low risk"

##############################
# 1. BUILD RESPONSE FUNCTION (high vs low)
##############################

rf_long <- bind_rows(
  rf %>%
    transmute(
      temp,
      spec = label_high,
      yhat = yhat_high,
      lwr  = yhat_high - 1.96 * se_high,
      upr  = yhat_high + 1.96 * se_high
    ),
  rf %>%
    transmute(
      temp,
      spec = label_low,
      yhat = yhat_low,
      lwr  = yhat_low - 1.96 * se_low,
      upr  = yhat_low + 1.96 * se_low
    )
)

# Axis limits for RF panel
y_range <- range(rf_long$lwr, rf_long$upr, na.rm = TRUE)
x_range <- range(rf_long$temp,              na.rm = TRUE)

##############################
# 1.5 COMPUTE PEAK COORDS (for subtitle)
##############################

# Define peak as argmax(yhat). If ties, take the first.
peak_df <- rf_long %>%
  filter(is.finite(temp), is.finite(yhat)) %>%
  group_by(spec) %>%
  slice_max(order_by = yhat, n = 1, with_ties = FALSE) %>%
  ungroup() %>%
  mutate(
    temp_round = round(temp, 8),
    yhat_round = round(yhat, 8)
  )

peak_high <- peak_df %>% filter(spec == label_high) %>% slice(1)
peak_low  <- peak_df %>% filter(spec == label_low)  %>% slice(1)

# Safe extraction (in case something is missing)
fmt_peak <- function(df_row, fallback = "x=NA, y=NA") {
  if (nrow(df_row) == 0) return(fallback)
  glue("x={df_row$temp_round}, y={df_row$yhat_round}")
}

peak_line <- glue(
  "{label_high} opt: {fmt_peak(peak_high)}   |   {label_low} opt: {fmt_peak(peak_low)}"
)

##############################
# 2. HISTOGRAM: high vs low
##############################

hist_high <- reshape(
  "high",
  df   = temp_dist,
  vars = c("risk_adj_sample_wgt", "pop_adj_sample_wgt")
) %>%
  transmute(
    temp,
    spec   = label_high,
    weight = risk_adj_sample_wgt
  )

hist_low <- reshape(
  "low",
  df   = temp_dist,
  vars = c("risk_adj_sample_wgt", "pop_adj_sample_wgt")
) %>%
  transmute(
    temp,
    spec   = label_low,
    weight = risk_adj_sample_wgt
  )

hist_long <- bind_rows(hist_high, hist_low)

hist_max <- max(hist_long$weight, na.rm = TRUE)
if (!is.finite(hist_max) || hist_max <= 0) hist_max <- 1

##############################
# 3. COLOR PALETTE
##############################

rf_long   <- rf_long   %>% mutate(spec = factor(spec, levels = c(label_low, label_high)))
hist_long <- hist_long %>% mutate(spec = factor(spec, levels = c(label_low, label_high)))

cols <- c(
  "Low risk"        = "#1B6CA8",
  "High risk = Agri" = "#5E4987"
)

fills <- cols

lts <- c(
  "Low risk"        = "dashed",
  "High risk = Agri" = "solid"
)

#########################################
# 4. PLOT: RESPONSE FUNCTION (TOP PANEL)
#########################################

p_rf <- ggplot(
  rf_long,
  aes(x = temp, y = yhat, colour = spec, fill = spec, linetype = spec)
) +
  geom_ribbon(aes(ymin = lwr, ymax = upr), alpha = 0.20, colour = NA) +
  geom_line(size = 1) +
  scale_colour_manual(values = cols, guide = "none") +
  scale_fill_manual(values   = fills, guide = "none") +
  scale_linetype_manual(values = lts, guide = "none") +
  scale_x_continuous(
    limits = x_range,
    breaks = seq(-20, 47, 10),
    expand = c(0, 0)
  ) +
  scale_y_continuous(
    limits = y_range,
    expand = c(0, 0)
  ) +
  labs(
    x = NULL,
    y = "Minutes worked"
  ) +
  theme_minimal(base_size = 13) +
  theme(
    panel.grid    = element_blank(),
    axis.text.y   = element_text(color = "black", face = "bold"),
    axis.text.x   = element_blank(),
    axis.ticks.x  = element_blank(),
    axis.line.y   = element_line(color = "black"),
    axis.ticks.y  = element_line(color = "black"),
    plot.margin   = margin(t = 5, r = 5, b = 0, l = 5)
  )

#########################################
# 5. OVERLAID HISTOGRAM (BOTTOM PANEL)
#########################################

p_hist <- ggplot(hist_long, aes(x = temp, y = weight, fill = spec)) +
  geom_col(position = "identity", alpha = 0.35) +
  scale_fill_manual(values = fills, name = "") +
  scale_x_continuous(
    limits = x_range,
    breaks = seq(-20, 47, 10),
    expand = c(0, 0),
    minor_breaks = NULL
  ) +
  scale_y_continuous(
    limits = c(0, hist_max),
    expand = c(0, 0)
  ) +
  labs(
    x = "Temperature (°C)",
    y = NULL
  ) +
  theme_minimal(base_size = 12) +
  theme(
    panel.grid       = element_blank(),
    axis.line.y      = element_line(color = "black"),
    axis.ticks       = element_line(color = "black"),
    axis.text.x      = element_text(color = "black", face = "bold"),
    axis.text.y      = element_blank(),
    axis.ticks.y     = element_blank(),
    legend.position  = "top",
    legend.direction = "horizontal",
    legend.box       = "horizontal",
    legend.text      = element_text(size = 11),
    plot.margin      = margin(t = 0, r = 5, b = 5, l = 5)
  )

#########################################
# 6. COMBINE PANELS + TITLE + SUBTITLE (peak line)
#########################################

p_final <- p_rf / p_hist +
  plot_layout(heights = c(2.2, 1.2), guides = "collect") &
  theme(legend.position = "top")

p_final <- p_final +
  plot_annotation(
    title    = "High & Low Risk Comparison (27-28-41 Knots) [real]",
    subtitle = peak_line,
    theme = theme(
      plot.title = element_text(hjust = 0.5, face = "bold", size = 16),
      plot.subtitle = element_text(hjust = 0.5, size = 11)
    )
  )

outfile <- glue("{outpath}/{outname}.{format}")

ggsave(
  filename = outfile,
  plot     = p_final,
  width    = 7,
  height   = 7.8,
  device   = cairo_pdf
)

cat(glue("\n✅ Figure saved (with peak coords in subtitle):\n{outfile}\n"))
