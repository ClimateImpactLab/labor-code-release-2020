*****************
*	INITIALIZE
*****************

* get functions and paths
run "/home/kschwarz/repos/labor-code-release-2020/0_subroutines/paths.do"
run "${DIR_REPO_LABOR}/2_analysis/0_subroutines/functions.do"

* log results
cap log close 
log using "${DIR_LOG}/uninteracted_reg_comlohi.smcl", replace

* select dataset and output folder
gl dataset 		"${ROOT_INT_DATA}/labor_dataset_splines_nochn_tmax_chn_prev_week_no_ll_0.dta"
loc reg_folder 	"${DIR_STER}/uninteracted_reg_comlohi"

* other selections
gl test_code "no"
gl reg_list common by_risk
loc fe fe_adm0_wk

********************
*	RUN REGRESSION
********************

* cycle through each of the two regressions
foreach reg in $reg_list {

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

	* differentiate treatment if reg is by risk
	if "`reg'" == "by_risk" loc reg_treatment (${vars_T_splines})##i.high_risk
	else if "`reg'" == "common" loc reg_treatment (${vars_T_splines})
	else di in red "bad reg specification -> pick 'common' or 'by_risk'"

	* both regressions have interacted controls
	local reg_control (${usual_controls})##i.high_risk
	
	* interact each fixed effect with the risk binary
	local reg_fe ""					
	foreach f in $`fe' {
		local reg_fe `reg_fe' `f'#high_risk
	}

	* set the ster file name and the notes to be included
	local ster_name "`reg_folder'/uninteracted_reg_`reg'.ster"
	local spec_desc "rcspline, 3 knots (27 37 39), tmax, differentiated treatment, fe = $fe, reg_type = `reg'"

	di "reghdfe mins_worked `reg_treatment' `reg_control' [pweight = risk_adj_sample_wgt], absorb(`reg_fe') vce(cl cluster_adm1yymm)"
	qui reghdfe mins_worked `reg_treatment' `reg_control' [pweight = risk_adj_sample_wgt], absorb(`reg_fe') vce(cl cluster_adm1yymm)
	estimates notes: "`spec_desc'"
	estimates save "`ster_name'", replace

	di "COMPLETED: `reg' regression."

}

cap log close
