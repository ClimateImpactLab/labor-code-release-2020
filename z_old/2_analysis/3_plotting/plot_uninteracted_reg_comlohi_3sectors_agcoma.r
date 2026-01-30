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

outpath <- glue("{DIR_FIG}")
dir.create(outpath, showWarnings = FALSE)

outname <- "uninteracted_reg_comlohi_rf_plot_3sector"
format  <- "pdf"

#############
# GET DATA
#############

# Response function (3-sector global RF)
rf <- read_csv(glue(
  "{DIR_RF}/uninteracted_reg_comlohi/",
  "uninteracted_reg_comlohi_full_response_2025_noeu_agcoma.csv"
))

# Temperature distribution and densities (global)
temp_dist <- read_csv(
  glue("{DIR_OUTPUT}/temp_dist/2_high_risk/noeu_temp_dist.csv")
)

####################
# SETTINGS
####################

# Five groups:
#   - comm    : all workers (common)
#   - low     : low-risk workers
#   - agri     : agriculture
#   - connmine: construction
#   - manuft  : manufacturing
risk_levels <- c("comm", "low", "agri", "connmine", "manuft")
n_cols      <- length(risk_levels)

####################
# RESPONSE FUNCTION
####################

data <- mclapply(
  risk_levels,
  df = rf,
  FUN = reshape,
  mc.cores = n_cols
) %>%
  rbindlist(use.names = TRUE)

####################
# HISTOGRAMS
####################

# Unweighted histogram
hist_no_wgt <- mclapply(
  risk_levels,
  df   = temp_dist,
  vars = c("no_wgt"),
  FUN  = reshape,
  mc.cores = n_cols
) %>%
  rbindlist(use.names = TRUE) %>%
  mutate(weight = no_wgt)

# Histogram with pop and risk-adj weights:
# comm -> pop_adj_sample_wgt; all others -> risk_adj_sample_wgt
hist_adj_wgt <- mclapply(
  risk_levels,
  df   = temp_dist,
  vars = c("risk_adj_sample_wgt", "pop_adj_sample_wgt"),
  FUN  = reshape,
  mc.cores = n_cols
) %>%
  rbindlist(use.names = TRUE) %>%
  mutate(
    weight = ifelse(
      risk == "comm",
      pop_adj_sample_wgt,
      risk_adj_sample_wgt
    )
  )

#############
# PLOT FUNCTION
#############

plot_temp_panels <- function(data,
                             hist_no_wgt,
                             hist_adj_wgt,
                             use_adj     = FALSE,
                             risk_levels = c("comm", "low", "agri", "connmine", "manuft")) {
  
  n_cols <- length(risk_levels)
  
  # Choose histogram DF
  hist_df <- if (use_adj) hist_adj_wgt else hist_no_wgt
  
  # Factor order
  data    <- data    %>% mutate(risk = factor(risk, levels = risk_levels))
  hist_df <- hist_df %>% mutate(risk = factor(risk, levels = risk_levels))
  
  # Shared histogram max for consistent scaling
  hist_max <- max(hist_df$weight, na.rm = TRUE)
  if (!is.finite(hist_max) || hist_max <= 0) hist_max <- 1
  
  # One column (response + histogram) per risk group
  make_strip <- function(r, hist_max) {
    
    d_sub <- dplyr::filter(data,    risk == r)
    h_sub <- dplyr::filter(hist_df, risk == r)
    
    # Top: response function
    p <- ggplot(d_sub, aes(x = temp, y = yhat)) +
      geom_line(size = 1, colour = "#5E4987") +
      geom_ribbon(
        aes(ymin = lowerci, ymax = upperci),
        alpha = 0.2, fill = "#5E4987", colour = NA
      ) +
      scale_y_continuous(
        limits = c(-123, 40),
        breaks = seq(-100, 40, 25),
        expand = c(0, 0)
      ) +
      scale_x_continuous(
        breaks = seq(-20, 47, 10),
        limits = c(-24, 47),
        expand = c(0, 0),
        minor_breaks = NULL
      ) +
      labs(x = NULL, y = NULL) +
      theme_minimal() +
      theme(
        axis.line         = element_blank(),
        axis.line.y       = element_line(color = "black"),
        axis.ticks        = element_line(color = "black"),
        axis.ticks.length = unit(3, "pt"),
        axis.ticks.x      = element_line(color = "black"),
        axis.text.x       = element_text(color = "black", face = "bold"),
        axis.ticks.y       = element_line(color = "black"),
        axis.text.y       = element_text(color = "black", face = "bold"),
        panel.grid        = element_blank(),
        panel.background  = element_blank(),
        legend.position   = "none",
        # remove extra space below top panel
        plot.margin       = margin(t = 5, r = 5, b = 0, l = 5)
      )
    
    # Bottom: histogram (no y label)
    q <- ggplot(h_sub, aes(x = temp, y = weight)) +
      geom_col(fill = "#1B6CA8") +
      scale_y_continuous(
        limits = c(0, hist_max),
        expand = c(0, 0)
      ) +
      scale_x_continuous(
        breaks = seq(-20, 47, 10),
        limits = c(-24, 47),
        expand = c(0, 0),
        minor_breaks = NULL
      ) +
      labs(x = NULL, y = NULL) +
      theme_minimal() +
      theme(
        axis.line         = element_blank(),
        axis.line.y       = element_line(color = "black"),
        axis.ticks        = element_line(color = "black"),
        axis.ticks.length = unit(3, "pt"),
        axis.text.y       = element_blank(),
        axis.ticks.y      = element_blank(),
        axis.ticks.x      = element_line(color = "black"),
        axis.text.x       = element_text(color = "black", face = "bold"),
        panel.grid        = element_blank(),
        panel.background  = element_blank(),
        legend.position   = "none",
        # collapse space below histograms
        plot.margin       = margin(t = 0, r = 5, b = 0, l = 5)
      )
    
    p / q
  }
  
  # Build strips for all risk groups
  strips <- mapply(
    FUN      = make_strip,
    r        = risk_levels,
    MoreArgs = list(hist_max = hist_max),
    SIMPLIFY = FALSE
  )
  
  strips <- wrap_plots(
    strips,
    ncol  = n_cols,
    align = "v"
  )
  
  ################
  # COLUMN HEADERS
  ################
  
  header_labels <- c(
    "A All workers",
    "B Low-risk workers",
    "C Workers in Agriculture",
    "D Workers in Construction",
    "E Workers in Manufacturing"
  )
  
  # x positions centered over each of the n_cols panels
  x_pos <- seq(
    1 / (2 * n_cols),
    1 - 1 / (2 * n_cols),
    length.out = n_cols
  )
  
  col_headers <- ggdraw()
  for (i in seq_len(n_cols)) {
    col_headers <- col_headers +
      draw_label(
        header_labels[i],
        x = x_pos[i], y = 0.98,
        hjust = 0.5, vjust = 1,
        fontface = "bold", size = 11
      )
  }
  
  ##############
  # COMBINE ALL
  ##############
  
  # Two rows: headers + panels
  grid <- (col_headers / strips) +
    plot_layout(heights = c(0.10, 0.90))
  
  # Title
  titled <- grid +
    plot_annotation(
      title = "Global Labor Supply–Temperature Response - Classification 1 Specification",
      theme = theme(
        plot.margin = margin(t = 5, r = 10, b = 20, l = 10),
        plot.title  = element_text(
          size  = 15,
          face  = "bold",
          hjust = 0.5
        )
      )
    )
  
  # Global axis labels (drawn on top of composed plot)
  final_plot <- ggdraw(titled) +
    # Shared x-axis label
    draw_label(
      "Temperature (°C)",
      x = 0.5, y = 0.02, vjust = 0,
      size = 13, fontface = "bold"
    ) +
    # y-axis label
    draw_label(
      "Minutes worked",
      x = 0.01, y = 0.64,
      angle = 90, vjust = 1,
      size = 13, fontface = "bold"
    )
  
  final_plot
}

#############
# RUN & SAVE
#############

# Define output directory
save_dir <- "/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/output/rf_plots/3sector_uninteracted_reg_comlohi_2025"

# Create the directory if it doesn't exist
dir.create(save_dir, showWarnings = FALSE, recursive = TRUE)

# Create the plot (adjusted version for paper)
p <- plot_temp_panels(data, hist_no_wgt, hist_adj_wgt, use_adj = TRUE)

# Define output filename
outfile <- glue("{save_dir}/3sector_uninteracted_reg_comlohi_rf_plot_2025_agcoma.pdf")

# Save the plot
ggsave(
  filename = outfile,
  plot = p,
  width = 12,
  height = 7,
  device = cairo_pdf
)

# Optional: message confirmation
cat(glue("\n✅ Figure saved successfully at:\n{outfile}\n"))
