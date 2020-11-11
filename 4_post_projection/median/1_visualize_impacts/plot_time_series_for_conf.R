
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


# time series of popweighted impacts
plot_fulladapt_noadapt_timeseries = function(rcp, ssp, iam, risk, region, aggregation="", suffix="", output_folder = DIR_FIG){
  
  # browser()
  df_fulladapt= read_csv(glue('{ROOT_INT_DATA}/projection_outputs/extracted_data/{ssp}-{rcp}_{iam}_{risk}_fulladapt{aggregation}{suffix}_{region}_timeseries.csv'))
  df_noadapt= read_csv(glue('{ROOT_INT_DATA}/projection_outputs/extracted_data/{ssp}-{rcp}_{iam}_{risk}_noadapt{aggregation}{suffix}_{region}_timeseries.csv'))

  if (aggregation == "-pop-allvars-aggregated") {
    plot_title <- "Pop Weighted Impacts - Mins Worked"
  } else if (aggregation == "-gdp-aggregated") {
    plot_title <- "Impacts as Percentage of GDP"
  } else if (aggregation == "-wage-aggregated") {
    plot_title <- "Impacts in Dollars"
  } else {
    print("wrong aggregation!")
    return()
  }
  # browser()
  p <- ggtimeseries(
    df.list = list(df_fulladapt[,c('year', 'mean')] %>% as.data.frame(),
                   df_noadapt[,c('year', 'mean')] %>% as.data.frame()), # mean lines
    x.limits = c(2010, 2098),
    y.label = 'changes in mins worked',
    rcp.value = rcp, ssp.value = ssp, end.yr = 2098,
    legend.values=c("blue","red"),
    legend.breaks = c("full adapt","no adapt")) + 
  ggtitle(plot_title) 
  ggsave(glue("{output_folder}/{ssp}-{rcp}_{iam}_{risk}_fulladapt_and_noadapt{aggregation}{suffix}_{region}_timeseries.pdf"), p)
}




# plot only those we need
plot_fulladapt_noadapt_timeseries(rcp="rcp85",ssp="SSP3",iam="high",
  risk="allrisk",region="global",aggregation = "-pop-allvars-aggregated")






# time series of popweighted impacts
plot_rcp45_rcp85_timeseries = function(rcp, ssp, iam, adapt,risk, region, aggregation="", suffix="", output_folder = DIR_FIG){
  
  # browser()
  df_45= read_csv(glue('{ROOT_INT_DATA}/projection_outputs/extracted_data/{ssp}-rcp45_{iam}_{risk}_{adapt}{aggregation}{suffix}_{region}_timeseries.csv'))
  df_85= read_csv(glue('{ROOT_INT_DATA}/projection_outputs/extracted_data/{ssp}-rcp85_{iam}_{risk}_{adapt}{aggregation}{suffix}_{region}_timeseries.csv'))

  if (aggregation == "-pop-allvars-aggregated") {
    plot_title <- "Pop Weighted Impacts - Mins Worked"
  } else if (aggregation == "-gdp-aggregated") {
    plot_title <- "Impacts as Percentage of GDP"
  } else if (aggregation == "-wage-aggregated") {
    plot_title <- "Impacts in Dollars"
  } else {
    print("wrong aggregation!")
    return()
  }
  # browser()
  p <- ggtimeseries(
    df.list = list(df_45[,c('year', 'mean')] %>% as.data.frame(),
                   df_85[,c('year', 'mean')] %>% as.data.frame()), # mean lines
    x.limits = c(2010, 2098),
    y.label = 'changes in mins worked',
    end.yr = 2098,
    legend.values=c("blue","red"),
    legend.breaks = c("rcp45","rcp85")) + 
  ggtitle(plot_title) 
  ggsave(glue("{output_folder}/{ssp}-rcp45_and_rcp85_{iam}_{risk}_{adapt}{aggregation}{suffix}_{region}_timeseries.pdf"), p)
}



plot_rcp45_rcp85_timeseries(ssp="SSP3",iam="high",
  adapt="fulladapt",risk="allrisk",region="global", aggregation = "-gdp-aggregated")





# time series of popweighted impacts
plot_three_adapt_timeseries = function(rcp, ssp, iam,risk, region, aggregation="", suffix="", output_folder = DIR_FIG){
  
  # browser()
  df_full= read_csv(glue('{ROOT_INT_DATA}/projection_outputs/extracted_data/{ssp}-{rcp}_{iam}_{risk}_fulladapt{aggregation}{suffix}_{region}_timeseries.csv')) %>%
          mutate(mean = -mean *100) 
  df_inc = read_csv(glue('{ROOT_INT_DATA}/projection_outputs/extracted_data/{ssp}-{rcp}_{iam}_{risk}_incadapt{aggregation}{suffix}_{region}_timeseries.csv')) %>%
          mutate(mean = -mean *100) 
  df_no  = read_csv(glue('{ROOT_INT_DATA}/projection_outputs/extracted_data/{ssp}-{rcp}_{iam}_{risk}_noadapt{aggregation}{suffix}_{region}_timeseries.csv')) %>%
          mutate(mean = -mean *100) 

  if (aggregation == "-pop-allvars-aggregated") {
    plot_title <- "Pop Weighted Impacts - Mins Worked"
  } else if (aggregation == "-gdp-aggregated") {
    plot_title <- "Impacts as Percentage of GDP"
  } else if (aggregation == "-wage-aggregated") {
    plot_title <- "Impacts in Dollars"
  } else {
    print("wrong aggregation!")
    return()
  }
  # browser()
  p <- ggtimeseries(
    df.list = list(df_full[,c('year', 'mean')] %>% as.data.frame(),
                   df_inc[,c('year', 'mean')] %>% as.data.frame(),
                   df_no[,c('year', 'mean')] %>% as.data.frame()), # mean lines
    x.limits = c(2010, 2098),
    y.label = 'changes in mins worked',
    end.yr = 2098,
    legend.values=c("blue","green","red"),
    legend.breaks = c("full adapt","inc adapt", "no adapt")) + 
  ggtitle(plot_title) 
  browser()
  ggsave(glue("{output_folder}/{ssp}-all-adapt-scenarios_{iam}_{risk}_{aggregation}{suffix}_{region}_timeseries.pdf"), p)
}



plot_three_adapt_timeseries(rcp = "rcp85", ssp="SSP3",iam="high", 
  risk="allrisk",region="global", aggregation = "-gdp-aggregated")





