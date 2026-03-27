# Run regressions (same as those in riskshare_regressions.do) and make table. 
# Using the yhat files, make overlaid scatter and yhat value plots.
# relative to the actual HR emp shares
# Author: Nishka Sharma, nishkasharma@uchicago.edu
# Date: 5/25/2021

rm(list=ls())
library(tidyverse)
library(glue)
library(cilpath.r)
library(lfe)
library(sf)
library(rgdal)
library(testthat)
library(grid)
library(gridExtra)
library(numbers)

cilpath.r:::cilpath()
source("~/repos/post-projection-tools/mapping/imgcat.R") #this redefines the way ggplot plots. 

lab = glue("/mnt/CIL_labor")
out = glue("/home/nsharma/repos/labor-code-release-2020/output/employment_shares") # change username here

# load data and clean it up a little
dat = read_csv(glue("{lab}/1_preparation/employment_shares/data/emp_inc_clim_merged.csv")) %>%
  # drop places that don't exist
  filter(geolev1 != 1 ) %>%
  filter(!(mod(geolev1, 100) %in% c(98, 99) & geolev1 != 192099)) %>%
  filter(!is.na(gdppc_adm1_pwt_downscaled_13br)) %>%
  filter(!is.na(total_pop)) %>% # filter to census years only
  filter(year <= 2010) # drop years we don't have clim data for (GMFD only goes to 2010)

max_yr = dat %>%
  group_by(geolev1) %>%
  summarize(max_year = max(year)) %>%
  ungroup()

dat %<>%
  left_join(max_yr, by="geolev1") %>%
  mutate(
    log_inc = log(gdppc_adm1_pwt_downscaled_13br), #use log_gdppc_adm1_pwt_ds_15ma instead of log_inc
    log_share = log(ind_highrisk_share),
    log_popop = log(popop),
  ) %>%
  data.frame() %>%
  filter(year == max_year)

# subset data to use in graphs
dat_ss <- dat[,c("year", "geolev1", "ind_highrisk_share", 
                 "log_gdppc_adm1_pwt_ds_15ma", "tavg_1_pop_MA_30yr", 
                 "tavg_2_pop_MA_30yr", "tavg_3_pop_MA_30yr", 
                 "tavg_4_pop_MA_30yr", "continent")]
dat_ss <- dat_ss[complete.cases(dat_ss),]

# load data for graph
yhat_inc = read_csv(glue("{out}/yhat_values/log_inc_poly4_IncPred.csv"))
yhat_temp = read_csv(glue("{out}/yhat_values/log_inc_poly4_TempPred.csv")) 
yhat_temp_poly4 = read_csv(glue("{out}/yhat_values/log_inc_poly4_TempPredMinMax.csv")) #change input filename here for 50C max temperature
yhat_inc_continent_fe = read_csv(glue("{out}/yhat_values/log_inc_poly4_continent_fes_IncPred.csv"))
yhat_temp_continent_fe = read_csv(glue("{out}/yhat_values/log_inc_poly4_continent_fes_TempPred.csv"))

# graphs

# temperature prediction with in-sample data limits
temp_pred <- ggplot() + 
  geom_point(data = dat_ss, aes(x= tavg_1_pop_MA_30yr, y= ind_highrisk_share)) + 
  geom_ribbon(data=yhat_temp,aes(x = temp, ymin = lowerci_hi, ymax = upperci_hi), 
              inherit.aes = FALSE, alpha = 0.6, fill = "grey") + 
  geom_line(data = yhat_temp, aes(x = temp, y = yhat, linetype= "no Continent FE")) + labs(colour = "Log GDP PC") + 
  geom_ribbon(data=yhat_temp_continent_fe,aes(x = temp, ymin = lowerci_hi, ymax = upperci_hi), 
              inherit.aes = FALSE, alpha = 0.6, fill = "grey") + 
  geom_line(data = yhat_temp_continent_fe, aes(x = temp, y = yhat, linetype= "Continent FE")) + 
  scale_linetype_manual("Model", values = c("no Continent FE" = 1, "Continent FE" = 2)) + labs(colour = "LRT") + 
  xlab("LRT - in sample") + ylab("predicted riskshare values- LR(T^K)")

temp_pred

ggsave(glue("{out}/plot/predictions/temp_pred_continent_fe_scatter.pdf"), plot = temp_pred, width = 10, height = 7)

# temperature prediction with global max of 50˚C
temp_pred_min_max <- ggplot() + 
  geom_point(data = dat_ss, aes(x= tavg_1_pop_MA_30yr, y= ind_highrisk_share)) + 
  geom_ribbon(data=yhat_temp_poly4,aes(x = temp, ymin = lowerci_hi, ymax = upperci_hi), 
              inherit.aes = FALSE, alpha = 0.6, fill = "grey") + 
  geom_line(data = yhat_temp_poly4, aes(x = temp, y = yhat)) + labs(colour = "Log GDP PC") + 
  xlab("LRT - across all models") + ylab("predicted riskshare values- LR(T^K)")

temp_pred_min_max

ggsave(glue("{out}/plot/predictions/temp_pred_scatter_min_max.pdf"), plot = temp_pred_min_max, width = 10, height = 7)

# income predictions with in-sample min and max
inc_pred <- ggplot()  + 
  geom_point(data = dat_ss, aes(x= log_gdppc_adm1_pwt_ds_15ma, y= ind_highrisk_share)) + 
  geom_ribbon(data=yhat_inc,aes(x = inc_log, ymin = lowerci_hi, ymax = upperci_hi), 
              inherit.aes = FALSE, alpha = 0.6, fill = "grey") + 
  geom_line(data = yhat_inc, aes(x= inc_log, y= yhat, linetype= "no Continent FE")) + labs(colour = "LRT") + 
  geom_ribbon(data=yhat_inc_continent_fe,aes(x = inc_log, ymin = lowerci_hi, ymax = upperci_hi), 
              inherit.aes = FALSE, alpha = 0.6, fill = "grey") + 
  geom_line(data = yhat_inc_continent_fe, aes(x= inc_log, y= yhat, linetype= "Continent FE")) + 
  scale_linetype_manual("Model", values = c("no Continent FE" = 1, "Continent FE" = 2)) + labs(colour = "LRT") + 
  xlab("Log GDP PC") + ylab("predicted riskshare values")

inc_pred

ggsave(glue("{out}/plot/predictions/inc_pred_continent_fe_scatter.pdf"), plot = inc_pred, width = 10, height = 7)

# regressions for table

fit1 = lm(ind_highrisk_share ~ tavg_1_pop_MA_30yr + tavg_2_pop_MA_30yr + 
            tavg_3_pop_MA_30yr + tavg_4_pop_MA_30yr + 
            log_gdppc_adm1_pwt_ds_15ma, data=dat)
summary(fit1)

fit2 = lm(ind_highrisk_share ~ tavg_1_pop_MA_30yr + tavg_2_pop_MA_30yr + 
            tavg_3_pop_MA_30yr + tavg_4_pop_MA_30yr + 
            log_gdppc_adm1_pwt_ds_15ma + factor(continent), data=dat)
summary(fit2)

stargazer(fit1, fit2, title = "Risk-share Regression Results", align=TRUE, 
          dep.var.caption = c("High risk share"), dep.var.labels = c(""), 
          column.labels = c("without continent FE", "with continent FE"), 
          covariate.labels = c("Temperature", "Temperature^2", "Temperature^3",
                               "Temperature^4", "Log Income", "Americas", 
                               "Asia", "Europe", "Constant"), 
          add.lines = list(c("Continent fixed effects", "No", "Yes")),
          omit.stat=c("ser","f"), no.space=TRUE)





