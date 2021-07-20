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


# time series of popweighted impacts
plot_impact_timeseries = function(ssp, iam, adapt, risk, region, aggregation="", suffix="", output_folder = glue("{DIR_FIG}/mc_correct_rebasing_for_integration/")){
  

  df_45= read_csv(glue('{ROOT_INT_DATA}/projection_outputs/extracted_data_mc_correct_rebasing_for_integration/{ssp}-rcp45_{iam}_{risk}_{adapt}{aggregation}{suffix}_{region}_timeseries.csv'))%>%
    mutate(mean = -mean) %>% select(year, mean)

  df_85= read_csv(glue('{ROOT_INT_DATA}/projection_outputs/extracted_data_mc_correct_rebasing_for_integration/{ssp}-rcp85_{iam}_{risk}_{adapt}{aggregation}{suffix}_{region}_timeseries.csv'))%>%
    mutate(mean = -mean) %>% select(year, mean)

  df_45_old= read_csv(glue('{ROOT_INT_DATA}/projection_outputs/extracted_data_mc/{ssp}-rcp45_{iam}_{risk}_{adapt}{aggregation}{suffix}_{region}_timeseries.csv'))%>%
    mutate(mean = -mean) %>% select(year, mean)

  df_85_old= read_csv(glue('{ROOT_INT_DATA}/projection_outputs/extracted_data_mc/{ssp}-rcp85_{iam}_{risk}_{adapt}{aggregation}{suffix}_{region}_timeseries.csv'))%>%
    mutate(mean = -mean) %>% select(year, mean)
  # browser()

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
      df_45_old[,c('year', 'mean')] %>% as.data.frame(),
      df_85_old[,c('year', 'mean')] %>% as.data.frame()
    ), # mean lines
    x.limits = c(2010, 2098),
    legend.values = c("red", "green", "blue", "orange"), 
    legend.breaks = c("RCP45 Full Adapt", "RCP85 Full Adapt",
                      "RCP45 Full Adapt old",  "RCP85 Full Adapt old"),
    y.label = 'dollar',
    ssp.value = ssp, end.yr = 2100) + 
  ggtitle(plot_title) 

  # browser()
  ggsave(glue("{output_folder}/{ssp}_{iam}_{risk}_{adapt}{aggregation}{suffix}_{region}_timeseries_compare_with_old_mc.pdf"), p)
  print(glue("{output_folder}/{ssp}_{iam}_{risk}_{adapt}{aggregation}{suffix}_{region}_timeseries_compare_with_old_mc.pdf saved"))

}


plot_impact_timeseries(ssp="SSP3",iam="high",
  adapt="fulladapt",risk="allrisk",region="global", aggregation = "-wage-aggregated")

