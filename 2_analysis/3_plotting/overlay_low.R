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

outname <- "overlay_low_lomaco_allworkers"
format  <- "pdf"

#############
# GET DATA
#############

# (change filename here if your CSV has a different name)
rf <- read_csv(glue(
  "{DIR_RF}/uninteracted_reg_comlohi/",
  "uninteracted_reg_comlohi_full_response_2025_low+low&manuf&connmine.csv"
))

# Temperature distribution (global)
temp_dist <- read_csv(
  glue("{DIR_OUTPUT}/temp_dist/2_high_risk/temp_dist.csv")
)

########################################
# LABELS (kept in one place)
########################################

# Short legend labels
label_lomaco <- "Low risk + manufacturing, mining, and construction"
label_low    <- "Low risk"

##############################
# 1. BUILD RESPONSE FUNCTION (Lomaco vs Low)
##############################

rf_long <- bind_rows(
  rf %>%
    transmute(
      temp,
      spec = label_lomaco,
      yhat = yhat_lomaco,
      lwr  = yhat_lomaco - 1.96 * se_lomaco,
      upr  = yhat_lomaco + 1.96 * se_lomaco
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
# 2. HISTOGRAM: Lomaco vs Low
##############################

# Lomaco histogram data
hist_lomaco <- reshape(
  "lomaco",
  df   = temp_dist,
  vars = c("risk_adj_sample_wgt", "pop_adj_sample_wgt")
) %>%
  transmute(
    temp,
    spec   = label_lomaco,
    weight = risk_adj_sample_wgt
  )

# Low-risk histogram data
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

# Stack histogram data
hist_long <- bind_rows(hist_lomaco, hist_low)

# Shared y-axis limit for histogram
hist_max <- max(hist_long$weight, na.rm = TRUE)
if (!is.finite(hist_max) || hist_max <= 0) hist_max <- 1

##############################
# 3. COLOR PALETTE (consistent across panels)
##############################

# Fix factor order: Low first, then Lomaco
rf_long   <- rf_long   %>% mutate(spec = factor(spec, levels = c(label_low, label_lomaco)))
hist_long <- hist_long %>% mutate(spec = factor(spec, levels = c(label_low, label_lomaco)))

# Darker original colors
cols <- c(
  "Low risk"                                   = "#1B6CA8", # blue
  "Low risk + manufacturing, mining, and construction" = "#5E4987"  # purple
)

fills <- cols

# Linetype for RF panel
lts <- c(
  "Low risk"                                   = "dashed",
  "Low risk + manufacturing, mining, and construction" = "solid"
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
    title = "Low Risk Subcategories Comparison",
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

cat(glue("\n✅ Figure saved with original colors and shorter legend labels:\n{outfile}\n"))
