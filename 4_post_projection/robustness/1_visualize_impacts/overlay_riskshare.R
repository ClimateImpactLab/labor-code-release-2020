rm(list = ls())
source("~/repos/labor-code-release-2020/0_subroutines/paths.R")
library(glue)
library(parallel)

##############
# FUNCTION
##############

# Load in the required packages, installing them if necessary 
if(!require("pacman")){install.packages(("pacman"))}
pacman::p_load(ggplot2, 
               dplyr,
               readr, 
               DescTools,
               RColorBrewer)

source(glue("{DIR_REPO_LABOR}/4_post_projection/0_utils/time_series.R"))

# time series of weighted impacts
overlay_impact_timeseries = function(
  IR='globe',
  file1, file2, file3, 
  legend1,legend2,legend3,
  output, rcp, ssp, adapt, weight, risk){


  title = glue("{risk}, {weight}-aggregated \n ({ssp}, {adapt}, IR = {IR})")

  df1 = read_csv(file1)
  df2 = read_csv(file2)
  df3 = read_csv(file3)

  if(IR == "globe"){

    df_plot1 = df1 %>% dplyr::filter(is.na(region)) %>% dplyr::filter(year != 2100) # drop 2100 because it's missing or wonk sometimes
    df_plot2 = df2 %>% dplyr::filter(is.na(region)) %>% dplyr::filter(year != 2100) # drop 2100 because it's missing or wonk sometimes
    df_plot3 = df3 %>% dplyr::filter(is.na(region)) %>% dplyr::filter(year != 2100) # drop 2100 because it's missing or wonk sometimes

  } else {
    
    df_plot1 = df1 %>% dplyr::filter(region == IR) %>% dplyr::filter(year != 2100) # drop 2100 because it's missing or wonk sometimes
    df_plot2 = df2 %>% dplyr::filter(region == IR) %>% dplyr::filter(year != 2100) # drop 2100 because it's missing or wonk sometimes
    df_plot3 = df3 %>% dplyr::filter(region == IR) %>% dplyr::filter(year != 2100) # drop 2100 because it's missing or wonk sometimes

  }


  p <- ggplot() + 
      geom_line(data = df_plot1, aes(x = year, y = value, color = glue("{legend1}"))) +
      geom_line(data = df_plot2, aes(x = year, y = value, color = glue("{legend2}"))) +
      geom_line(data = df_plot3, aes(x = year, y = value, color = glue("{legend3}"))) +
      xlim(2010, 2099) + 
      xlab('year') +
      ylab('') +
      ggtitle(title)

  dir.create(glue("{DIR_OUTPUT}/{output}"), recursive=TRUE)
  ggsave(glue("{DIR_OUTPUT}/{output}/timeseries-{weight}-{risk}-{adapt}-{rcp}-{ssp}.pdf"), p)

}


#######################################
# MAIN MODEL VS EDGE RESTRICTED MODEL 
#######################################

# main model data

model = 'surrogate_GFDL-CM3_99'
# model = 'CCSM4'

file1 = glue('/shares/gcp/outputs/labor/impacts-woodwork/point_estimate_google_rebased/',
  'median/rcp85/{model}/high/SSP3/csv/',
  'uninteracted_main_model-riskshare-noadapt-pop-aggregated.csv')

file2 = glue('/shares/gcp/outputs/labor/impacts-woodwork/point_estimate_google_rebased/',
  'median/rcp85/{model}/high/SSP3/csv/',
  'uninteracted_main_model-riskshare-incadapt-pop-aggregated.csv')

file3 = glue('/shares/gcp/outputs/labor/impacts-woodwork/point_estimate_google_rebased/',
  'median/rcp85/{model}/high/SSP3/csv/',
  'uninteracted_main_model-riskshare-fulladapt-pop-aggregated.csv')

legend1 = "noadapt"
legend2 = "incadapt"
legend3 = "fulladapt"

output = glue('diagnostics/timeseries_diagnostics/{model}')


#############
# RUN MODEL 
#############

overlay_impact_timeseries(IR = 'globe',
                       file1=file1,
                       file2=file2,
                       file3=file3,
                       legend1=legend1,
                       legend2=legend2,
                       legend3=legend3,
                       output=output,
                       ssp="SSP3",
                       rcp='rcp85',
                       adapt="",
                       risk=c("riskshare"),
                       weight=c("pop")
                       )

