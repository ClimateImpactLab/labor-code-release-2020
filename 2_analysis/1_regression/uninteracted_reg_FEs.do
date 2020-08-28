*****************
*	INITIALIZE
*****************

* get functions and paths
run "/home/kschwarz/repos/labor-code-release-2020/0_subroutines/paths.do"
run "${DIR_REPO_LABOR}/2_analysis/0_subroutines/functions.do"

* log results
cap log close 
log using "${DIR_LOG}/uninteracted_reg_FEs.smcl", replace

* select dataset and output folder
gl dataset 		"${ROOT_INT_DATA}/labor_dataset_splines_nochn_tmax_chn_prev_week_no_ll_0.dta"
loc reg_folder 	"${DIR_STER}/uninteracted_reg_FEs"

* other selections
global test_code "no"
global fe_list fe_adm0_y fe_adm0_my fe_adm0_wk fe_adm3_my 

********************
*	RUN REGRESSION
********************

* cycle through each fixed effect selected
foreach fe in $fe_list {

	use $dataset, clear

	* if test code mode is on, take a random sample
	if "${test_code}"=="yes" {
		sample 0.1
	}

	* only include non-zero observations
	keep if mins_worked > 0

	* get rid of some awkward naming
	rename *27_37_39_* **

	* generate regression variables
	gen_controls_and_FEs
	gen_treatment_splines rcspl 3 tmax this_week 1
	local reg_treatment (${vars_T_splines})##i.high_risk
	local reg_control (${usual_controls})##i.high_risk
	
	* interact each fixed effect with the risk binary
	local reg_fe ""					
	foreach f in $`fe' {
		local reg_fe `reg_fe' `f'#high_risk
	}

	* set the ster file name and the notes to be included
	local ster_name "`reg_folder'/uninteracted_reg_FE_`fe'.ster"
	local spec_desc "rcspline, 3 knots (27 37 39), tmax, differentiated treatment, fe = `fe'"

	di "reghdfe mins_worked `reg_treatment' `reg_control' [pweight = risk_adj_sample_wgt], absorb(`reg_fe') vce(cl cluster_adm1yymm)"
	qui reghdfe mins_worked `reg_treatment' `reg_control' [pweight = risk_adj_sample_wgt], absorb(`reg_fe') vce(cl cluster_adm1yymm)
	estimates notes: "`spec_desc'"
	estimates save "`ster_name'", replace

	di "COMPLETED: reg with `fe' fixed effects."

}

cap log close
