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

  # browser()
  df= read_csv(glue('{ROOT_INT_DATA}/projection_outputs/extracted_data_mc/{ssp}-{rcp}_{iam}_{risk}_{adapt}{aggregation}{suffix}_{year}_map.csv')) # browser()

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
    rescale_value <- scale_v*bound
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
  
  ggsave(glue("{output_folder}/{ssp}-{rcp}_{iam}_{risk}_{adapt}{aggregation}{suffix}_{year}_map.pdf"), p)
  # return(p)
}

# plot_impact_map(rcp="rcp85",ssp="SSP3",iam="high", adapt="fulladapt",year=2099,risk="highrisk",aggregation="-wage-levels", output_folder = DIR_FIG)


# # the following two blocks can plot everything
# args = expand.grid(rcp=c("rcp85","rcp45"),
#                        ssp=c("SSP1","SSP2","SSP3","SSP4","SSP5"),
#                        adapt=c("fulladapt","noadapt","incadapt","histclim"),
#                        year=c(2020,2098,2099),
#                        risk=c("highrisk","lowrisk","allrisk","riskshare"),
#                        iam=c("high","low"),
#                        aggregation=c("")
#                        )

# mcmapply(plot_impact_map, 
#   rcp=args$rcp, 
#   ssp=args$ssp, 
#   iam=args$iam,
#   year=args$year, 
#   risk=args$risk, 
#   adapt=args$adapt,
#   output_folder = glue("{DIR_FIG}/all_maps/"),
#   aggregation=args$aggregation,
#   mc.cores = 40)


# args = expand.grid(rcp=c("rcp85","rcp45"),
#                        ssp=c("SSP1","SSP2","SSP3","SSP4","SSP5"),
#                        adapt=c("fulladapt","histclim"),
#                        year=c(2020,2098,2099),
#                        risk=c("highrisk","lowrisk","allrisk"),
#                        iam=c("high","low"),
#                        aggregation=c("-wage-levels","-gdp-levels")
#                        )

# mcmapply(plot_impact_map, 
#   rcp=args$rcp, 
#   ssp=args$ssp, 
#   iam=args$iam,
#   year=args$year, 
#   risk=args$risk, 
#   adapt=args$adapt,
#   output_folder = glue("{DIR_FIG}/all_maps/"),
#   aggregation=args$aggregation,
#   mc.cores = 30)



# now ony plot the ones we need
plot_impact_map(rcp="rcp85",ssp="SSP3",iam="high", adapt="fulladapt",year=2099,risk="highrisk",aggregation="", output_folder = DIR_FIG)
plot_impact_map(rcp="rcp85",ssp="SSP3",iam="high", adapt="fulladapt",year=2099,risk="lowrisk",aggregation="", output_folder = DIR_FIG)
plot_impact_map(rcp="rcp85",ssp="SSP3",iam="high", adapt="fulladapt",year=2099,risk="allrisk",aggregation="", output_folder = DIR_FIG)
plot_impact_map(rcp="rcp85",ssp="SSP3",iam="high", adapt="fulladapt",year=2020,risk="riskshare",aggregation="-gdp-levels", output_folder = DIR_FIG)




# ################################
# # plot beta maps

# # get the 2099 risk share from the single projection



# plot_beta_map = function(rcp, ssp, iam, adapt, year, risk, aggregation="", suffix="", response_at_temp=37){
#   print(glue('{ROOT_INT_DATA}/projection_outputs/extracted_data/{ssp}-{rcp}_{iam}_riskshare_{adapt}{aggregation}{suffix}_{year}_map.csv'))
#   df_riskshare = read_csv(glue('{ROOT_INT_DATA}/projection_outputs/extracted_data/{ssp}-{rcp}_{iam}_riskshare_{adapt}{aggregation}{suffix}_{year}_map.csv')) # browser()
#   df_response_function = read_csv(glue('{DIR_RF}/uninteracted_reg_comlohi/uninteracted_reg_comlohi_full_response.csv'))

#   response = df_response_function %>% 
#                 dplyr::filter(temp == response_at_temp) %>%
#                 dplyr::select(c("yhat_low","yhat_high"))
#                 # we were converting minutes to minutes lost

  
#   df_plot = df_riskshare %>%
#               dplyr::mutate(mean = mean * response$yhat_high + (1-mean) * response$yhat_low)
#   rescale_value <- c(-12, -11,-10,-9,-8,-7,-6,-5,-4,-3,-2,-1,0)

#   p = join.plot.map(map.df = mymap, 
#                      df = df_plot, 
#                      df.key = "region", 
#                      plot.var = "mean", 
#                      topcode = T, 
#                      # outlines = F,
#                      topcode.ub = 0,
#                      topcode.lb = -12,
#                      breaks_labels_val = rescale_value,
#                      color.scheme = "seq",
#                      color.values = c("#c92116", "#ec603f", "#fd9b64","#fdc370", "#fee69b","#fef7d1", "#f0f7d9"),
#                      rescale_val = rescale_value,
#                      colorbar.title = paste0("Impacts in Minutes Worked per Worker"), 
#                      map.title = glue("beta-map-{ssp}-{rcp}-{iam}-{risk}-{adapt}{aggregation}-{year}"))

#   ggsave(glue("{DIR_FIG}/{ssp}-{rcp}_{iam}_{risk}_{adapt}{aggregation}{suffix}_{year}_beta_map.pdf"), p)
# }


# for (yr in c(2020,2040,2060,2080,2098,2099)) {
#   plot_beta_map(rcp="rcp85",ssp="SSP3",iam="high", adapt="fulladapt",year=yr,risk="allrisk",aggregation="")
# }

#  # doing!!!1

# # plot gdp maps 
# cov_file= read_csv(glue('/shares/gcp/outputs/labor/impacts-woodwork/projection_combined_uninteracted_splines_by_risk_empshare_noFE_YearlyAverageDay/rcp85/CCSM4/high/SSP3/projection_combined_uninteracted_splines_by_risk_empshare_noFE-allcalcs-combined_uninteracted_spline_empshare_noFE.csv'),
#  skip = 25)

# cov_loggdppc = cov_file %>%dplyr::select("year","region", "loggdppc") %>% unique()

# plot_cov_map = function(cov_file, year, output_folder = DIR_FIG){

#   # browser()
#   df_plot = cov_file %>% dplyr::filter(year == !!year)
  
    
#   # find the scales for nice plotting
  
#   rescale_value <- c(0,1,2,3,4,5,6,7,8,9,10,11,12)
#   p = join.plot.map(map.df = mymap, 
#                      df = df_plot, 
#                      df.key = "region", 
#                      plot.var = "loggdppc", 
#                      topcode = T, 
#                      topcode.lb = 0,
#                      topcode.ub = 12,
#                      breaks_labels_val = rescale_value,
#                      color.scheme = "seq", 
#                      color.values = c("#c92116", "#ec603f", "#fd9b64","#fdc370", "#fee69b","#fef7d1", "#f0f7d9"),
#                      # outlines = F,
#                      rescale_val = rescale_value,
#                      colorbar.title = "loggdppc", 
#                      map.title = glue("ssp3-rcp85-high-loggdppc-{year}")
#                      )
#   # browser()

#   ggsave(glue("{output_folder}/ssp3-rcp85-high-loggdppc_{year}_map.png"), p)
# }


# for (yr in c(2020,2040,2060,2080,2098,2099)) {
#   plot_cov_map(cov_file = cov_loggdppc, yr)
# }




