*****************
*	INITIALIZE
*****************

* get functions and paths
run "/project/cil/home_dirs/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"
run "${DIR_REPO_LABOR}/2_analysis/0_subroutines/functions.do"
run "/project/cil/home_dirs/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"
run "/project/cil/home_dirs/`c(username)'/repos/labor-code-release-2020/2_analysis/0_subroutines/utils.do"

* log results
cap log close 
log using "${DIR_LOG}/uninteracted_polynomials.smcl", replace

* other selections
gl test_code "no"
loc fe fe_adm0_wk

gl reg_list nochn

* ---------- CHOOSE WHICH RISK DEFINITION TO USE ----------
* options: "high_risk" or "high_risk_old"
global risk_def "high_risk" 
* ---------------------------------------------------------

****************************************
*	RUN REGRESSION - WITH AND WITHOUT CHINA
****************************************

* with and without China
foreach reg in $reg_list {

	* for each order of polynomial in 2, 3, 4
	forval N_order=2(1)4 {

		* select dataset and output folder
		gl dataset 		"/project/cil/battuta_shares/gcp/estimation/labor/code_release_int_data/regression_ready_data/z_old/labor_dataset_polynomials_nochn_tmax_chn_prev_week_no_ll_0.dta"
		cap mkdir 		"${DIR_STER}/uninteracted_polynomials"
		loc reg_folder 	"${DIR_STER}/uninteracted_polynomials"

		use $dataset, clear

		* if test code mode is on, take a random sample
		if "${test_code}"=="yes" {
			sample 0.1
		}

		* only include non-zero observations
		keep if mins_worked > 0
		
		* ---------- DEFINE risk_level FROM CHOSEN SOURCE ----------
		cap drop risk_level 
		gen risk_level = .   
		replace risk_level = high_risk     if "${risk_def}"=="high_risk"
	*	replace risk_level = high_risk_old if "${risk_def}"=="high_risk_old"
	*	replace risk_level = sector if "${risk_def}"=="sector"
	*	replace risk_level = occup_code if "${risk_def}"=="occup_code"
	
		* generate regression variables
		gen_controls_and_FEs
		gen_treatment_polynomials `N_order' tmax this_week 1

		* differentiate treatment if reg is by risk
		loc reg_treatment (${vars_T_polynomials})##i.risk_level
		* both regressions have interacted controls
		local reg_control (${usual_controls})##i.risk_level

		* interact each fixed effect with the risk binary
		local reg_fe "adm3_id#risk_level dow_week#risk_level adm0_id#year#risk_level adm0_id#week_fe#risk_level"


* -------------------------------------------------------------------------------------------------------
		* set the ster file name and the notes to be included
		local ster_name "`reg_folder'/uninteracted_polynomials_`reg'_`N_order'_2025_oldold.ster"
		local spec_desc "polynomial, uninteracted_polynomials_`reg', order = `N_order', tmax, differentiated treatment, fe = `fe'"
* -------------------------------------------------------------------------------------------------------
		di "reghdfe mins_worked `reg_treatment' `reg_control' [pweight = risk_adj_sample_wgt], absorb(`reg_fe') vce(cl cluster_adm1yymm)"
		qui reghdfe mins_worked `reg_treatment' `reg_control' [pweight = risk_adj_sample_wgt], absorb(`reg_fe') vce(cl cluster_adm1yymm)
		estimates notes: "`spec_desc'"
		estimates save "`ster_name'", replace

	}
}

cap log close
