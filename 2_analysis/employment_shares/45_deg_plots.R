rm(list=ls())
library(tidyverse)
library(glue)
#library(cilpath.r)
library(lfe)
library(sf)
library(rgdal)
library(testthat)
library(grid)
library(gridExtra)
library(numbers)
library(cowplot)

#cilpath.r:::cilpath()

out = glue("/home/jonahmgilbert/repos/labor-code-release-2020/output/employment_shares") # change username here

plot = read_csv(glue("{out}/yhat_values/45_deg_plot.csv")) %>% 
      rename(temp = tavg_1_pop_ma_30yr) 

plot = plot %>% filter(complete.cases(plot)) # writing filter separately as it won't work in loading data above

# temperature prediction with global min of -27˚C and global max of 43˚C and no continent fixed effect
plot1 <- ggplot() + 
  geom_point(data = plot, aes(x= yhat_main, y= yhat_lrtk, 
                                colour = log_inc)) + 
  geom_line(data = plot, aes(x = yhat_lrtk, y = yhat_lrtk), colour = "red") + labs(colour = "Log GDP PC") + 
  xlab("predicted riskshare values- LR(T^K)") + ylab("predicted riskshare values- LRT^K") + 
  ylim(0,1) + xlim(0,1)

plot2 <- ggplot() + 
  geom_point(data = plot, aes(x= yhat_main, y= yhat_lrtk, 
                                colour = temp)) + 
  geom_line(data = plot, aes(x = yhat_lrtk, y = yhat_lrtk), color = "red") + labs(colour = "LRT") + 
  xlab("predicted riskshare values- LR(T^K)") + ylab("predicted riskshare values- LRT^K") + 
  ylim(0,1) + xlim(0,1)

# combine line graph and histogram together
theme_set(theme_minimal())

p <- plot_grid(
  plot_grid(
    plot1 + theme(legend.position = "none")
    , plot2 + theme(legend.position = "none")
    , ncol = 1
    , rel_heights = c(1,1)
    , align = "hv")
  , plot_grid(
    get_legend(plot1)
    , get_legend(plot2)
    , ncol =1)
  , rel_widths = c(4,1)
  )

ggsave(glue("{out}/plot/predictions/45_deg_shaded.pdf"), plot = p, width = 8, height = 11)
