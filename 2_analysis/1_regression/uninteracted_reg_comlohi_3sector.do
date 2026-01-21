****************************************************
* This file runs the main regression.
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
log using "${DIR_LOG}/uninteracted_reg_comlohi_3sector.smcl", replace

* select dataset and output folder
gl dataset      "/project/cil/battuta_shares/gcp/estimation/labor/code_release_int_data/regression_ready_data/labor_dataset_splines_nochn_tmax_chn_prev_week_no_ll_0_agnonag_272841.dta"
loc reg_folder  "${DIR_STER}/uninteracted_reg_comlohi"

* other selections
gl test_code "no"
gl reg_list by_risk common
loc fe fe_adm0_wk

* ---------- CHOOSE WHICH RISK DEFINITION TO USE ----------
* options: "high_risk" or "high_risk_old"
global risk_def "sector" 
* ---------------------------------------------------------

********************
*  RUN REGRESSION
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
    local ster_name "`reg_folder'/uninteracted_reg_`reg'_2025_272841_sector.ster"
    local spec_desc "rcspline, 3 knots (27 28 41), tmax, differentiated treatment, fe = $fe, reg_type = `reg'"
    
* -------------------------------------------------------------------------------------------------------
    * set the regression weight (pop_adj for common, risk_adj for by-risk)
    if "`reg'" == "common" loc weight "pop_adj_sample_wgt"
    else loc weight "risk_adj_sample_wgt_sector"

    di "reghdfe mins_worked `reg_treatment' `reg_control' [pweight = `weight'], absorb(`reg_fe') vce(cl cluster_adm1yymm)"
    reghdfe mins_worked `reg_treatment' `reg_control' [pweight = `weight'], absorb(`reg_fe') vce(cl cluster_adm1yymm)

    * count regression N by risk
    gen included = e(sample)
    count if included == 1 & risk_level == 1       
    estadd scalar ag_N = `r(N)'
    count if included == 1 & risk_level == 0      
    estadd scalar low_N = `r(N)'
    count if included == 1 & risk_level == 2
    estadd scalar nonag_N = `r(N)'

    estimates notes: "`spec_desc'"
    estimates save "`ster_name'", replace

    di "COMPLETED: `reg' regression."

}

cap log close
