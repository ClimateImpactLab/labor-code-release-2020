
rm(list = ls())
source("~/repos/labor-code-release-2020/0_subroutines/paths.R")
source("~/repos/post-projection-tools/mapping/imgcat.R") #this redefines the way ggplot plots. 
library(glue)
library(parallel)
# Load in the required packages, installing them if necessary 
if(!require("pacman")){install.packages(("pacman"))}
pacman::p_load(ggplot2, 
               dplyr,
               readr, 
               DescTools,
               RColorBrewer)

source(glue("{DIR_REPO_LABOR}/4_post_projection/0_utils/time_series.R"))


# time series of popweighted impacts
plot_impact_timeseries = function(rcp, ssp, iam, adapt, risk, region, aggregation="", suffix="", output_folder = glue("{DIR_FIG}/mc/"){
  
  # browser()
  if ((ssp=="SSP1" & rcp=="rcp85") | (ssp=="SSP5" & rcp=="rcp45")) {
    return()
  }
  df= read_csv(glue('{ROOT_INT_DATA}/projection_outputs/extracted_data_mc/{ssp}-{rcp}_{iam}_{risk}_{adapt}{aggregation}{suffix}_{region}_timeseries.csv'))

  if (aggregation == "-pop-aggregated") {
    plot_title <- "Pop Weighted Impacts - Mins Worked"
  } else if (aggregation == "-gdp-aggregated") {
    plot_title <- "Impacts as Percentage of GDP"
  } else if (aggregation == "-wage-aggregated") {
    plot_title <- "Impacts in Dollars"
  } else {
    print("wrong aggregation!")
    return()
  }
  # browser()
  p <- ggtimeseries(
    df.list = list(df[,c('year', 'mean')] %>% as.data.frame()), # mean lines
    x.limits = c(2010, 2098),
    y.label = 'mins worked',
    rcp.value = rcp, ssp.value = ssp, end.yr = 2100,
    legend.breaks = adapt) + 
  ggtitle(plot_title) 
  ggsave(glue("{output_folder}/{ssp}-{rcp}_{iam}_{risk}_{adapt}{aggregation}{suffix}_{region}_timeseries.pdf"), p)
  print(glue("{output_folder}/{ssp}-{rcp}_{iam}_{risk}_{adapt}{aggregation}{suffix}_{region}_timeseries.pdf saved"))

}



args = expand.grid(rcp=c("rcp85","rcp45"),
                       ssp=c("SSP1","SSP2","SSP3","SSP4","SSP5"),
                       iam=c("high","low"),
                       adapt=c("fulladapt","noadapt","incadapt","histclim"),
                       aggregation =c("-pop-aggregated"),
                       risk=c("highrisk","lowrisk","allrisk","riskshare")
                       )


mcmapply(plot_impact_timeseries, 
  rcp=args$rcp, 
  ssp=args$ssp, 
  iam=args$iam,
  risk=args$risk, 
  adapt=args$adapt,
  aggregation=args$aggregation,
  region="global",
  output_folder = glue("{DIR_FIG}/all_timeseries/"),
  mc.cores = 50)


args = expand.grid(rcp=c("rcp85","rcp45"),
                       ssp=c("SSP1","SSP2","SSP3","SSP4","SSP5"),
                       iam=c("high","low"),
                       adapt=c("fulladapt","histclim"),
                       aggregation =c("-gdp-aggregated","-wage-aggregated"),
                       risk=c("highrisk","lowrisk","allrisk","riskshare")
                       )

mcmapply(plot_impact_timeseries, 
  rcp=args$rcp, 
  ssp=args$ssp, 
  iam=args$iam,
  risk=args$risk, 
  adapt=args$adapt,
  aggregation=args$aggregation,
  region="global",
  output_folder = glue("{DIR_FIG}/all_timeseries/"),
  mc.cores = 50)


# plot only those we need
plot_impact_timeseries(rcp="rcp85",ssp="SSP3",iam="high",
  adapt="fulladapt",risk="allrisk",region="global",aggregation = "-pop-aggregated")

plot_impact_timeseries(rcp="rcp85",ssp="SSP3",iam="high",
  adapt="incadapt",risk="allrisk",region="global",aggregation = "-pop-aggregated")

plot_impact_timeseries(rcp="rcp85",ssp="SSP3",iam="high",
  adapt="noadapt",risk="allrisk",region="global",aggregation = "-pop-aggregated")

plot_impact_timeseries(rcp="rcp85",ssp="SSP3",iam="high",
  adapt="fulladapt",risk="allrisk",region="global", aggregation = "-gdp-aggregated")

plot_impact_timeseries(rcp="rcp85",ssp="SSP3",iam="high",
  adapt="incadapt",risk="allrisk",region="global", aggregation = "-gdp-aggregated")

plot_impact_timeseries(rcp="rcp85",ssp="SSP3",iam="high",
  adapt="noadapt",risk="allrisk",region="global", aggregation = "-gdp-aggregated")
