**********************************************************************************
* SET UP -- Change paths and input choices to fit desired output
**********************************************************************************

clear all
set more off
set scheme s1color

glob DB "/mnt"

glob DB_data "$DB/Global_ACP/damage_function"
glob dir "$DB_data/projection_system_outputs/damage_function_estimation/resampled_data"

do "/home/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"
do "$DIR_REPO_LABOR/0_subroutines/paths.do"

glob output "$DIR_FIG/mc/"

* SSP toggle - options are "SSP2", "SSP3", or "SSP4"
loc ssp = "SSP3" 

* Model toggle  - options are "main", "lininter", or "lininter_double"
loc model = "main"

* What year do we use data from for determining DF estimates used for the out of sample extrapolation
loc subset = 2085


loc model_tag = ""

* **********************************************************************************
* * STEP 1: Pull in global consumption csv and save as tempfile
* **********************************************************************************

import delimited "$DIR_REPO_LABOR/output/damage_function_no_cons/unmodified_betas/global_consumption.csv", encoding(Big5) clear

keep model ssp year global_cons_ramsey 
collapse (mean) global_cons_ramsey, by(year) 

sum global_cons_ramsey if year == 2099
loc gc_2099 = `r(mean)'

gen ratio = global_cons_ramsey/`gc_2099' if year >= 2100

tempfile consumption
save `consumption', replace

*****************************************************************************************

import delimited "$DIR_REPO_LABOR/output/damage_function_no_cons/unmodified_betas/nocons_smooth_df_mean_output_SSP3.csv", clear 

keep year cons beta1 beta2 

merge 1:m year using `consumption'
keep if _m == 3
drop _m

foreach var in "beta1" "beta2"{
	sum `var' if year == 2099
	loc b_`var' = `r(mean)'
	replace `var' = `b_`var''*ratio if year > 2099
}

sum beta1 beta2, d

export delimited using "$DIR_REPO_LABOR/output/damage_function_no_cons/nocons_betas_SSP3.csv", replace 

*****************************************************************************************

import delimited "$DIR_REPO_LABOR/output/damage_function_no_cons/unmodified_betas/nocons_ce_df_coeffs_SSP3.csv", clear 

keep year cons beta1 beta2 

merge 1:m year using `consumption'
keep if _m == 3
drop _m

foreach var in "beta1" "beta2"{
	sum `var' if year == 2099
	loc b_`var' = `r(mean)'
	replace `var' = `b_`var''*ratio if year > 2099
}

sum beta1 beta2, d

export delimited using "$DIR_REPO_LABOR/output/damage_function_no_cons/ce_betas_SSP3.csv", replace 
