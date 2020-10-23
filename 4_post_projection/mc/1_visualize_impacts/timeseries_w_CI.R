# %GDP full-adapt impacts time series RCP8.5 and RCP4.5 
# (5-95, 25-75 percentiles, and end-of-century box and whiskers plots with these intervals, 
# whiskers extending to full range) (energy fig_2C)

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
DB = "/mnt/CIL_energy"

DB_data = paste0(DB, "/code_release_data_pixel_interaction")
root =  "/home/liruixue/repos/energy-code-release-2020"
output = paste0(root, "/figures")

# Source time series plotting codes
source(glue("{DIR_REPO_LABOR}/4_post_projection/0_utils/time_series.R"))

#########################################
# 1. Figure 2C
# There are three functions needed for replicating this figure
    # "get.boxplot.vect" takes in a dataframe, and returns a vector of quantiles
    # "get_df_list_fig_2C" loads in the impacts projected data, and returns a formatted list of 
        # lines for plotting
    # "plot_ts_fig_2C" uses the above two functions, and the "time_series.R" code to 
        # replicate figure 2C

# Function for formatting a vector of the distribution of the data for a given year, for use in the box plots.
get.boxplot.vect <- function(df = NULL, yr = 2099) {
  boxplot <- c(as.numeric(df[df$year==yr,'q5']), 
               as.numeric(df[df$year==yr,'q10']),
               as.numeric(df[df$year==yr,'q25']),
               as.numeric(df[df$year==yr,'mean']),
               as.numeric(df[df$year==yr,'q75']),
               as.numeric(df[df$year==yr,'q90']),
               as.numeric(df[df$year==yr,'q95']))
  return(boxplot)
}

# Function that takes in the long data, subsets it and returns a list of dataframes 
# and vectors needed to plot the time series for a given fuel
get_df_list_fig_2C = function(DB_data){
  
  # Load in the impacts data: 
  load_df = function(rcp, adapt){
    print(rcp)
    df= read_csv(glue('{DB_data}/projection_outputs/extracted_data_mc/SSP3-{rcp}_high_allrisk_{adapt}-gdp-aggregated_global_timeseries.csv'))
    # df = read_csv(paste0(DB_data,   
    #                '/projection_system_outputs/time_series_data/', 
    #                'main_model-', fuel, '-SSP3-',rcp, '-high-',adapt,'-impact_pc.csv')
    #                      ) 
    return(df)
  }
  options = expand.grid(rcp = c("rcp45", "rcp85"), 
                        adapt = c("fulladapt", "noadapt"))
  df = mapply(load_df, rcp = options$rcp, adapt = options$adapt, 
              MoreArgs = list(fuel = fuel), SIMPLIFY = FALSE) %>% 
    bind_rows()

  # Subset and format for plotting

  bp_45 = df %>%
    dplyr::filter(rcp == "rcp45", adapt_scen == "fulladapt") %>%
    get.boxplot.vect(yr = 2099)
  
  bp_85 = df %>%
    dplyr::filter(rcp == "rcp85", adapt_scen == "fulladapt") %>%
    get.boxplot.vect(yr = 2099 )
  
  u_85 = df %>% 
    dplyr::filter(rcp == "rcp85", adapt_scen == "fulladapt") %>% 
    dplyr::select(year, q10, q90) %>%
    rename(q10_85 = q10, 
           q90_85 = q90)
  
  u_45 = df %>% 
    dplyr::filter(rcp == "rcp45", adapt_scen == "fulladapt") %>% 
    dplyr::select(year, q10, q90) %>%
    rename(q10_45 = q10, 
           q90_45 = q90)
  
  df.u = left_join(u_85, u_45, by = "year")
  
  return(
      list(
        df_45 = df[df$rcp == "rcp45" & df$adapt_scen == "fulladapt",], 
        df_85 = df[df$rcp == "rcp85" & df$adapt_scen == "fulladapt",], 
        df_45.na = df[df$rcp == "rcp45" & df$adapt_scen == "noadapt",], 
        df_85.na = df[df$rcp == "rcp85" & df$adapt_scen == "noadapt",], 
        df.u = df.u,
        bp_45 = bp_45, 
        bp_85 = bp_85
        )
    )
}

# Plotting function, for replicating Figure 2C. Note - coloring in the paper requires 
# post processing in illustrator 

plot_ts_fig_2C = function(output, DB_data){
  
  plot_df = get_df_list_fig_2C(DB_data = DB_data)
  
  p <- ggtimeseries(
    df.list = list(plot_df$df_85[,c('year', 'mean')] %>% as.data.frame() , 
                   plot_df$df_85.na[,c('year', 'mean')]%>% as.data.frame(),
                   plot_df$df_45[,c('year', 'mean')]%>% as.data.frame(),
                   plot_df$df_45.na[,c('year', 'mean')]%>% as.data.frame()), # mean lines
    df.u = plot_df$df.u %>% as.data.frame(), 
    ub = "q90_85", lb = "q10_85", #uncertainty - first layer
    ub.2 = "q90_45", lb.2 = "q10_45", #uncertainty - second layer
    uncertainty.color = "red", 
    uncertainty.color.2 = "blue",
    df.box = plot_df$bp_85, 
    df.box.2 = plot_df$bp_45,
    x.limits = c(2010, 2099),
    y.label = 'Hot and cold impacts: change in GJ/pc',
    legend.values = c("red", "black", "blue", "orange"), #color of mean line
    legend.breaks = c("RCP85 Full Adapt", "RCP85 No Adapt", 
                      "RCP45 Full Adapt", "RCP45 No Adapt"),
    rcp.value = 'rcp85', ssp.value = 'SSP3', iam.value = 'high-fulluncertainty')+ 
  ggtitle(paste0("high", "-rcp85","-SSP3", "-fulluncertainty")) 
  ggsave(paste0(output, "/fig", "_SSP3_fulluncertainty_time_series.pdf"), p)
  return(p)
}

p = plot_ts_fig_2C(output = output, DB_data = DB_data)

