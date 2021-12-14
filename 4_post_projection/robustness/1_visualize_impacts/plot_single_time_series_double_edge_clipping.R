rm(list = ls())
source("~/repos/labor-code-release-2020/0_subroutines/paths.R")
library(glue)
library(parallel)

##############
# FUNCTION
##############

# Load in the required packages, installing them if necessary 
if(!require("pacman")){install.packages(("pacman"))}
pacman::p_load(ggplot2, 
               dplyr,
               readr, 
               DescTools,
               RColorBrewer)

source(glue("{DIR_REPO_LABOR}/4_post_projection/0_utils/time_series.R"))

# time series of aggregationed impacts
plot_impact_timeseries = function(IR='globe', folder, name, output, rcp, ssp, aggregation, varname){
  # browser()

  if (aggregation == "") {
    print("wrong spec")
  } else {
    file = glue('{folder}/{name}-{varname}-{aggregation}-aggregated.csv')
    title = glue("{varname}, {aggregation} weighted aggregated impacts \n ({ssp}, {rcp}, IR = {IR})")
    y_label = glue("{aggregation}-aggregated mins worked")
  }

  df = read_csv(file)
  
  if(IR == "globe"){
    df_plot = df %>% dplyr::filter(is.na(region)) %>% dplyr::filter(year != 2100) # drop 2100 because it's missing or wonk sometimes
  } else {
    df_plot = df %>% dplyr::filter(region == IR) %>% dplyr::filter(year != 2100)
  }

  p <- ggtimeseries(
    df.list = list(df_plot[,c('year', 'value')] %>% as.data.frame()), # mean lines
    x.limits = c(2011, 2099),
    y.label = y_label,
    rcp.value = rcp, ssp.value = ssp) + 
  ggtitle(title)

  dir.create(glue("{DIR_FIG}/{output}"), recursive=TRUE)
  ggsave(glue("{DIR_FIG}/{output}/timeseries-{name}-{varname}-{aggregation}-{rcp}-{ssp}.pdf"), p)

}

######################
# MAIN MODEL - CLIPPING LR TEMP
######################

# change input folder path here
folder = glue('/mnt/battuta_shares/gcp/outputs/labor/impacts-woodwork/double_edge_restriction_single/median/rcp85/CCSM4/high/SSP3/csv')

#change output folder name here
output = 'double_edge_restriction_single'

###########
# RUN IT
###########


ts_args = expand.grid(IR = "globe",
                       folder= folder,
                       name=c("clip_lrt_edge_restriction","clip_lrt_edge_restriction-incadapt","clip_lrt_edge_restriction-noadapt"),
                       output=output,
                       rcp="rcp85",
                       ssp="SSP3",
                       varname=c( "highriskimpacts","rebased", "lowriskimpacts"),
                       aggregation = c("pop", "gdp", "wage") 
                       )
# testing code:
# plot_impact_timeseries("globe",folder, "clip-noadapt", output, "rcp85", "SSP3", "pop", "rebased_new")

print(ts_args)

mcmapply(plot_impact_timeseries,
         IR = ts_args$IR,
         folder= ts_args$folder,
         name=ts_args$name,
         output=output,
         ssp=ts_args$ssp,
         rcp=ts_args$rcp,
         aggregation=ts_args$aggregation,
         varname=ts_args$varname,
         mc.cores=20
        )
