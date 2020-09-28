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
plot_impact_timeseries = function(IR=NA, folder, name, output, rcp, ssp, adapt, weight, risk){

  # file = glue('{folder}/{name}-{risk}-{weight}-aggregated-combined.csv')
  file = glue('{folder}/{name}-{risk}-combined.csv')
  title = glue("minutes per worker per day ({ssp}, {rcp}, {adapt}, IR = {IR})")

  df = read_csv(file)

  df_plot = df %>% dplyr::filter(region == IR)

  p <- ggtimeseries(
    df.list = list(df_plot[,c('year', 'value')] %>% as.data.frame()), # mean lines
    x.limits = c(2010, 2099),
    y.label = 'mins worked',
    rcp.value = rcp, ssp.value = ssp) + 
  ggtitle(title)
  ggsave(glue("{DIR_FIG}/{output}/{rcp}-{ssp}-{weight}-{risk}-{adapt}_impacts_timeseries.pdf"), p)
}


######################
# MAIN MODEL - CHECK
######################

# folder = glue('/shares/gcp/outputs/labor/impacts-woodwork/',
#         'combined_uninteracted_splines_27_37_39_by_risk_empshare_noFE_YearlyAverageDay/',
#         'median/rcp85/CCSM4/high/SSP3/csv')

# name = 'combined_uninteracted_spline_empshare_noFE'
# output = 'main_model_check'

# map_args = expand.grid(folder= folder,
#                        name=name,
#                        output=output,
#                        rcp="rcp85",
#                        ssp="SSP3",
#                        adapt="fulladapt",
#                        risk=c("highriskimpacts","rebased", "lowriskimpacts"),
#                        weight=c("wage","gdp","pop")
#                        )

# print(map_args)

# mcmapply(plot_impact_timeseries,
#          folder= map_args$folder,
#          name=map_args$name,
#          output=output,
#          ssp=map_args$ssp,
#          rcp=map_args$rcp,
#          adapt=map_args$adapt,
#          risk=map_args$risk,
#          weight=map_args$weight,
#          mc.cores=5
#           )


######################
# EDGE RESTRICTION MODEL
######################

# folder = glue('/shares/gcp/outputs/labor/impacts-woodwork/',
#       'edge_clipping/uninteracted_splines_27_37_39_by_risk_empshare_noFE_YearlyAverageDay/',
#       'rcp85/CCSM4/high/SSP3/csv/')

# name = 'uninteracted_main_model'
# output = 'single_edge_restriction_model'

# map_args = expand.grid(folder= folder,
#                        name=name,
#                        output=output,
#                        rcp="rcp85",
#                        ssp="SSP3",
#                        adapt="fulladapt",
#                        risk=c("highriskimpacts","rebased", "lowriskimpacts"),
#                        weight=c("wage","gdp","pop")
#                        )

# print(map_args)

# mcmapply(plot_impact_timeseries,
#          folder= map_args$folder,
#          name=map_args$name,
#          output=output,
#          ssp=map_args$ssp,
#          rcp=map_args$rcp,
#          adapt=map_args$adapt,
#          risk=map_args$risk,
#          weight=map_args$weight,
#          mc.cores=5
#           )

######################
# CLIPPING MODEL
######################

folder = glue('/shares/gcp/outputs/labor/impacts-woodwork/clipping_extrema/',
              'median/rcp85/CCSM4/high/SSP3/csv')

name = 'combined_uninteracted_spline_empshare_noFE'
output = 'single_mixed_model/USA.14.608'

map_args = expand.grid(IR = 'USA.14.608',
                       folder= folder,
                       name=name,
                       output=output,
                       rcp="rcp85",
                       ssp="SSP3",
                       adapt="fulladapt",
                       risk=c("highriskimpacts","rebased", "lowriskimpacts"),
                       weight=c("wage","gdp","pop")
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
          