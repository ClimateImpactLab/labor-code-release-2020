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
#'  Outline:
#'    - Pull in functions for each plot type
#'    - Will need 1 impact map func, 1 kernel desnity func, 1 decile func, 3 TS funcs
#'    - One run function for each plot type
#'    - One call for each of the above
#'   
#' How To Run:
#'   - The toggles below control which portions of the analysis are run.
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

source("/project/cil/home_dirs/nishkasharma/repos/labor-code-release-2020/0_subroutines/paths.R")
# Source labor utils/functions.
Rfiles = Sys.glob(glue("{DIR_REPO_LABOR}", "/4_post_projection/0_utils/*.R"))
Rfiles = Rfiles[!mapply(x=Rfiles, grepl, MoreArgs=list(pattern='load_utils'))]
null = lapply(Rfiles, source)

# TOGGLES
Part1 = TRUE # Impact Map
Part2 = TRUE # Decile Plot
Part3 = FALSE # Time Series
Appendix = TRUE # Appendix F, G figures.

# RCP scenario ('rcp85', 'rcp45')
rcp='rcp85' 

# Economic modeling scenario:
#  'low': "IIASA GDP"
#  'high': "OECD Econ Growth"
iam='high'

# SSP ('SSP2', 'SSP3', 'SSP4')
ssp='SSP3'

# input path to single/median/mc
input_path = "/project/cil/gcp/outputs/labor/impacts-woodwork/median/extracted"

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
                  rcp="rcp85",
                  ssp="SSP3",
                  iam="high", 
                  adapt="fulladapt",
                  impact="rebased",
                  aggregation="-gdp-levels", 
                  year=2099,
                  output.folder = glue("{DIR_FIG}/median/maps"))
  
  # Regions - Lagos, Delhi, Beijing, Sao Paulo, Chicago, Oslo
  regions = c("NGA.25.510", "IND.10.121.371", "CHN.2.18.78", 
              "BRA.25.5212.R3fd4ed07b36dfd9c", "USA.14.608", "NOR.12.288")
  
  # IR density plots without accounting for adaptation costs (Figure 7)
  impacts.density.plot(model.name = "uninteracted_main_model_agnonag_27_28_41", 
                       ssp="SSP3", 
                       rcp="rcp85", 
                       iam="high", 
                       impact="rebased", 
                       adapt="fulladapt", 
                       aggregation="-gdp-levels", 
                       regions=regions, 
                       year=2099, 
                       output.folder = glue("{DIR_FIG}/median/density_plots"))
  
}

# Part 2: Future disutility costs are correlated with present-day income and 
# climate.

if (Part2) {
  
  lapply(c("loggdppc", "climtas"), function(covar) {
    deciles.plot(model.name = "uninteracted_main_model_agnonag_27_28_41", 
                 ssp = "SSP3", 
                 iam = "high", 
                 rcp = "rcp85", 
                 adapt = "fulladapt", 
                 aggregation = "-gdp-levels", 
                 covar = covar,
                 output.dir = glue("{DIR_FIG}/median"))
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
  
  # Time series comparison of adaptation scenarios without accounting for adaptation costs (Figure 8 Panel A)
  timeseries_compare_adaptation(rcp=rcp, iam=iam, ssp=ssp, with_costs=FALSE)
  
  # Time series with uncertainty and comparison of RCPs without accounting for adaptation costs (Figure 8 Panel B)
  timeseries_compare_rcp(rcp=rcp, iam=iam, ssp=ssp, with_costs=FALSE)
  
  # To account for adaptation costs, pass with_costs=TRUE. 
}


if (Appendix) {
  
  # Appendix time series all account for adaptation costs.
  
  # Figure F.1 A, B, C, D: Projected impact in labor supply and disutility costs 
  # by RCPs
  plot.impact.map(model.name = "uninteracted_main_model_agnonag_27_28_41",
                  rcp="rcp85",
                  ssp="SSP3",
                  iam="high", 
                  adapt="fulladapt",
                  impact="rebased",
                  aggregation="", 
                  year=2099,
                  output.folder = glue("{DIR_FIG}/median/maps"))
  
  plot.impact.map(model.name = "uninteracted_main_model_agnonag_27_28_41",
                  rcp="rcp45",
                  ssp="SSP3",
                  iam="high", 
                  adapt="fulladapt",
                  impact="rebased",
                  aggregation="", 
                  year=2099,
                  output.folder = glue("{DIR_FIG}/median/maps"))
  
  plot.impact.map(model.name = "uninteracted_main_model_agnonag_27_28_41",
                  rcp="rcp45",
                  ssp="SSP3",
                  iam="high", 
                  adapt="fulladapt",
                  impact="rebased",
                  aggregation="-gdp-levels", 
                  year=2099,
                  output.folder = glue("{DIR_FIG}/median/maps"))
  
  # Figure G.2 A, B: Projected disutility costs by RCPs under the benefits of   
  # income growth and adaptation while additionally accounting for the 
  # temperature sensitivity of high-risk labor supply
  timeseries_compare_age_groups()
  
}

