
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
plot_impact_timeseries = function(rcp, ssp, iam, adapt, risk, region, aggregation="", suffix=""){
  
  # browser()
  df= read_csv(glue('{ROOT_INT_DATA}/projection_outputs/mapping_data/{ssp}-{rcp}_{iam}_{risk}_{adapt}{aggregation}{suffix}_{region}_timeseries.csv'))

  p <- ggtimeseries(
    df.list = list(df[,c('year', 'mean')] %>% as.data.frame()), # mean lines
    x.limits = c(2010, 2099),
    y.label = 'mins worked',
    rcp.value = rcp, ssp.value = ssp) + 
  ggtitle("pop weighted impact - mins worked") 
  ggsave(glue("{DIR_FIG}/{ssp}-{rcp}_{iam}_{risk}_{adapt}{aggregation}{suffix}_{region}_timeseries.pdf"), p)
}


plot_impact_timeseries(rcp="rcp85",ssp="SSP2",iam="high",
  adapt="fulladapt",risk="highrisk",region="global")

args = expand.grid(rcp=c("rcp85","rcp45"),
                       ssp=c("SSP2","SSP3","SSP4"),
                       iam=c("high","low"),
                       adapt=c("fulladapt","noadapt"),
                       risk=c("highrisk","lowrisk","allrisk")
                       )

mcmapply(plot_impact_timeseries, 
  rcp=args$rcp, 
  ssp=args$ssp, 
  iam=args$iam,
  risk=args$risk, 
  adapt=args$adapt,
  region="global",
  mc.cores = 5)


