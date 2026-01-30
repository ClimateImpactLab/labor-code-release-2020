****************************************************
* This file runs the main regression by three groups - low, non-ag, ag.
* Modified to create weights in memory without saving intermediate dataset
*
* How to use:
*   1. Log in to a computing node.
*   2. Update the following settings in this file:
*        - logs
*        - dataset
*        - risk_def
*        - ster_name
*        - weight
*   3. Weight naming convention:
*        - For low-risk and sector-specific regressions, 
*          add the suffix "_old" or "_sector" to the weight variable.
*        - For high-risk regressions, use the weight variable
*          without any suffix.
*   4. For "sector", change: (you can also use "uninteracted_reg_comlohi_3sector.do")
*	*count regression N by risk
*	gen included = e(sample)
*	count if included == 1 & risk_level == 1       
*	estadd scalar ag_N = `r(N)'
*	count if included == 1 & risk_level == 0      
*	estadd scalar low_N = `r(N)'
*	count if included == 1 & risk_level == 2
*	estadd scalar nonag_N = `r(N)'
*
* Runtime:
*   - Approximately 2 hours.
****************************************************

*****************
*  INITIALIZE
*****************

* get functions and paths
run "/project/cil/home_dirs/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"
run "${DIR_REPO_LABOR}/2_analysis/0_subroutines/functions.do"

* log results
cap log close 
*--------------------------------------------------------
log using "${DIR_LOG}/uninteracted_reg_comlohi_occup.smcl", replace

* select dataset and output folder
gl dataset      "/project/cil/battuta_shares/gcp/estimation/labor/code_release_int_data/regression_ready_data/labor_dataset_splines_nochn_tmax_chn_prev_week_no_ll_0_agnonag_272841_0121.dta"
loc reg_folder  "${DIR_STER}/uninteracted_reg_comlohi"

* other selections
gl test_code "no"
gl reg_list by_risk common
loc fe fe_adm0_wk

* ---------- CHOOSE WHICH RISK DEFINITION TO USE ----------
* options: "high_risk" or "high_risk_old"
global risk_def "occup_code" 
* ---------------------------------------------------------

*****************
*  LOAD DATA AND CREATE WEIGHTS
*****************

use "$dataset", clear

	capture program drop create_risk_weights
	program define create_risk_weights
	
		syntax varname, base_weight(varname) [suffix(string)]
    
		* Store the grouping variable name
		local group_var `varlist'
    
		* Set default suffix to empty if not provided
		if "`suffix'" == "" {
			local suffix ""
		}
    
		* Calculate proportions within iso
		bysort iso `group_var': gen `group_var'_prop = _N 
		by iso: replace `group_var'_prop = `group_var'_prop/_N 
    
		* Adjust weights by proportion
		gen risk_adj_sample_wgt`suffix' = `base_weight' * `group_var'_prop
		bysort `group_var': egen `group_var'_sum = total(risk_adj_sample_wgt`suffix')
		gen total_`group_var'_share = _N 
		bysort `group_var': replace total_`group_var'_share = _N / total_`group_var'_share
		replace risk_adj_sample_wgt`suffix' = risk_adj_sample_wgt`suffix' / `group_var'_sum * total_`group_var'_share
    
		* clean up
		drop total_`group_var'_share `group_var'_prop `group_var'_sum
    
		* Representative unit sample weights - by rep_unit
		gegen rep_unit_tot_wgt`suffix' = total(risk_adj_sample_wgt`suffix'), by(rep_unit)
		gen rep_unit_sample_wgt`suffix' = risk_adj_sample_wgt`suffix'/rep_unit_tot_wgt`suffix'
		gegen test_sum`suffix' = total(rep_unit_sample_wgt`suffix'), by(rep_unit)
    
		* Representative unit sample weights - by rep_unit and year
		gegen rep_unit_year_tot_wgt`suffix' = total(risk_adj_sample_wgt`suffix'), by(rep_unit year)
		gen rep_unit_year_sample_wgt`suffix' = risk_adj_sample_wgt`suffix'/rep_unit_year_tot_wgt`suffix'
		gegen test_sum_2`suffix' = total(rep_unit_year_sample_wgt`suffix'), by(rep_unit year)
    
		* Test weights
		count if (round(test_sum`suffix') != 1) | (round(test_sum_2`suffix') != 1)
		if `r(N)' != 0 {
			di as error "Whoops, you biffed it! Sample weights for `group_var' don't add to 1."
		}
		else {
			di as result "Great job, sample weights for `group_var' correctly generated."
			drop rep_unit_tot_wgt`suffix' rep_unit_year_tot_wgt`suffix' test_sum`suffix' test_sum_2`suffix'
		}
    
	end

	* run function to create weights for each of the three variables. Occupations code weights to
	* be made in regression script for flexibility
	create_risk_weights occup_code, base_weight(pop_adj_sample_wgt) suffix(_occup)

********************
*  RUN REGRESSION
********************

* cycle through each of the two regressions
foreach reg in $reg_list {

    di "`reg_list'"

    preserve

    * if test code mode is on, take a random sample
    if "${test_code}"=="yes" {
        sample 0.1
    }

    * only include non-zero observations
    keep if mins_worked > 0

    * get rid of some awkward naming
    rename *27_28_41_* ** 

    * ---------- DEFINE risk_level FROM CHOSEN SOURCE ----------
    cap drop risk_level 
    gen risk_level = .   
    replace risk_level = high_risk     if "${risk_def}"=="high_risk"
    replace risk_level = high_risk_old if "${risk_def}"=="high_risk_old"
    replace risk_level = sector if "${risk_def}"=="sector"
    replace risk_level = occup_code if "${risk_def}"=="occup_code"

    * generate regression variables
    gen_controls_and_FEs
    gen_treatment_splines rcspl 3 tmax this_week 1

    * differentiate treatment if reg is by risk
    if "`reg'" == "by_risk" loc reg_treatment (${vars_T_splines})##i.risk_level 
    else if "`reg'" == "common" loc reg_treatment (${vars_T_splines})
    else di in red "bad reg specification -> pick 'common' or 'by_risk'"
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
    local ster_name "`reg_folder'/uninteracted_reg_`reg'_2026_272841_occup.ster"
    local spec_desc "rcspline, 3 knots (27 28 41), tmax, differentiated treatment, fe = $fe, reg_type = `reg'"
    
* -------------------------------------------------------------------------------------------------------
    * set the regression weight (pop_adj for common, risk_adj for by-risk)
    if "`reg'" == "common" loc weight "pop_adj_sample_wgt"
    else loc weight "risk_adj_sample_wgt_occup"

    di "reghdfe mins_worked `reg_treatment' `reg_control' [pweight = `weight'], absorb(`reg_fe') vce(cl cluster_adm1yymm)"
    reghdfe mins_worked `reg_treatment' `reg_control' [pweight = `weight'], absorb(`reg_fe') vce(cl cluster_adm1yymm)

    * count regression N by risk
    gen included = e(sample)
    count if included == 1 & risk_level == 1       
    estadd scalar ag_N = `r(N)'
    count if included == 1 & risk_level == 0      
    estadd scalar low_N = `r(N)'
    count if included == 1 & risk_level == 2
    estadd scalar manuf_N = `r(N)'
    count if included == 1 & risk_level == 3
    estadd scalar con_N = `r(N)'
    
    estimates notes: "`spec_desc'"
    estimates save "`ster_name'", replace

    di "COMPLETED: `reg' regression."
    
    restore

}

cap log close
