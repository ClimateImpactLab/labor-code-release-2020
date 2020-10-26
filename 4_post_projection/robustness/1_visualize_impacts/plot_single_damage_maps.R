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
# 1. Load in a world shapefile, containing Impact Region boundaries, 
# and convert to a dataframe for plotting
#############################################

mymap = load.map(shploc = paste0(ROOT_INT_DATA, "/shapefiles/world-combo-new-nytimes"))

#################
# FUNCTION
#################

plot_impact_map = function(folder, name, output, rcp, ssp, adapt, weight, risk, suffix){

  if (adapt != "") {
      file = glue('{folder}/{name}-{risk}-{weight}-levels-combined.csv')
      title = glue("{risk} {weight}-weighted impacts ({ssp}, {rcp}, {adapt}) 2099")
  } else {
      file = glue('{folder}/{name}-{risk}-combined.csv')
      title = glue("minutes per worker per day ({ssp}, {rcp}, {adapt}) 2099")
  }
  
  print(file)  
  df= read_csv(file)
  
  df_plot = df %>% 
              dplyr::filter(year == 2099) %>% 
              dplyr::mutate(value = -as.numeric(value))
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
                     map.title = title)

  dir.create(file.path(DIR_FIG, output), recursive = TRUE)
  ggsave(glue("{DIR_FIG}/{output}/map-{weight}-{risk}-{adapt}-{rcp}-{ssp}.pdf"), p)
}


######################
# EDGE RESTRICTION MODEL
######################

folder = glue('/shares/gcp/outputs/labor/impacts-woodwork/hi_1factor_lo_unint_mixed_model_copy/',
  'combined_mixed_splines_27_37_39_by_risk_empshare_noFE_YearlyAverageDay/rcp85/CCSM4/high/SSP3/csv')

name = 'hi_1factor_lo_unint_mixed_model_splines_empshare_noFE'
output = 'hi_1factor_lo_unint_mixed_model/'

######################
# MAIN MODEL - CHECK
######################

# folder = glue('/shares/gcp/outputs/labor/impacts-woodwork/',
#         'combined_uninteracted_splines_27_37_39_by_risk_empshare_noFE_YearlyAverageDay/',
#         'median/rcp85/CCSM4/high/SSP3/csv')

# name = 'combined_uninteracted_spline_empshare_noFE'
# output = 'main_model_check'

######################
# MIXED MODEL
######################

# folder = glue('/shares/gcp/outputs/labor/impacts-woodwork/z_old/test_clipping_extrema_mixed_model/',
#   'combined_mixed_splines_27_37_39_by_risk_empshare_noFE_YearlyAverageDay/rcp85/CCSM4/high/SSP3/csv')

# name = 'combined_mixed_model_splines_empshare_noFE'
# output = 'single_mixed_model/'

######################
# WITH CHINA
######################

# folder = glue('/shares/gcp/outputs/labor/impacts-woodwork/uninteracted_main_model_w_chn_copy/',
#   'uninteracted_splines_w_chn_21_37_41_by_risk_empshare_noFE_YearlyAverageDay/rcp85/CCSM4/high/SSP3/csv')

# name = 'uninteracted_main_model_w_chn'
# output = 'uninteracted_main_model_w_chn/'


######################
# RUN THE FUNCTION
######################

map_args = expand.grid(folder= folder,
                       name=name,
                       output=output,
                       rcp="rcp85",
                       ssp="SSP3",
                       adapt="fulladapt",
                       risk=c("lowriskimpacts","rebased_new", "highriskimpacts"),
                       weight=c("wage", "gdp", "pop"),
                       suffix=("levels")
                       )

map_args = map_args %>% rbind(
                       expand.grid(folder= folder,
                       name=name,
                       output=output,
                       rcp="rcp85",
                       ssp="SSP3",
                       adapt="",
                       risk=c("lowriskimpacts","rebased_new", "highriskimpacts"),
                       weight="",
                       suffix=""
                       )
                       )

print(map_args)

mcmapply(plot_impact_map,
         folder= map_args$folder,
         name=map_args$name,
         output=output,
         ssp=map_args$ssp,
         rcp=map_args$rcp,
         adapt=map_args$adapt,
         risk=map_args$risk,
         weight=map_args$weight,
         suffix=map_args$suffix,
         mc.cores=5
          )