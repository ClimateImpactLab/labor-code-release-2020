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

source('/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/0_subroutines/paths.R')
source('/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/2_analysis/0_subroutines/functions.R')

#################
# DEFINE OUTPATH
#################

# Define output path
outpath = glue("{DIR_FIG}/paper")
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
       "uninteracted_reg_comlohi_full_response_2025_manu_noeu.csv"))

# temperature distribution and densities
temp_dist = read_csv(
  glue("{DIR_OUTPUT}/temp_dist/nochn_temp_dist.csv")
)

####################
# RESPONSE FUNCTION
####################

data = mclapply(
  list("comm","low","hr3","manuf"),
  df = rf,
  reshape,
  mc.cores=4) %>%
  rbindlist(use.names=TRUE)

####################
# HISTOGRAMS
####################

# unweighted histogram
hist_no_wgt_raw = mclapply(
  list("comm","low","high"),
  df = temp_dist,
  vars=c("no_wgt"),
  reshape,
  mc.cores=3) %>%
  rbindlist(use.names=TRUE) %>%
  mutate(weight = no_wgt)

hist_no_wgt = hist_no_wgt_raw %>%
  bind_rows(
    hist_no_wgt_raw %>% filter(risk == "high") %>% mutate(risk = "hr3"),
    hist_no_wgt_raw %>% filter(risk == "high") %>% mutate(risk = "manuf")
  )

# histogram with pop and risk-adj weights respectively
hist_adj_wgt_raw = mclapply(
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

hist_adj_wgt = hist_adj_wgt_raw %>%
  bind_rows(
    hist_adj_wgt_raw %>% filter(risk == "high") %>% mutate(risk = "hr3"),
    hist_adj_wgt_raw %>% filter(risk == "high") %>% mutate(risk = "manuf")
  )

#############
# PLOT
#############

plot_temp_panels <- function(data,
                             hist_no_wgt,
                             hist_adj_wgt,
                             use_adj = FALSE,
                             risk_levels = c("comm", "low", "hr3", "manuf")) {
  
  # pick which histogram DF
  hist_df = if (use_adj) hist_adj_wgt else hist_no_wgt
  
  # enforce factor order
  data = data %>% mutate(risk=factor(risk, levels=risk_levels))
  hist_df = hist_df %>% mutate(risk=factor(risk, levels=risk_levels))
  
  # compute global y-ranges
  y_range = range(data$lowerci, data$upperci, na.rm = TRUE)
  hist_max = max(hist_df$weight, na.rm = TRUE)
  
  make_strip <- function(r, tag_letter, y_range, hist_max, panel_label) {
    
    d_sub = filter(data, risk==r)
    h_sub = filter(hist_df, risk==r)
    
    # response plot
    p <- ggplot(d_sub, aes(x=temp, y=yhat)) +
      geom_line(size=1, colour="#5E4987") +
      geom_ribbon(aes(ymin=lowerci, ymax=upperci), alpha=0.2, fill="#5E4987",colour = NA) +
      scale_y_continuous(limits=c(-123,40), breaks=seq(-100, 40, 50), expand=c(0,0)) +
      scale_x_continuous(breaks=seq(-20, 47, 20),
                         limits=c(-24, 47),
                         expand=c(0,0),
                         minor_breaks=NULL) +
      labs(y=NULL,
           tag=tag_letter) +
      theme_minimal() +
      theme(axis.line=element_blank(),
            axis.line.y=element_line(color = "black"),
            axis.ticks=element_line(color = "black"),
            axis.ticks.length=unit(3, "pt"),
            panel.grid=element_blank(),
            panel.background=element_blank(),
            legend.position="none",
            plot.tag.position=c(0.02, 0.98),
            plot.tag=element_text(size = 14, hjust = 0, vjust = 1))
    
    # histogram plot
    q = ggplot(h_sub, aes(x=temp, y=weight)) +
      geom_col() +
      scale_y_continuous(limits=c(0, hist_max), expand = c(0,0)) +
      scale_x_continuous(breaks=seq(-20, 47, 20), limits=c(-24, 47), expand=c(0,0), minor_breaks=NULL) +
      labs(x=NULL,
           y=NULL,
           title=panel_label) +
      theme_minimal() +
      theme(axis.line=element_blank(),
            axis.line.y=element_line(color = "black"),
            axis.ticks=element_line(color="black"),
            axis.ticks.length=unit(3, "pt"),
            axis.text.y=element_blank(),
            axis.ticks.y=element_blank(),
            panel.grid=element_blank(),
            panel.background=element_blank(),
            legend.position="none",
            plot.title=element_text(hjust=0.5, size=12))
    
    p / q
  }

  panel_labels = c("comm", "low", "hr3", "manuf")
  
  strips <- mapply(
    FUN=make_strip,
    r=risk_levels,
    tag_letter=LETTERS[seq_along(risk_levels)],
    panel_label=panel_labels,
    MoreArgs=list(y_range=y_range, hist_max=hist_max),
    SIMPLIFY=F
  )
  
  wrap_plots(strips, ncol=length(risk_levels), align="v")
}
#######################
# PLOT AND SAVE OUTPUT
#######################

# Define output directory
save_dir <- "/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/output/rf_plots/3sector_uninteracted_reg_comlohi_2025"

# Create the directory if it doesn't exist
dir.create(save_dir, showWarnings = FALSE, recursive = TRUE)

# Create the plot (adjusted version for paper)
p <- plot_temp_panels(data, hist_no_wgt, hist_adj_wgt, use_adj = TRUE)

# Define output filename
outfile <- glue("{save_dir}/3sector_uninteracted_reg_comlohi_rf_plot_2025.pdf")

# Save the plot
ggsave(
  filename = outfile,
  plot = p,
  width = 12,
  height = 9,
  device = cairo_pdf
)

# Optional: message confirmation
cat(glue("\n✅ Figure saved successfully at:\n{outfile}\n"))
