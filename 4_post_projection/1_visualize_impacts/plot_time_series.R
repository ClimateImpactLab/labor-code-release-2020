
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
plot_impact_timeseries = function(rcp, ssp, adapt, year, risk){

  df= read_csv(
    glue('{ROOT_INT_DATA}/projection_outputs/mapping_data/{ssp}-{rcp}_{risk}_{adapt}_timeseries.csv')) 

  df_plot = df %>% dplyr::filter(is.na(region))

  p <- ggtimeseries(
    df.list = list(df_plot[,c('year', 'mean')] %>% as.data.frame()), # mean lines
    x.limits = c(2010, 2099),
    y.label = 'mins worked',
    rcp.value = rcp, ssp.value = ssp) + 
  ggtitle("pop weighted impact - mins worked") 
  ggsave(glue("{DIR_FIG}/{ssp}-{rcp}-{risk}-{adapt}_impacts_timeseries.pdf"), p)
}


plot_impact_timeseries(rcp="rcp85",ssp="SSP2",adapt="fulladapt",year=2099,risk="high")

map_args = expand.grid(rcp=c("rcp85","rcp45"),
                       ssp=c("SSP2","SSP3","SSP4"),
                       adapt=c("fulladapt","noadapt"),
                       year=c(2010,2099),
                       risk=c("high","low","highlow")
                       )

mcmapply(plot_impact_timeseries, 
  rcp=map_args$rcp, 
  ssp=map_args$ssp, 
  year=map_args$year, 
  risk=map_args$risk, 
  adapt=map_args$adapt,
  mc.cores = 5)


