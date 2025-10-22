# Mins. time series (full, income, and no adapt)
# %GDP time series (full, income, and no adapt)

rm(list = ls())
source("/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/0_subroutines/paths.R")
source("/project/cil/home_dirs/maiqi/repos/post-projection-tools/mapping/imgcat.R") #this redefines the way ggplot plots. 
library(glue)
library(parallel)
# Load in the required packages, installing them if necessary 
if(!require("pacman")){install.packages(("pacman"))}
pacman::p_load(ggplot2, 
               dplyr,
               readr, 
               DescTools,
               RColorBrewer)

source(glue("{DIR_REPO_LABOR}/4_post_projection/0_utils/time_series.R"))
# source(glue("~/repos/post-projection-tools/timeseries/ggtimeseries.R"))

# output_folder_mc = paste0(DIR_FIG, "/mc/")

# time series of popweighted impacts
plot_impact_timeseries = function(rcp, ssp, iam, adapt, risk, region, aggregation="", suffix="", output_folder = glue("{DIR_FIG}/fig8")){
  
  # browser()
  if ((ssp=="SSP1" & rcp=="rcp85") | (ssp=="SSP5" & rcp=="rcp45")) {
    print("invalid combination of ssp and rcp")
    return()
  }
  df= read_csv(glue('/project/cil/gcp/outputs/labor/impacts-woodwork/montecarlo/timeseries/{ssp}-{rcp}_{iam}_{risk}_{adapt}{aggregation}{suffix}_{region}_timeseries.csv'))

  if (aggregation == "-pop-aggregated") {
    plot_title <- "Pop Weighted Impacts - Mins Worked"
  } else if (aggregation == "-gdp-aggregated") {
    plot_title <- "Impacts as Fraction of GDP"
  } else if (aggregation == "-wage-aggregated") {
    plot_title <- "Impacts in Dollars"
  } else {
    print("wrong aggregation!")
    return()
  }
  # browser()
  
  df <- df |>
    dplyr::filter(is.na(region) | region %in% c("", 0, "0")) |>
    dplyr::mutate(mean = as.numeric(mean) * -100)
  
  if (nrow(df) == 0L) {
    message("No rows with region missing/0; skipping plot.")
    return(invisible(NULL))
  }
  
  p <- ggtimeseries(
    df.list = list(df[,c('year', 'mean')] %>% as.data.frame()), # 改为mean
    x.limits = c(2010, 2098),
    y.label = 'mins worked',
    rcp.value = rcp, ssp.value = ssp, end.yr = 2100,
    legend.breaks = adapt) + 
    ggtitle(plot_title)

  # browser()
  ggsave(glue("{output_folder}/{ssp}-{rcp}_{iam}_{risk}_{adapt}{aggregation}{suffix}_{region}_timeseries.pdf"), p)
  print(glue("{output_folder}/{ssp}-{rcp}_{iam}_{risk}_{adapt}{aggregation}{suffix}_{region}_timeseries.pdf saved"))

}



# args = expand.grid(rcp=c("rcp85"),
#                        ssp=c("SSP3"),
#                        iam=c("low"),
#                        adapt=c("fulladapt","noadapt","incadapt"),
#                        aggregation =c("-gdp-aggregated"),
#                        risk=c("rebased")
#                        )
# 
# 
# mcmapply(plot_impact_timeseries,
#   rcp=args$rcp,
#   ssp=args$ssp,
#   iam=args$iam,
#   risk=args$risk,
#   adapt=args$adapt,
#   aggregation=args$aggregation,
#   region="global",
#   output_folder = glue("{DIR_FIG}/fig8/"),
#   mc.cores = 50)


# args = expand.grid(rcp=c("rcp85","rcp45"),
#                        ssp=c("SSP1","SSP2","SSP3","SSP4","SSP5"),
#                        iam=c("high","low"),
#                        adapt=c("fulladapt","histclim"),
#                        aggregation =c("-gdp-aggregated","-wage-aggregated"),
#                        risk=c("highrisk","lowrisk","allrisk","riskshare")
#                        )

# mcmapply(plot_impact_timeseries, 
#   rcp=args$rcp, 
#   ssp=args$ssp, 
#   iam=args$iam,
#   risk=args$risk, 
#   adapt=args$adapt,
#   aggregation=args$aggregation,
#   region="global",
#   output_folder = glue("{DIR_FIG}/all_timeseries/"),
#   mc.cores = 50)


# plot only those we need
# plot_impact_timeseries(rcp="rcp85",ssp="SSP3",iam="low",
#   adapt="fulladapt",risk="rebased",region="global",aggregation = "-gdp-aggregated")

# plot_impact_timeseries(rcp="rcp45",ssp="SSP3",iam="high",
#   adapt="incadapt",risk="allrisk",region="global",aggregation = "-gdp-aggregated")


plot_multiple_adapt_timeseries = function(rcp, ssp, iam, risk, region, aggregation="", suffix="", adapt_list=c("fulladapt","noadapt","incadapt"), output_folder = glue("{DIR_FIG}/fig8/")){
  
  df_list = list()
  for(adapt in adapt_list) {
    df_temp = read_csv(glue('/project/cil/gcp/outputs/labor/impacts-woodwork/montecarlo/timeseries/{ssp}-{rcp}_{iam}_{risk}_{adapt}{aggregation}{suffix}_{region}_timeseries.csv'))
    df_temp <- df_temp %>%
      dplyr::filter(is.na(region) | region %in% c("", 0, "0")) |>
      dplyr::mutate(value = as.numeric(mean) * -100, 
                    adapt_scenario = adapt)
    df_list[[adapt]] = df_temp
  }
  
  df_combined = bind_rows(df_list)
  

  if (aggregation == "-gdp-aggregated") {
    plot_title <- "Worker disutility costs of climate change (RCP85, mean)"
  } else if (aggregation == "-gdp-aggregated") {
    plot_title <- "Impacts as Fraction of GDP"
  } else if (aggregation == "-wage-aggregated") {
    plot_title <- "Impacts in Dollars"
  }
  

  p <- ggplot(df_combined, aes(x = year, y = value, color = adapt_scenario)) +
    geom_line(size = 1) +
    labs(x = "Year", y = "Impact", 
         title = plot_title,
         color = "Adaptation Scenario") +
    theme_minimal() +
    xlim(2010, 2098)

  filename = glue("{output_folder}/{ssp}-{rcp}_{iam}_{risk}_multi-adapt{aggregation}{suffix}_{region}_global_timeseries.pdf")
  ggsave(filename, p, width = 10, height = 6)
  print(glue("{filename} saved"))
}

plot_multiple_adapt_timeseries(
  rcp="rcp85", 
  ssp="SSP3", 
  iam="low", 
  risk="rebased", 
  region="global", 
  aggregation="-gdp-aggregated",
  adapt_list=c("fulladapt","noadapt","incadapt")
)