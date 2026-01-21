****************************************************
* This file runs the main interacted regression.
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
*   - Approximately 2-3 hours.
****************************************************






*****************
*  INITIALIZE
*****************

* get functions and paths
run "/project/cil/home_dirs/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"
run "${DIR_REPO_LABOR}/2_analysis/0_subroutines/functions.do"

* log results
cap log close 
log using "/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/logs/interacted_splines_lr_interaction_and_mixed_weight_0120.smcl", replace

* select dataset and output folder
gl dataset      "/project/cil/battuta_shares/gcp/estimation/labor/code_release_int_data/regression_ready_data/labor_dataset_splines_nochn_tmax_chn_prev_week_no_ll_0_agnonag_272841.dta"
loc reg_folder  "${DIR_OUTPUT}/interacted_reg_output/ster"

* other selections
gl test_code "no"
gl reg_list 2_factor
loc fe fe_adm0_wk

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

    di "`reg_list'"

    use $dataset, clear
    drop if iso == "GBR" & year == 1984 & month == 1 & day == 2

    * if test code mode is on, take a random sample
    if "${test_code}"=="yes" {
        sample 0.1
    }

    * only include non-zero observations
    keep if mins_worked > 0

    * get rid of some awkward naming
    rename *27_28_41_* **

    * generate regression variables
    gen_controls_and_FEs
    gen_treatment_splines rcspl 3 tmax this_week 1

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

    gen tmax_rcspl_3kn_t0_lr    = tmax_rcspl_3kn_t0    * low_risk
    gen tmax_rcspl_3kn_t0_lr_v1 = tmax_rcspl_3kn_t0_v1 * low_risk
    gen tmax_rcspl_3kn_t0_lr_v2 = tmax_rcspl_3kn_t0_v2 * low_risk
    gen tmax_rcspl_3kn_t0_lr_v3 = tmax_rcspl_3kn_t0_v3 * low_risk
    gen tmax_rcspl_3kn_t0_lr_v4 = tmax_rcspl_3kn_t0_v4 * low_risk
    gen tmax_rcspl_3kn_t0_lr_v5 = tmax_rcspl_3kn_t0_v5 * low_risk
    gen tmax_rcspl_3kn_t0_lr_v6 = tmax_rcspl_3kn_t0_v6 * low_risk

    gen tmax_rcspl_3kn_t1_lr    = tmax_rcspl_3kn_t1    * low_risk
    gen tmax_rcspl_3kn_t1_lr_v1 = tmax_rcspl_3kn_t1_v1 * low_risk
    gen tmax_rcspl_3kn_t1_lr_v2 = tmax_rcspl_3kn_t1_v2 * low_risk
    gen tmax_rcspl_3kn_t1_lr_v3 = tmax_rcspl_3kn_t1_v3 * low_risk
    gen tmax_rcspl_3kn_t1_lr_v4 = tmax_rcspl_3kn_t1_v4 * low_risk
    gen tmax_rcspl_3kn_t1_lr_v5 = tmax_rcspl_3kn_t1_v5 * low_risk
    gen tmax_rcspl_3kn_t1_lr_v6 = tmax_rcspl_3kn_t1_v6 * low_risk

    gen tmax_rcspl_3kn_t0_hr    = tmax_rcspl_3kn_t0    * risk_level
    gen tmax_rcspl_3kn_t0_hr_v1 = tmax_rcspl_3kn_t0_v1 * risk_level
    gen tmax_rcspl_3kn_t0_hr_v2 = tmax_rcspl_3kn_t0_v2 * risk_level
    gen tmax_rcspl_3kn_t0_hr_v3 = tmax_rcspl_3kn_t0_v3 * risk_level
    gen tmax_rcspl_3kn_t0_hr_v4 = tmax_rcspl_3kn_t0_v4 * risk_level
    gen tmax_rcspl_3kn_t0_hr_v5 = tmax_rcspl_3kn_t0_v5 * risk_level
    gen tmax_rcspl_3kn_t0_hr_v6 = tmax_rcspl_3kn_t0_v6 * risk_level

    gen tmax_rcspl_3kn_t1_hr    = tmax_rcspl_3kn_t1    * risk_level
    gen tmax_rcspl_3kn_t1_hr_v1 = tmax_rcspl_3kn_t1_v1 * risk_level
    gen tmax_rcspl_3kn_t1_hr_v2 = tmax_rcspl_3kn_t1_v2 * risk_level
    gen tmax_rcspl_3kn_t1_hr_v3 = tmax_rcspl_3kn_t1_v3 * risk_level
    gen tmax_rcspl_3kn_t1_hr_v4 = tmax_rcspl_3kn_t1_v4 * risk_level
    gen tmax_rcspl_3kn_t1_hr_v5 = tmax_rcspl_3kn_t1_v5 * risk_level
    gen tmax_rcspl_3kn_t1_hr_v6 = tmax_rcspl_3kn_t1_v6 * risk_level

    gen tmax_rcspl_3kn_t0_hr_g    = tmax_rcspl_3kn_t0    * risk_level * log_gdp_pc_adm1
    gen tmax_rcspl_3kn_t0_hr_g_v1 = tmax_rcspl_3kn_t0_v1 * risk_level * log_gdp_pc_adm1
    gen tmax_rcspl_3kn_t0_hr_g_v2 = tmax_rcspl_3kn_t0_v2 * risk_level * log_gdp_pc_adm1
    gen tmax_rcspl_3kn_t0_hr_g_v3 = tmax_rcspl_3kn_t0_v3 * risk_level * log_gdp_pc_adm1
    gen tmax_rcspl_3kn_t0_hr_g_v4 = tmax_rcspl_3kn_t0_v4 * risk_level * log_gdp_pc_adm1
    gen tmax_rcspl_3kn_t0_hr_g_v5 = tmax_rcspl_3kn_t0_v5 * risk_level * log_gdp_pc_adm1
    gen tmax_rcspl_3kn_t0_hr_g_v6 = tmax_rcspl_3kn_t0_v6 * risk_level * log_gdp_pc_adm1

    gen tmax_rcspl_3kn_t1_hr_g    = tmax_rcspl_3kn_t1    * risk_level * log_gdp_pc_adm1
    gen tmax_rcspl_3kn_t1_hr_g_v1 = tmax_rcspl_3kn_t1_v1 * risk_level * log_gdp_pc_adm1
    gen tmax_rcspl_3kn_t1_hr_g_v2 = tmax_rcspl_3kn_t1_v2 * risk_level * log_gdp_pc_adm1
    gen tmax_rcspl_3kn_t1_hr_g_v3 = tmax_rcspl_3kn_t1_v3 * risk_level * log_gdp_pc_adm1
    gen tmax_rcspl_3kn_t1_hr_g_v4 = tmax_rcspl_3kn_t1_v4 * risk_level * log_gdp_pc_adm1
    gen tmax_rcspl_3kn_t1_hr_g_v5 = tmax_rcspl_3kn_t1_v5 * risk_level * log_gdp_pc_adm1
    gen tmax_rcspl_3kn_t1_hr_g_v6 = tmax_rcspl_3kn_t1_v6 * risk_level * log_gdp_pc_adm1

    if "`reg'" == "1_factor" loc reg_treatment tmax_rcspl_3kn_t0_lr* tmax_rcspl_3kn_t1_lr* tmax_rcspl_3kn_t0_hr* tmax_rcspl_3kn_t1_hr*

    *** This will give you un-useable estimate for LR
    *if "`reg'" == "1_factor" loc reg_treatment (${vars_T_splines} ${vars_T_x_gdp_splines})##i.risk_level
  
    else if "`reg'" == "2_factor" loc reg_treatment (${vars_T_splines} ${vars_T_x_gdp_splines} ${vars_T_x_lr_tmax_splines})##i.risk_level
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
    local ster_name "`reg_folder'/interacted_reg_`reg'_2026_272841.ster"
    local spec_desc "rcspline, 3 knots (27 28 41), tmax, differentiated treatment withlr interaction, fe = $fe, reg_type = `reg'"

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

cap log close
