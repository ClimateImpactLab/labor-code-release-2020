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

source('/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/0_subroutines/paths.R')
source('/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/2_analysis/0_subroutines/functions.R')

#################
# DEFINE OUTPATH
#################

# Define output path
outpath = glue("/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/output/rf_plots/uninteracted_reg_comlohi_2026")
dir.create(outpath, showWarnings=F)

# Define plot name
outname = "uninteracted_reg_comlohi_rf_plot"
format = "pdf"

#############
# GET DATA
#############

# response function
rf = read_csv(
  glue("{DIR_RF}/uninteracted_reg_comlohi/",
       "uninteracted_reg_comlohi_full_response_2026_272841.csv"))

# temperature distribution and densities
temp_dist = read_csv(
  glue("{DIR_OUTPUT}/temp_dist/Dec2025/global_temp_dist.csv")
)

####################
# RESPONSE FUNCTION
####################

data = mclapply(
  list("comm","low","high"),
  df = rf,
  reshape,
  mc.cores=3) %>%
  rbindlist(use.names=TRUE)

####################
# HISTOGRAMS
####################

# unweighted histogram
hist_no_wgt = mclapply(
  list("comm","low","high"),
  df = temp_dist,
  vars=c("no_wgt"),
  reshape,
  mc.cores=3) %>%
  rbindlist(use.names=TRUE) %>%
  mutate(weight = no_wgt)

# histogram with pop and risk-adj weights respectively
hist_adj_wgt = mclapply(
  list("comm","low","high"),
  df = temp_dist,
  vars=c("risk_adj_sample_wgt", "pop_adj_sample_wgt"),
  reshape,
  mc.cores=3) %>%
  rbindlist(use.names=TRUE) %>%
  mutate(weight = 
           ifelse(risk == "comm",
                  pop_adj_sample_wgt,
                  risk_adj_sample_wgt)
  )

#############
# PLOT
#############

plot_temp_panels <- function(data,
                             hist_no_wgt,
                             hist_adj_wgt,
                             use_adj = FALSE,
                             risk_levels = c("comm", "low", "high")) {
  
  # pick which histogram DF
  hist_df = if (use_adj) hist_adj_wgt else hist_no_wgt
  
  # enforce factor order
  data = data %>% mutate(risk=factor(risk, levels=risk_levels))
  hist_df = hist_df %>% mutate(risk=factor(risk, levels=risk_levels))
  
  # compute global y-ranges
  y_range = range(data$lowerci, data$upperci, na.rm = TRUE)
  hist_max = max(hist_df$weight, na.rm = TRUE)
  
  make_strip <- function(r, tag_letter, hist_max) {
    
    d_sub <- dplyr::filter(data, risk == r)
    h_sub <- dplyr::filter(hist_df, risk == r)
    
    # Common x scale
    x_breaks  <- seq(-20, 47, 20)
    x_limits  <- c(-24, 47)
    
    # ---------- Top: response function ----------
    p <- ggplot(d_sub, aes(x = temp, y = yhat)) +
      geom_line(size = 1, colour = "#5E4987") +
      geom_ribbon(aes(ymin = lowerci, ymax = upperci),
                  alpha = 0.2, fill = "#5E4987", colour = NA) +
      scale_y_continuous(
        limits = c(-400, 40),
        expand = c(0, 0)
      ) +
      scale_x_continuous(
        breaks = x_breaks, limits = x_limits,
        expand = c(0, 0), minor_breaks = NULL
      ) +
      labs(x = NULL, y = NULL, tag = tag_letter) +
      theme_minimal() +
      theme(
        panel.grid = element_blank(),
        panel.background = element_blank(),
        legend.position = "none",
        
        # keep y axis line, remove x axis elements (shared x shown below)
        axis.line = element_blank(),
        axis.line.y = element_line(color = "black"),
        axis.ticks = element_line(color = "black"),
        axis.ticks.length = unit(3, "pt"),
        axis.text.x = element_blank(),
        axis.ticks.x = element_blank(),
        
        # IMPORTANT: kill margins so it touches the histogram
        plot.margin = margin(t = 0, r = 0, b = 0, l = 0),
        
        plot.tag.position = c(0.02, 0.98),
        plot.tag = element_text(size = 14, hjust = 0, vjust = 1)
      )
    
    # ---------- Bottom: histogram ----------
    q <- ggplot(h_sub, aes(x = temp, y = weight)) +
      geom_col() +
      scale_y_continuous(
        limits = c(0, hist_max),
        expand = c(0, 0)
      ) +
      scale_x_continuous(
        breaks = x_breaks, limits = x_limits,
        expand = c(0, 0), minor_breaks = NULL
      ) +
      labs(x = NULL, y = NULL) +
      theme_minimal() +
      theme(
        panel.grid = element_blank(),
        panel.background = element_blank(),
        legend.position = "none",
        
        axis.line = element_blank(),
        axis.line.y = element_line(color = "black"),
        axis.ticks = element_line(color = "black"),
        axis.ticks.length = unit(3, "pt"),
        
        # remove bottom y numbers/ticks (keep axis line)
        axis.text.y = element_blank(),
        axis.ticks.y = element_blank(),
        
        # IMPORTANT: kill margins so it touches the response plot
        plot.margin = margin(t = 0, r = 0, b = 0, l = 0)
      )
    
    # Stack with zero gap and 2:1 height ratio
    (p / q) + patchwork::plot_layout(heights = c(2, 1))
  }
  
  
  hist_max <- max(hist_df$weight, na.rm = TRUE)
  
  strips <- mapply(
    FUN = make_strip,
    r = risk_levels,
    tag_letter = LETTERS[seq_along(risk_levels)],
    MoreArgs = list(hist_max = hist_max),
    SIMPLIFY = FALSE
  )
  
  wrap_plots(strips, ncol = length(risk_levels))
  
}

# Example usage
# unweighted
print(plot_temp_panels(data, hist_no_wgt, hist_adj_wgt, use_adj=FALSE))

# adjusted
print(plot_temp_panels(data, hist_no_wgt, hist_adj_wgt, use_adj=TRUE)) # THIS IS PAPER SPEC

# plot and save
p = plot_temp_panels(data, hist_no_wgt, hist_adj_wgt, use_adj=TRUE)
outfile = glue("{outpath}/{outname}.{format}")
ggsave(outfile, plot=p, width=12, height=4)
