#========================================================================================#
#' Labor Uninteracted Model Post-projection Figures
#'
#' Author: Elliot Grenier (egrenier@uchicago.edu)
#' Date Created: June 6 2025
#' Last Modified: June 6 2025
#'
#' Produces:
#'   - Figure 6A | Impact Map (Minutes/worker/day, rcp85/high/SSP3, 2099)
#'   - Figure 6B | Impact Map (% GDP, rcp85/high/SSP3, 2099)
#'   - Figure 7 | Decile Plots (% GDP, rcp85/high/SSP3, 2099, income deciles + temp deciles)
#'   - Figure 8A | Time Series (% GDP, rcp85/high/SSP3, 2000-2099)
#'   - Figure 8B | Time Series w/ CI (% GDP, rcp85/high/SSP3, 2000-2099)
#'   - Appendix F.1C | Impact Map (Minutes/worker/day, rcp45/high/SSP3, 2099)
#'   - Appendix F.1D | Impact Map (% GDP, rcp45/high/SSP3, 2099)
#'   - Figure G.2A | Time Series w/ multicolor CI (% GDP, rcp85/high/SSP3, 2000-2099)
#'   - Figure G.2B | Time Series w/ multicolor CI (% GDP, rcp45/high/SSP3, 2000-2099)
#'   
#'  Outline:
#'    - Pull in functions for each plot type
#'    - Will need 1 impact map func, 1 decile func, 3 TS funcs
#'    - One run function foe each plot type
#'    - One call for each of the above
#'   
#' How To Run:
#'   - TBD
#=========================================================================================#