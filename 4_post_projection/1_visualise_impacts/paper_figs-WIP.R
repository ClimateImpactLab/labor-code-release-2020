#========================================================================================#
#' Labor Uninteracted Model Post-projection Figures
#'
#' Latest Edits By: Nishka Sharma; Created By: Elliot Grenier 
#' Date Created: June 6 2025
#' Last Modified: Feb 23 2026
#'
#' Produces:
#'   - Figure 6A | Impact Map (Minutes/worker/day, rcp85/high/SSP3, 2099)
#'   - Figure 6B | Impact Map (% GDP, rcp85/high/SSP3, 2099)
#'   - Figure 7 | Decile Plots (% GDP, rcp85/high/SSP3, 2099, income deciles + temp deciles)
#'   - Figure 8A | Time Series (% GDP, rcp85/high/SSP3, 2000-2099)
#'   - Figure 8B | Time Series w/ CI (% GDP, rcp85/high/SSP3, 2000-2099)
#'   - Appendix F.1A | Impact Map (Minutes/worker/day, rcp85/high/SSP3, 2099)
#'   - Appendix F.1B | Impact Map (% GDP, rcp85/high/SSP3, 2099)
#'   - Appendix F.1C | Impact Map (Minutes/worker/day, rcp45/high/SSP3, 2099)
#'   - Appendix F.1D | Impact Map (% GDP, rcp45/high/SSP3, 2099)
#'   - Figure G.2A | Time Series w/ multicolor CI (% GDP, rcp85/high/SSP3, 2000-2099)
#'   - Figure G.2B | Time Series w/ multicolor CI (% GDP, rcp45/high/SSP3, 2000-2099)
#'   
#' How To Run:
#'   - Items under "change this section to customise plots" control what is plotted 
#=========================================================================================#

#==============================================================================#
packages = c("ggplot2", "dplyr", "magrittr", "readr", "RColorBrewer", 
             "glue", "scales", "parallel", "sf", "raster", "rnaturalearth")

message(" ---- loading packages ---- ")
invisible(lapply(packages, function(pkg) {
  suppressPackageStartupMessages(library(pkg, character.only = TRUE))
}))

rm(packages)

#==============================================================================#
# get user and source paths
USER = Sys.getenv("USER")
source(glue("/project/cil/home_dirs/{USER}/repos/labor-code-release-2020/0_subroutines/paths.R"))

# source labor utils/functions.
Rfiles = Sys.glob(glue("{DIR_REPO_LABOR}", "/4_post_projection/0_utils/*.R"))
Rfiles = Rfiles[!mapply(x=Rfiles, grepl, MoreArgs=list(pattern='load_utils'))]
null = lapply(Rfiles, source)

#==================change this section to customise plots======================#
# toggles
Part1 = TRUE # Impact Map
Part2 = TRUE # Decile Plot
Part3 = TRUE # Time Series
Appendix = TRUE # Appendix F, G figures.

# RCP scenario ('rcp85', 'rcp45')
rcp_in = 'rcp85' 

# Economic modeling scenario
#   'low': "IIASA GDP"
#  'high': "OECD Econ Growth"
iam_in = 'high'

# SSP ('SSP2', 'SSP3', 'SSP4')
ssp_in = 'SSP3'

# impact
# 'rebased': minutes worked 
#   'clip' : share of high risk workers
impact_in = 'rebased'

# adaptation scenario ('fulladapt', 'incadapt', 'noadapt')
adapt_in = 'fulladapt'

# input path to single/median/mc
input_path = "/project/cil/gcp/outputs/labor/impacts-woodwork/montecarlo/extracted"

#==============================================================================#
# Part 1: End of century mortality risk of climate change maps and density
# plots.
# 
# This section generates the following plots in Carleton et al. (2019):
# 
#   - Impact map (Figure 6A): Impact-region level map showing the change in mins 
#     per worker per day in 2099. Impacts represent the mean across Monte Carlo
#     simulations conducted on 33 climate models. 
# 
#   - Impact map (Figure 6B): Impact-region level map showing the corresponding 
#     total annual labor disutility costs for each impact in 2099. Impacts 
#     represent the mean across Monte Carlo simulations conducted on 33 climate 
#     models. 
# 
#   - IR density plots (Figure 6B): Full distribution of estimated impacts across
#     GCMs and Monte Carlo draws. Solid lines indiciate mean estimate with shading
#     at one, two, and three standard deviations from the mean.

if (Part1) {
  
  plot.impact.map(model.name = "uninteracted_main_model_agnonag_27_28_41",
                  rcp=rcp_in,
                  ssp=ssp_in,
                  iam=iam_in, 
                  adapt=adapt_in,
                  impact=impact_in,
                  aggregation="-gdp-levels", 
                  year=2099,
                  output.folder = glue("{DIR_FIG}/mc/maps"))
  
  # Regions - Lagos, Delhi, Beijing, Sao Paulo, Chicago, Oslo
  regions_right = c("NGA.25.510", "IND.10.121.371", "CHN.2.18.78")
  # IR density plots without accounting for adaptation costs (Figure 7)
  impacts.density.plot(model.name = "uninteracted_main_model_agnonag_27_28_41",
                       ssp=ssp_in,
                       rcp=rcp_in,
                       iam=iam_in,
                       impact=impact_in,
                       adapt=adapt_in,
                       aggregation="-gdp-levels",
                       regions=regions_right,
                       year=2099,
                       left.panel=FALSE,
                       output.folder = glue("{DIR_FIG}/mc/density_plots"))
  
  regions_left =  c("BRA.25.5212.R3fd4ed07b36dfd9c", "USA.14.608", "NOR.12.288")
  # IR density plots without accounting for adaptation costs (Figure 7)
  impacts.density.plot(model.name = "uninteracted_main_model_agnonag_27_28_41",
                       ssp=ssp_in,
                       rcp=rcp_in,
                       iam=iam_in,
                       impact=impact_in,
                       adapt=adapt_in,
                       aggregation="-gdp-levels",
                       regions=regions_left,
                       year=2099,
                       left.panel=TRUE,
                       output.folder = glue("{DIR_FIG}/mc/density_plots"))
  
}

# Part 2: Future disutility costs are correlated with present-day income and 
# climate.

if (Part2) {
  
  lapply(c("loggdppc", "climtas"), function(covar) {
    deciles.plot(model.name = "uninteracted_main_model_agnonag_27_28_41", 
                 ssp = ssp_in, 
                 iam = iam_in, 
                 rcp = rcp_in, 
                 adapt = adapt_in, 
                 aggregation = "-gdp-levels", 
                 covar = covar,
                 output.dir = glue("{DIR_FIG}/mc"))
  })
  
}


# Part 3: Time series of projected disutility cost of climate change.
# 
#   - Time series (Figure 8A): Comparison of disutility costs under different 
#     adaptation scenarios - without adaptation, with only the benefits of 
#     income growth, with the benefits of income growth and adaptation.
# 
#   - Time series (Figure 8B): Comparison of disutility costs with the benefits 
#     of income growth and adaptation under RCP4.5 and RCP8.5. Includes the  
#     10th-90th percentile range of the Monte Carlo simulations. Boxplots show 
#     the distribution of impacts at end of century for both RCPs.

if (Part3) {
  
  # Time series comparison of adaptation scenarios (Figure 8 Panel A)
  plot.ts(model.name = "uninteracted_main_model_agnonag_27_28_41",
          rcp = rcp_in,
          ssp=ssp_in,
          iam=iam_in,
          impact=impact_in,
          aggregation="-gdp-aggregated",
          color_var = "adapt_scen",
          ir = "global",
          x_title = "Year",
          labs_color = "Worker disutility costs of climate change",
          output.folder = glue("{DIR_FIG}/mc/timeseries")
  )
  
  # Time series with uncertainty and comparison of RCPs (Figure 8 Panel B)
  plot.ts.ci.rcp(model.name = "uninteracted_main_model_agnonag_27_28_41",
                 ssp = ssp_in,
                 iam = iam_in,
                 adapt = adapt_in,
                 impact = impact_in,
                 aggregation = "-gdp-aggregated",
                 fill_var = "rcp",
                 linetype_var = "rcp",
                 ir = "global",
                 x_title = "Year",
                 labs_linetype = "Worker disutility costs of climate change, \nwith changing workforce composition due to \neconomic development and climate adaptation",
                 boxplot = TRUE,
                 yr = 2099,
                 output.folder = glue("{DIR_FIG}/mc/timeseries")
  )
  
}


if (Appendix) {
  
  # Appendix time series all account for adaptation costs.
  
  # Figure F.1 A, B, C, D: Projected impact in labor supply and disutility costs 
  # by RCPs
  plot.impact.map(model.name = "uninteracted_main_model_agnonag_27_28_41",
                  rcp=rcp_in,
                  ssp=ssp_in,
                  iam=iam_in, 
                  adapt=adapt_in,
                  impact=impact_in,
                  aggregation="", 
                  year=2099,
                  output.folder = glue("{DIR_FIG}/mc/maps"))
  
  plot.impact.map(model.name = "uninteracted_main_model_agnonag_27_28_41",
                  rcp="rcp45",
                  ssp=ssp_in,
                  iam=iam_in, 
                  adapt=adapt_in,
                  impact=impact_in,
                  aggregation="", 
                  year=2099,
                  output.folder = glue("{DIR_FIG}/mc/maps"))
  
  plot.impact.map(model.name = "uninteracted_main_model_agnonag_27_28_41",
                  rcp="rcp45",
                  ssp=ssp_in,
                  iam=iam_in, 
                  adapt=adapt_in,
                  impact=impact_in,
                  aggregation="-gdp-levels", 
                  year=2099,
                  output.folder = glue("{DIR_FIG}/mc/maps"))
  
  # Figure G.2 A, B: Projected disutility costs by RCPs under the benefits of
  # income growth and adaptation while additionally accounting for the
  # temperature sensitivity of high-risk labor supply
  plot.ts.ci.model(model.name = "uninteracted_main_model_agnonag_27_28_41",
                   ssp = ssp_in,
                   iam = iam_in,
                   adapt = adapt_in,
                   impact = impact_in,
                   aggregation = "-gdp-aggregated",
                   fill_var = "adapt_scen",
                   color_var = "adapt_scen",
                   ir = "global",
                   x_title = "Year",
                   labs_color = "Worker disutility costs of climate change",
                   output.folder = glue("{DIR_FIG}/mc/timeseries")
  )
}

