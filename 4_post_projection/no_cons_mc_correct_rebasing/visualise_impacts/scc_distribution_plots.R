rm(list=ls())

source("~/repos/labor-code-release-2020/0_subroutines/paths.R")

library(tidyverse)
library(glue)
library(lfe)
library(grid)
library(gridExtra)
library(DescTools)

scc_dist = read_csv("/mnt/CIL_labor/6_ce/risk_aversion_constant_model_collapsed_uncollapsed_sccs.csv") 

scc_dist <- scc_dist[,c(2:10)]

scc_wins = scc_dist %>% 
		group_by(discrate, rcp) %>% 
		mutate(
			scc_wins = Winsorize(scc, probs = c(0.01, 0.99), minval = NULL, maxval = NULL)
			)

scc_dist %>% 
	group_by(discrate, rcp) %>% 
	summarise(mean = mean(scc), min = min(scc), max = max(scc), median = median(scc), 
		q1 = quantile(scc, 0.01), q5 = quantile(scc, 0.05), q25 = quantile(scc, 0.25), 
		q75 = quantile(scc, 0.75), q95 = quantile(scc, 0.95), q99 =  quantile(scc, 0.99), 
		n= n())

scc_wins %>% 
	group_by(discrate, rcp) %>% 
	summarise(mean = mean(scc_wins), min = min(scc_wins), max = max(scc_wins), 
		median = median(scc_wins), n= n())

p2 <- ggplot() + 
    geom_boxplot(data = scc_wins, aes(x=rcp, y= scc_wins, fill=rcp)) +
    facet_wrap(~discrate, scale="free")

ggsave(glue("{DIR_FIG}/scc_distribution_plots/rcp_box_2_try.pdf"), plot = p2, 
	width = 10, height = 10)


## code below for reference
# dist <- ggplot() + 
#   geom_point(data = dat_ss, aes(x= tavg_1_pop_MA_30yr, y= ind_highrisk_share, 
#                                 colour = log_gdppc_adm1_pwt_ds_15ma)) + 
#   geom_ribbon(data=yhat_temp,aes(x = temp, ymin = lowerci_hi, ymax = upperci_hi), 
#               inherit.aes = FALSE, alpha = 0.6, fill = "grey") + 
#   geom_line(data = yhat_temp, aes(x = temp, y = yhat)) + labs(colour = "Log GDP PC") + 
#   xlab("LRT - in sample") + ylab("predicted riskshare values- LR(T^K)")

# temp_pred

# ggsave(glue("{DIR_FIG}/scc_distribution_plots/box_scatter.pdf"), plot = temp_pred, width = 10, height = 7)
