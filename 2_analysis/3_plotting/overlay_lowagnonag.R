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

outname <- "overlay_272841_sector"
format  <- "pdf"

#############
# GET DATA
#############

# Response function
rf <- read_csv(glue(
  "{DIR_RF}/uninteracted_reg_comlohi/",
  "uninteracted_reg_comlohi_full_response_2025_272841_sector.csv"
))

# Temperature distribution (global)
temp_dist <- read_csv(
  glue("{DIR_OUTPUT}/temp_dist/Dec2025/global_temp_dist_sector.csv")
)




########################################
# LABELS + COLUMN MAP (edit column names here)
########################################

label_ag    <- "High risk = Agri"
label_nonag <- "High risk = Non-agri"
label_low   <- "Low risk"

# ---- IMPORTANT ----
spec_map <- data.frame(
  spec       = c(label_ag,         label_nonag,        label_low),
  yhat_col   = c("yhat_ag",         "yhat_nonag",       "yhat_low"),   # <-- adjust if needed
  se_col     = c("se_ag",           "se_nonag",         "se_low"),     # <-- adjust if needed
  weight_col = c("risk_adj_sample_wgt_sector_ag",
                 "risk_adj_sample_wgt_sector_nonag",
                 "risk_adj_sample_wgt_sector_low"),
  stringsAsFactors = FALSE
)


########################################
# 1. BUILD RESPONSE FUNCTION (ag vs nonag vs low)
########################################

rf_long_list <- lapply(seq_len(nrow(spec_map)), function(i) {
  sp  <- spec_map$spec[i]
  yh  <- spec_map$yhat_col[i]
  se  <- spec_map$se_col[i]
  
  rf %>%
    transmute(
      temp = temp,
      spec = sp,
      yhat = .data[[yh]],
      lwr  = .data[[yh]] - 1.96 * .data[[se]],
      upr  = .data[[yh]] + 1.96 * .data[[se]]
    )
})

rf_long <- bind_rows(rf_long_list)

# Axis limits for RF panel
y_range <- range(rf_long$lwr, rf_long$upr, na.rm = TRUE)
x_range <- range(rf_long$temp,              na.rm = TRUE)

########################################
# 1.5 COMPUTE PEAK COORDS (for subtitle)
########################################

peak_df <- rf_long %>%
  filter(is.finite(temp), is.finite(yhat)) %>%
  group_by(spec) %>%
  slice_max(order_by = yhat, n = 1, with_ties = FALSE) %>%
  ungroup() %>%
  mutate(
    temp_round = round(temp, 8),
    yhat_round = round(yhat, 8)
  )

fmt_peak <- function(df_row, fallback = "x=NA, y=NA") {
  if (nrow(df_row) == 0) return(fallback)
  glue("x={df_row$temp_round}, y={df_row$yhat_round}")
}

peak_line <- paste(
  sapply(spec_map$spec, function(sp) {
    df_row <- peak_df %>% filter(spec == sp) %>% slice(1)
    glue("{sp} opt: {fmt_peak(df_row)}")
  }),
  collapse = "\n"
)


########################################
# 2. HISTOGRAM: ag vs nonag vs low
########################################

hist_long_list <- lapply(seq_len(nrow(spec_map)), function(i) {
  sp <- spec_map$spec[i]
  wc <- spec_map$weight_col[i]
  
  temp_dist %>%
    transmute(
      temp   = temp,
      spec   = sp,
      weight = .data[[wc]]
    )
})

hist_long <- bind_rows(hist_long_list)

hist_max <- max(hist_long$weight, na.rm = TRUE)
if (!is.finite(hist_max) || hist_max <= 0) hist_max <- 1

########################################
# 3. FACTOR ORDER + STYLE MAPS
########################################

spec_levels <- c(label_low, label_nonag, label_ag)  # change order if you want
rf_long   <- rf_long   %>% mutate(spec = factor(spec, levels = spec_levels))
hist_long <- hist_long %>% mutate(spec = factor(spec, levels = spec_levels))

# Colors: names MUST match the actual values of `spec`
cols <- setNames(
  c("#1B6CA8", "#2A9D8F", "#5E4987"),
  c(label_low, label_nonag, label_ag)
)
fills <- cols

# Linetypes: names MUST match the actual values of `spec`
lts <- setNames(
  c("dashed", "dotdash", "solid"),
  c(label_low, label_nonag, label_ag)
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
  geom_col(position = "identity", alpha = 0.30) +
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
    title    = "Ag vs Non-ag vs Low Comparison (27-28-41 Knots) [real]",
    subtitle = peak_line,
    theme = theme(
      plot.title    = element_text(hjust = 0.5, face = "bold", size = 16),
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

cat(glue("\n✅ Figure saved (3-way overlay + peak coords in subtitle):\n{outfile}\n"))
