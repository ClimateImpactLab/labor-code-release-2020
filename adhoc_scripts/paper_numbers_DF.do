/*

Purpose: plot labor end-of-century damage function (no constant) 
with points, curve, and confidence interval

*/


clear all
set more off
set scheme s1color


glob DB "/mnt"

glob DB_data "$DB/Global_ACP/damage_function"

do "/home/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"

glob output "$DIR_FIG/mc/"


*Load in GMTanom data file, save as a tempfile 
insheet using "$DB_data/GMST_anomaly/GMTanom_all_temp_2001_2010_smooth.csv", comma names clear
drop if year < 2010 | year > 2099
tempfile GMST_anom
drop if temp == .
save `GMST_anom', replace

* **********************************************************************************
* * STEP 1: Pull in Damage CSVs and Merge with GMST Anomaly Data
* **********************************************************************************
loc type = "wages"

import delimited "$ROOT_INT_DATA/projection_outputs/extracted_data_mc/SSP3-valuescsv_wage_global.csv", varnames(1) clear
drop if year < 2010 | year > 2099
replace value = -value 
* / 1000000000000

merge m:1 year gcm rcp using `GMST_anom', nogen assert(3)
tempfile master
save `master', replace

qui bysort year: egen minT=min(temp)
qui bysort year: egen maxT=max(temp)
qui replace minT=round(minT,0.1)
qui replace maxT=round(maxT,0.1)
qui keep year minT maxT
qui duplicates drop year, force

merge 1:m year using `master', nogen assert(3)


* **********************************************************************************
* * STEP 2: Estimate damage functions and plot, pre-2100
* **********************************************************************************

cap rename temp anomaly



* Nonparametric model for use pre-2100 
foreach yr of numlist 2099/2099 {
      qui reg value c.anomaly##c.anomaly if year>=`yr'-2 & year <= `yr'+2, nocons
      drop if _n > 0
      set obs 2
      gen beta1 = _b[c.anomaly]
      gen beta2 = _b[c.anomaly#c.anomaly]
      replace anomaly = 1 if _n == 1
      replace anomaly = 5 if _n == 2
      cap qui predict yhat_`yr'_trillion
}

keep beta1 beta2 anomaly yhat_2099_trillion



gen gdp_ssp3_highlow_avg_2099 = 344899876500631.5
gen gdp_ssp3_global_consumption_2099 = 344716964716523

export delimited "$DIR_REPO_LABOR/output/end_of_century_DF_responses_pct_gdp", replace


* CE version

import delimited "/mnt/CIL_labor/6_ce/risk_aversion_constant/risk_aversion_constant_damage_function_points.csv", varnames(1) clear
drop if year < 2010 | year > 2099
rename global_damages_constant value
drop if ssp != "SSP3"
replace value = value 
*/ 1000000000000

merge m:1 year gcm rcp using `GMST_anom', nogen keep(3)
tempfile master
save `master', replace

qui bysort year: egen minT=min(temp)
qui bysort year: egen maxT=max(temp)
qui replace minT=round(minT,0.1)
qui replace maxT=round(maxT,0.1)
qui keep year minT maxT
qui duplicates drop year, force

merge 1:m year using `master', nogen assert(3)


* **********************************************************************************
* * STEP 2: Estimate damage functions and plot, pre-2100
* **********************************************************************************

cap rename temp anomaly


* Nonparametric model for use pre-2100 
foreach yr of numlist 2099/2099 {
      qui reg value c.anomaly##c.anomaly if year>=`yr'-2 & year <= `yr'+2, nocons
      drop if _n > 0
      set obs 2
      gen beta1 = _b[c.anomaly]
      gen beta2 = _b[c.anomaly#c.anomaly]
      replace anomaly = 1 if _n == 1
      replace anomaly = 5 if _n == 2
      cap qui predict yhat_`yr'_trillion   
}

keep beta1 beta2 anomaly yhat_2099_trillion

conversion_value = 1.273526
gen gdp_ssp3_highlow_avg_2099 = 344899876500631.5 / conversion_value
gen gdp_ssp3_global_consumption_2099 = 344716964716523 / conversion_value

export delimited "$DIR_REPO_LABOR/output/end_of_century_DF_responses_pct_gdp_CE", replace







/* 

import delimited "$DIR_REPO_LABOR/output/damage_function_no_cons/unmodified_betas/global_consumption_new.csv", encoding(Big5) clear

rename global_cons_constant_model_colla global_consumption
keep ssp year global_consumption 
format global_consumption %20.0f
list if year == 2090


/* 
import delimited using "/mnt/CIL_energy/code_release_data_pixel_interaction/projection_system_outputs/covariates/SSP3-high-global-gdp-time_series.csv", clear
format gdp %20.0f
list if year == 2090

import delimited using "/mnt/CIL_energy/code_release_data_pixel_interaction/projection_system_outputs/covariates/SSP3-low-global-gdp-time_series.csv", clear
format gdp %20.0f */
list if year == 2090

3.447e+14
loc ssp3_global_gdp = (336158149056357 + 353641603944906)/2

344716964716523
344899876500631.5


import delimited using "/mnt/CIL_labor/3_projection/global_gdp_time_series.csv", clear
 */
