rm(list=ls())

source("~/repos/labor-code-release-2020/0_subroutines/paths.R")

library(tidyverse)
library(dplyr)
library(reshape2)
library(glue)

full = read_csv("/mnt/CIL_labor/6_ce/scc_distribution_with_uncertainty/fulluncertainty.csv") 
clim = read_csv("/mnt/CIL_labor/6_ce/scc_distribution_with_uncertainty/climateuncertainty.csv")
stat = read_csv("/mnt/CIL_labor/6_ce/scc_distribution_with_uncertainty/statisticaluncertainty_quantiles.csv")

full <- full[,c(2:7)]
clim <- clim[,c(2:6)]

# adding this column to ease rbind in the next steps
clim <- clim %>% add_column(pctile = NA, .before = 2)

full$uncertainty <- "Full uncertainty"
clim$uncertainty <- "Climate uncertainty"

# combined to calculate quantiles for boxplot
df <- rbind(full, clim)

full %>% 
  group_by(rcp) %>% 
  summarise(mean = mean(scc), min = min(scc), max = max(scc), median = median(scc), 
            q1 = quantile(scc, 0.01), q5 = quantile(scc, 0.05), q25 = quantile(scc, 0.25), 
            q75 = quantile(scc, 0.75), q95 = quantile(scc, 0.95), q99 =  quantile(scc, 0.99), 
            n= n())
clim %>% 
  group_by(rcp) %>% 
  summarise(mean = mean(scc), min = min(scc), max = max(scc), median = median(scc), 
            q1 = quantile(scc, 0.01), q5 = quantile(scc, 0.05), q25 = quantile(scc, 0.25), 
            q75 = quantile(scc, 0.75), q95 = quantile(scc, 0.95), q99 =  quantile(scc, 0.99), 
            n= n())

#checking to if summary stats are same as above or not
df %>% 
  group_by(rcp, uncertainty) %>% 
  summarise(mean = mean(scc), min = min(scc), max = max(scc), median = median(scc), 
            q1 = quantile(scc, 0.01), q5 = quantile(scc, 0.05), q25 = quantile(scc, 0.25), 
            q75 = quantile(scc, 0.75), q95 = quantile(scc, 0.95), q99 =  quantile(scc, 0.99), 
            n= n())

# first four rows of the 5,95 data frame. full and climate uncertainty quantiles for boxplots
y <- df %>% 
  group_by(rcp, uncertainty) %>%
  summarise(
    mean = mean(scc),
    y1 = quantile(scc, 0.01), 
    y5 = quantile(scc, 0.05), 
    y25 = quantile(scc, 0.25), 
    y50 = quantile(scc, 0.5), 
    y75 = quantile(scc, 0.75), 
    y95 = quantile(scc, 0.95),
    y99 = quantile(scc, 0.99))

# replacing mean in full uncertainty to adding_up_mean scc values from integration code.
# comment the following three lines to retain mean(scc) in full uncertainty.
y <- y %>% 
  mutate(mean=ifelse(uncertainty == "Full uncertainty" & rcp == "rcp45" , 17.08698915, mean),
         mean=ifelse(uncertainty == "Full uncertainty" & rcp == "rcp85" , 20.95549221, mean))

# last two rows of the 5,95 data frame. statistical uncertainty quantiles for boxplot
stat <- stat[stat$discrate==0.02, c("rcp","0.01", "0.05", "0.25", "0.5", "0.75", "0.95", "0.99")] 

# mean for stat uncertainty obtained from the labour SCC spreadsheet in the labour repo
stat <- stat  %>% 
  add_column(uncertainty = "Statistical uncertainty", .before = 2) %>%
  add_column(mean = c(10.788731969266022, 17.028311491665164), .before = 3) %>%
  rename(y1 = "0.01", y5 = "0.05", y25 = "0.25", y50 = "0.5", y75 = "0.75", y95 = "0.95", y99 = "0.99")

# combining everything in data frame for boxplots
y <- rbind(y, stat)

# boxplot!! 
# change ymin and ymax to y1 and y99 respectively for 1,99 whiskers in geom_box aes()
p <- ggplot(y, aes(x = rcp, fill = uncertainty, 
                   group = interaction(rcp, uncertainty))) + theme_bw() +
  geom_boxplot(
    aes(ymin = y5, lower = y25, middle = y50, upper = y75, ymax = y95), 
    stat = "identity") + 
  geom_point(aes(y=mean, colour = "Mean SCC"), 
             shape = 21, size = 2, stroke = 1,
             fill = "white", position = position_dodge(width=0.9)) +
  scale_colour_manual(name = "", values = c("Mean SCC" = "black" )) +
  guides(colour = guide_legend(override.aes = list(linetype = c("blank"), 
                                                   shape = c(21)))) +
  labs(y = "SCC in trillion dollars", x = "", fill = "") +
  theme(axis.title=element_text(size=16), axis.text=element_text(size=14),
        legend.text=element_text(size=14), legend.key.size = unit(2,"line")) +
  scale_x_discrete(labels = c("RCP 4.5", "RCP 8.5"))

ggsave(glue("{DIR_FIG}/scc_distribution_plots/rcp_box_kelly_dist_5_95.pdf"), plot = p, width = 9, height = 7)
