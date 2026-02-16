*****************
*	INITIALIZE
*****************

* get functions and paths
run "/home/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"
run "${DIR_REPO_LABOR}/2_analysis/0_subroutines/functions.do"

* log results
cap log close 
log using "${DIR_LOG}/uninteracted_bins.smcl", replace


* setting folders and data
gl dataset 		"${ROOT_INT_DATA}/regression_ready_data/labor_dataset_bins_tmax_chn_prev_week_no_ll_0_0Cto42C_3Cbins.dta"
loc reg_folder 	"${DIR_STER}/uninteracted_bins"

* other selections
gl test_code "no"
loc fe fe_adm0_wk

gl reg_list nochn
gl bin_width 3C

****************************************
*	RUN REGRESSION - WITH AND WITHOUT CHINA
****************************************

* with and without China
foreach reg in $reg_list {

	* select dataset and output folder

		use $dataset, clear

		* if test code mode is on, take a random sample
		if "${test_code}"=="yes" {
			sample 0.1
		}

		* drop China if not included
		if "`reg'" == "nochn" drop if iso == "CHN"

		* only include non-zero observations
		keep if mins_worked > 0

		* generate regression variables
		gen_controls_and_FEs
		* arguments are: start, end, ref, below_temp, above_temp
		gen_treatment_bins 14 27 22 0 42
		
		* differentiate treatment if reg is by risk
		loc reg_treatment (${varlist_bins_${bin_width}})##i.high_risk

		* both regressions have interacted controls
		local reg_control (${usual_controls})##i.high_risk

		* interact each fixed effect with the risk binary
		local reg_fe ""					
		foreach f in $`fe' {
			local reg_fe `reg_fe' `f'#high_risk
		}

		* set the ster file name and the notes to be included
		local ster_name "`reg_folder'/uninteracted_bins_`reg'_${bin_width}.ster"
		local spec_desc "${bin_width} bin regression with above42 and below0 bins, reg = `reg', tmax, differentiated treatment, fe = `fe'"

		di "reghdfe mins_worked `reg_treatment' `reg_control' [pweight = risk_adj_sample_wgt], absorb(`reg_fe') vce(cl cluster_adm1yymm)"
		qui reghdfe mins_worked `reg_treatment' `reg_control' [pweight = risk_adj_sample_wgt], absorb(`reg_fe') vce(cl cluster_adm1yymm)
		estimates notes: "`spec_desc'"
		estimates save "`ster_name'", replace
}

cap log close


     
