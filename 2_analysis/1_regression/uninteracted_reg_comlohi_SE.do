********************************************************************************
* uninteracted_reg_by_comlohi_SE.do
*
* PURPOSE:
*   Estimate by-risk (high_risk vs low_risk) labor-supply temperature response
*   regressions separately by employment type, splitting the sample into:
*     (A) Non–self-employed workers  (self_emp == 0)  -> tag: noSE
*     (B) Self-employed workers      (self_emp == 1)  -> tag: onlySE
*
* INPUT DATA:
*   ${ROOT_INT_DATA}/regression_ready_data/
*     labor_dataset_splines_nochn_tmax_chn_prev_week_no_ll_0_agnonag_272841_0129.dta
*
* OUTPUT:
*   Saves one .ster per employment-type subsample to:
*     ${DIR_STER}/uninteracted_reg_comlohi_SE/
*       uninteracted_reg_by_risk_noSE_2026.ster
*       uninteracted_reg_by_risk_onlySE_2026.ster
*
* AUTHOR: Marine de Franciosi
* LAST UPDATED: 01/20/2026
********************************************************************************


version 16.0
clear all
set more off

*****************
* INITIALIZE
*****************

run "/project/cil/home_dirs/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"
run "${DIR_REPO_LABOR}/2_analysis/0_subroutines/functions.do"

cap log close
log using "${DIR_LOG}/uninteracted_reg_by_risk_selfemp_split.smcl", replace

* ---- DATA ----
gl dataset "${ROOT_INT_DATA}/regression_ready_data/labor_dataset_splines_nochn_tmax_chn_prev_week_no_ll_0_agnonag_272841_0129.dta"

* ---- OUTPUT ----
loc reg_folder "${DIR_STER}/uninteracted_reg_comlohi_SE"
cap mkdir "`reg_folder'"

* ---- SETTINGS ----
gl test_code "no"
loc fe fe_adm0_wk

* renaming spline terms (removing knots in var names)
local do_rename 1

********************
* RUN REGRESSIONS
********************

foreach se_tag in noSE onlySE {

    di as txt "=============================================="
    di as txt "Running by-risk regression for group: `se_tag'"
    di as txt "=============================================="

    use $dataset, clear

    if "${test_code}"=="yes" sample 0.1

    * only include non-zero observations
    keep if mins_worked > 0

    * split samples
    if "`se_tag'" == "noSE"    keep if self_emp == 0
    if "`se_tag'" == "onlySE"  keep if self_emp == 1

    * (optional) normalize spline var names if dataset embeds knot tags
    if `do_rename' {
        cap noi rename *27_28_41_* **
    }

    * generate regression variables/macros
    gen_controls_and_FEs
    gen_treatment_splines rcspl 3 tmax this_week 1

    * by-risk treatment
    local reg_treat   ( ${vars_T_splines} )##i.high_risk
    local reg_ctrl    ( ${usual_controls} )##i.high_risk

    * interact each FE with high_risk 
    local reg_fe ""
    foreach f in $`fe' {
        local reg_fe `reg_fe' `f'#high_risk
    }

    * weight for by-risk
    local weight "risk_adj_sample_wgt"

    * run regression
    di "reghdfe mins_worked `reg_treat' `reg_ctrl' [pweight=`weight'], absorb(`reg_fe') vce(cl cluster_adm1yymm)"
    reghdfe mins_worked `reg_treat' `reg_ctrl' [pweight=`weight'], absorb(`reg_fe') vce(cl cluster_adm1yymm)

    * add N by risk 
    gen included = e(sample)
    count if included==1 & high_risk==1
    estadd scalar high_N = `r(N)'
    count if included==1 & high_risk==0
    estadd scalar low_N  = `r(N)'

    local spec_desc "by-risk rcspline 3 knots (27 28 41), tmax, sample=`se_tag', fe=$fe interacted w/ high_risk, clustered ADM1×month"
    estimates notes: "`spec_desc'"

    local ster_name "`reg_folder'/uninteracted_reg_by_risk_`se_tag'_2026.ster"
    estimates save "`ster_name'", replace

    di as txt "SAVED: `ster_name'"
}

cap log close
