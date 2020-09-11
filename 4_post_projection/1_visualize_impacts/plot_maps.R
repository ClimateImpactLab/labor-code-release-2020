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
# 1. Load in a world shapefile, containing Impact Region boundaries, and convert to a 
#     dataframe for plotting

mymap = load.map(shploc = paste0(ROOT_INT_DATA, "/shapefiles/world-combo-new-nytimes"))


#############################################
# map of overall impact in 2099


plot_impact_map = function(rcp, ssp, iam, adapt, year, risk, aggregation="", suffix="",output_folder = DIR_FIG){
  

  if ((ssp=="SSP1" & rcp=="rcp85") | (ssp=="SSP5" & rcp=="rcp45")) {
    return()
  }

  df= read_csv(glue('{ROOT_INT_DATA}/projection_outputs/extracted_data/{ssp}-{rcp}_{iam}_{risk}_{adapt}{aggregation}{suffix}_{year}_map.csv')) # browser()

  df_plot = df %>% 
                dplyr::mutate(mean = -mean)
                # we were converting minutes to minutes lost

  # find the scales for nice plotting
  # browser()
  bound = ceiling(max(abs(df_plot$mean)))
  scale_v = c(-1, -0.2, -0.05, -0.005, 0, 0.005, 0.05, 0.2, 1)
  rescale_value <- scale_v*bound
  

  p = join.plot.map(map.df = mymap, 
                     df = df_plot, 
                     df.key = "region", 
                     plot.var = "mean", 
                     topcode = T, 
                     topcode.ub = max(rescale_value),
                     breaks_labels_val = seq(-bound, bound, bound/3),
                     color.scheme = "div", 
                     rescale_val = rescale_value,
                     colorbar.title = paste0("mins lost"), 
                     map.title = glue("{ssp}-{rcp}-{iam}-{risk}-{adapt}{aggregation}-{year}"))

  ggsave(glue("{output_folder}/{ssp}-{rcp}_{iam}_{risk}_{adapt}{aggregation}{suffix}_{year}_map.pdf"), p)
}



# the following two blocks can plot everything
args = expand.grid(rcp=c("rcp85","rcp45"),
                       ssp=c("SSP1","SSP2","SSP3","SSP4","SSP5"),
                       adapt=c("fulladapt","noadapt","incadapt","histclim"),
                       year=c(2020,2099),
                       risk=c("highrisk","lowrisk","allrisk","riskshare"),
                       iam=c("high","low"),
                       aggregation=c("","-pop-allvars-levels","-wage-levels","-gdp-levels")
                       # aggregation=c("", "-pop-allvars-levels")
                       )

mcmapply(plot_impact_map, 
  rcp=args$rcp, 
  ssp=args$ssp, 
  iam=args$iam,
  year=args$year, 
  risk=args$risk, 
  adapt=args$adapt,
  # suffix="_raw_impacts",
  output_folder = glue("{DIR_FIG}/all_maps/"),
  aggregation=args$aggregation,
  mc.cores = 40)


# now ony plot the ones we need
plot_impact_map(rcp="rcp85",ssp="SSP3",iam="high", adapt="fulladapt",year=2098,risk="highrisk",aggregation="", output_folder = DIR_FIG)
plot_impact_map(rcp="rcp85",ssp="SSP3",iam="high", adapt="fulladapt",year=2098,risk="lowrisk",aggregation="", output_folder = DIR_FIG)
plot_impact_map(rcp="rcp85",ssp="SSP3",iam="high", adapt="fulladapt",year=2098,risk="riskshare",aggregation="", output_folder = DIR_FIG)
plot_impact_map(rcp="rcp85",ssp="SSP3",iam="high", adapt="fulladapt",year=2020,risk="riskshare",aggregation="", output_folder = DIR_FIG)
plot_impact_map(rcp="rcp85",ssp="SSP3",iam="high", adapt="fulladapt",year=2098,risk="allrisk",aggregation="", output_folder = DIR_FIG)
# plot_impact_map(rcp="rcp85",ssp="SSP3",iam="high", adapt="fulladapt",year=2098,risk="allrisk",aggregation="-gdp")

################################
# plot beta maps

# get the 2099 risk share from the single projection



plot_beta_map = function(rcp, ssp, iam, adapt, year, risk, aggregation="", suffix="", response_at_temp=37){
  df_riskshare = read_csv(glue('{ROOT_INT_DATA}/projection_outputs/mapping_data/{ssp}-{rcp}_{iam}_riskshare_{adapt}{aggregation}{suffix}_{year}_map.csv')) # browser()
  df_response_function = read_csv(glue('{DIR_RF}/uninteracted_reg_comlohi/uninteracted_reg_comlohi_full_response.csv'))

  response = df_response_function %>% 
                dplyr::filter(temp == response_at_temp) %>%
                dplyr::select(c("yhat_low","yhat_high"))
                # we were converting minutes to minutes lost

  
  df_plot = df_riskshare %>%
              dplyr::mutate(mean = mean * response$yhat_high + (1-mean) * response$yhat_low) %>%
              dplyr::mutate(mean = -mean)
  # find the scales for nice plotting
  # browser()
  bound = ceiling(max(abs(df_plot$mean)))
  scale_v = c(-1, -0.2, -0.05, -0.005, 0, 0.005, 0.05, 0.2, 1)
  rescale_value <- scale_v*bound
  
  p = join.plot.map(map.df = mymap, 
                     df = df_plot, 
                     df.key = "region", 
                     plot.var = "mean", 
                     topcode = T, 
                     topcode.ub = max(rescale_value),
                     breaks_labels_val = seq(-bound, bound, bound/3),
                     color.scheme = "div", 
                     rescale_val = rescale_value,
                     colorbar.title = paste0("mins lost"), 
                     map.title = glue("beta-map-{ssp}-{rcp}-{iam}-{risk}-{adapt}{aggregation}-{year}"))

  ggsave(glue("{DIR_FIG}/{ssp}-{rcp}_{iam}_{risk}_{adapt}{aggregation}{suffix}_{year}_beta_map.pdf"), p)
}

plot_beta_map(rcp="rcp85",ssp="SSP3",iam="high", adapt="fulladapt",year=2098,risk="allrisk",aggregation="")
plot_beta_map(rcp="rcp85",ssp="SSP3",iam="high", adapt="fulladapt",year=2020,risk="allrisk",aggregation="")

 

