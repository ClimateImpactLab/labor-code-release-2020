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

plot_impact_map = function(folder, name, output, rcp, ssp, aggregation, varname){

  # browser()
  
  if (aggregation != "") {
      file <- glue('{folder}/{name}-{varname}-{aggregation}-levels.csv')
      colorbar_title = aggregation
      title <- glue("{varname} {aggregation}-weighted impacts ({ssp}, {rcp}) 2099")
      # gdp weighted impacts - Damages as Percentage of GDP
      # wage weighted impacts - Damages in Million Dollars
  } else {
      file <- glue('{folder}/{name}-{varname}.csv')
      colorbar_title = "mins lost"
      title <- glue("{varname} impacts in minutes worked per worker ({ssp}, {rcp}) 2099")
  }
  
  if (varname == "clip") {
    file <- glue('{folder}/{name}-{varname}.csv')
    colorbar_title = "risk share"
    title <- glue("risk share raw impacts ({ssp}, {rcp}) 2099")
    
  }
  print(file)  
  df= read_csv(file)
  
  df_plot = df %>% 
              dplyr::filter(year == 2099) 

  if (varname != "clip") {
    df_plot = df_plot %>% 
              dplyr::mutate(value = -as.numeric(value))
  }
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
                     plot.lakes=F,
                     rescale_val = rescale_value,
                     colorbar.title = colorbar_title,
                     map.title = title)

  dir.create(file.path(glue("{DIR_FIG}"), output), recursive = TRUE)
  ggsave(glue("{DIR_FIG}/{output}/map-{name}-{varname}-{aggregation}-{rcp}-{ssp}-2099.pdf"), p)
}


######################
# MAIN MODEL - CLIPPING LR TEMP
######################

# change input folder path here
folder = glue('/mnt/battuta_shares/gcp/outputs/labor/impacts-woodwork/double_edge_restriction_single/median/rcp85/CCSM4/high/SSP3/csv')

# change output folder name here
output = 'double_edge_restriction_single'

######################
# RUN THE FUNCTION
######################

# raw impact and damages in percent gdp maps
map_args = expand.grid(folder= folder,
                       name=c("clip_lrt_edge_restriction","clip_lrt_edge_restriction-incadapt","clip_lrt_edge_restriction-noadapt"),
                       output=output,
                       rcp="rcp85",
                       ssp="SSP3",
                       varname=c( "highriskimpacts", "rebased", "lowriskimpacts"),
                       aggregation = c("", "gdp", "wage") 
                       )

print(map_args)

mcmapply(plot_impact_map,
         folder= map_args$folder,
         name=map_args$name,
         output=output,
         ssp=map_args$ssp,
         rcp=map_args$rcp,
         aggregation=map_args$aggregation,
         varname=map_args$varname,
         mc.cores=20
        )

# risk share map
plot_impact_map(folder, "clip_lrt_edge_restriction", output, "rcp85", "SSP3", "", "clip")


