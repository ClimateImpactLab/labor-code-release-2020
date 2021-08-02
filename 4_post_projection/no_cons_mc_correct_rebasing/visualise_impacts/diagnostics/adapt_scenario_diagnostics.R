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

# DB_data = paste0(DB, "/code_release_data_pixel_interaction")
# root =  "/home/liruixue/repos/energy-code-release-2020"
# output = paste0(root, "/figures")

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
    # df= read_csv(glue('{ROOT_INT_DATA}/projection_outputs/extracted_data_mc_correct_rebasing_for_integration/{ssp}-{rcp}_{iam}_{risk}_{adapt}{aggregation}{suffix}_{region}_timeseries.csv'))
    df= read_csv(glue('{DB_data}/projection_outputs/extracted_data_mc_correct_rebasing_for_integration/SSP3-{rcp}_high_allrisk_{adapt}-pop-aggregated_global_timeseries.csv'))
    # df = read_csv(paste0(DB_data,   
    #                '/projection_system_outputs/time_series_data/', 
    #                'main_model-', fuel, '-SSP3-',rcp, '-high-',adapt,'-impact_pc.csv')
    #                      ) 
    df = df %>% mutate(rcp = rcp, adapt_scen = adapt) %>% filter(year <= 2099)
    return(df)
  }
  # browser()

  # d = load_df("rcp45","fulladapt")
  # d = load_df("rcp85","incadapt")

  # print(d, n = 120)
  options = expand.grid(rcp = c( "rcp85"), 
                        adapt = c("fulladapt", "incadapt", "noadapt"))
  df = mapply(load_df, rcp = options$rcp, adapt = options$adapt, 
            SIMPLIFY = FALSE) %>% 
    bind_rows()

  # browser()
  # Subset and format for plotting

  bp_full = df %>%
    dplyr::filter(rcp == "rcp85", adapt_scen == "fulladapt") %>%
    get.boxplot.vect(yr = 2099)
  
  bp_inc = df %>%
    dplyr::filter(rcp == "rcp85", adapt_scen == "incadapt") %>%
    get.boxplot.vect(yr = 2099 )

  bp_no = df %>%
    dplyr::filter(rcp == "rcp85", adapt_scen == "noadapt") %>%
    get.boxplot.vect(yr = 2099 )

  
  u_full = df %>% 
    dplyr::filter(rcp == "rcp85", adapt_scen == "fulladapt") %>% 
    dplyr::select(year, q10, q90) %>%
    rename(q10_full = q10, 
           q90_full = q90)
  u_inc = df %>% 
    dplyr::filter(rcp == "rcp85", adapt_scen == "incadapt") %>% 
    dplyr::select(year, q10, q90) %>%
    rename(q10_inc = q10, 
           q90_inc = q90)
  u_no = df %>% 
    dplyr::filter(rcp == "rcp85", adapt_scen == "noadapt") %>% 
    dplyr::select(year, q10, q90) %>%
    rename(q10_no = q10, 
           q90_no = q90)
  

  
  df.u = left_join(u_full, u_inc, by = "year")
  df.u = left_join(df.u, u_no, by = "year")

  
  return(
      list(
        df_45 = df[df$rcp == "rcp45" & df$adapt_scen == "fulladapt",], 
        df_85 = df[df$rcp == "rcp85" & df$adapt_scen == "fulladapt",], 
        df_45.na = df[df$rcp == "rcp45" & df$adapt_scen == "noadapt",], 
        df_85.na = df[df$rcp == "rcp85" & df$adapt_scen == "noadapt",], 
        df_45.ia = df[df$rcp == "rcp45" & df$adapt_scen == "incadapt",], 
        df_85.ia = df[df$rcp == "rcp85" & df$adapt_scen == "incadapt",], 
        df.u = df.u,
        bp_full = bp_full, 
        bp_inc = bp_inc,
        bp_no = bp_no
        )
    )
}

# Plotting function, for replicating Figure 2C. Note - coloring in the paper requires 
# post processing in illustrator 

plot_ts_fig_2C = function(output, DB_data){
  
  plot_df = get_df_list_fig_2C(DB_data = DB_data) 
  # browser()
  
  p <- ggtimeseries(
    df.list = list(plot_df$df_85[,c('year', 'mean')] %>% as.data.frame() , 
                   plot_df$df_85.ia[,c('year', 'mean')]%>% as.data.frame()
                   # ,
                   # plot_df$df_85.na[,c('year', 'mean')]%>% as.data.frame()
                   ), # mean lines
    df.u = plot_df$df.u %>% as.data.frame(), 
    ub = "q90_full", lb = "q10_full", #uncertainty - first layer
    ub.2 = "q90_inc", lb.2 = "q10_inc", #uncertainty - second layer
    # ub.3 = "q90_no", lb.3 = "q10_no", #uncertainty - second layer
    uncertainty.color = "red", 
    uncertainty.color.2 = "blue",
    # uncertainty.color.3 = "green",
    df.box = plot_df$bp_full, 
    df.box.2 = plot_df$bp_inc,
    # df.box.3 = plot_df$bp_no,
    x.limits = c(2010, 2099),
    y.label = 'Impacts: min lost per person',
    legend.values = c("red", "black"), #color of mean line
    legend.breaks = c("RCP85 Full Adapt", "RCP85 Inc Adapt"),
    rcp.value = 'rcp85', ssp.value = 'SSP3', iam.value = 'high-fulluncertainty')+ 
  ggtitle(paste0("high", "-rcp85","-SSP3", "-fulluncertainty MC")) 
  # print(paste0(output, "/mc/fig", "_SSP3_fulluncertainty_time_series_gdp.pdf"))
  ggsave(paste0(output, "/mc/diagnostics/fig", "_SSP3_full_uncertainty_time_series_pop_mc.pdf"), p)
  return(p)
}

output = DIR_FIG
p = plot_ts_fig_2C(output = output, DB_data = DB_data)




