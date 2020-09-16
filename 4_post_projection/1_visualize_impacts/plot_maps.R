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

  if (aggregation == "-pop-allvars-aggregated") {
    plot_title <- "Pop Weighted Impacts - Mins Worked"
  } else if (aggregation == "-gdp-aggregated") {
    plot_title <- "Impacts as Percentage of GDP"
  } else if (aggregation == "-wage-aggregated") {
    plot_title <- "Impacts in Dollars"
  } else if (aggregation == "") {
    plot_title <- "Impacts in Minutes Worked per Worker"
  } else {
    print("wrong aggregation!")
    return()
  }

  df= read_csv(glue('{ROOT_INT_DATA}/projection_outputs/extracted_data/{ssp}-{rcp}_{iam}_{risk}_{adapt}{aggregation}{suffix}_{year}_map.csv')) # browser()
  bound = 30

  if ((aggregation == "-wage-levels" ) || (aggregation == "-gdp-levels")) {
    df_plot = df %>% dplyr::mutate(mean = -mean)
    scale_v = c(-1, -0.2, -0.05, -0.005, 0, 0.005, 0.05, 0.2, 1)
    # invert the sign for dollar values and gdp percentage
  } else {
    df_plot = df
    scale_v = c(1, 0.2, 0.05, 0.005, 0, -0.005, -0.05, -0.2, -1)
  }

  if (risk == "riskshare") {
    bound = 1
    scale_v = c(1, 0.2, 0.05, 0.005, 0, -0.005, -0.05, -0.2, -1)
  }

    
  # find the scales for nice plotting
  # browser()
  # bound = ceiling(max(abs(df_plot$mean)))
  
  rescale_value <- scale_v*bound

  # browser()
  p = join.plot.map(map.df = mymap, 
                     df = df_plot, 
                     df.key = "region", 
                     plot.var = "mean", 
                     topcode = T, 
                     topcode.ub = max(rescale_value),
                     breaks_labels_val = seq(-bound, bound, bound/3),
                     color.scheme = "div", 
                     # outlines = F,
                     rescale_val = rescale_value,
                     colorbar.title = paste0(plot_title), 
                     map.title = glue("{ssp}-{rcp}-{iam}-{risk}-{adapt}{aggregation}-{year}"))
  # browser()

  ggsave(glue("{output_folder}/{ssp}-{rcp}_{iam}_{risk}_{adapt}{aggregation}{suffix}_{year}_map.pdf"), p)
}
  


# now ony plot the ones we need
plot_impact_map(rcp="rcp85",ssp="SSP3",iam="high", adapt="fulladapt",year=2099,risk="highrisk",aggregation="", output_folder = DIR_FIG)
plot_impact_map(rcp="rcp85",ssp="SSP3",iam="high", adapt="fulladapt",year=2099,risk="lowrisk",aggregation="", output_folder = DIR_FIG)
plot_impact_map(rcp="rcp85",ssp="SSP3",iam="high", adapt="fulladapt",year=2099,risk="allrisk",aggregation="", output_folder = DIR_FIG)

plot_impact_map(rcp="rcp85",ssp="SSP3",iam="high", adapt="fulladapt",year=2020,risk="riskshare",aggregation="", output_folder = DIR_FIG)
plot_impact_map(rcp="rcp85",ssp="SSP3",iam="high", adapt="fulladapt",year=2040,risk="riskshare",aggregation="", output_folder = DIR_FIG)
plot_impact_map(rcp="rcp85",ssp="SSP3",iam="high", adapt="fulladapt",year=2060,risk="riskshare",aggregation="", output_folder = DIR_FIG)
plot_impact_map(rcp="rcp85",ssp="SSP3",iam="high", adapt="fulladapt",year=2080,risk="riskshare",aggregation="", output_folder = DIR_FIG)

# plot_impact_map(rcp="rcp85",ssp="SSP3",iam="high", adapt="fulladapt",year=2020,risk="riskshare",aggregation="", output_folder = DIR_FIG)
# plot_impact_map(rcp="rcp85",ssp="SSP3",iam="high", adapt="fulladapt",year=2098,risk="allrisk",aggregation="-gdp")


# # the following two blocks can plot everything
# args = expand.grid(rcp=c("rcp85","rcp45"),
#                        ssp=c("SSP1","SSP2","SSP3","SSP4","SSP5"),
#                        adapt=c("fulladapt","noadapt","incadapt","histclim"),
#                        year=c(2020,2099),
#                        risk=c("highrisk","lowrisk","allrisk","riskshare"),
#                        iam=c("high","low"),
#                        aggregation=c("","-pop-allvars-levels","-wage-levels","-gdp-levels")
#                        # aggregation=c("", "-pop-allvars-levels")
#                        )

# mcmapply(plot_impact_map, 
#   rcp=args$rcp, 
#   ssp=args$ssp, 
#   iam=args$iam,
#   year=args$year, 
#   risk=args$risk, 
#   adapt=args$adapt,
#   # suffix="_raw_impacts",
#   output_folder = glue("{DIR_FIG}/all_maps/"),
#   aggregation=args$aggregation,
#   mc.cores = 40)


################################
# plot beta maps

# get the 2099 risk share from the single projection



plot_beta_map = function(rcp, ssp, iam, adapt, year, risk, aggregation="", suffix="", response_at_temp=37){
  print(glue('{ROOT_INT_DATA}/projection_outputs/extracted_data/{ssp}-{rcp}_{iam}_riskshare_{adapt}{aggregation}{suffix}_{year}_map.csv'))
  df_riskshare = read_csv(glue('{ROOT_INT_DATA}/projection_outputs/extracted_data/{ssp}-{rcp}_{iam}_riskshare_{adapt}{aggregation}{suffix}_{year}_map.csv')) # browser()
  df_response_function = read_csv(glue('{DIR_RF}/uninteracted_reg_comlohi/uninteracted_reg_comlohi_full_response.csv'))

  response = df_response_function %>% 
                dplyr::filter(temp == response_at_temp) %>%
                dplyr::select(c("yhat_low","yhat_high"))
                # we were converting minutes to minutes lost

  
  df_plot = df_riskshare %>%
              dplyr::mutate(mean = mean * response$yhat_high + (1-mean) * response$yhat_low)
  rescale_value <- c(-12, -11,-10,-9,-8,-7,-6,-5,-4,-3,-2,-1,0)

  p = join.plot.map(map.df = mymap, 
                     df = df_plot, 
                     df.key = "region", 
                     plot.var = "mean", 
                     topcode = T, 
                     # outlines = F,
                     topcode.ub = 0,
                     topcode.lb = -12,
                     breaks_labels_val = rescale_value,
                     color.scheme = "seq",
                     color.values = c("#c92116", "#ec603f", "#fd9b64","#fdc370", "#fee69b","#fef7d1", "#f0f7d9"),
                     rescale_val = rescale_value,
                     colorbar.title = paste0("Impacts in Minutes Worked per Worker"), 
                     map.title = glue("beta-map-{ssp}-{rcp}-{iam}-{risk}-{adapt}{aggregation}-{year}"))

  ggsave(glue("{DIR_FIG}/{ssp}-{rcp}_{iam}_{risk}_{adapt}{aggregation}{suffix}_{year}_beta_map.pdf"), p)
}


for (yr in c(2020,2040,2060,2080,2098,2099)) {
  plot_beta_map(rcp="rcp85",ssp="SSP3",iam="high", adapt="fulladapt",year=yr,risk="allrisk",aggregation="")
}

 

# plot gdp maps 
cov_file= read_csv(glue('/shares/gcp/outputs/energy_pixel_interaction/impacts-blueghost/single-OTHERIND_electricity_FD_FGLS_719_Exclude_all-issues_break2_semi-parametric_TINV_clim_GMFD/rcp85/CCSM4/high/SSP3/hddcddspline_OTHERIND_electricity-allcalcs-FD_FGLS_inter_OTHERIND_electricity_TINV_clim.csv'),
    skip = 114)

cov_loggdppc = cov_file %>%dplyr::select("year","region", "loggdppc") %>% unique()

plot_cov_map = function(cov_file, year, output_folder = DIR_FIG){

  # browser()
  df_plot = cov_file %>% dplyr::filter(year == !!year)
  
    
  # find the scales for nice plotting
  
  rescale_value <- c(0,1,2,3,4,5,6,7,8,9,10,11,12)
  p = join.plot.map(map.df = mymap, 
                     df = df_plot, 
                     df.key = "region", 
                     plot.var = "loggdppc", 
                     topcode = T, 
                     topcode.lb = 0,
                     topcode.ub = 12,
                     breaks_labels_val = rescale_value,
                     color.scheme = "seq", 
                     color.values = c("#c92116", "#ec603f", "#fd9b64","#fdc370", "#fee69b","#fef7d1", "#f0f7d9"),
                     # outlines = F,
                     rescale_val = rescale_value,
                     colorbar.title = "loggdppc", 
                     map.title = glue("ssp3-rcp85-high-loggdppc-{year}")
                     )
  # browser()

  ggsave(glue("{output_folder}/ssp3-rcp85-high-loggdppc_{year}_map.png"), p)
}

plot_cov_map(cov_file = cov_loggdppc, 2020)

for (yr in c(2020,2040,2060,2080,2098,2099)) {
  plot_cov_map(cov_file = cov_loggdppc, yr)
}




