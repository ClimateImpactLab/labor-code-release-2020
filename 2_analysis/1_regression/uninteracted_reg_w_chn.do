*****************
*	INITIALIZE
*****************

* get functions and paths
run "/home/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"
run "${DIR_REPO_LABOR}/2_analysis/0_subroutines/functions.do"

* log results
cap log close 
log using "${DIR_LOG}/uninteracted_reg_w_chn.smcl", replace

* select dataset and output folder
gl dataset 		"${ROOT_INT_DATA}/regression_ready_data/labor_dataset_splines_wchn_tmax_chn_prev_week_no_ll_0.dta"
loc reg_folder 	"${DIR_STER}/uninteracted_reg_w_chn"

* other selections
gl test_code "no"
gl spline 21_37_41
loc fe fe_adm0_wk

********************
*	RUN REGRESSION
********************

use $dataset, clear

* if test code mode is on, take a random sample
if "${test_code}"=="yes" {
	sample 0.1
}

* only include non-zero observations
keep if mins_worked > 0

* get rid of some awkward naming
rename *${spline}_* **

* generate regression variables
gen_controls_and_FEs
gen_treatment_splines rcspl 3 tmax this_week 1

* differentiate treatment if reg is by risk
loc reg_treatment (${vars_T_splines})##i.high_risk
* both regressions have interacted controls
local reg_control (${usual_controls})##i.high_risk

* interact each fixed effect with the risk binary
local reg_fe ""					
foreach f in $`fe' {
	local reg_fe `reg_fe' `f'#high_risk
}

* get weight
loc weight "risk_adj_sample_wgt"

* set the ster file name and the notes to be included
local ster_name "`reg_folder'/uninteracted_reg_w_chn.ster"
local spec_desc "rcspline, 3 knots (${spline}), tmax, differentiated treatment, fe = $fe"

di "reghdfe mins_worked `reg_treatment' `reg_control' [pweight = `weight'], absorb(`reg_fe') vce(cl cluster_adm1yymm)"
qui reghdfe mins_worked `reg_treatment' `reg_control' [pweight = `weight'], absorb(`reg_fe') vce(cl cluster_adm1yymm)

* count regression N by risk
gen included = e(sample)
count if included == 1 & high_risk == 1
estadd scalar high_N = `r(N)'
count if included == 1 & high_risk == 0
estadd scalar low_N = `r(N)'

estimates notes: "`spec_desc'"
estimates save "`ster_name'", replace

cap log close
   
