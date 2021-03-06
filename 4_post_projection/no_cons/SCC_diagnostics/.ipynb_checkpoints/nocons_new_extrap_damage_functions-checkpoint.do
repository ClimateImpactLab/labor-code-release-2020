**********************************************************************************
* SET UP -- Change paths and input choices to fit desired output
**********************************************************************************

clear all
set more off
set scheme s1color

glob DB "/mnt"

glob DB_data "$DB/Global_ACP/damage_function"

do "/home/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"
do "$DIR_REPO_LABOR/0_subroutines/paths.do"

* SSP toggle - options are "SSP2", "SSP3", or "SSP4"
loc ssp = "SSP2" 

* Model toggle  - options are "main", "lininter", or "lininter_double"
loc model = "main"

loc model_tag = ""


**********************************************************************************
* STEP 1: Pull in global consumption csv and save as tempfile
**********************************************************************************

import delimited "$DIR_OUTPUT/damage_function_no_cons/global_consumption_all_SSPs.csv", encoding(Big5) clear

rename global_cons_constant_model_colla global_consumption

keep if ssp == "`ssp'"

keep ssp year global_consumption 

sum global_consumption if year == 2099
loc gc_2099 = `r(mean)'

gen ratio = global_consumption/`gc_2099' if year >= 2100

tempfile consumption
save `consumption', replace

**********************************************************************************

*Load in GMTanom data file, save as a tempfile 
insheet using "$DB_data/GMST_anomaly/GMTanom_all_temp_2001_2010_smooth.csv", comma names clear
drop if year < 2010 | year > 2099
tempfile GMST_anom
save `GMST_anom', replace

**********************************************************************************
* STEP 2: Pull in Damage CSVs and Merge with GMST Anomaly Data
**********************************************************************************
loc type = "wages"

import delimited "$ROOT_INT_DATA/projection_outputs/extracted_data_mc/`ssp'-valuescsv_wage_global.csv", varnames(1) clear
drop if year < 2010 | year > 2099
replace value = -value / 1000000000000

merge m:1 year gcm rcp using `GMST_anom'
keep if _m == 3
drop _m
tempfile master
save `master', replace

qui bysort year: egen minT=min(temp)
qui bysort year: egen maxT=max(temp)
qui replace minT=round(minT,0.1)
qui replace maxT=round(maxT,0.1)
qui keep year minT maxT
qui duplicates drop year, force

merge 1:m year using `master', nogen assert(3)

* save "$DIR_REPO_LABOR/output/ce/dfs_mc_batches.csv"

**********************************************************************************
* STEP 3: Estimate damage functions and plot, pre-2100
**********************************************************************************

cap rename temp anomaly

* collapse(mean) minT maxT value anomaly , by(gcm rcp iam year)

**  INITIALIZE FILE WE WILL POST RESULTS TO
capture postutil clear
tempfile coeffs
postfile damage_coeffs str20(var_type) year beta1 beta2 anomalymin anomalymax using "`coeffs'", replace

gen t = year-2010

** Regress, and output coeffs 
foreach vv in value {
  * Nonparametric model for use pre-2100 
  foreach yr of numlist 2015/2099 {
    di "`vv' `yr'"
    reg `vv' c.anomaly##c.anomaly if year>=`yr'-2 & year <= `yr'+2 , nocons
    
    * Need to save the min and max temperature for each year for plotting
    qui summ anomaly if year == `yr', det 
    loc amin = `r(min)'
    loc amax =  `r(max)'
    
    * Save coefficients for all years prior to 2100
    post damage_coeffs ("`vv'") (`yr') (_b[anomaly]) (_b[c.anomaly#c.anomaly]) (`amin') (`amax')
  }

  * Generate predicted coeffs for each year post 2100 with linear extrapolation
  foreach yr of numlist 2100/2300 {
    di "`vv' `yr'"
    loc beta1 = .
    loc beta2 = .
    
    * NOTE: we don't have future min and max, so assume they go through all GMST values   
    post damage_coeffs ("`vv'") (`yr') (`beta1') (`beta2') (0) (11)            
  }   
}

postclose damage_coeffs

**********************************************************************************
* STEP 4: WRITE AND SAVE OUTPUT 
**********************************************************************************

* Format for the specific requirements of the SCC code, and write out results 
use "`coeffs'", clear

merge 1:m year using `consumption'
keep if _m == 3
drop _m

foreach var in "beta1" "beta2"{
  sum `var' if year == 2099
  loc b_`var' = `r(mean)'
  replace `var' = `b_`var''*ratio if year > 2099
}

gen placeholder = "ss"
gen cons = 0
ren var_type growth_rate
order year placeholder growth_rate cons

outsheet using "$DIR_REPO_LABOR/output/damage_function_no_cons/SCC_diagnostics/nocons_df_new_`ssp'`model_tag'.csv", comma replace 
