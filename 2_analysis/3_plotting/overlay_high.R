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

outname <- "overlay_agri_high_allworkers"
format  <- "pdf"

#############
# GET DATA
#############

# Response function: high–vs–agri RF
# (change filename here if your CSV has a different name)
rf <- read_csv(glue(
  "{DIR_RF}/uninteracted_reg_comlohi/",
  "uninteracted_reg_comlohi_full_response_2025_ag&high.csv"
))

# Temperature distribution (global)
temp_dist <- read_csv(
  glue("{DIR_OUTPUT}/temp_dist/2_high_risk/temp_dist.csv")
)
########################################
# LABELS (kept in one place)
########################################

# Legend labels for high-risk comparison
label_agri <- "Agriculture (high risk)"
label_high <- "High risk"

##############################
# 1. BUILD RESPONSE FUNCTION (Agri vs High)
##############################

rf_long <- bind_rows(
  rf %>%
    transmute(
      temp,
      spec = label_agri,
      yhat = yhat_agri,
      lwr  = yhat_agri - 1.96 * se_agri,
      upr  = yhat_agri + 1.96 * se_agri
    ),
  rf %>%
    transmute(
      temp,
      spec = label_high,
      yhat = yhat_high,
      lwr  = yhat_high - 1.96 * se_high,
      upr  = yhat_high + 1.96 * se_high
    )
)

# Axis limits for RF panel
y_range <- range(rf_long$lwr, rf_long$upr, na.rm = TRUE)
x_range <- range(rf_long$temp,              na.rm = TRUE)

##############################
# 2. HISTOGRAM: Agri vs High
##############################

# Agriculture histogram data
hist_agri <- reshape(
  "agri",
  df   = temp_dist,
  vars = c("risk_adj_sample_wgt", "pop_adj_sample_wgt")
) %>%
  transmute(
    temp,
    spec   = label_agri,
    weight = risk_adj_sample_wgt
  )

# High-risk histogram data
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

# Stack histogram data
hist_long <- bind_rows(hist_agri, hist_high)

# Shared y-axis limit for histogram
hist_max <- max(hist_long$weight, na.rm = TRUE)
if (!is.finite(hist_max) || hist_max <= 0) hist_max <- 1

##############################
# 3. COLOR PALETTE (consistent across panels)
##############################

# Fix factor order: High first, then Agri (you can swap if you prefer)
rf_long   <- rf_long   %>% mutate(spec = factor(spec, levels = c(label_high, label_agri)))
hist_long <- hist_long %>% mutate(spec = factor(spec, levels = c(label_high, label_agri)))

# Darker original colors: blue for high, purple for agri
cols <- c(
  "High risk"              = "#1B6CA8", # blue
  "Agriculture (high risk)" = "#5E4987"  # purple
)

fills <- cols

# Linetype for RF panel
lts <- c(
  "High risk"               = "dashed",
  "Agriculture (high risk)" = "solid"
)

#########################################
# 4. PLOT: RESPONSE FUNCTION (TOP PANEL)
#########################################

p_rf <- ggplot(rf_long,
               aes(x = temp, y = yhat,
                   colour   = spec,
                   fill     = spec,
                   linetype = spec)) +
  geom_ribbon(aes(ymin = lwr, ymax = upr),
              alpha = 0.20, colour = NA) +
  geom_line(size = 1) +
  scale_colour_manual(values    = cols, guide = "none") +
  scale_fill_manual(values      = fills, guide = "none") +
  scale_linetype_manual(values  = lts,   guide = "none") +
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
# 5. SIMPLE OVERLAID HISTOGRAM (BOTTOM PANEL)
#########################################

p_hist <- ggplot(hist_long,
                 aes(x = temp, y = weight, fill = spec)) +
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
    x   = "Temperature (°C)",
    y   = NULL
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
# 6. COMBINE PANELS WITH SHARED LEGEND AND TITLE
#########################################

p_final <- p_rf / p_hist +
  plot_layout(heights = c(2.2, 1.2), guides = "collect") &
  theme(legend.position = "top")

p_final <- p_final +
  plot_annotation(
    title = "High Risk Subcategories Comparison",
    theme = theme(
      plot.title = element_text(
        hjust = 0.5,
        face  = "bold",
        size  = 16
      )
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

cat(glue("\n✅ High-risk RF + histogram figure saved at:\n{outfile}\n"))
