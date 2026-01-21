*****************
*  INITIALIZE
*****************

* get functions and paths
run "/project/cil/home_dirs/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"
run "${DIR_REPO_LABOR}/2_analysis/0_subroutines/functions.do"

* log results
cap log close 
log using "/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/logs/interacted_splines_lr_interaction_and_mixed_weight_new.smcl", replace

* select dataset and output folder
gl dataset      "/project/cil/battuta_shares/gcp/estimation/labor/code_release_int_data/regression_ready_data/labor_dataset_polynomials_nochn_tmax_chn_prev_week_no_ll_0.dta"
loc reg_folder  "${DIR_OUTPUT}/interacted_reg_output/ster"

* other selections
gl test_code "no"
gl reg_list 2_factor
loc fe fe_adm0_wk
local t_version "tmax"

* Note on weights: 
*   run regression 1_factor with mixed weights (see line 131, 144,)
*   run regression 2_factor with rep_unit_year_sample_wgt

* ---------- CHOOSE WHICH RISK DEFINITION TO USE ---------- 
global risk_def "high_risk"
* --------------------------------------------------------

********************
*  RUN REGRESSION
********************

* cycle through each of the two regressions
foreach reg in $reg_list {
forval N_order=2(1)4 {
	    di "`reg_list'"
	    gl dataset 		"/project/cil/battuta_shares/gcp/estimation/labor/code_release_int_data/regression_ready_data/labor_dataset_polynomials_nochn_tmax_chn_prev_week_no_ll_0.dta"
	    cap mkdir 		"${DIR_STER}/interacted_polynomials"
	    loc reg_folder 	"${DIR_STER}/interacted_polynomials"

		
	    use $dataset, clear
	    drop if iso == "GBR" & year == 1984 & month == 1 & day == 2

	    * if test code mode is on, take a random sample
	    if "${test_code}"=="yes" {
		sample 0.1
	    }

	    * only include non-zero observations
	    keep if mins_worked > 0

	    * generate regression variables
	    gen_controls_and_FEs
	    gen_treatment_polynomials `N_order' tmax this_week 1

	    * ---------- DEFINE risk_level FROM CHOSEN SOURCE ----------
	    cap drop risk_level
	    gen risk_level = .
	    replace risk_level = high_risk_old if "${risk_def}"=="high_risk_old"
	    replace risk_level = high_risk        if "${risk_def}"=="high_risk"
	    replace risk_level = sector if "${risk_def}"=="sector"
	    replace risk_level = occup_code if "${risk_def}"=="occup_code"
	    * ----------------------------------------------------------

	    * generate variables for the pooled regression to get the correct coeffs for LR group
	    gen low_risk = 1 - risk_level
*******need add 
	    if "`reg'" == "1_factor" loc reg_treatment tmax_rcspl_3kn_t0_lr* tmax_rcspl_3kn_t1_lr* tmax_rcspl_3kn_t0_hr* tmax_rcspl_3kn_t1_hr*

	    *** This will give you un-useable estimate for LR
	    *if "`reg'" == "1_factor" loc reg_treatment (${vars_T_splines} ${vars_T_x_gdp_splines})##i.risk_level
	  
	    else if "`reg'" == "2_factor" loc reg_treatment (${vars_T_polynomials} ${vars_T_x_gdp_polynomials} ${vars_T_x_lr_`t_version'_polynomials})##i.risk_level
	    else di in red "bad reg specification -> pick '1 factor' or '2 factor'"
	    di "`reg_treatment'"

	    * both regressions have interacted controls
	    local reg_control (${usual_controls})##i.risk_level
	    di "`reg_control'"
	    
	    * interact each fixed effect with the risk binary
	    local reg_fe ""                    
	    foreach f in $`fe' {
		local reg_fe `reg_fe' `f'#risk_level
	    }
	* -------------------------------------------------------------------------------------------------------
	    * set the ster file name and the notes to be included
	    local ster_name "`reg_folder'/interacted_polynomials_`reg'_`N_order'_2025.ster"
	    local spec_desc "rcspline, 3 knots (27 37 39), tmax, differentiated treatment withlr interaction, fe = $fe, reg_type = `reg'"

	* -------------------------------------------------------------------------------------------------------
	    * set the regression weight
	    *replace risk_adj_sample_wgt = rep_unit_year_sample_wgt if risk_level == 1
	    loc weight "rep_unit_year_sample_wgt"

	    di "reghdfe mins_worked `reg_treatment' `reg_control' [pweight = `weight'], absorb(`reg_fe') vce(cl cluster_adm1yymm)"
	    reghdfe mins_worked `reg_treatment' `reg_control' [pweight = `weight'], absorb(`reg_fe') vce(cl cluster_adm1yymm)

	    * count regression N by risk
	    gen included = e(sample)
	    count if included == 1 & risk_level == 0
	    estadd scalar low_N = `r(N)'
	    count if included == 1 & risk_level == 1
	    estadd scalar high_N = `r(N)'
	 *   count if included == 1 & risk_level == 2
	  *  estadd scalar nonag_N = `r(N)'

	    estimates notes: "`spec_desc' representative unit-year weights"
	    estimates save "`ster_name'", replace

	    di "COMPLETED: `reg' regression."
	}
}

cap log close
