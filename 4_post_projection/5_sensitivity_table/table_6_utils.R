#==============================================================================#
#  3_table_6_utils.R
#  Shared functions sourced by both 3_table_6_xr.R and 3_table_6_e.R.
#
#  Function index:
#
#  read_hedonic_tex(path)
#    Parse table4_hedonic_value*.tex → list(mean, p5, p95) [% annual income]
#
#  read_disutility_gdp_csv(path, year_val)
#    Read interacted-model GDP-aggregated CSV for one year.
#    Raw values are negative → multiplied by (−100) before return.
#    → list(mean, p_lo, p_hi) [% 2099 global GDP, positive loss]
#      p_lo = q5  × (−100)  [upper bound of loss CI]
#      p_hi = q95 × (−100)  [lower bound of loss CI]
#
#  run_hedonic(frisch_HR, frisch_LR)
#    Compute global average hedonic value of thermal comfort.
#    Monetises (HR − LR) disutility gap with group-specific Frisch elasticities,
#    sums over the year, expresses as % of 2010 GDPpc.
#    → list(mean, p5, p95) [% annual income, population-weighted global]
#
#  run_disutility(rcp, frisch_HR, frisch_LR, iam, ssp_scen)
#    Compute labor disutility cost of climate change at 2099 (rows 2–3).
#    Combines HR/LR Monte Carlo projections weighted by clip shares and
#    Frisch elasticities; subtracts historical-climate baseline; GDP-weights
#    to a single global value via weighted ECDF matching quantiles.py.
#    Raw values are negative → multiplied by (−100) before return.
#    → list(mean, se, p5, p95) [% 2099 global GDP, positive loss]
#
#  run_disutility_scc_prep(rcp, frisch_HR, frisch_LR, iam, ssp_scen, output_dir)
#    Data-preparation step for SCC rows (4–5) of the e table.
#    Saves regional + global wage-welfare summaries to CSV for the
#    external discounting pipeline.
#    → data.table (also written to output_dir)
#==============================================================================#

packages <- c("data.table", "tidyverse", "Hmisc", "glue")
invisible(lapply(packages, function(pkg) {
  suppressPackageStartupMessages(library(pkg, character.only = TRUE))
}))
rm(packages)

DIR_GCP_CLIMATE   <- "/project/cil/gcp/climate"
DIR_WEATHER_DAILY <- file.path(DIR_GCP_CLIMATE, "_spatial_data/impactregions/weather_data/csv_daily")
DIR_SMME_WEIGHTS  <- file.path(DIR_GCP_CLIMATE, "SMME-weights")
DIR_ECON_BC39     <- "/project/cil/sacagawea_shares/gcp/integration/float32/dscim_input_data/econvars/zarrs"
DIR_IMPACT_SENS   <- paste0(
  "/project/cil/gcp/outputs/labor/impacts-woodwork/montecarlo/extracted/",
  "uninteracted_main_model_agnonag_27_28_41/sensitivity_table"
)
DIR_USER_TMP      <- file.path("/project/cil/home_dirs", USER, "tmp")

#==============================================================================#
# 1. read_hedonic_tex: parse baseline hedonic value from table4 tex file ----
#==============================================================================#

read_hedonic_tex <- function(path) {
  lines <- readLines(path)
  extract_pct <- function(pattern) {
    ln <- lines[grepl(pattern, lines, fixed = TRUE)]
    if (length(ln) == 0) stop(paste("Pattern not found in", path, ":", pattern))
    as.numeric(sub(".*& ([0-9.]+)\\\\%.*", "\\1", ln[1]))
  }
  list(
    mean = extract_pct("Global average"),
    p5   = extract_pct("5th percentile"),
    p95  = extract_pct("95th percentile")
  )
}

#==============================================================================#
# 2. read_disutility_gdp_csv: read interacted-model GDP-aggregated output ----
#    Returns list(mean, p_lo, p_hi) in positive-% loss units, where
#    p_lo = q5  * (-100)  [larger value, upper bound of loss CI]
#    p_hi = q95 * (-100)  [smaller value, lower bound of loss CI]
#    Matches the p_lo/p_hi convention used by fmt_cell_disutility.
#==============================================================================#

read_disutility_gdp_csv <- function(path, year_val = 2099) {
  dt  <- fread(path)
  row <- dt[year == year_val]
  if (nrow(row) == 0) stop(paste("year", year_val, "not found in", path))
  list(
    mean = row$mean * (-100),
    p_lo = row$q5   * (-100),
    p_hi = row$q95  * (-100)
  )
}

#==============================================================================#
# 3. run_hedonic ----
#==============================================================================#

run_hedonic <- function(frisch_HR, frisch_LR) {

  dfa <- fread(file.path(DIR_WEATHER_DAILY, "GMDF_tmax_temp_and_spline_27_28_41_avg_year.csv"))

  soc_ec <- fread(file.path(DIR_ECON_BC39, "integration-econ-bc39.csv"))
  soc_ec <- soc_ec[year == 2010 & model == "IIASA GDP" & ssp == "SSP3"]
  soc_ec[, wage := (gdppc * 0.6) / (250 * 6 * 60)]
  soc_ec <- soc_ec[, .(region, wage, gdppc, pop)]

  # Optimal temperatures derived analytically from uninteracted model
  T_opt_LR <- 28.0163007177373
  T_opt_HR <- 30.6378578604641

  # Gamma coefficients from uninteracted model .csvv
  LR_temp   <-  0.0574303265122028
  LR_temp_s <- -0.018539409626495
  HR_temp   <-  4.71644124663339
  HR_temp_s <- -0.273863500208779

  dfa[, d_h := temp * HR_temp + temp_s * HR_temp_s -
        (T_opt_HR * HR_temp + ((T_opt_HR-28)^3 - (T_opt_HR-28)^3*(41-27)/(41-28)) * HR_temp_s)]
  dfa[, d_l := temp * LR_temp + temp_s * LR_temp_s -
        (T_opt_LR * LR_temp + ((T_opt_LR-28)^3 - (T_opt_LR-28)^3*(41-27)/(41-28)) * LR_temp_s)]

  dfa <- merge(dfa, soc_ec, by.x = "hierid", by.y = "region",
               all.x = TRUE, all.y = TRUE, allow.cartesian = TRUE)

  dfa[, diff_dis := (-1) * ((d_h * wage) / frisch_HR - (d_l * wage) / frisch_LR)]

  dfa <- aggregate(diff_dis ~ hierid, data = dfa, FUN = sum)
  dfa <- merge(dfa, soc_ec, by.x = "hierid", by.y = "region",
               all.x = TRUE, all.y = TRUE, allow.cartesian = TRUE)
  dfa$diff_dis_p <- ifelse(dfa$gdppc != 0, (dfa$diff_dis / dfa$gdppc) * 100, 0)

  mean_val <- weighted.mean(dfa$diff_dis_p, dfa$pop, na.rm = TRUE)
  quants   <- Hmisc::wtd.quantile(
    x = dfa$diff_dis_p, weights = dfa$pop,
    probs = c(0.05, 0.95), na.rm = TRUE
  )

  list(mean = round(mean_val, 1),
       p5   = round(quants[1], 1),
       p95  = round(quants[2], 1))
}

#==============================================================================#
# 2. run_disutility (rows 2 & 3: % GDP, weighted-ECDF global summary) ----
#==============================================================================#

.get_model_weights <- function(rcp) {
  weight_file <- file.path(DIR_SMME_WEIGHTS, glue("{rcp}_2090_SMME_edited_for_April_2016.tsv"))
  weights <- fread(weight_file, select = c("model", "weight"))

  pattern_map <- list(
    rcp45 = list(
      "pattern1_"  = "surrogate_MRI-CGCM3_01",
      "pattern2_"  = "surrogate_GFDL-ESM2G_01",
      "pattern3_"  = "surrogate_MRI-CGCM3_06",
      "pattern5_"  = "surrogate_MRI-CGCM3_11",
      "pattern6_"  = "surrogate_GFDL-ESM2G_11",
      "pattern27_" = "surrogate_GFDL-CM3_89",
      "pattern28_" = "surrogate_CanESM2_89",
      "pattern29_" = "surrogate_GFDL-CM3_94",
      "pattern30_" = "surrogate_CanESM2_94",
      "pattern31_" = "surrogate_GFDL-CM3_99",
      "pattern32_" = "surrogate_CanESM2_99"
    ),
    rcp85 = list(
      "pattern1_"  = "surrogate_MRI-CGCM3_01",
      "pattern2_"  = "surrogate_GFDL-ESM2G_01",
      "pattern3_"  = "surrogate_MRI-CGCM3_06",
      "pattern4_"  = "surrogate_GFDL-ESM2G_06",
      "pattern5_"  = "surrogate_MRI-CGCM3_11",
      "pattern6_"  = "surrogate_GFDL-ESM2G_11",
      "pattern28_" = "surrogate_GFDL-CM3_89",
      "pattern29_" = "surrogate_CanESM2_89",
      "pattern30_" = "surrogate_GFDL-CM3_94",
      "pattern31_" = "surrogate_CanESM2_94",
      "pattern32_" = "surrogate_GFDL-CM3_99",
      "pattern33_" = "surrogate_CanESM2_99"
    )
  )

  common_map <- list(
    "access1-0"      = "ACCESS1-0",
    "bnu-esm"        = "BNU-ESM",
    "canesm2"        = "CanESM2",
    "ccsm4"          = "CCSM4",
    "cesm1-bgc"      = "CESM1-BGC",
    "cnrm-cm5"       = "CNRM-CM5",
    "csiro-mk3-6-0"  = "CSIRO-Mk3-6-0",
    "gfdl-cm3"       = "GFDL-CM3",
    "gfdl-esm2g"     = "GFDL-ESM2G",
    "gfdl-esm2m"     = "GFDL-ESM2M",
    "ipsl-cm5a-lr"   = "IPSL-CM5A-LR",
    "ipsl-cm5a-mr"   = "IPSL-CM5A-MR",
    "miroc-esm-chem" = "MIROC-ESM-CHEM",
    "miroc-esm"      = "MIROC-ESM",
    "miroc5"         = "MIROC5",
    "mpi-esm-lr"     = "MPI-ESM-LR",
    "mpi-esm-mr"     = "MPI-ESM-MR",
    "mri-cgcm3"      = "MRI-CGCM3",
    "noresm1-m"      = "NorESM1-M"
  )

  full_map <- c(pattern_map[[rcp]], common_map)
  for (old in names(full_map)) {
    matches <- grepl(old, weights$model, fixed = TRUE)
    weights[matches, model := full_map[[old]]]
  }
  weights[, model := gsub("*", "", model, fixed = TRUE)]
  setnames(weights, "model", "gcm")
  weights[, .(gcm, weight)]
}

run_disutility <- function(rcp, frisch_HR, frisch_LR,
                           iam = "high", ssp_scen = "SSP3") {

  base_path <- DIR_IMPACT_SENS

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

  dts_raw <- lapply(names(file_names), function(nm) {
    dt <- fread(file.path(base_path, file_names[[nm]]))
    dt[is.na(region) | region == "", region := "global"]
    dt
  })
  names(dts_raw) <- names(file_names)

  weights_use <- .get_model_weights(rcp)

  dts <- lapply(names(dts_raw), function(nm) merge_val(dts_raw[[nm]], nm))
  names(dts) <- names(file_names)

  df <- dts[["high_fa"]]
  for (nm in setdiff(names(dts), "high_fa")) {
    df <- merge(df, dts[[nm]], by = keys, all.x = TRUE)
  }

  df[, histclim_adj := high_hist * clip_hist * (0.5 / frisch_HR) +
       low_hist  * (1 - clip_hist) * (0.5 / frisch_LR)]
  df[, disutility   := high_fa  * clip_fa   * (0.5 / frisch_HR) +
      low_fa   * (1 - clip_fa) * (0.5 / frisch_LR) - histclim_adj]

  cov_bc39 <- fread(file.path(DIR_ECON_BC39, "integration-econ-bc39.csv"))
  cov_use  <- cov_bc39[year == 2099 & ssp == ssp_scen & model == "OECD Env-Growth", .(region, gdp, gdppc, pop)]
  cov_use  <- cov_use[, .SD[1], by = region]

  df_gcm <- merge(df[, .SD, .SDcols = c(keys, "disutility")],
                  cov_use, by = "region", all.x = TRUE)
  df_gcm[, gdppcize := disutility * 0.00487]

  global_gdp <- unique(df_gcm[!is.na(gdp), .(region, gdp)])[, sum(gdp)]

  result_w <- merge(df_gcm, weights_use, by = "gcm", all.x = TRUE)
  result_w[is.na(weight), weight := 0]

  global_per_batch_gcm <- result_w[year == 2099,
    .(global_gdppcize = sum(gdppcize * gdp, na.rm = TRUE) / global_gdp,
      weight          = weight[1]),
    by = .(batch, gcm)
  ]

  vals  <- global_per_batch_gcm$global_gdppcize
  w     <- global_per_batch_gcm$weight
  w_sum <- sum(w, na.rm = TRUE)

  mn <- sum(vals * w, na.rm = TRUE) / w_sum
  se <- sqrt(sum(w * (vals - mn)^2, na.rm = TRUE) / w_sum)

  ord         <- order(vals)
  vals_sorted <- vals[ord]
  cum_w       <- cumsum(w[ord]) / w_sum

  weighted_quantile <- function(p) {
    idx <- sum(cum_w < p)
    if (idx < 1L) return(-Inf)
    vals_sorted[idx]
  }

  p5  <- weighted_quantile(0.05)
  p95 <- weighted_quantile(0.95)

  list(mean = mn  * (-100),
       se   = se  *   100,
       p5   = p5  * (-100),
       p95  = p95 * (-100))
}

#==============================================================================#
# 3. run_disutility_scc_prep (rows 4 & 5 data prep: saves regional CSV) ----
#==============================================================================#

.QUANTILE_PROBS <- c(0.01, 0.05, 0.10, 0.17, 0.25, 0.50, 0.75, 0.83, 0.90, 0.95, 0.99)

run_disutility_scc_prep <- function(rcp,
                                    frisch_HR,
                                    frisch_LR,
                                    iam        = "high",
                                    ssp_scen   = "SSP3",
                                    output_dir = DIR_USER_TMP) {

  base_path <- glue(
    "/project/cil/gcp/outputs/labor/impacts-woodwork/montecarlo/extracted/",
    "uninteracted_main_model_agnonag_27_28_41/sensitivity_table/"
  )

  file_names <- list(
    clip_fa   = glue("{ssp_scen}-{rcp}_{iam}_clip_fulladapt.csv"),
    clip_hist = glue("{ssp_scen}-{rcp}_{iam}_clip_histclim.csv"),
    high_fa   = glue("{ssp_scen}-{rcp}_{iam}_highriskimpacts_fulladapt-wage-levels_valuescsv.csv"),
    high_hist = glue("{ssp_scen}-{rcp}_{iam}_highriskimpacts_histclim-wage-levels_valuescsv.csv"),
    low_fa    = glue("{ssp_scen}-{rcp}_{iam}_lowriskimpacts_fulladapt-wage-levels_valuescsv.csv"),
    low_hist  = glue("{ssp_scen}-{rcp}_{iam}_lowriskimpacts_histclim-wage-levels_valuescsv.csv")
  )

  keys <- c("region", "year", "gcm", "batch")

  merge_val <- function(dt, nm) {
    d <- dt[, .SD, .SDcols = c(keys, "value")]
    setnames(d, "value", nm)
    d
  }

  dts_raw <- lapply(names(file_names), function(nm) {
    dt <- fread(file.path(base_path, file_names[[nm]]))
    dt[is.na(region) | region == "", region := "global"]
    dt
  })
  names(dts_raw) <- names(file_names)

  weights_use <- unique(dts_raw[["clip_fa"]][, .(gcm, weight)])

  dts <- lapply(names(dts_raw), function(nm) merge_val(dts_raw[[nm]], nm))
  names(dts) <- names(file_names)

  df <- dts[["high_fa"]]
  for (nm in setdiff(names(dts), "high_fa")) {
    df <- merge(df, dts[[nm]], by = keys, all.x = TRUE)
  }

  df[, histclim_adj_wage :=
       high_hist * clip_hist * (0.5 / frisch_HR) +
       low_hist  * (1 - clip_hist) * (0.5 / frisch_LR)]

  df[, wage_welfare :=
       high_fa * clip_fa * (0.5 / frisch_HR) +
       low_fa  * (1 - clip_fa) * (0.5 / frisch_LR) -
       histclim_adj_wage]

  result_w <- merge(
    df[, .SD, .SDcols = c(keys, "wage_welfare")],
    weights_use, by = "gcm", all.x = TRUE
  )

  gcm_agg <- result_w[
    ,
    .(wage_welfare = sum(wage_welfare * weight, na.rm = TRUE) /
        sum(weight, na.rm = TRUE)),
    by = .(region, year, batch)
  ]

  cov <- fread("/project/cil/sacagawea_shares/gcp/integration/float32/dscim_input_data/econvars/zarrs/integration-econ-bc39.csv")
  cov_use <- cov[year == 2099 & ssp == ssp_scen & model == "IIASA GDP",
                 .(region, gdp, gdppc, pop)]

  dup_regions <- cov_use[duplicated(region), unique(region)]
  if (length(dup_regions) > 0)
    warning(glue("Duplicate regions in cov_use; keeping first row for: ",
                 paste(dup_regions, collapse = ", ")))
  cov_use <- cov_use[, .SD[1], by = region]

  gcm_agg <- merge(gcm_agg, cov_use, by = "region", all.x = TRUE)
  gcm_agg_2099 <- gcm_agg[year == 2099]

  make_summary <- function(x) {
    q_vals  <- unname(quantile(x, probs = .QUANTILE_PROBS, na.rm = TRUE))
    q_names <- paste0("p", formatC(.QUANTILE_PROBS * 100, format = "fg", flag = "0"))
    as.list(c(mean = mean(x, na.rm = TRUE), setNames(q_vals, q_names)))
  }

  regional_summary <- gcm_agg_2099[
    region != "global"
  ][, make_summary(wage_welfare), by = region]

  global_per_batch <- gcm_agg_2099[
    region != "global",
    .(global_wage_welfare = weighted.mean(wage_welfare, pop, na.rm = TRUE)),
    by = batch
  ]

  global_summary <- as.data.table(make_summary(global_per_batch$global_wage_welfare))
  global_summary[, region := "global"]

  stat_cols <- c("mean", paste0("p", formatC(.QUANTILE_PROBS * 100, format = "fg", flag = "0")))

  final_out <- rbindlist(
    list(
      regional_summary[, c("region", stat_cols), with = FALSE],
      global_summary[,  c("region", stat_cols), with = FALSE]
    ),
    use.names = TRUE, fill = TRUE
  )

  final_out[, (stat_cols) := lapply(.SD, function(x) round(x, 6)), .SDcols = stat_cols]

  ehigh_str <- gsub("\\.", "p", as.character(frisch_HR))
  elow_str  <- gsub("\\.", "p", as.character(frisch_LR))
  outfile   <- glue("{ssp_scen}-{rcp}_{iam}_rebased_change_e_{ehigh_str}_{elow_str}.csv")
  outpath   <- file.path(output_dir, outfile)

  fwrite(final_out, outpath)
  message(glue("Saved: {outpath}"))

  return(final_out[])
}
