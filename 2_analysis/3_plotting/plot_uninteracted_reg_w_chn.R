#############
# INITIALIZE
#############

rm(list = ls())
library(dplyr)
library(ggplot2)
library(readr)
library(patchwork)
library(parallel)
library(testit)  
library(dplyr)
library(readr)
library(testit)
library(glue)
library(data.table)

source('~/repos/labor-code-release-2020/0_subroutines/paths.R')
source('~/repos/labor-code-release-2020/2_analysis/0_subroutines/functions.R')

#############
# GET DATA
#############

rf = read_csv(
		glue("{DIR_RF}/uninteracted_reg_w_chn/",
		"uninteracted_reg_w_chn_full_response.csv"))


temp_dist = read_csv(
  glue("{DIR_OUTPUT}/temp_dist/wchn_temp_dist.csv")
)

data = mclapply(
      list("low","high"),
      df = rf,
      reshape,
      mc.cores=3) %>%
      rbindlist(use.names=TRUE)

  hist = mclapply(
    list("low","high"),
    df = temp_dist,
    vars=c("no_wgt", "risk_adj_sample_wgt"),
    reshape,
    mc.cores=3) %>%
    rbindlist(use.names=TRUE)

  #############
  # PLOT
  #############

for(weight in list("no_wgt", "risk_adj_sample_wgt")) {

  # Plot response function
  p = ggplot(data, aes(x = temp)) +
        geom_line(aes(y = yhat), size = 1) + 
        facet_wrap(vars(risk))  +    
        theme_bw() + 
        geom_hline(yintercept=0, color = "red") + 
        theme(legend.position = "none") + 
        ggtitle("Response Functions") +
        ylab("Change in mins worked") + xlab("Temperature") +
        geom_ribbon(aes(ymin = lowerci, ymax = upperci), alpha = 0.2 )  +
        scale_x_continuous(breaks=seq(-20,45,10),labels=waiver())

  # Plot histogram
  q = ggplot(hist) +
        geom_col(aes(x = temp, y = get(weight)), 
                 alpha = 1, orientation = "x") +
        facet_wrap(vars(risk))  +    
        theme_bw() +
        theme(legend.position = "none") +
        ylab("Observations") + xlab("Density") +
        scale_fill_manual(values=c("black","red")) +    
        guides(alpha=FALSE)  +
        scale_x_continuous(breaks=seq(-20,45,10),labels=waiver())

  # Combine and export
  pdf(glue('{DIR_FIG}/rf_plots/uninteracted_reg_w_chn_hist_{weight}.pdf'))
  plot(p/q)
  dev.off()

}
  
