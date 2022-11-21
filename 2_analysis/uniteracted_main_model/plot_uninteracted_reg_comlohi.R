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

# response function
rf = read_csv(
		glue("{DIR_RF}/uninteracted_reg_comlohi/",
		"uninteracted_reg_comlohi_full_response.csv"))

# temperature distribution and densities
temp_dist = read_csv(
  glue("{DIR_OUTPUT}/temp_dist/nochn_temp_dist.csv")
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

for(hist in list("hist_no_wgt", "hist_adj_wgt")) {

# Plot response function
p = ggplot(data, aes(x = temp)) +
      geom_line(aes(y = yhat), size = 1) + 
      facet_wrap(vars(risk))  +    
      theme_bw() + 
      geom_hline(yintercept=0, color = "red") + 
      theme(legend.position = "none") + 
      ggtitle("Response Functions") +
      ylab("Change in mins worked") + xlab("Temperature") +
      geom_ribbon(aes(ymin = lowerci, ymax = upperci), alpha = 0.2 ) +
      scale_x_continuous(breaks=seq(-20,45,10),labels=waiver())


# Plot histogram
q = ggplot(get(hist)) +
      geom_col(aes(x = temp, y = weight), 
               alpha = 1, orientation = "x") +
      facet_wrap(vars(risk))  +    
      theme_bw() +
      theme(legend.position = "none") +
      ylab("Observations") + xlab("Density") +
      scale_fill_manual(values=c("black","red")) +    
      guides(alpha=FALSE) +
      scale_x_continuous(breaks=seq(-20,45,10),labels=waiver())


# Combine and export
pdf(glue('{DIR_FIG}/rf_plots/uninteracted_reg_comlohi_{hist}.pdf'))
plot(p/q)
dev.off()

}


plot(p/q)
