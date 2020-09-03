# Produces maps displayed in the energy paper. Uses Functions in mapping.R
# done 26 aug 2020

rm(list = ls())

source("~/repos/labor-code-release-2020/0_subroutines/paths.R")
# source("~/repos/post-projection-tools/mapping/imgcat.R") #this redefines the way ggplot plots. 

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


plot_impact_map = function(rcp, ssp, adapt, weight, risk){

  file = glue('/shares/gcp/outputs/labor/impacts-woodwork/',
      'combined_mixed_splines_27_37_39_by_risk_empshare_noFE_YearlyAverageDay/',
      'rcp85/CCSM4/high/SSP3/csv/',
      'combined_mixed_model_splines_empshare_noFE-{risk}-{weight}-levels-combined.csv')

  print(file)  
  df= read_csv(file)
  
  df_plot = df %>% 
              dplyr::filter(year == 2099) %>% 
              dplyr::mutate(value = -value)
              # we were converting minutes to minutes lost

  # find the scales for nice plotting
  bound = ceiling(max(abs(df_plot$value), na.rm=TRUE))
  scale_v = c(-1, -0.2, -0.05, -0.005, 0, 0.005, 0.05, 0.2, 1)
  rescale_value <- scale_v*bound
  

  p = join.plot.map(map.df = mymap, 
                     df = df_plot, 
                     df.key = "region", 
                     plot.var = "value", 
                     topcode = T, 
                     topcode.ub = max(rescale_value),
                     breaks_labels_val = seq(-bound, bound, bound/3),
                     color.scheme = "div", 
                     rescale_val = rescale_value,
                     colorbar.title = paste0("mins lost"), 
                     map.title = glue("{ssp}-{rcp}-{risk}-{adapt}"))

  ggsave(glue("{DIR_FIG}/single_mixed_model/{rcp}-{ssp}-{weight}-{risk}-{adapt}_impacts_map.pdf"), p)
}

map_args = expand.grid(rcp="rcp85",
                       ssp="SSP3",
                       adapt="fulladapt",
                       risk=c("lowriskimpacts","rebased", "highriskimpacts"),
                       weight=c("wage","pop", "gdp")
                       )

print(map_args)

mcmapply(plot_impact_map,
         ssp=map_args$ssp,
         rcp=map_args$rcp,
         adapt=map_args$adapt,
         risk=map_args$risk,
         weight=map_args$weight,
         mc.cores=5
          )