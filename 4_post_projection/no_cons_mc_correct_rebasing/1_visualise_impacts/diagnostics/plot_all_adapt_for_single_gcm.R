# trying to figure out 


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

# Set paths
DB_data = "/shares/gcp/estimation/labor/code_release_int_data/"
source(glue("{DIR_REPO_LABOR}/4_post_projection/0_utils/time_series.R"))

# Function that takes in the long data, subsets it and returns a list of dataframes 
# and vectors needed to plot the time series for a given fuel
get_df_list_fig_2C = function(DB_data, model){
  
  # Load in the impacts data: 
  load_df = function(adapt, model){
    df= read_csv(glue('{DB_data}/projection_outputs/extracted_data/median/SSP3-rcp85_high_allrisk_{adapt}-pop-aggregated_rebased_new_global_{model}_timeseries.csv'))
    df = df %>% mutate(rcp = "rcp85", adapt_scen = adapt) %>% filter(year <= 2099)
    return(df)
  }

  # browser()
  options = expand.grid(adapt = c("fulladapt", "incadapt", "noadapt"), model = model)
  df = mapply(load_df, adapt = options$adapt, model = options$model,
            SIMPLIFY = FALSE) %>% 
    bind_rows()
  
  # browser()
  # add wrongly rebased allrisk impact
  df_wrong_rebasing = read_csv(glue('{DB_data}/projection_outputs/extracted_data/median/SSP3-rcp85_high_allrisk_fulladapt-pop-aggregated_rebased_global_{model}_timeseries.csv'))
  df_wrong_rebasing = df_wrong_rebasing %>% mutate(rcp = "rcp85", adapt_scen = "fulladapt-wrong-rebasing") %>% filter(year <= 2099)
  df = rbind(df, df_wrong_rebasing)

  
  return(
      list(
        df_85 = df[df$rcp == "rcp85" & df$adapt_scen == "fulladapt",], 
        df_85.na = df[df$rcp == "rcp85" & df$adapt_scen == "noadapt",], 
        df_85.ia = df[df$rcp == "rcp85" & df$adapt_scen == "incadapt",], 
        df_85.wrong = df[df$rcp == "rcp85" & df$adapt_scen == "fulladapt-wrong-rebasing",] 
        )
    )
}


plot_ts_fig_2C = function(output, DB_data, model){
  
  plot_df = get_df_list_fig_2C(DB_data = DB_data, model = model) 
  # browser()
  
  p <- ggtimeseries(
    df.list = list(plot_df$df_85[,c('year', 'mean')] %>% as.data.frame(), 
                   plot_df$df_85.ia[,c('year', 'mean')]%>% as.data.frame(),
                   plot_df$df_85.na[,c('year', 'mean')]%>% as.data.frame(),
                   plot_df$df_85.wrong[,c('year', 'mean')]%>% as.data.frame()
                   ), # mean lines
    x.limits = c(2010, 2099),
    y.label = 'Impacts: min lost per person',
    legend.values = c("red", "black","blue","green"), #color of mean line
    legend.breaks = c("RCP85 Full Adapt", "RCP85 Inc Adapt", "RCP85 No Adapt","RCP85 Full Adapt Wrong Rebasing"),
    rcp.value = 'rcp85', ssp.value = 'SSP3', iam.value = 'high-fulluncertainty')+ 
  ggtitle(paste0("high", "-rcp85","-SSP3", "-fulluncertainty ", model)) 
  # print(paste0(output, "/mc/fig", "_SSP3_fulluncertainty_time_series_gdp.pdf"))
  ggsave(paste0(output, "/mc/diagnostics/fig", "_SSP3_climate_uncertainty_time_series_pop_median_", model, ".pdf"), p)
  return(p)
}

output = DIR_FIG
p = plot_ts_fig_2C(output = output, DB_data = DB_data, model = "surrogate_GFDL-CM3_99")

