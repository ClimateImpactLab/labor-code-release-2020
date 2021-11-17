# Produces maps displayed in the energy paper. Uses Functions in mapping.R
# done 26 aug 2020

rm(list = ls())

if(!require("pacman")){install.packages(("pacman"))}
pacman::p_load(ggplot2, 
               dplyr,
               readr,
               glue,
               parallel,
               data.table)

source("~/repos/labor-code-release-2020/0_subroutines/paths.R")
source("~/repos/post-projection-tools/mapping/imgcat.R") #this redefines the way ggplot plots. 
source("~/repos/post-projection-tools/mapping/mapping.R")

#############################################
# 1. Load in a world shapefile, containing Impact Region boundaries, and convert to a 
#     dataframe for plotting
#############################################

mymap = load.saved.map()

#################
# FUNCTION
#################

plot_impact_map = function(folder, name, output, rcp, ssp, weight, risk){

  # browser()
  
  if (weight != "") {
      file <- glue('{folder}/{name}-{risk}-{weight}-levels.csv')
      colorbar_title = weight
      title <- glue("{risk} {weight}-weighted impacts (rff-{ssp}, {rcp}) 2099")
  } else {
      file <- glue('{folder}/{name}-{risk}.csv')
      colorbar_title = "mins lost"
      title <- glue("{name} {risk} raw impacts (rff-{ssp}, {rcp}) 2099")
  }
  
  if (risk == "clip") {
    file <- glue('{folder}/{name}-{risk}.csv')
    colorbar_title = "risk share"
    title <- glue("{name} risk share raw impacts (rff-{ssp}, {rcp}) 2099")
    
  }
  print(file)  
  df= read_csv(file)
  
  df_plot = df %>% 
              dplyr::filter(year==2099) 

  if (risk != "clip") {
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
  ggsave(glue("{DIR_FIG}/{output}/map-{name}-{risk}-{weight}-{rcp}-{ssp}-2099.pdf"), p)
}

######################
# MAIN MODEL - CLIPPING LR TEMP
######################

# change input folder path here
folder_rcp85 = glue('/shares/gcp/outputs/labor/impacts-woodwork/test_rff_scenario_single/',
        'median/rcp85/CCSM4/rff/6546/csv')

folder_rcp45 = glue('/shares/gcp/outputs/labor/impacts-woodwork/test_rff_scenario_single/',
        'median/rcp45/CCSM4/rff/6546/csv')

# change output folder name here
output = 'test_rff_scenario_single'


######################
# RUN THE FUNCTION
######################

map_args = expand.grid(name=c("uninteracted_main_model","uninteracted_main_model-incadapt","uninteracted_main_model-noadapt"),
                      ssp="6456",
                      risk=c("highriskimpacts","rebased", "lowriskimpacts","clip"),
                      weight = ""
                       )
# testing code
# plot_impact_map(folder, "clip", output, "rcp85", "SSP3", "", "rebased_new")

print(map_args)

########## RCP 8.5
mcmapply(plot_impact_map,
    folder=folder_rcp85,
    name=map_args$name,
    output=output,
    ssp=map_args$ssp,
    rcp="rcp85",
    weight=map_args$weight,
    risk=map_args$risk,
    mc.cores=20
)

########## RCP 4.5
mcmapply(plot_impact_map,
    folder=folder_rcp45,
    name=map_args$name,
    output=output,
    ssp=map_args$ssp,
    rcp="rcp45",
    weight=map_args$weight,
    risk=map_args$risk,
    mc.cores=20
)



