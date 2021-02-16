# plot some maps and see if james' config output 
# is totally all over the place

# High-risk impact map (mins)
# Low-risk impact map (mins)
# Overall impact map (mins)
# Overall impact map (%GDP)

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

plot_impact_map = function(mymap, df_path, var_list, save_name){

  # browser()
  df = read_csv(df_path) 
	# browser()
  
	for (v in var_list) {
		for (y in c(2020, 2050, 2099)) {
		  df_plot = df %>% dplyr::filter(year == !!y)
		  bound = ceiling(max(abs(df_plot %>% dplyr::select(!!v))))
		  scale_v = c(-1, -0.2, -0.05, -0.005, 0, 0.005, 0.05, 0.2, 1)
		  rescale_value <- scale_v*bound
		  ub = max(rescale_value,na.rm = TRUE)
		  lb = -ub
		  breaks_labels = seq(-bound, bound, bound/4)
		  # browser()
		  
		  p = join.plot.map(map.df = mymap, 
		                     df = df_plot, 
		                     df.key = "regions", 
		                     plot.var = v, 
		                     topcode = T, 
		                     topcode.lb = lb,
		                     topcode.ub = ub,
		                     breaks_labels_val = breaks_labels,
		                     color.scheme = "div", 
		                     rescale_val = rescale_value,
		                     colorbar.title = "difference", 
		                     map.title = glue("{save_name} : {v}"))
		  
		  save_path = paste0(DIR_FIG, "/re-rebasing_comparison/") 
		  save_file = paste0(save_name, "-", v, "-", y,".pdf")
		  ggsave(paste0(save_path, save_file), p)				
		}
	}
}

# now ony plot the ones we need
results_root = "/shares/gcp/outputs/labor/impacts-woodwork/"
single_folder = "/rcp85/CCSM4/high/SSP3/"
our_projection = paste0(results_root, "uninteracted_splines_27_37_39_by_risk_empshare_noFE_YearlyAverageDay_wrong_rebasing/", single_folder, "impacts_for_mapping.csv")
james_projection = paste0(results_root, "uninteracted_splines_27_37_39_by_risk_empshare_noFE_YearlyAverageDay_correct_rebasing/", single_folder, "impacts_for_mapping.csv")

plot_impact_map(mymap, our_projection, c('clip','highriskimpacts','highriskimpacts_rebased','lowriskimpacts','lowriskimpacts_rebased','rebased','rebased_new'), "old")
plot_impact_map(mymap, james_projection, c('clip','highriskimpacts','lowriskimpacts','rebased') ,"new")


