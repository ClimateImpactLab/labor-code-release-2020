#==============================================================================#
#'
#' This script calculates the hedonic value of a temperature controlled 
#' workplace for every impact region. Also calculates associated IR-level 
#' standard deviations using the delta-method.
#' 
#==============================================================================#

#==============================================================================#
# 0. load paths, packages and data ----
packages = c("data.table", "tidyverse", "sf", "scales", "glue", "purrr", "knitr", "kableExtra")
invisible(lapply(packages, function(pkg) {
  suppressPackageStartupMessages(library(pkg, character.only = TRUE))
}))
rm(packages)

USER = Sys.getenv("USER")
source(glue('/project/cil/home_dirs/{USER}/repos/labor-code-release-2020/0_subroutines/paths.R'))

spec = "hot" # "cold" or "hot" or ""
cutoff_temp = 29

#==============================================================================#
# 1. Data cleaning and analysis ----

# Load data
# Crosswalk mapping region codes to agglomerated regions.
region_map = fread(glue("{ROOT_INT_DATA}/misc/ag_intensive_agglomerated_regions.csv"))

# GMFD climate data averaged across years in step 0
dfa = fread("/project/cil/gcp/climate/_spatial_data/impactregions/weather_data/csv_daily/GMDF_tmax_temp_and_spline_27_28_41_avg_year.csv") 

# ===== subset data depending on plot type ===== #
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

# ===== Calculate 2010 wages ===== #

soc_ec = fread("/project/cil/sacagawea_shares/gcp/integration/float32/dscim_input_data/econvars/zarrs/integration-econ-bc39.csv") 
soc_ec = subset(soc_ec, year == 2010)
soc_ec = subset(soc_ec, model == "IIASA GDP") # low iam
soc_ec = subset(soc_ec, ssp == "SSP3")
soc_ec$wage = (soc_ec$gdppc*0.6)/(250*6*60)
soc_ec = subset(soc_ec, select = c(region, wage, gdppc, pop))

# ===== Bring in coefs, vcv elements from .csvv, calculate deviations from optimal temp ===== #

# Optimal temps for low risk and high risk workers. Calculated by hand 
T_opt_LR = 28.0163007177373
T_opt_HR = 30.6378578604641

# calculate deviations from optimal temp
dfa$tl = dfa$temp - T_opt_LR
dfa$sl = dfa$temp_s - ( (T_opt_LR-28)^3 - (T_opt_LR-28)^3 * (41 - 27) / (41 - 28))
dfa$th = dfa$temp - T_opt_HR
dfa$sh = dfa$temp_s - ( (T_opt_HR-28)^3 - (T_opt_HR-28)^3 * (41 - 27) / (41 - 28))

dfb = aggregate(cbind(th,sh,tl,sl) ~ hierid, data = dfa, FUN = sum)

# Hardcoded from uninteracted model .csvv. Read covariances as C_{row}_{col}
# gamma coefs
LR_temp = rep(0.0574303265122028, nrow(dfb))
LR_temp_s = rep(-0.018539409626495, nrow(dfb))
HR_temp = rep(4.71644124663339, nrow(dfb))
HR_temp_s = rep(-0.273863500208779, nrow(dfb))

# VCV diagonal
V_LR_t = rep(0.0505587708036388, nrow(dfb))
V_LR_s = rep(0.0002267178219042, nrow(dfb))
V_HR_t = rep(3.24968722108206, nrow(dfb))
V_HR_s = rep(0.0063063790519171, nrow(dfb))

# Off diagonal VCV elements (covariances)
C_LR_t_LR_s = rep(-0.0022516478474324, nrow(dfb))
C_HR_s_LR_s = rep(-0.0000957840964433, nrow(dfb))
C_HR_s_LR_t = rep(0.0002157185208938, nrow(dfb))
C_HR_t_LR_s = rep(0.0017002151370133, nrow(dfb))
C_HR_t_LR_t = rep(-0.0048233912806641, nrow(dfb))
C_HR_t_HR_s = rep(-0.109253785690528, nrow(dfb))

# merge together row-wise
dfb = cbind(dfb, 
            LR_temp, LR_temp_s, HR_temp, HR_temp_s, 
            V_LR_t, V_LR_s, V_HR_t, V_HR_s, 
            C_LR_t_LR_s, C_HR_s_LR_s, C_HR_s_LR_t, 
            C_HR_t_LR_s, C_HR_t_LR_t, C_HR_t_HR_s)

# ===== add countries to dfs ===== #
dfa = dfa %>% mutate(ISO = sapply(strsplit(as.character(hierid), ".", fixed = TRUE), `[`, 1))
dfb = dfb %>% mutate(ISO = sapply(strsplit(as.character(hierid), ".", fixed = TRUE), `[`, 1))

# ===== Calculate avg. daily minutes lost (long run values) ===== #
#Predict LS based on temp for each group on actual temp realizations and the optimal temp
dfa$f_h = dfa$temp * HR_temp[1] + dfa$temp_s * HR_temp_s[1]
dfa$f_h_opt_h = T_opt_HR * HR_temp[1] + ((T_opt_HR - 28)^3 - (T_opt_HR - 28)^3 * (41 - 27) / (41 - 28)) * HR_temp_s[1]

dfa$f_l = dfa$temp * LR_temp[1] + dfa$temp_s * LR_temp_s[1]
dfa$f_l_opt_l = T_opt_LR * LR_temp[1] + ((T_opt_LR - 28)^3 - (T_opt_LR - 28)^3 * (41 - 27) / (41 - 28)) * LR_temp_s[1]

#Calculate each group's daily decrease in LS  relative to its own optimum
dfa$d_h = dfa$f_h - dfa$f_h_opt_h
dfa$d_l = dfa$f_l - dfa$f_l_opt_l

dfa$diff = dfa$d_h - dfa$d_l

# Merge socioeconomics with main df
dfa = merge(dfa, soc_ec, by.x = "hierid", by.y = "region", all.x = TRUE, all.y = TRUE, allow.cartesian=TRUE)

# calculate monetized impacts
dfa$diff_dis = (-1) * (dfa$diff * dfa$wage) / 0.5

# add up results over the full year 
dfa = aggregate(cbind(diff, d_h, d_l, diff_dis) ~ ISO + hierid, data = dfa, FUN = sum)
dfa = merge(dfa, soc_ec, by.x="hierid", by.y="region", all.x=TRUE, all.y=TRUE, allow.cartesian=TRUE)

# calculate disultility as % of 2010 GDP 
dfa$diff_dis_p = ifelse(dfa$gdppc != 0, (dfa$diff_dis / dfa$gdppc) * 100, 0)

# ===== Get standard deviations using delta method ===== #

dfb = merge(dfb, soc_ec, by.x = "hierid", by.y = "region", all.x = TRUE, all.y = FALSE,allow.cartesian=TRUE)

dfb$a = ((dfb$wage / 0.5) * dfb$th) * (100 / dfb$gdppc)
dfb$b = ((dfb$wage / 0.5) * dfb$sh) * (100 / dfb$gdppc)
dfb$c = ((dfb$wage / 0.5) * dfb$tl * (-1)) * (100 / dfb$gdppc)
dfb$d = ((dfb$wage / 0.5) * dfb$sl * (-1)) * (100 / dfb$gdppc)

dfb$Var = (dfb$a^2)*V_HR_t + (dfb$b^2)*V_HR_s + (dfb$c^2)*V_LR_t + (dfb$d^2)*V_LR_s + 2*dfb$a*dfb$b*C_HR_t_HR_s + 2*dfb$a*dfb$c*C_HR_t_LR_t + 2*dfb$a*dfb$d*C_HR_t_LR_s + 2*dfb$b*dfb$c*C_HR_s_LR_t + 2*dfb$b*dfb$d*C_HR_s_LR_s + 2*dfb$c*dfb$d*C_LR_t_LR_s
dfb$SE = (dfb$Var)^(0.5)

#==============================================================================#
# 2. Format table ----

# take subset of rows for result
regs = dfa %>% dplyr::select(hierid, diff_dis_p, pop) %>% left_join(dfb %>% dplyr::select(hierid, SE))

regs$diff_dis_p = ifelse(is.na(regs$diff_dis_p), 0, regs$diff_dis_p)

# ===== Get global pop weighted mean and standard deviation ===== #
total_pop = sum(soc_ec$pop, na.rm = TRUE)
mean_val = round(sum(regs$diff_dis_p * regs$pop, na.rm = TRUE) / total_pop, 1)
sd_val = round(sum(regs$SE * regs$pop, na.rm = TRUE) / total_pop, 1)

# ===== Get global pop weighted quantiles ===== #
quants = as.matrix(
  Hmisc::wtd.quantile(x = regs$diff_dis_p, 
                      weights = regs$pop, 
                      probs = c(0.05, 0.1, 0.25, 0.5, 0.75, 0.90, 0.95), 
                      na.rm = TRUE)
)

# create labels and merge with data above
percs = c("5th", "10th", "25th", "50th", "75th", "90th", "95th")
pw_quants = as.data.frame(cbind(percs,quants))

# ===== Pop-weighted averages across agglomerated regions ===== #
# Merge crosswalk onto IR-level results, then collapse to agglom level by
# population-weighting both the point estimate and the delta-method SE.
agglom_data = regs %>%
  inner_join(region_map, by = "hierid") %>%
  filter(!is.na(agglom)) %>%
  group_by(agglom) %>%
  summarise(
    diff_dis_p = sum(diff_dis_p * pop, na.rm = TRUE) / sum(pop, na.rm = TRUE),
    SE = sum(SE * pop, na.rm = TRUE) / sum(pop, na.rm = TRUE),
    .groups = "drop"
  )

# global distribution 
summary_stats = data.frame(label = c("Global average", paste0(pw_quants$percs, " percentile")),
                           value = c(paste0(mean_val, "% (", sd_val, "%)"),
                                     paste0(round(as.numeric(pw_quants$V2), 1), "%")))

# agglomerated regions
city_data = agglom_data %>%
  mutate(value = paste0(round(diff_dis_p, 1), "% (", round(SE, 1), "%)")) %>%
  dplyr::select(label = agglom, value)
 
#==============================================================================#
# 3. PRINT and SAVE ----

message(" ===== TABLE 4 ===== ")
tex_table = kable(rbind(summary_stats, city_data), 
                  format = "latex",
                  col.names = NULL,
                  booktabs = TRUE,
                  align = c("l", "r"))

# print to console
print(tex_table)

# export to .tex file
tex_path = glue("{DIR_TABLE}/table4_hedonic_value{suffix}.tex")
writeLines(as.character(tex_table), tex_path)
message(glue("Wrote LaTeX table to: {tex_path}"))


