rm(list = ls())
source("~/repos/labor-code-release-2020/0_subroutines/paths.R")
source("~/repos/post-projection-tools/mapping/imgcat.R") #this redefines the way ggplot plots. 
library(glue)

# Load in the required packages, installing them if necessary 
if(!require("pacman")){install.packages(("pacman"))}
pacman::p_load(ggplot2, 
               dplyr,
               readr, 
               DescTools,
               RColorBrewer)

source(glue("{DIR_REPO_LABOR}/4_post_projection/0_utils/time_series.R"))


# time series of popweighted impacts

df= read_csv(
  paste0('/shares/gcp/outputs/labor/impacts-woodwork/',
      'combined_mixed_splines_27_37_39_by_risk_empshare_noFE_YearlyAverageDay/',
      'rcp85/CCSM4/high/SSP3/', 
        'combined_mixed_model_splines_empshare_noFE-pop-combined.csv')) 
df_plot = df %>% dplyr::filter(is.na(region))

p <- ggtimeseries(
  df.list = list(df_plot[,c('year', 'value')] %>% as.data.frame()), # mean lines
  x.limits = c(2010, 2099),
  y.label = 'mins worked',
  rcp.value = 'rcp85', ssp.value = 'SSP3', iam.value = 'high') + 
ggtitle("pop weighted impact - mins worked") 

pdf(glue("{DIR_OUTPUT}/single_time_series.pdf"))
p
dev.off()
