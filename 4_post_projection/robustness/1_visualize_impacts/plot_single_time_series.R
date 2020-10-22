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
plot_impact_timeseries = function(IR='globe', folder, name, output, rcp, ssp, adapt, weight, risk){

  if(weight == "raw"){
    # please note: you cannot use 'raw' weighting unless you are choosing a specific IR
    file = glue('{folder}/{name}-{risk}-combined.csv')
  } else {
    file = glue('{folder}/{name}-{risk}-{weight}-aggregated-combined.csv')
  }

  title = glue("minutes per worker per day -- {risk} \n ({weight}, {ssp}, {rcp}, {adapt}, IR = {IR})")

  df = read_csv(file)
  
  if(IR == "globe"){
    df_plot = df %>% dplyr::filter(is.na(region)) %>% dplyr::filter(year != 2100) # drop 2100 because it's missing or wonk sometimes
  } else {
    df_plot = df %>% dplyr::filter(region == IR) %>% dplyr::filter(year != 2100)
  }

  p <- ggtimeseries(
    df.list = list(df_plot[,c('year', 'value')] %>% as.data.frame()), # mean lines
    x.limits = c(2011, 2099),
    y.label = 'mins worked',
    rcp.value = rcp, ssp.value = ssp) + 
  ggtitle(title)

  dir.create(glue("{DIR_FIG}/{output}"), recursive=TRUE)
  ggsave(glue("{DIR_FIG}/{output}/timeseries-{weight}-{risk}-{adapt}-{rcp}-{ssp}.pdf"), p)

}


######################
# MAIN MODEL - CHECK
######################

# folder = glue('/shares/gcp/outputs/labor/impacts-woodwork/',
#         'combined_uninteracted_splines_27_37_39_by_risk_empshare_noFE_YearlyAverageDay/',
#         'median/rcp85/CCSM4/high/SSP3/csv')

# name = 'combined_uninteracted_spline_empshare_noFE'
# output = 'main_model_check/SDN.6.16.75.230'

######################
# EDGE RESTRICTION MODEL
######################

# folder = glue('/shares/gcp/outputs/labor/impacts-woodwork/',
#       'edge_clipping_copy/uninteracted_splines_27_37_39_by_risk_empshare_noFE_YearlyAverageDay/',
#       'rcp85/CCSM4/high/SSP3/csv/')

# name = 'uninteracted_main_model'
# output = 'single_edge_restriction_model/'

######################
# CLIPPING MODEL
######################

# folder = glue('/shares/gcp/outputs/labor/impacts-woodwork/z_old/test_clipping_extrema_mixed_model/',
#   'combined_mixed_splines_27_37_39_by_risk_empshare_noFE_YearlyAverageDay/rcp85/CCSM4/high/SSP3/csv')

# name = 'combined_mixed_model_splines_empshare_noFE'
# output = 'single_mixed_model/'

######################
# WITH CHINA MODEL
######################

folder = glue('/shares/gcp/outputs/labor/impacts-woodwork/uninteracted_main_model_w_chn_copy/',
  'uninteracted_splines_w_chn_21_37_41_by_risk_empshare_noFE_YearlyAverageDay/rcp85/CCSM4/high/SSP3/csv')

name = 'uninteracted_main_model_w_chn'
output = 'uninteracted_main_model_w_chn/'

map_args = expand.grid(IR = "globe",
                       folder= folder,
                       name=name,
                       output=output,
                       rcp="rcp85",
                       ssp="SSP3",
                       adapt="fulladapt",
                       risk=c( "highriskimpacts","rebased_new", "lowriskimpacts"),
                       weight=c("wage","gdp", "pop") 
                       )

print(map_args)

mcmapply(plot_impact_timeseries,
         IR = map_args$IR,
         folder= map_args$folder,
         name=map_args$name,
         output=output,
         ssp=map_args$ssp,
         rcp=map_args$rcp,
         adapt=map_args$adapt,
         risk=map_args$risk,
         weight=map_args$weight,
         mc.cores=5
          )
          