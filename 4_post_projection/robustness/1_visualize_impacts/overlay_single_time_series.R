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
overlay_impact_timeseries = function(IR=NA, folder1, name1, legend1, folder2, name2, legend2, output, rcp, ssp, weight, risk, type='combined', title=glue("{output}")){

  file1 = glue('{folder1}/{name1}-{risk}-{type}.csv')
  file2 = glue('{folder2}/{name2}-{risk}-{type}.csv')

  title = glue("{title} \n {risk} ({ssp}, {rcp}, {type})")

  df1 = read_csv(file1)
  df2 = read_csv(file2)

  df_plot1 = df1 %>% dplyr::filter(region == IR)
  df_plot2 = df2 %>% dplyr::filter(region == IR)


  p <- ggplot() + 
      geom_line(data = df_plot1, aes(x = year, y = value, colour = 'darkblue')) +
      geom_line(data = df_plot2, aes(x = year, y = value, colour = 'red')) +
      xlim(2010, 2099) + 
      xlab('year') +
      ylab('mins worked') +
      ggtitle(title) +
      scale_color_discrete(name = "Models", labels = c(glue("{legend1}"), glue("{legend2}"))) +
      theme(legend.position="bottom")

  dir.create(glue("{DIR_FIG}/{output}"), showWarnings = FALSE)
  ggsave(glue("{DIR_FIG}/{output}/{rcp}-{ssp}-{risk}-{type}_impacts_timeseries.pdf"), p)
}


##################################################################
# MAIN MODEL VS EDGE RESTRICTED MODEL - DEDUPLICATED CHECK
##################################################################

# main model data
folder1 = glue('/shares/gcp/outputs/labor/impacts-woodwork/test_rcc/',
      'uninteracted_splines_27_37_39_by_risk_empshare_noFE_YearlyAverageDay/',
      'rcp85/CCSM4/high/SSP3/csv')
name1 = 'uninteracted_main_model'

legend1 = "main uninteracted"

# edge restricted model data
folder2 = glue('/shares/gcp/outputs/labor/impacts-woodwork/edge_clipping/',
      'uninteracted_splines_27_37_39_by_risk_empshare_noFE_YearlyAverageDay/',
      'rcp85/CCSM4/high/SSP3/csv')
name2 = 'uninteracted_main_model'

legend2 = "edge restricted uninteracted"

output = 'compare_main_edge_restriction/SDN.6.16.75.230'

map_args = expand.grid(IR = 'SDN.6.16.75.230',
                       folder1= folder1,
                       name1=name1,
                       legend1=legend1,
                       folder2=folder2,
                       name2=name2,
                       legend2=legend2,
                       output=output,
                       rcp="rcp85",
                       ssp="SSP3",
                       type="combined",
                       risk=c("highriskimpacts","rebased", "lowriskimpacts"),
                       weight=c("wage")
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
        rcp=map_args$rcp,
        type=map_args$type,
        risk=map_args$risk,
        weight=map_args$weight,
        mc.cores=5
        )



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

# map_args = expand.grid(IR = 'USA.14.608',
#                        folder1= folder1,
#                        name1=name1,
#                        legend1=legend1,
#                        folder2=folder2,
#                        name2=name2,
#                        legend2=legend2,
#                        output=output,
#                        rcp="rcp85",
#                        ssp="SSP3",
#                        risk=c("highriskimpacts", 'rebased', 'lowriskimpacts'),
#                        type=c('combined'),
#                        weight=c("wage","gdp","pop")
#                        )

# print(map_args)

# mcmapply(overlay_impact_timeseries,
#         IR= map_args$IR,
#         folder1= map_args$folder1,
#         name1=map_args$name1,
#         legend1=map_args$legend1,
#         folder2=map_args$folder2,
#         name2=map_args$name2,
#         legend2=map_args$legend2,
#         output=map_args$output,
#         ssp=map_args$ssp,
#         rcp=map_args$rcp,
#         risk=map_args$risk,
#         type=map_args$type,
#         weight=map_args$weight,
#         mc.cores=5
#         )
#           