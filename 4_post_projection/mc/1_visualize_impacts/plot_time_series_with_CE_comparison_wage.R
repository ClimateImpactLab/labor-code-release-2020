# Mins. time series (full, income, and no adapt)
# %GDP time series (full, income, and no adapt)

rm(list = ls())
source("~/repos/labor-code-release-2020/0_subroutines/paths.R")
source("~/repos/post-projection-tools/mapping/imgcat.R") #this redefines the way ggplot plots. 
library(glue)
library(parallel)
library(imputeTS)
library(tidyverse)
library(tidyr)
# Load in the required packages, installing them if necessary 
if(!require("pacman")){install.packages(("pacman"))}
pacman::p_load(ggplot2, 
               dplyr,
               readr, 
               DescTools,
               RColorBrewer)

source(glue("{DIR_REPO_LABOR}/4_post_projection/0_utils/time_series.R"))



# process CE data (only need to run once)


# CE_data = read_csv("/mnt/CIL_energy/code_release_data_pixel_interaction/intermediate_data/maps_data.csv")

# CE_data = CE_data %>% filter(model == "OECD Env-Growth")%>%
#           select(c("year", "region", "rcp", "cons_ce", "gdppc", "cons", "damages"))
# CE_data = CE_data %>% mutate(ce_dmgpc = gdppc - cons_ce,
#                               dmgpc = gdppc - cons,)

# IR_pop = read_csv('/mnt/CIL_energy/code_release_data_pixel_interaction/projection_system_outputs/covariates/SSP3_IR_level_population.csv')

# # IR_pop$year[IR_pop$year == 2100] <- 2099

# global_gdp = read_csv("/mnt/CIL_energy/code_release_data_pixel_interaction/projection_system_outputs/covariates/SSP3-high-global-gdp-time_series.csv")

# merged = merge(CE_data, IR_pop, by = c("region","year"), all.x = TRUE)

# merged = merged %>% arrange(desc(rcp))
# merged$pop = na_interpolation(merged$pop)


# results = merged %>% mutate(
#   ce_dmg = ce_dmgpc * pop,
#   dmg = dmgpc * pop,
#   dmg_old = damages * pop) %>%
#   group_by(year,rcp) %>% summarise(
#     global_ce_dmg = sum(ce_dmg, na.rm = TRUE),
#     global_dmg = sum(dmg, na.rm = TRUE),
#     global_dmg_old = sum(dmg_old, na.rm = TRUE),
#     global_pop = sum(pop)) %>% 
#   mutate(
#     dmgpc_global = global_dmg / global_pop,
#     dmgpc_ce_global = global_ce_dmg / global_pop
#     ) %>%
#   left_join(global_gdp, by = "year") %>%
#   mutate(pct_gdp_ce = global_ce_dmg / gdp,
#     pct_gdp = global_dmg / gdp,
#     pct_gdp_old = global_dmg_old / gdp)

# write_csv(results, "/mnt/CIL_energy/code_release_data_pixel_interaction/intermediate_data/ce_damage_timeseries.csv")


df_45= read_csv(glue('{ROOT_INT_DATA}/projection_outputs/extracted_data_mc/SSP3-rcp45_high_allrisk_fulladapt-wage-aggregated_global_timeseries.csv')) %>%
  mutate(mean = -mean) %>% select(year, mean)

# time series of popweighted impacts
plot_impact_timeseries = function(ssp, iam, adapt, risk, region, aggregation="", suffix="", output_folder = glue("{DIR_FIG}/mc/")){
  

  df_45= read_csv(glue('{ROOT_INT_DATA}/projection_outputs/extracted_data_mc/{ssp}-rcp45_{iam}_{risk}_{adapt}{aggregation}{suffix}_{region}_timeseries.csv')) %>%
    mutate(mean = -mean) %>% select(year, mean)

  df_85= read_csv(glue('{ROOT_INT_DATA}/projection_outputs/extracted_data_mc/{ssp}-rcp85_{iam}_{risk}_{adapt}{aggregation}{suffix}_{region}_timeseries.csv')) %>%
    mutate(mean = -mean) %>% select(year, mean)

  df_ce = read_csv("/mnt/CIL_energy/code_release_data_pixel_interaction/intermediate_data/ce_damage_timeseries.csv")
  ce_45 = df_ce %>% filter(rcp == "rcp45") %>% rename(mean = global_ce_dmg) %>% select(year, mean)
  ce_85 = df_ce %>% filter(rcp == "rcp85") %>% rename(mean = global_ce_dmg) %>% select(year, mean)
  df_dmg_45 = df_ce %>% filter(rcp == "rcp45") %>% rename(mean = global_dmg) %>% select(year, mean)
  df_dmg_85 = df_ce %>% filter(rcp == "rcp85") %>% rename(mean = global_dmg) %>% select(year, mean)
  df_dmg_old_45 = df_ce %>% filter(rcp == "rcp45") %>% rename(mean = global_dmg_old) %>% select(year, mean)
  df_dmg_old_85 = df_ce %>% filter(rcp == "rcp85") %>% rename(mean = global_dmg_old) %>% select(year, mean)
  browser()

  if (aggregation == "-pop-aggregated") {
    plot_title <- "Pop Weighted Impacts - Mins Worked"
  } else if (aggregation == "-gdp-aggregated") {
    plot_title <- "Impacts as Fraction of GDP"
  } else if (aggregation == "-wage-aggregated") {
    plot_title <- "Impacts in Dollars"
  } else {
    print("wrong aggregation!")
    return()
  }
  # browser()
  p <- ggtimeseries(
    df.list = list(
      df_45[,c('year', 'mean')] %>% as.data.frame(),
      df_85[,c('year', 'mean')] %>% as.data.frame(),
      ce_45[,c('year', 'mean')] %>% as.data.frame(),
      ce_85[,c('year', 'mean')] %>% as.data.frame(),
      df_dmg_45[,c('year', 'mean')] %>% as.data.frame(),
      df_dmg_85[,c('year', 'mean')] %>% as.data.frame(),
      df_dmg_old_45[,c('year', 'mean')] %>% as.data.frame(),
      df_dmg_old_85[,c('year', 'mean')] %>% as.data.frame()

    ), # mean lines
    x.limits = c(2010, 2098),
    legend.values = c("red", "green", "blue", "orange","black","pink","navy","purple"), 
    legend.breaks = c("RCP45 Full Adapt", "RCP85 Full Adapt",
                      "RCP45 CE",  "RCP85 CE",
                      "RCP45 dmg",  "RCP85 dmg",
                      "RCP45 dmg old",  "RCP85 dmg old"),
    y.label = 'dollar',
    ssp.value = ssp, end.yr = 2100) + 
  ggtitle(plot_title) 

  # browser()
  ggsave(glue("{output_folder}/{ssp}_{iam}_{risk}_{adapt}{aggregation}{suffix}_{region}_timeseries_ce.pdf"), p)
  print(glue("{output_folder}/{ssp}_{iam}_{risk}_{adapt}{aggregation}{suffix}_{region}_timeseries_ce.pdf saved"))

}


plot_impact_timeseries(ssp="SSP3",iam="high",
  adapt="fulladapt",risk="allrisk",region="global", aggregation = "-wage-aggregated")

