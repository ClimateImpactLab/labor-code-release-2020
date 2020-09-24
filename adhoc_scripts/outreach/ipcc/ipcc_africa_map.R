# a map of just Africa for low and high risk labor, minutes worked 2100 RCP85

# Produces maps displayed in the energy paper. Uses Functions in mapping.R
# done 26 aug 2020

rm(list = ls())
source("~/repos/labor-code-release-2020/0_subroutines/paths.R")
source("~/repos/post-projection-tools/mapping/imgcat.R") #this redefines the way ggplot plots. 


library(ggplot2)
library(magrittr)
library(dplyr)
library(parallel)
library(glue)
library(data.table)
library(ncdf4)
library(ggpubr)
library(gridExtra)


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
# subset to african IRs
ContinentSplit <- function(weirdlist = FALSE){

	continents <- setnames(subset(fread("/shares/gcp/regions/continents2.csv"), select=c('alpha-3', 'region')), c('iso', 'continent'))
	regions <- setnames(subset(fread("/shares/gcp/regions/hierarchy.csv"), select=c('region-key', 'is_terminal')), c('region', 'is_terminal'))

	regions[,iso:=substr(x=region,start=1,stop=3)]
	
	setkey(regions, iso)
	setkey(continents, iso)

	DT <- regions[continents][is_terminal==TRUE][,is_terminal:=NULL][,iso:=NULL][continent!=""][]

	split <- sapply(unique(DT[,continent]),function(c) DT[continent==c], simplify=FALSE)

	if (weirdlist) split <- mapply(RegionListName,d=split, n=names(split), SIMPLIFY = FALSE)

	return(split)
}

split = ContinentSplit()
african_IRs = split$Africa[,region]
mymap_africa = mymap %>% dplyr::filter(as.character(id) %in% african_IRs)


plot_impact_map = function(rcp, ssp, iam, adapt, year, risk, aggregation="", suffix="",output_folder = DIR_FIG){

  if ((ssp=="SSP1" & rcp=="rcp85") | (ssp=="SSP5" & rcp=="rcp45")) {
    return()
  }

  # browser()
  df= read_csv(glue('{ROOT_INT_DATA}/projection_outputs/extracted_data/{ssp}-{rcp}_{iam}_{risk}_{adapt}{aggregation}{suffix}_{year}_map.csv')) # browser()
 
  df = df %>% dplyr::filter(region %in% african_IRs)

  if (aggregation == "-pop-allvars-levels") {
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


  p = join.plot.map(map.df = mymap_africa, 
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

  ggsave(glue("{output_folder}/{ssp}-{rcp}_{iam}_{risk}_{adapt}{aggregation}{suffix}_{year}_map_africa.pdf"), p)
}


plot_impact_map(rcp="rcp85",ssp="SSP3",iam="high", adapt="fulladapt",year=2099,risk="highrisk",aggregation="", output_folder = "/mnt/CIL_labor/outreach/ipcc")
plot_impact_map(rcp="rcp85",ssp="SSP3",iam="high", adapt="fulladapt",year=2099,risk="lowrisk",aggregation="", output_folder = "/mnt/CIL_labor/outreach/ipcc")
plot_impact_map(rcp="rcp85",ssp="SSP3",iam="high", adapt="fulladapt",year=2099,risk="allrisk",aggregation="-gdp-levels", output_folder = "/mnt/CIL_labor/outreach/ipcc")

