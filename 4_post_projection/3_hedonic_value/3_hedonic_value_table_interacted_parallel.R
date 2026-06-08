#==============================================================================#
#'
#' Interacted Model Hedonic Value Calculation
#' 
#' Author: Rebecca Frost
#' Edits by: Elliot Grenier
#' Last updated: 5 June 2026
#' 
#' Description: 
#' 
#' This script calculates the hedonic value of a temperature controlled
#' workplace for every impact region. Also calculates associated IR-level
#' standard deviations using a bootstrap over the coefficient VCV.
#'
#' Notes:
#' 
#'    - clipping: The HR curve is grounded at its own per-region optimum T_opt_HR. 
#'                The LR curve is grounded at the global LR optimum T_opt_LR. 
#'                d_h is clipped down to d_l: if HR is no worse than LR 
#'                (d_h_raw >= d_l), d_h is set to d_l so hedonic value is 0.
#'
#==============================================================================#

# 0. Packages and paths ----

packages = c("data.table", "tidyverse", "sf", "scales", "glue", "purrr", "knitr", "kableExtra", "mvtnorm", "parallel")
invisible(lapply(packages, function(pkg) {
  suppressPackageStartupMessages(library(pkg, character.only = TRUE))
}))
rm(packages)

USER = Sys.getenv("USER")
source(glue('/project/cil/home_dirs/{USER}/repos/labor-code-release-2020/0_subroutines/paths.R'))

spec = ""
cutoff_temp = 29
n_boot = 1000
n_cores = 20

# Crosswalk mapping region codes to agglomerated regions.
region_map = fread(glue("{ROOT_INT_DATA}/misc/ag_intensive_agglomerated_regions.csv"))

#==============================================================================#
# 1. Load data ----
#==============================================================================#

dfa = fread("/project/cil/gcp/climate/_spatial_data/impactregions/weather_data/csv_daily/GMDF_tmax_temp_and_spline_27_28_41_avg_year.csv")

if (spec == "cold"){
  dfa = dfa %>% mutate(temp = ifelse(temp <= cutoff_temp, temp, NA),
                       temp_s = ifelse(temp <= cutoff_temp, temp_s, NA))
  suffix="_cold"
} else if (spec == "hot"){
  dfa = dfa %>% mutate(temp = ifelse(temp > cutoff_temp, temp, NA),
                       temp_s = ifelse(temp > cutoff_temp, temp_s, NA))
  suffix="_hot"
} else {
  dfa = dfa
  suffix=""
}

# 2010 wages
soc_ec = fread("/project/cil/sacagawea_shares/gcp/integration/float32/dscim_input_data/econvars/zarrs/integration-econ-bc39.csv") %>%
  filter(year == 2010,
         model == "IIASA GDP",
         ssp == "SSP3") %>%
  mutate(wage = (gdppc * 0.6) / (250 * 6 * 60)) %>%
  rename(hierid = region) %>%
  select(hierid, wage, gdppc, pop)

# long run climate
clim = fread("/project/cil/gcp/outputs/labor/impacts-woodwork/single/single_agnonag_27_28_41/single/rcp85/CCSM4/low/SSP3/single-allcalcs-uninteracted_main_model_agnonag_27_28_41.csv") %>%
  select(-19) %>%
  filter(year == 2015) %>%
  select(region, climtasmax) %>%
  rename(hierid = region)

#==============================================================================#
# 2. Coefficients and VCV matrix (hardcoded) ----
#==============================================================================#

LR_temp =  0.057430329
LR_temp_s = -0.01853941

HR_temp = -17.69520297
HR_temp_s =  1.186135858

HR_temp_clim =  0.70615313
HR_temp_s_clim = -0.046964351

mu_coefs = c(LR_temp, LR_temp_s, HR_temp, HR_temp_s, HR_temp_clim, HR_temp_s_clim)

vcv = matrix(c(
  # LR_t          LR_s           HR_t           HR_s           HR_t_clim      HR_s_clim
  0.050558878,  -0.002251653,   0.065847874,  -0.003250606,  -0.000504696,   0.0000326,
  -0.002251653,   0.000226718,  -0.006815442,   0.000399769,   0.000161446,  -0.00000636,
  0.065847874,  -0.006815442,  61.239571890,  -1.643244440,  -2.129495424,   0.059797574,
  -0.003250606,   0.000399769,  -1.643244440,   0.250995814,   0.057075397,  -0.008120869,
  -0.000504696,   0.000161446,  -2.129495424,   0.057075397,   0.075224093,  -0.002115432,
  0.0000326,    -0.00000636,    0.059797574,  -0.008120869,  -0.002115432,   0.000266339
), nrow = 6, ncol = 6, byrow = TRUE)


#==============================================================================#
# 3. Spline and response functions ----
#==============================================================================#

spline_val = function(T) {
  pmax(T - 27, 0)^3 -
    pmax(T - 28, 0)^3 * (41 - 27) / (41 - 28) +
    pmax(T - 41, 0)^3 * (28 - 27) / (41 - 28)
}

spline_second_deriv = function(T) {
  6 * pmax(T - 27, 0) -
    6 * pmax(T - 28, 0) * (41 - 27) / (41 - 28) +
    6 * pmax(T - 41, 0) * (28 - 27) / (41 - 28)
}

lr_response = function(T) LR_temp * T + LR_temp_s * spline_val(T)
hr_response = function(T, ht, hs) ht * T + hs * spline_val(T)

# Analytical solution for T_opt_HR per region.
# Sets f'(T) = ht + hs * spline_deriv(T) = 0 and solves within each spline
# segment. Second derivative test determines whether each root is a max or min;
# if the second derivative is zero or undefined at all roots (inconclusive),
# fall back to 27.
find_T_opt_HR = function(ht, hs) {
  
  candidates = numeric(0)
  
  # Segment [27, 28]: spline_deriv(T) = 3*(T-27)^2
  # ht + 3*hs*(T-27)^2 = 0  =>  T = 27 + sqrt(-ht / (3*hs))
  inner = -ht / (3 * hs)
  if (is.finite(inner) && inner >= 0) {
    T_cand = 27 + sqrt(inner)
    if (T_cand <= 28) candidates = c(candidates, T_cand)
  }
  
  # Segment [28, 41]: spline_deriv(T) = 3*(T-27)^2 - (14/13)*3*(T-28)^2
  # After expansion: 3*hs*T^2 - 246*hs*T + (4497*hs - 13*ht) = 0
  a_q = 3 * hs
  b_q = -246 * hs
  c_q = 4497 * hs - 13 * ht
  disc = b_q^2 - 4 * a_q * c_q
  
  if (is.finite(disc) && disc >= 0 && a_q != 0) {
    for (T_cand in c((-b_q + sqrt(disc)) / (2*a_q),
                     (-b_q - sqrt(disc)) / (2*a_q))) {
      if (T_cand >= 28 && T_cand <= 41) candidates = c(candidates, T_cand)
    }
  }
  
  if (length(candidates) == 0) return(27)
  
  # Retain only roots where the second derivative is non-zero (defined test)
  sd_vals = hs * spline_second_deriv(candidates)
  valid = candidates[is.finite(sd_vals) & sd_vals != 0]
  
  if (length(valid) == 0) return(27)
  
  # Among valid roots, take the one giving the highest hr_response value
  valid[which.max(sapply(valid, function(T) hr_response(T, ht, hs)))]
}

#==============================================================================#
# 4. Draw bootstrap coefficient samples ----
#==============================================================================#

set.seed(12345)
draws = rmvnorm(n = n_boot, mean = mu_coefs, sigma = vcv)

#==============================================================================#
# 5. Pre-merge weather data with socioeconomics and climate ----
#==============================================================================#

dfa = merge(dfa, clim, by = "hierid")
dfa = merge(dfa, soc_ec, by = "hierid")
dfa = dfa %>% mutate(ISO = sapply(strsplit(as.character(hierid), ".", fixed = TRUE), `[`, 1))

total_pop  = sum(soc_ec$pop, na.rm = TRUE)
region_ids = unique(dfa$hierid)

#==============================================================================#
# 6. Bootstrap loop (parallelised over draws) ----
#==============================================================================#

run_draw = function(i) {
  
  LR_t_i = draws[i, 1]
  LR_s_i = draws[i, 2]
  HR_t_i = draws[i, 3]
  HR_s_i = draws[i, 4]
  HR_tc_i = draws[i, 5]
  HR_sc_i = draws[i, 6]
  
  # LR optimum for this draw (scalar)
  lr_i = function(T) LR_t_i * T + LR_s_i * spline_val(T)
  T_opt_LR_i = optimize(lr_i, interval = c(27, 41), maximum = TRUE)$maximum
  f_l_opt_l_i = lr_i(T_opt_LR_i)
  
  # Per-region HR effective coefficients
  HR_eff_i = HR_t_i + HR_tc_i * dfa$climtasmax
  HR_s_eff_i = HR_s_i + HR_sc_i * dfa$climtasmax
  
  # T_opt_HR per region — solved analytically on the clim table
  clim_i = clim %>%
    mutate(
      ht = HR_t_i + HR_tc_i * climtasmax,
      hs = HR_s_i + HR_sc_i * climtasmax,
      T_opt_HR = mapply(find_T_opt_HR, ht, hs)
    ) %>%
    select(hierid, T_opt_HR)
  
  dfa_i = merge(dfa, clim_i, by = "hierid")
  
  # Response at actual temperature
  dfa_i$f_h = dfa_i$temp * HR_eff_i[match(dfa_i$hierid, dfa$hierid)] + dfa_i$temp_s * HR_s_eff_i[match(dfa_i$hierid, dfa$hierid)]
  dfa_i$f_l = dfa_i$temp * LR_t_i + dfa_i$temp_s * LR_s_i
  
  # HR response at per-region optimum
  dfa_i$f_h_opt_h = dfa_i$T_opt_HR * (HR_t_i + HR_tc_i * dfa_i$climtasmax) + spline_val(dfa_i$T_opt_HR) * (HR_s_i + HR_sc_i * dfa_i$climtasmax)
  
  # Clipping
  dfa_i$d_l = dfa_i$f_l - f_l_opt_l_i
  dfa_i$d_h_raw = dfa_i$f_h - dfa_i$f_h_opt_h
  dfa_i$d_h = ifelse(dfa_i$d_h_raw < dfa_i$d_l, dfa_i$d_h_raw, dfa_i$d_l)
  dfa_i$diff = dfa_i$d_h - dfa_i$d_l
  
  # Monetise and aggregate to region level
  dfa_i$diff_dis = (-1) * (dfa_i$diff * dfa_i$wage) / 0.5
  
  dfb_i = aggregate(diff_dis ~ hierid, data = dfa_i, FUN = sum)
  dfb_i = merge(dfb_i, soc_ec, by = "hierid")
  dfb_i$diff_dis_p = ifelse(dfb_i$gdppc != 0, (dfb_i$diff_dis / dfb_i$gdppc) * 100, 0)
  
  list(
    region_vals = setNames(dfb_i$diff_dis_p, as.character(dfb_i$hierid)),
    global_mean = weighted.mean(dfb_i$diff_dis_p, dfb_i$pop, na.rm = TRUE)
  )
}

results = mclapply(seq_len(n_boot), run_draw, mc.cores = n_cores)

# Reassemble results
boot_global = sapply(results, `[[`, "global_mean")

boot_region = matrix(NA, nrow = length(region_ids), ncol = n_boot,
                     dimnames = list(as.character(region_ids), NULL))
for (i in seq_len(n_boot)) {
  rv = results[[i]]$region_vals
  boot_region[names(rv), i] = rv
}

#==============================================================================#
# 7. Summarise bootstrap distribution ----
#==============================================================================#

region_mean = rowMeans(boot_region, na.rm = TRUE)
region_sd = apply(boot_region, 1, sd, na.rm = TRUE)

regs = data.frame(
  hierid = names(region_mean),
  diff_dis_p = region_mean,
  SD = region_sd
)
regs = merge(regs, soc_ec, by = "hierid")

regs$diff_dis_p = ifelse(is.na(regs$diff_dis_p), 0, regs$diff_dis_p)

global_mean = round(mean(boot_global, na.rm = TRUE), 1)
global_sd = round(sd(boot_global, na.rm = TRUE), 1)

#==============================================================================#
# 8. Format table ----
#==============================================================================#
quants = as.matrix(
  Hmisc::wtd.quantile(x = regs$diff_dis_p,
                      weights = regs$pop,
                      probs = c(0.05, 0.1, 0.25, 0.5, 0.75, 0.90, 0.95),
                      na.rm = TRUE)
)

percs = c("5th", "10th", "25th", "50th", "75th", "90th", "95th")
pw_quants = as.data.frame(cbind(percs, quants))

# ===== Pop-weighted averages across agglomerated regions ===== #
# For each bootstrap draw, compute the pop-weighted mean of diff_dis_p within
# each agglomerated region (using the full boot_region matrix).
pop_vec = setNames(soc_ec$pop, as.character(soc_ec$hierid))
crosswalk = setNames(region_map$agglom, as.character(region_map$hierid))

agg_grp = crosswalk[rownames(boot_region)]   # agglom label for each IR row (NA if unmatched)
keep = !is.na(agg_grp)
br = boot_region[keep, , drop = FALSE]
w = pop_vec[rownames(br)]
grp = agg_grp[keep]

# Per-draw pop-weighted mean within each agglom region.
num = rowsum(br * w, grp, na.rm = TRUE)
den = rowsum((!is.na(br)) * w, grp, na.rm = TRUE)
agg_boot = num / den # rows = agglom regions, cols = draws

agglom_data = data.frame(
  agglom = rownames(agg_boot),
  diff_dis_p = rowMeans(agg_boot, na.rm = TRUE),
  SD = apply(agg_boot, 1, sd, na.rm = TRUE),
  row.names  = NULL
)

summary_stats = data.frame(
  label = c("Global average", paste0(pw_quants$percs, " percentile")),
  value = c(paste0(global_mean, "% (", global_sd, "%)"),
            paste0(round(as.numeric(pw_quants$V2), 1), "%"))
)

city_data = agglom_data %>%
  mutate(value = paste0(round(diff_dis_p, 1), "% (", round(SD, 1), "%)")) %>%
  dplyr::select(label = agglom, value)


#==============================================================================#
# 9. Print ----
#==============================================================================#

message(" ===== Interacted Model Version of Table 4 ===== ")
message(glue(" Number of montecarlo simulations: {n_boot}"))
tex_table = kable(rbind(summary_stats, city_data), 
                  format = "latex",
                  col.names = NULL,
                  booktabs = TRUE,
                  align = c("l", "r"))

# print to console
print(tex_table)

# export to .tex file
# --- EDIT this path to point to your desired output location ---
tex_path = glue("{DIR_TABLE}/table4_hedonic_value_interacted{suffix}.tex")
writeLines(as.character(tex_table), tex_path)
message(glue("Wrote LaTeX table to: {tex_path}"))