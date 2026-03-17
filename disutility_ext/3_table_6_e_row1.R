#==============================================================================#
#'
#' This script calculates the global average hedonic value of a temperature-
#' controlled workplace as a percentage of annual income. For each impact
#' region, we compute the monetized disutility difference between high-risk
#' (HR) and low-risk (LR) workers when exposed to actual vs. optimal
#' temperatures, using group-specific Frisch elasticities. Standard errors
#' are derived via the delta method, propagating uncertainty from the
#' regression coefficient variance-covariance matrix. The global statistic
#' is a population-weighted mean across all impact regions, with a
#' population-weighted 5th–95th percentile interval reported alongside.
#'
#' Main export: run_hedonic(frisch_HR, frisch_LR)
#'   Returns a list with: mean, p5, p95
#'
#==============================================================================#

#==============================================================================#
# 0. Packages and paths ----
#==============================================================================#

packages <- c("data.table", "tidyverse", "Hmisc", "glue")
invisible(lapply(packages, function(pkg) {
  suppressPackageStartupMessages(library(pkg, character.only = TRUE))
}))
rm(packages)

USER <- Sys.getenv("USER")
source(glue('/project/cil/home_dirs/{USER}/repos/labor-code-release-2020/0_subroutines/paths.R'))

#==============================================================================#
# 1. Main function ----
#==============================================================================#

run_hedonic <- function(frisch_HR, frisch_LR) {
  
  # --- Load climate data --- #
  dfa <- fread("/project/cil/gcp/climate/_spatial_data/impactregions/weather_data/csv_daily/GMDF_tmax_temp_and_spline_27_28_41_avg_year.csv")
  
  # --- Load socioeconomic covariates: 2010 wages proxied as 60% of GDPpc / (250 days * 6 hrs * 60 min) --- #
  soc_ec <- fread("/project/cil/sacagawea_shares/gcp/integration/float32/dscim_input_data/econvars/zarrs/integration-econ-bc39.csv")
  soc_ec <- soc_ec[year == 2010 & model == "IIASA GDP" & ssp == "SSP3"]
  soc_ec[, wage := (gdppc * 0.6) / (250 * 6 * 60)]
  soc_ec <- soc_ec[, .(region, wage, gdppc, pop)]
  
  # --- Optimal temperatures for LR and HR workers (derived analytically from model) --- #
  T_opt_LR <- 28.0163007177373
  T_opt_HR <- 30.6378578604641
  
  # --- Gamma coefficients (hardcoded from uninteracted model .csvv) --- #
  LR_temp   <-  0.0574303265122028
  LR_temp_s <- -0.018539409626495
  HR_temp   <-  4.71644124663339
  HR_temp_s <- -0.273863500208779
  
  # --- Daily decrease in labor supply relative to each group's optimum (minutes) --- #
  dfa[, d_h := temp * HR_temp + temp_s * HR_temp_s -
        (T_opt_HR * HR_temp + ((T_opt_HR-28)^3 - (T_opt_HR-28)^3*(41-27)/(41-28)) * HR_temp_s)]
  dfa[, d_l := temp * LR_temp + temp_s * LR_temp_s -
        (T_opt_LR * LR_temp + ((T_opt_LR-28)^3 - (T_opt_LR-28)^3*(41-27)/(41-28)) * LR_temp_s)]
  
  # --- Merge socioeconomics and monetize --- #
  dfa <- merge(dfa, soc_ec, by.x = "hierid", by.y = "region",
               all.x = TRUE, all.y = TRUE, allow.cartesian = TRUE)
  
  # Monetize HR and LR impacts separately with group-specific Frisch elasticities,
  # then compute net hedonic value (HR disutility minus LR disutility)
  dfa[, diff_dis := (-1) * ((d_h * wage) / frisch_HR - (d_l * wage) / frisch_LR)]
  
  # --- Sum over full year and express as % of 2010 GDPpc --- #
  dfa <- aggregate(diff_dis ~ hierid, data = dfa, FUN = sum)
  dfa <- merge(dfa, soc_ec, by.x = "hierid", by.y = "region",
               all.x = TRUE, all.y = TRUE, allow.cartesian = TRUE)
  dfa$diff_dis_p <- ifelse(dfa$gdppc != 0, (dfa$diff_dis / dfa$gdppc) * 100, 0)
  
  # --- Population-weighted global mean and 5th/95th percentiles --- #
  mean_val <- weighted.mean(dfa$diff_dis_p, dfa$pop, na.rm = TRUE)
  quants   <- Hmisc::wtd.quantile(
    x = dfa$diff_dis_p, weights = dfa$pop,
    probs = c(0.05, 0.95), na.rm = TRUE
  )
  
  list(mean = round(mean_val, 1),
       p5   = round(quants[1], 1),
       p95  = round(quants[2], 1))
}