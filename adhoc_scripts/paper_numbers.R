* produce statistics for paper

# Mins. time series (full, income, and no adapt)
# %GDP time series (full, income, and no adapt)

rm(list = ls())
source("~/repos/labor-code-release-2020/0_subroutines/paths.R")
source("~/repos/post-projection-tools/mapping/imgcat.R") #this redefines the way ggplot plots. 
library(glue)
library(parallel)
# Load in the required packages, installing them if necessary 
if(!require("pacman")){install.packages(("pacman"))}
pacman::p_load(ggplot2, 
               dplyr,
               readr, 
               DescTools,
               RColorBrewer)

source(glue("{DIR_REPO_LABOR}/4_post_projection/0_utils/time_series.R"))
# source(glue("~/repos/post-projection-tools/timeseries/ggtimeseries.R"))

# output_folder_mc = paste0(DIR_FIG, "/mc/")

# time series of popweighted impacts
load_impact = function(rcp, ssp, iam, adapt, risk, region, aggregation="", suffix="", output_folder = glue("{DIR_FIG}/mc/")){
  
  # browser()
  if ((ssp=="SSP1" & rcp=="rcp85") | (ssp=="SSP5" & rcp=="rcp45")) {
    print("invalid combination of ssp and rcp")
    return()
  }
  df= read_csv(glue('{ROOT_INT_DATA}/projection_outputs/extracted_data_mc/{ssp}-{rcp}_{iam}_{risk}_{adapt}{aggregation}{suffix}_{region}_timeseries.csv'))
  return(df)

}

df = load_impact(rcp="rcp85",ssp="SSP3",iam="high",
  adapt="fulladapt",risk="allrisk",region="global",aggregation = "-gdp-aggregated")

df = load_impact(rcp="rcp85",ssp="SSP3",iam="high",
  adapt="incadapt",risk="allrisk",region="global",aggregation = "-gdp-aggregated")

df = load_impact(rcp="rcp85",ssp="SSP3",iam="high",
  adapt="noadapt",risk="allrisk",region="global",aggregation = "-gdp-aggregated")

