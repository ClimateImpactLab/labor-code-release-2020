#==============================================================================#
#'
#' SCRIPT 2: Labor Disutility Cost of Climate Change
#'
#' This script computes the labor disutility cost of climate change at 2099
#' as a percentage of 2099 global GDP, for a given RCP/SSP/IAM scenario.
#' Disutility is constructed from Monte Carlo projection outputs by combining
#' high-risk and low-risk worker impacts, each weighted by the share of hours
#' worked in that risk category (clip) and scaled by the respective Frisch
#' elasticity. A historical-climate adjustment is subtracted to isolate the
#' climate-change component. GCM uncertainty is folded in via weighted
#' averaging in Step 1; Monte Carlo (batch) uncertainty is retained through
#' Step 2 and summarised as a standard error in Step 3.
#' The final global statistic is a population-weighted mean of region-level
#' gdppcize values, averaged across batches.
#'
#' Main export: run_disutility(rcp, frisch_HR, frisch_LR, iam, ssp)
#'   Returns a list with: mean, se
#'
#==============================================================================#

#==============================================================================#
# 0. Packages and paths ----
#==============================================================================#

packages <- c("data.table", "tidyverse", "glue")
invisible(lapply(packages, function(pkg) {
  suppressPackageStartupMessages(library(pkg, character.only = TRUE))
}))
rm(packages)

USER <- Sys.getenv("USER")
source(glue('/project/cil/home_dirs/{USER}/repos/labor-code-release-2020/0_subroutines/paths.R'))

#==============================================================================#
# 1. Main function ----
#==============================================================================#

run_disutility <- function(rcp, frisch_HR, frisch_LR,
                           iam = "high", ssp_scen = "SSP3") {
  
  base_path <- glue("/project/cil/gcp/outputs/labor/impacts-woodwork/montecarlo/extracted/uninteracted_main_model_agnonag_27_28_41/sensitivity_table/")
  
  # --- Load Monte Carlo projection files --- #
  file_names <- list(
    clip_fa   = glue("{ssp_scen}-{rcp}_{iam}_clip_fulladapt.csv"),
    clip_hist = glue("{ssp_scen}-{rcp}_{iam}_clip_histclim.csv"),
    high_fa   = glue("{ssp_scen}-{rcp}_{iam}_highriskimpacts_fulladapt.csv"),
    high_hist = glue("{ssp_scen}-{rcp}_{iam}_highriskimpacts_histclim.csv"),
    low_fa    = glue("{ssp_scen}-{rcp}_{iam}_lowriskimpacts_fulladapt.csv"),
    low_hist  = glue("{ssp_scen}-{rcp}_{iam}_lowriskimpacts_histclim.csv")
  )
  
  keys <- c("region", "year", "gcm", "batch")
  
  merge_val <- function(dt, nm) {
    d <- dt[, .SD, .SDcols = c(keys, "value")]
    setnames(d, "value", nm)
    d
  }
  
  # Read raw files first (before merge_val drops columns)
  dts_raw <- lapply(names(file_names), function(nm) {
    dt <- fread(file.path(base_path, file_names[[nm]]))
    dt[is.na(region) | region == "", region := "global"]
    dt
  })
  names(dts_raw) <- names(file_names)
  
  # Extract GCM weights from raw clip_fa before column subsetting
  weights_use <- unique(dts_raw[["clip_fa"]][, .(gcm, weight)])
  
  # Now apply merge_val to subset to keys + value
  dts <- lapply(names(dts_raw), function(nm) merge_val(dts_raw[[nm]], nm))
  names(dts) <- names(file_names)
  
  # --- Merge all files onto high_fa as base --- #
  df <- dts[["high_fa"]]
  for (nm in setdiff(names(dts), "high_fa")) {
    df <- merge(df, dts[[nm]], by = keys, all.x = TRUE)
  }
  
  # --- Compute disutility: full-adapt impacts minus historical-climate baseline --- #
  df[, histclim_adj := high_hist * clip_hist * (0.5 / frisch_HR) +
       low_hist  * (1 - clip_hist) * (0.5 / frisch_LR)]
  df[, disutility   := high_fa  * clip_fa   * (0.5 / frisch_HR) +
       low_fa   * (1 - clip_fa) * (0.5 / frisch_LR) - histclim_adj]
  
  # --- Step 1: GCM-weighted mean per (region, year, batch) --- #
  # GCM uncertainty is folded into each batch-level estimate here
  result_w    <- merge(df[, .SD, .SDcols = c(keys, "disutility")],
                       weights_use, by = "gcm", all.x = TRUE)
  
  gcm_agg <- result_w[,
                      .(disutility = sum(disutility * weight, na.rm = TRUE) / sum(weight, na.rm = TRUE)),
                      by = .(region, year, batch)
  ]
  
  # --- Step 2: Merge covariates and monetize --- #
  cov     <- fread("/project/cil/sacagawea_shares/gcp/integration/float32/dscim_input_data/econvars/zarrs/integration-econ-bc39.csv")
  cov_use <- cov[year == 2099 & ssp == ssp_scen & model == "IIASA GDP", .(region, gdp, gdppc, pop)]
  cov_use <- cov_use[, .SD[1], by = region]
  
  gcm_agg <- merge(gcm_agg, cov_use, by = "region", all.x = TRUE)
  gcm_agg[, gdppcize := (disutility * pop * 0.00487 * gdppc) / gdp]
  
  # Population-weighted global mean per batch
  # Batch uncertainty (Monte Carlo draws) is preserved at this stage
  global_per_batch <- gcm_agg[year == 2099,
                              .(global_gdppcize = sum(gdppcize * pop, na.rm = TRUE) / sum(pop, na.rm = TRUE)),
                              by = batch
  ]
  
  # --- Step 3: Mean, p5, p95 across batches --- #
  # p5/p95 of the batch distribution captures Monte Carlo sampling uncertainty
  mn  <- mean(global_per_batch$global_gdppcize, na.rm = TRUE)
  p5  <- quantile(global_per_batch$global_gdppcize, 0.05, na.rm = TRUE)
  p95 <- quantile(global_per_batch$global_gdppcize, 0.95, na.rm = TRUE)
  
  list(mean = round(mn  * (-100), 2),
       p5   = round(p5  * (-100), 2),
       p95  = round(p95 * (-100), 2))
}