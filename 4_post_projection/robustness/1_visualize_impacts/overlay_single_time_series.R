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
  folder1, name1, legend1,
  folder2, name2, legend2,
  output, ssp, adapt, weight, risk){

  if(weight == "raw"){
    # please note: you cannot use 'raw' weighting unless you are choosing a specific IR
    file1_85 = glue('{folder1}/rcp85/CCSM4/high/SSP3/csv/{name1}-{risk}-combined.csv')
    file1_45 = glue('{folder1}/rcp45/CCSM4/high/SSP3/csv/{name1}-{risk}-combined.csv')

    file2_85 = glue('{folder2}/rcp85/CCSM4/high/SSP3/csv/{name2}-{risk}-combined.csv')
    file2_45 = glue('{folder2}/rcp45/CCSM4/high/SSP3/csv/{name2}-{risk}-combined.csv')

  } else {

    file1_85 = glue('{folder1}/rcp85/CCSM4/high/SSP3/csv/{name1}-{risk}-{weight}-aggregated-combined.csv')
    file1_45 = glue('{folder1}/rcp45/CCSM4/high/SSP3/csv/{name1}-{risk}-{weight}-aggregated-combined.csv')

    file2_85 = glue('{folder2}/rcp85/CCSM4/high/SSP3/csv/{name2}-{risk}-{weight}-aggregated-combined.csv')
    file2_45 = glue('{folder2}/rcp45/CCSM4/high/SSP3/csv/{name2}-{risk}-{weight}-aggregated-combined.csv')

  }

  title = glue("{risk}, {weight}-aggregated \n ({ssp}, {adapt}, IR = {IR})")

  df1_85 = read_csv(file1_85)
  df1_45 = read_csv(file1_45)

  df2_85 = read_csv(file2_85)
  df2_45 = read_csv(file2_45)

  if(IR == "globe"){

    df_plot1_85 = df1_85 %>% dplyr::filter(is.na(region)) %>% dplyr::filter(year != 2100) # drop 2100 because it's missing or wonk sometimes
    df_plot1_45 = df1_45 %>% dplyr::filter(is.na(region)) %>% dplyr::filter(year != 2100) # drop 2100 because it's missing or wonk sometimes

    df_plot2_85 = df2_85 %>% dplyr::filter(is.na(region)) %>% dplyr::filter(year != 2100)
    df_plot2_45 = df2_45 %>% dplyr::filter(is.na(region)) %>% dplyr::filter(year != 2100)

  } else {
    
    df_plot1_85 = df1_85 %>% dplyr::filter(region == IR) %>% dplyr::filter(year != 2100) # drop 2100 because it's missing or wonk sometimes
    df_plot1_45 = df1_45 %>% dplyr::filter(region == IR) %>% dplyr::filter(year != 2100) # drop 2100 because it's missing or wonk sometimes

    df_plot2_85 = df2_85 %>% dplyr::filter(region == IR) %>% dplyr::filter(year != 2100)
    df_plot2_45 = df2_45 %>% dplyr::filter(region == IR) %>% dplyr::filter(year != 2100)
  }


  p <- ggplot() + 
      geom_line(data = df_plot1_85, aes(x = year, y = value, colour = 'darkblue')) +
      geom_line(data = df_plot1_45, aes(x = year, y = value, colour = 'green')) +
      geom_line(data = df_plot2_85, aes(x = year, y = value, colour = 'red')) +
      geom_line(data = df_plot2_45, aes(x = year, y = value, colour = 'orange')) +
      xlim(2010, 2099) + 
      xlab('year') +
      ylab('') +
      ggtitle(title) +
      scale_color_discrete(name = "Models", 
        labels = c(glue("{legend1}-RCP85"), 
                   glue("{legend1}-RCP45"), 
                   glue("{legend2}-RCP85"), 
                   glue("{legend2}-RCP45"))) +
      theme(legend.position="bottom")

  dir.create(glue("{DIR_FIG}/{output}"), recursive=TRUE)
  ggsave(glue("{DIR_FIG}/{output}/timeseries-{weight}-{risk}-{adapt}-{ssp}.pdf"), p)
}

##################################################################
# CLIPPED MIXED MODEL VS UNCLIPPED MIXED MODEL - DUPLICATED CHECK
##################################################################

# # unclipped data
# folder1 = glue('/shares/gcp/outputs/labor/impacts-woodwork/unclipped_mixed_model/',
#       'combined_mixed_splines_27_37_39_by_risk_empshare_noFE_YearlyAverageDay/',
#       'rcp85/CCSM4/high/SSP3/csv')
# name1 = 'combined_mixed_model_splines_empshare_noFE'

# legend1 = "unclipped mixed"

# # clipped model data
# folder2 = glue('/shares/gcp/outputs/labor/impacts-woodwork/clipping_extrema/',
#         'combined_mixed_splines_27_37_39_by_risk_empshare_noFE_YearlyAverageDay/',
#         'rcp85/CCSM4/high/SSP3/csv')
# name2 = 'combined_mixed_model_splines_empshare_noFE'

# legend2 = "clipped mixed"

# output = 'compare_clipped_unclipped_mixed/USA.14.608'

#######################################
# MAIN MODEL VS WITH-CHINA MODEL 
#######################################

# # main model data
# folder1 = glue('/shares/gcp/outputs/labor/impacts-woodwork/test_rcc_copy1/',
#       'uninteracted_splines_27_37_39_by_risk_empshare_noFE_YearlyAverageDay/')

# name1 = 'uninteracted_main_model'

# legend1 = "no-China uninteracted (main)"

# # edge restricted model data
# folder2 = glue('/shares/gcp/outputs/labor/impacts-woodwork/uninteracted_main_model_w_chn_copy/',
#   'uninteracted_splines_w_chn_21_37_41_by_risk_empshare_noFE_YearlyAverageDay/')

# name2 = 'uninteracted_main_model_w_chn'

# legend2 = "with-China uninteracted"

# output = 'uninteracted_main_model_w_chn/compare_main'

#######################################
# MAIN MODEL VS EDGE RESTRICTED MODEL 
#######################################

# main model data
folder1 = glue('/shares/gcp/outputs/labor/impacts-woodwork/test_rcc_copy1/',
      'uninteracted_splines_27_37_39_by_risk_empshare_noFE_YearlyAverageDay/')
name1 = 'uninteracted_main_model'

legend1 = "uninteracted (main)"

# edge restricted model data
folder2 = glue('/shares/gcp/outputs/labor/impacts-woodwork/edge_clipping_copy/',
  'uninteracted_splines_27_37_39_by_risk_empshare_noFE_YearlyAverageDay/')
name2 = 'uninteracted_main_model'

legend2 = "edge-restricted uninteracted"

output = 'single_edge_restriction_model/compare_main'


#############
# RUN MODEL 
#############

map_args = expand.grid(IR = 'globe',
                       folder1= folder1,
                       name1=name1,
                       legend1=legend1,
                       folder2=folder2,
                       name2=name2,
                       legend2=legend2,
                       output=output,
                       ssp="SSP3",
                       adapt="fulladapt",
                       risk=c( "highriskimpacts","rebased_new", "lowriskimpacts"),
                       weight=c("gdp","wage","pop")
                       )

print(map_args)

mcmapply(overlay_impact_timeseries,
        IR= map_args$IR,
        folder1= map_args$folder1,
        name1=map_args$name1,
        legend1=map_args$legend1,
        folder2=map_args$folder2,
        name2=map_args$name2,
        legend2=map_args$legend2,
        output=map_args$output,
        ssp=map_args$ssp,
        adapt=map_args$adapt,
        risk=map_args$risk,
        weight=map_args$weight,
        mc.cores=5
        )


