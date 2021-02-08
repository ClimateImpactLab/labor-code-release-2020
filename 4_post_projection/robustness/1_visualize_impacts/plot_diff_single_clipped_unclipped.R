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
library(glue)
library(parallel)

source(paste0(DIR_REPO_LABOR, "/4_post_projection/0_utils/mapping.R"))

#############################################
# 1. Load in a world shapefile, containing Impact Region boundaries, 
# and convert to a dataframe for plotting
#############################################

mymap = load.map(shploc = paste0(ROOT_INT_DATA, "/shapefiles/world-combo-new-nytimes"))

#################
# FUNCTION
#################

plot_impact_map = function(folder, name, output){

  # browser()
  
file <- glue('{folder}/{name}.csv')
    colorbar_title = "risk share"
    title <- glue("{name} LRT in 1-99 (SSP3, rcp85) 2099")
    
  print(file)  
  df_plot= read_csv(file)

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
                     plot.lakes=F,
                     rescale_val = rescale_value,
                     colorbar.title = colorbar_title,
                     map.title = title)

  dir.create(file.path(glue("{DIR_FIG}"), output), recursive = TRUE)
  ggsave(glue("{DIR_FIG}/{output}/map-{name}-rcp85-SSP3-2099.pdf"), p)
}

######################
# MAIN MODEL - CLIPPING LR TEMP
######################

folder = glue('/mnt/CIL_labor/3_projection/impact_checks/clipping_lrclim') 

output = 'diff_clipped_vs_unclipped'

######################
# RUN THE FUNCTION
######################



map_args = expand.grid(folder= folder,
                       name=c("riskshare", "lrt_riskshare", "impacts", "lrt_impacts"), #change name argument here
                       output=output
                       )
# testing code
# plot_impact_map(folder, "clip", output, "rcp85", "SSP3", "", "rebased_new")

print(map_args)

mcmapply(plot_impact_map,
         folder= map_args$folder,
         name=map_args$name,
         output=output,
         mc.cores=20
        )



