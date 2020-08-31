
rm(list = ls())
source("~/repos/labor-code-release-2020/0_subroutines/paths.R")
source("~/repos/post-projection-tools/mapping/imgcat.R") #this redefines the way ggplot plots. 

# Load in the required packages, installing them if necessary 
if(!require("pacman")){install.packages(("pacman"))}
pacman::p_load(ggplot2, 
               dplyr,
               readr, 
               DescTools,
               RColorBrewer)

source(paste0(DIR_REPO_LABOR, "/4_post_projection/0_utils/time_series.R"))


# time series of popweighted impacts

df= read_csv(
  paste0(ROOT_INT_DATA, '/projection_outputs/mapping_data/', 
         'SSP3-rcp45_test_aggregated.csv')) 
df_plot = df %>% dplyr::filter(is.na(region))

p <- ggtimeseries(
  df.list = list(df_plot[,c('year', 'mean')] %>% as.data.frame()), # mean lines
  x.limits = c(2010, 2099),
  y.label = 'mins worked',
  rcp.value = 'rcp45', ssp.value = 'SSP3', iam.value = 'high') + 
ggtitle("pop weighted impact - mins worked") 





