rm(list = ls())
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

source("~/repos/labor-code-release-2020/0_subroutines/paths.R")
source("~/repos/post-projection-tools/mapping/imgcat.R") #this redefines the way ggplot plots. 
source(glue("{DIR_REPO_LABOR}/4_post_projection/0_utils/time_series.R"))

# time series of weighted impacts
overlay_impact_timeseries = function(IR='globe', folder1, name1, legend1, folder2, name2, legend2, output, ssp, rcp, adapt, weight, varname1, varname2){

  if(weight == "raw"){
    # please note: you cannot use 'raw' weighting unless you are choosing a specific IR
    file1 = glue('{folder1}/{name1}-{varname1}.csv')
    file2 = glue('{folder2}/{name2}-{varname2}.csv')
  } else {
    file1 = glue('{folder1}/{name1}-{varname1}-{weight}-aggregated.csv')
    file2 = glue('{folder2}/{name2}-{varname2}-{weight}-aggregated.csv')
  }

  title = glue("{varname2}, {weight}-aggregated \n ({ssp}, {adapt}, {rcp} IR = {IR})")

  df1 = read_csv(file1)
  df2 = read_csv(file2)
  
  if(IR == "globe"){
    df_plot1 = df1 %>% dplyr::filter(is.na(region)) %>% dplyr::filter(year != 2100) # drop 2100 because it's missing or wonk sometimes
    df_plot2 = df2 %>% dplyr::filter(is.na(region)) %>% dplyr::filter(year != 2100)
  } else {
    df_plot1 = df1 %>% dplyr::filter(region == IR) %>% dplyr::filter(year != 2100) # drop 2100 because it's missing or wonk sometimes
    df_plot2 = df2 %>% dplyr::filter(region == IR) %>% dplyr::filter(year != 2100)
  }

  # plotting -value to make upward sloping graphs. to make downward sloping graphs, plot value instead of -value.
  p <- ggplot() + 
      geom_line(data = df_plot1, aes(x = year, y = -value, colour = 'darkblue')) +
      geom_line(data = df_plot2, aes(x = year, y = -value, colour = 'red')) +
      xlim(2011, 2099) + 
      xlab('year') +
      ylab('') +
      ggtitle(title) +
      scale_color_discrete(name = "Models", 
        labels = c(glue("{legend1}"), 
                   glue("{legend2}"))) +
      theme(legend.position="bottom")

  dir.create(glue("{DIR_FIG}/{output}"), recursive=TRUE)
  ggsave(glue("{DIR_FIG}/{output}/timeseries-{weight}-{varname2}-{adapt}-{ssp}.pdf"), p)
}

##################################################################
# CLIPPED MIXED MODEL VS UNCLIPPED MIXED MODEL - DUPLICATED CHECK
##################################################################

# # unclipped data
# folder1 = glue('/shares/gcp/outputs/labor/impacts-woodwork/unclipped_mixed_model/',
#       'combined_mixed_splines_27_37_39_by_risk_empshare_noFE_YearlyAverageDay/rcp85/CCSM4/high/SSP3/csv',
#       'rcp85/CCSM4/high/SSP3/csv')
# name1 = 'combined_mixed_model_splines_empshare_noFE'

# legend1 = "unclipped mixed"

# # clipped model data
# folder2 = glue('/shares/gcp/outputs/labor/impacts-woodwork/clipping_extrema/',
#         'combined_mixed_splines_27_37_39_by_risk_empshare_noFE_YearlyAverageDay/rcp85/CCSM4/high/SSP3/csv',
#         'rcp85/CCSM4/high/SSP3/csv')
# name2 = 'combined_mixed_model_splines_empshare_noFE'

# legend2 = "clipped mixed"

# output = 'compare_clipped_unclipped_mixed/USA.14.608'

#######################################
# MAIN MODEL VS WITH-CHINA MODEL 
#######################################

# # main model data
# folder1 = glue('/shares/gcp/outputs/labor/impacts-woodwork/test_rcc_copy1/',
#       'uninteracted_splines_27_37_39_by_risk_empshare_noFE_YearlyAverageDay/rcp85/CCSM4/high/SSP3/csv')

# name1 = 'uninteracted_main_model'

# legend1 = "no-China uninteracted (main)"

# # edge restricted model data
# folder2 = glue('/shares/gcp/outputs/labor/impacts-woodwork/uninteracted_main_model_w_chn_copy/',
#   'uninteracted_splines_w_chn_21_37_41_by_risk_empshare_noFE_YearlyAverageDay/rcp85/CCSM4/high/SSP3/csv')

# name2 = 'uninteracted_main_model_w_chn'

# legend2 = "with-China uninteracted"

# output = 'uninteracted_main_model_w_chn/compare_main'

#######################################
# MAIN MODEL VS EDGE RESTRICTED MODEL 
#######################################

# # main model data
# folder1 = glue('/shares/gcp/outputs/labor/impacts-woodwork/test_rcc_copy1/',
#       'uninteracted_splines_27_37_39_by_risk_empshare_noFE_YearlyAverageDay/rcp85/CCSM4/high/SSP3/csv')
# name1 = 'uninteracted_main_model'

# legend1 = "uninteracted (main)"

# # edge restricted model data
# folder2 = glue('/shares/gcp/outputs/labor/impacts-woodwork/edge_clipping_copy/',
#   'uninteracted_splines_27_37_39_by_risk_empshare_noFE_YearlyAverageDay/rcp85/CCSM4/high/SSP3/csv')
# name2 = 'uninteracted_main_model'

# legend2 = "edge-restricted uninteracted"

# output = 'single_edge_restriction_model/compare_main'

#######################################
# MAIN MODEL VS DOUBLE EDGE CLIPPING MODEL 
#######################################

# main model data
folder1 = glue('/mnt/battuta_shares/gcp/outputs/labor/impacts-woodwork/test_rcc_copy1/',
      'uninteracted_splines_27_37_39_by_risk_empshare_noFE_YearlyAverageDay/rcp85/CCSM4/high/SSP3/csv')

legend1 = "main model"

# double edge restricted model data
folder2 = glue('/mnt/battuta_shares/gcp/outputs/labor/impacts-woodwork/double_edge_restriction_single/',
  'median/rcp85/CCSM4/high/SSP3/csv')

legend2 = "double edge restricted model"

output = 'double_edge_restriction_single/compare_main'


#############
# RUN FUNCTION 
#############
# run like this for overlaid plots. looping over all possible combinations using mcmapply leads to incorrect graphs in this case
overlay_impact_timeseries("globe", folder1, "uninteracted_main_model", legend1, folder2, "clip_lrt_edge_restriction", legend2, output, "SSP3", "RCP 85", "fulladapt", "gdp", "highriskimpacts", "highriskimpacts")
overlay_impact_timeseries("globe", folder1, "uninteracted_main_model", legend1, folder2, "clip_lrt_edge_restriction", legend2, output, "SSP3", "RCP 85", "fulladapt", "gdp", "lowriskimpacts", "lowriskimpacts")
overlay_impact_timeseries("globe", folder1, "uninteracted_main_model", legend1, folder2, "clip_lrt_edge_restriction", legend2, output, "SSP3", "RCP 85", "fulladapt", "gdp", "rebased_new", "rebased")

# map_args = expand.grid(IR = 'globe',
#                        folder1= folder1,
#                        # name1=c("uninteracted_main_model","uninteracted_main_model-incadapt","uninteracted_main_model-noadapt"),
#                        name1="uninteracted_main_model",
#                        rcp = "RCP 85",
#                        legend1=legend1,
#                        folder2=folder2,
#                        # name2=c("clip_lrt_edge_restriction","clip_lrt_edge_restriction-incadapt","clip_lrt_edge_restriction-noadapt"),
#                        name2="clip_lrt_edge_restriction",
#                        legend2=legend2,
#                        output=output,
#                        ssp="SSP3",
#                        adapt="fulladapt",
#                        varname1=c( "highriskimpacts", "rebased_new", "lowriskimpacts"),
#                        varname2=c( "highriskimpacts", "rebased", "lowriskimpacts"),
#                        # weight = c("wage","gdp", "pop")
#                        weight="gdp"
#                        )

# print(map_args)

# mcmapply(overlay_impact_timeseries,
#         IR= map_args$IR,
#         folder1= map_args$folder1,
#         name1=map_args$name1,
#         rcp=map_args$rcp,
#         legend1=map_args$legend1,
#         folder2=map_args$folder2,
#         name2=map_args$name2,
#         legend2=map_args$legend2,
#         output=map_args$output,
#         ssp=map_args$ssp,
#         adapt=map_args$adapt,
#         varname1=map_args$varname1,
#         varname2=map_args$varname2,
#         weight=map_args$weight,
#         mc.cores=5
#         )


