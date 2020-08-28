*****************
*	INITIALIZE
*****************

* log results
cap log close 
log using "/home/kschwarz/logs/uninteracted_reg_FEs.smcl", replace

* set paths to access functions
gl REPO 	"/home/kschwarz/repos"
gl code_dir "${REPO}/gcp-labor/code_release"
do "${code_dir}/1_estimation/functions.do"

init, install(none)

* select dataset and output folder
gl dataset 		"${data_dir}/labor_dataset_splines_nochn_tmax_chn_prev_week_no_ll_0.dta"
loc reg_folder 	"${output_dir}/ster/uninteracted_reg_FEs"
loc rf_folder 	"${output_dir}/rf/uninteracted_reg_FEs"

* other selections
global test_code "no"
global fe_list fe_adm0_y fe_adm0_my fe_adm0_wk fe_adm3_my 
global ref_temp 27 

* select this for the full response function
* numlist "-20(0.1)47"
* otherwise select this for 6 table values
numlist "40 35 30 10 5 0"

gl row_values `r(numlist)'

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


***********************************
*	GENERATE RESPONSE FUNCTION CSV
***********************************

foreach fe in $fe_list {

	* set the ster file name and the output CSV
	local ster_name	"`reg_folder'/uninteracted_reg_FE_`fe'.ster"
	local rf_name 	"`rf_folder'/uninteracted_reg_FE_`fe'.csv"
	
	* create the temp list that we want to predict for
	make_temp_dist, list($row_values) ref($ref_temp)
	est use `ster_name'

	* generate spline terms and collect in macros
	make_spline_terms 27 37 39
	collect_spline_terms, splines(0 1) unint(unint) int(int)

	* need this blank variable to get standard errors in predictnl
	gen mins_worked = .

	* predict response function by risk
		predictnl yhat_low =	(T_spline0 - ref_spline0) * (${unint0}) +			///
								(T_spline1 - ref_spline1) * (${unint1}), 			///
								ci(lowerci_low upperci_low) se(se_low)

		predictnl yhat_high =	(T_spline0 - ref_spline0) * (${unint0} + ${int0}) +	///
								(T_spline1 - ref_spline1) * (${unint1} + ${int1}),	///
								ci(lowerci_high upperci_high) se(se_high)

	drop T* ref_* min*
	export delim `rf_name', replace
	clear

}

cap log close 
   
