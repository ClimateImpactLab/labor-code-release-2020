*****************
*	INITIALIZE
*****************

* get functions and paths
run "/home/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"
run "${DIR_REPO_LABOR}/2_analysis/0_subroutines/functions.do"

* log results
cap log close 
log using "/home/nsharma/repos/logs/interacted_splines.smcl", replace

* select dataset and output folder
gl dataset 		"${ROOT_INT_DATA}/regression_ready_data/labor_dataset_splines_nochn_tmax_chn_prev_week_no_ll_0.dta"
loc reg_folder 	"${DIR_STER}/interacted_splines"

* other selections
gl test_code "no"
gl reg_list 1_factor 2_factor
loc fe fe_adm0_wk

********************
*	RUN REGRESSION
********************

* cycle through each of the two regressions
foreach reg in $reg_list {

	di "`reg_list'"

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
	if "`reg'" == "1_factor" loc reg_treatment (${vars_T_splines} ${vars_T_x_gdp_splines})##i.high_risk
	else if "`reg'" == "2_factor" loc reg_treatment (${vars_T_splines} ${vars_T_x_gdp_splines} ${vars_T_x_lr_tmax_splines})##i.high_risk
	else di in red "bad reg specification -> pick '1 factor' or '2 factor'"
	di "`reg_treatment'"

	* both regressions have interacted controls
	local reg_control (${usual_controls})##i.high_risk
	di "`reg_control'"
	
	* interact each fixed effect with the risk binary
	local reg_fe ""					
	foreach f in $`fe' {
		local reg_fe `reg_fe' `f'#high_risk
	}

	* set the ster file name and the notes to be included
	local ster_name "`reg_folder'/interacted_reg_`reg'_test.ster"
	local spec_desc "rcspline, 3 knots (27 37 39), tmax, differentiated treatment, fe = $fe, reg_type = `reg'"

	* set the regression weight
	loc weight "rep_unit_year_sample_wgt"

	di "reghdfe mins_worked `reg_treatment' `reg_control' [pweight = `weight'], absorb(`reg_fe') vce(cl cluster_adm1yymm)"
	reghdfe mins_worked `reg_treatment' `reg_control' [pweight = `weight'], absorb(`reg_fe') vce(cl cluster_adm1yymm)

	* count regression N by risk
	gen included = e(sample)
	count if included == 1 & high_risk == 1
	estadd scalar high_N = `r(N)'
	count if included == 1 & high_risk == 0
	estadd scalar low_N = `r(N)'

	estimates notes: "`spec_desc'"
	estimates save "`ster_name'", replace

	di "COMPLETED: `reg' regression."

}

cap log close
