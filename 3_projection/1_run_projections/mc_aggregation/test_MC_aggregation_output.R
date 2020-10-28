# test MC aggregation output
# plot one map and one time series

rm(list = ls())
source("~/repos/labor-code-release-2020/0_subroutines/paths.R")
source("~/repos/post-projection-tools/mapping/imgcat.R") #this redefines the way ggplot plots. 

# Load in the required packages, installing them if necessary 
if(!require("pacman")){install.packages(("pacman"))}
pacman::p_load(ggplot2, 
               dplyr,
               readr)
library(glue)
library(parallel)

source(paste0(DIR_REPO_LABOR, "/4_post_projection/0_utils/mapping.R"))

#############################################
# 1. Load in a world shapefile, containing Impact Region boundaries, and convert to a 
#     dataframe for plotting

mymap = load.map(shploc = paste0(ROOT_INT_DATA, "/shapefiles/world-combo-new-nytimes"))


#############################################
# map of overall impact in 2099

plot_impact_map = function(rcp, ssp, iam, adapt, year, risk, aggregation="", suffix="",output_folder = DIR_FIG){

  if ((ssp=="SSP1" & rcp=="rcp85") | (ssp=="SSP5" & rcp=="rcp45")) {
    print("invalid ssp and rcp combination")
    return()
  }

  # browser()
  df= read_csv(glue('{ROOT_INT_DATA}/projection_outputs/extracted_data_mc/{ssp}-{rcp}_{iam}_{risk}_{adapt}{aggregation}{suffix}_{year}_map.csv')) # browser()

  if (aggregation == "-pop") {
    plot_title <- "Pop Weighted Impacts - Mins Worked"

  } else if (aggregation == "-gdp-levels") {
    plot_title <- "Damages as Percentage of GDP"
    df_plot <- df %>% dplyr::mutate(mean = -mean * 100)     
    
    bound = ceiling(max(abs(df_plot$mean), na.rm=TRUE))
    scale_v = c(-1, -0.2, -0.05, -0.005, 0, 0.005, 0.05, 0.2, 1)
    rescale_value <- scale_v*bound
    ub = max(rescale_value,na.rm = TRUE)
    lb = -ub
    # browser()
    breaks_labels = seq(-bound, bound, bound/4)
    color_scheme = "div"
  
  } else if (aggregation == "-wage-levels") {
    plot_title <- "Damages in Million Dollars"
    df_plot <- df %>% dplyr::mutate(mean = -mean / 1000000000) 
  
    bound = ceiling(max(abs(df_plot$mean)))
    scale_v = c(-1, -0.2, -0.05, -0.005, 0, 0.005, 0.05, 0.2, 1)
    rescale_value <- scale_v*bound
    ub = max(rescale_value,na.rm = TRUE)
    lb = -ub
    breaks_labels = seq(-bound, bound, bound/4)
    color_scheme = "div"
  
  } else if (aggregation == "") {
    plot_title <- "Impacts in Minutes Worked per Worker"
    bound = 30
    df_plot <- df 
    scale_v = c(-1, -0.2, -0.05, -0.005, 0, 0.005, 0.05, 0.2, 1)
    rescale_value <- scale_v*bound
    ub = max(rescale_value)
    lb = -ub
    breaks_labels = seq(-bound, bound, bound/3)
    color_scheme = "div"
  
  } else {
  
    print("wrong aggregation!")
    return()
  
  }

  if (risk == "riskshare") {
    rescale_value <- seq(0,1,0.2)
    ub = 1
    lb = 0
    breaks_labels = rescale_value
    color_scheme = "seq"
  }


  p = join.plot.map(map.df = mymap, 
                     df = df_plot, 
                     df.key = "region", 
                     plot.var = "mean", 
                     topcode = T, 
                     topcode.lb = lb,
                     topcode.ub = ub,
                     breaks_labels_val = breaks_labels,
                     color.scheme = color_scheme, 
                     rescale_val = rescale_value,
                     colorbar.title = plot_title, 
                     map.title = glue("{ssp}-{rcp}-{iam}-{risk}-{adapt}{aggregation}-{year}"))

	browser()  
  ggsave(glue("{output_folder}/{ssp}-{rcp}_{iam}_{risk}_{adapt}{aggregation}{suffix}_{year}_map.pdf"), p)
  # return(p)
}

# now ony plot the ones we need
output_folder_mc = paste0(DIR_FIG, "/mc/")
plot_impact_map(rcp="rcp85",ssp="SSP3",iam="high", adapt="fulladapt",year=2098,risk="allrisk",aggregation="", output_folder = output_folder_mc)






################# time series ####################
# Mins. time series (full, income, and no adapt)
# %GDP time series (full, income, and no adapt)

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

# output_folder_mc = paste0(DIR_FIG, "/mc/")

# time series of popweighted impacts
plot_impact_timeseries = function(rcp, ssp, iam, adapt, risk, region, aggregation="", suffix="", output_folder = glue("{DIR_FIG}/mc/")){
  
  # browser()
  if ((ssp=="SSP1" & rcp=="rcp85") | (ssp=="SSP5" & rcp=="rcp45")) {
    print("invalid combination of ssp and rcp")
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
  # browser()
  ggsave(glue("{output_folder}/{ssp}-{rcp}_{iam}_{risk}_{adapt}{aggregation}{suffix}_{region}_timeseries.pdf"), p)
  print(glue("{output_folder}/{ssp}-{rcp}_{iam}_{risk}_{adapt}{aggregation}{suffix}_{region}_timeseries.pdf saved"))

}

# plot only those we need
plot_impact_timeseries(rcp="rcp85",ssp="SSP3",iam="high",
  adapt="fulladapt",risk="allrisk",region="global",aggregation = "-pop-aggregated")



