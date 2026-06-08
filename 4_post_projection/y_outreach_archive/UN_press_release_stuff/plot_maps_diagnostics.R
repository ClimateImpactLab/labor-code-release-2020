# High-risk impact map (mins)
# Low-risk impact map (mins)
# Overall impact map (mins)
# Overall impact map (%GDP)

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
  df= read_csv(glue('{ROOT_INT_DATA}/projection_outputs/outreach/{ssp}-{rcp}_{iam}_{risk}_{adapt}{aggregation}.csv')) # browser()

  df = filter(df, year == 2099)

  if (aggregation == "-pop-levels") {
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
    rescale_value <- -scale_v*bound
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
  # browser()

  ggsave(glue("{output_folder}/{ssp}-{rcp}_{iam}_{risk}_{adapt}{aggregation}_{year}_map.pdf"), p)
  # return(p)
}

# now ony plot the ones we need
output_folder_mc = paste0(DIR_FIG, "/mc_correct_rebasing_for_integration/")

plot_impact_map(rcp="rcp85",ssp="SSP3",iam="low", adapt="fulladapt",year=2099,risk="highrisk",aggregation="", output_folder = output_folder_mc)
plot_impact_map(rcp="rcp85",ssp="SSP3",iam="low", adapt="fulladapt",year=2099,risk="lowrisk",aggregation="", output_folder = output_folder_mc)
plot_impact_map(rcp="rcp85",ssp="SSP3",iam="low", adapt="fulladapt",year=2099,risk="allrisk",aggregation="-gdp-levels", output_folder = output_folder_mc)

# for (yr in c(2040,2060,2080,2099)) {
#   plot_impact_map(rcp="rcp85",ssp="SSP3",iam="low", adapt="fulladapt",year=yr,risk="highrisk",aggregation="pop", output_folder = output_folder_mc)
#   plot_impact_map(rcp="rcp85",ssp="SSP3",iam="low", adapt="fulladapt",year=yr,risk="lowrisk",aggregation="pop", output_folder = output_folder_mc)
#   plot_impact_map(rcp="rcp85",ssp="SSP3",iam="low", adapt="fulladapt",year=yr,risk="allrisk",aggregation="gdp", output_folder = output_folder_mc)
#   # plot_impact_map(rcp="rcp85",ssp="SSP3",iam="high", adapt="fulladapt",year=yr,risk="riskshare",aggregation="", output_folder = output_folder_mc)
# }


