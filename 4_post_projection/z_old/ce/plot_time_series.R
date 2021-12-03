# plot time series for the CE and MC outputs, SSP3, rcp45 and rcp85


rm(list = ls())
source("~/repos/labor-code-release-2020/0_subroutines/paths.R")
source("~/repos/post-projection-tools/mapping/imgcat.R") #this redefines the way ggplot plots. 
library(glue)
library(parallel)
# Load in the required packages, installing them if necessary 
if(!require("pacman")){install.packages(("pacman"))}
pacman::p_load(ggplot2, 
               dplyr,
               readr, 
               DescTools,
               RColorBrewer)
source("~/repos/post-projection-tools/mapping/imgcat.R") #this redefines the way ggplot plots. 
source(glue("{DIR_REPO_LABOR}/4_post_projection/0_utils/time_series.R"))

# load CE data
ce_raw = read_csv("/mnt/CIL_labor/6_ce/risk_constant_all_ssps_damage_function.csv") %>% 
        select(-X1) %>% distinct()

# load gcm weights
weights = read_csv(paste0('/mnt/CIL_energy/code_release_data_pixel_interaction/', 
	'/miscellaneous/gcm_weights.csv'))
# computed weighted damage for each ssp iam rcp
ce_dmg = left_join(ce_raw, weights, by = "gcm") %>% 
		dplyr::select(ssp, model, year, rcp, gcm, collapsed_damages_constant, norm_weight_rcp45, norm_weight_rcp85) %>% 
	mutate(dmg = ifelse(rcp=="rcp45",
		collapsed_damages_constant * norm_weight_rcp45,
		collapsed_damages_constant * norm_weight_rcp85)) %>%
	group_by(year, rcp, ssp, model) %>% 
	summarize(mean = sum(dmg) / 1000000000000) %>% 
	dplyr::filter(ssp == "SSP3", model == "OECD Env-Growth") 


# convert to %GDP
# load global GDP
global_gdp = read_csv(paste0('/mnt/CIL_energy/code_release_data_pixel_interaction/', 
	'/projection_system_outputs/covariates/SSP3-global-gdp-time_series.csv')) %>%
  mutate(gdp = gdp / 1000000000000)

ce_gdp = left_join(ce_dmg, global_gdp, by = "year") %>%
		 mutate(mean = mean / gdp * 100)

# load MC data
DB_data = "/shares/gcp/estimation/labor/code_release_int_data/"

get_mc_output = function(){
  
  # Load in the impacts data: 
  load_df = function(rcp, adapt, type){
    print(rcp)
	DB_data = "/shares/gcp/estimation/labor/code_release_int_data/"
    df= read_csv(glue('{DB_data}/projection_outputs/extracted_data_mc/SSP3-{rcp}_high_allrisk_{adapt}-{type}-aggregated_global_timeseries.csv'))
    df = df %>% mutate(rcp = rcp, adapt_scen = adapt, type = type, mean = -mean) %>% filter(year <= 2099, year >= 2010)
    return(df)
  }

  options = expand.grid(rcp = c("rcp45", "rcp85"), 
                        adapt = c("fulladapt"),
                        type = c("gdp", "wage"))
  df = mapply(load_df, rcp = options$rcp, adapt = options$adapt, type = options$type,
            SIMPLIFY = FALSE) %>% 
    bind_rows()

  return(
      list(
        df_gdp_45 = df[df$rcp == "rcp45" & df$adapt_scen == "fulladapt" & df$type == "gdp",c('year', 'mean')] %>% mutate(mean = mean * 100), 
        df_gdp_85 = df[df$rcp == "rcp85" & df$adapt_scen == "fulladapt" & df$type == "gdp",c('year', 'mean')] %>% mutate(mean = mean * 100),
        df_dmg_45 = df[df$rcp == "rcp45" & df$adapt_scen == "fulladapt" & df$type == "wage",c('year', 'mean')] %>% mutate(mean = mean / 1000000000000), 
        df_dmg_85 = df[df$rcp == "rcp85" & df$adapt_scen == "fulladapt" & df$type == "wage",c('year', 'mean')] %>% mutate(mean = mean / 1000000000000)
        )
    )
}

df = get_mc_output()

# compute percent gdp using MC damages divided by gdp
df_gdp_45_check = left_join(df$df_dmg_45, global_gdp, by = "year") %>%
		 mutate(mean = mean / gdp * 100)
df_gdp_85_check = left_join(df$df_dmg_85, global_gdp, by = "year") %>%
		 mutate(mean = mean / gdp * 100)


# damage plots
p <- ggtimeseries(
    df.list = list(ce_dmg[ce_dmg$rcp == "rcp45",c('year', 'mean')] %>% as.data.frame(),
    			   ce_dmg[ce_dmg$rcp == "rcp85",c('year', 'mean')] %>% as.data.frame(),
    			   df$df_dmg_45 %>% as.data.frame(),
    			   df$df_dmg_85 %>% as.data.frame()), # mean lines
    x.limits = c(2010, 2098),
    y.label = 'trillion dollars',
    ssp.value = "SSP3", 
    end.yr = 2100,
    legend.values = c("lightblue", "pink", "blue", "red"),
    legend.breaks = c("CE rcp45","CE rcp85","MC rcp45","MC rcp85")) + 
  ggtitle("MC vs CE damages") 

output_dir = "/mnt/CIL_labor/6_ce/"
ggsave(glue("{output_dir}/CE_vs_MC_damages.pdf"), p)


# pct gdp plots
p <- ggtimeseries(
    df.list = list(ce_gdp[ce_gdp$rcp == "rcp45",c('year', 'mean')] %>% as.data.frame(),
    			   ce_gdp[ce_gdp$rcp == "rcp85",c('year', 'mean')] %>% as.data.frame(),
    			   df_gdp_45_check[,c('year', 'mean')] %>% as.data.frame(),
    			   df_gdp_85_check[,c('year', 'mean')] %>% as.data.frame()), # mean lines
    x.limits = c(2010, 2098),
    y.label = 'percent GDP', 
    ssp.value = "SSP3", 
    end.yr = 2100,
    legend.values = c("lightblue", "pink", "blue", "red"),
    legend.breaks = c("CE rcp45","CE rcp85","MC rcp45","MC rcp85")) + 
  ggtitle("MC vs CE percent GDP") 
ggsave(glue("{output_dir}/CE_vs_MC_pct_gdp.pdf"), p)

