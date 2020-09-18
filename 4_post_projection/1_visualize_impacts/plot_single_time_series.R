rm(list = ls())
source("~/repos/labor-code-release-2020/0_subroutines/paths.R")
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
plot_impact_timeseries = function(rcp, ssp, adapt, model, risk, weight){

  # df= read_csv(
  #     glue('/shares/gcp/outputs/labor/impacts-woodwork/',
  #     'combined_mixed_splines_27_37_39_by_risk_empshare_noFE_YearlyAverageDay/',
  #     'rcp85/CCSM4/high/SSP3/csv/', 
  #     'combined_mixed_model_splines_empshare_noFE-{risk}-{weight}-combined.csv')) 


  # YOU NEED TO GET THIS ONE EXTRACTED -- THE AGGREGATED VERSION
  df= read_csv(
      glue('/shares/gcp/outputs/labor/impacts-woodwork/',
      'edge_clipping/uninteracted_splines_27_37_39_by_risk_empshare_noFE_YearlyAverageDay/',
      'rcp85/CCSM4/high/SSP3/csv/',
      'uninteracted_main_model-{risk}-{weight}-aggregated-combined.csv'))

  df_plot = df %>% dplyr::filter(is.na(region))

  p <- ggtimeseries(
    df.list = list(df_plot[,c('year', 'value')] %>% as.data.frame()), # mean lines
    x.limits = c(2010, 2099),
    y.label = 'mins worked',
    rcp.value = rcp, ssp.value = ssp) + 
  ggtitle(glue("{weight} weighted impact - mins worked - {risk}"))
  ggsave(glue("{DIR_FIG}/single_edge_restriction_model/{rcp}-{ssp}-{weight}-{risk}-{adapt}_impacts_timeseries.pdf"), p)
}

map_args = expand.grid(rcp="rcp85",
                       ssp="SSP3",
                       adapt="fulladapt",
                       risk=c("highriskimpacts","lowriskimpacts","rebased"),
                       weight=c("wage","pop")
                       )

print(map_args)

mcmapply(plot_impact_timeseries, 
  rcp=map_args$rcp, 
  ssp=map_args$ssp, 
  risk=map_args$risk, 
  adapt=map_args$adapt,
  weight=map_args$weight,
  mc.cores = 5)
