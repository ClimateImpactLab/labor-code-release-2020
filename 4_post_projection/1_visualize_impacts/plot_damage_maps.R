# Produces maps displayed in the energy paper. Uses Functions in mapping.R
# done 26 aug 2020
rm(list = ls())
source("~/repos/labor-code-release-2020/0_subroutines/paths.R")
source("~/repos/post-projection-tools/mapping/imgcat.R") #this redefines the way ggplot plots. 

# Load in the required packages, installing them if necessary 
if(!require("pacman")){install.packages(("pacman"))}
pacman::p_load(ggplot2, 
               dplyr,
               readr)

source(paste0(DIR_REPO_LABOR, "/4_post_projection/0_utils/mapping.R"))

#############################################
# 1. Load in a world shapefile, containing Impact Region boundaries, and convert to a 
#     dataframe for plotting

mymap = load.map(shploc = paste0(ROOT_INT_DATA, "/shapefiles/world-combo-new-nytimes"))


#############################################
# map of overall impact in 2099


df= read_csv(
  paste0(ROOT_INT_DATA, '/projection_outputs/mapping_data/', 
         'SSP3-rcp85_high_fulladapt_map.csv')) 

df_plot = df %>% dplyr::filter(year == 2099)
# df = df %>% dplyr::mutate(mean = 1 / 0.0036 * mean)
# Set scaling factor for map color bar

p = join.plot.map(map.df = mymap, 
                   df = df_plot, 
                   df.key = "region", 
                   plot.var = "mean", 
                   topcode = F, 
                   color.scheme = "div", 
                   colorbar.title = paste0("mins worked"), 
                   map.title = paste0("SSP3-rcp45"))

ggsave(paste0(DIR_FIG,"SSP3-rcp85_high_rulladapt_impacts_map.pdf"), p)



