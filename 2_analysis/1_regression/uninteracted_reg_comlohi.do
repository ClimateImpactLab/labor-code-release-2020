*-------------------------------------------------------------------------------
* uninteracted_reg_comlohi.do
*-------------------------------------------------------------------------------
* PURPOSE
*   Estimate the main low-risk and high-risk labor-temperature regressions
*
* STEPS
*   1. Load the regression-ready labor dataset
*   2. Keep survey rows with positive work minutes
*   3. Generate controls, fixed effects, and 3-knot spline terms
*   4. Estimate common and by-risk reghdfe models
*
* INPUTS
*   ${ROOT_INT_DATA}/regression_ready_data/
*     labor_dataset_splines_nochn_tmax_chn_prev_week_no_ll_0_agnonag_272841_0814.dta
*
* OUTPUTS
*   ${DIR_STER}/uninteracted_reg_comlohi/
*     uninteracted_reg_common_2026_272841.ster
*     uninteracted_reg_by_risk_2026_272841.ster
*-------------------------------------------------------------------------------

version 16.1
clear all
set more off
set rmsg on
set trace off

run "/project/cil/home_dirs/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"
run "${DIR_REPO_LABOR}/2_analysis/0_subroutines/functions.do"

cap log close
cap mkdir "${DIR_OUTPUT}/logs"
log using "${DIR_OUTPUT}/logs/uninteracted_reg_comlohi.log", replace text

*-------------------------------------------------------------------------------
* Settings
*-------------------------------------------------------------------------------

local dataset "${ROOT_INT_DATA}/regression_ready_data/labor_dataset_splines_nochn_tmax_chn_prev_week_no_ll_0_agnonag_272841_0814.dta"
local reg_folder "${DIR_STER}/uninteracted_reg_comlohi"
local reg_list "by_risk common"
local fe "fe_adm0_wk"

cap mkdir "`reg_folder'"

*-------------------------------------------------------------------------------
* Run regressions
*-------------------------------------------------------------------------------

foreach reg of local reg_list {

    use "`dataset'", clear

    keep if mins_worked > 0
    rename *27_28_41_* **

    cap drop risk_level
    gen byte risk_level = high_risk

    gen_controls_and_FEs
    gen_treatment_splines rcspl 3 tmax this_week 1

    if "`reg'" == "by_risk" {
        local reg_treatment "(${vars_T_splines})##i.risk_level"
        local weight "risk_adj_sample_wgt"
    }
    else {
        local reg_treatment "(${vars_T_splines})"
        local weight "pop_adj_sample_wgt"
    }

    local reg_control "(${usual_controls})##i.risk_level"

    local reg_fe ""
    foreach f in $`fe' {
        local reg_fe `reg_fe' `f'#risk_level
    }

    local ster_name "`reg_folder'/uninteracted_reg_`reg'_2026_272841.ster"
    local spec_desc "Main low/high-risk model; knots 27 28 41; fe=$`fe'; spec=`reg'; weight=`weight'"

    di as txt "Running `reg' regression"

    reghdfe mins_worked ///
        `reg_treatment' ///
        `reg_control' ///
        [pweight = `weight'], ///
        absorb(`reg_fe') ///
        vce(cl cluster_adm1yymm)

    tempvar included
    gen byte `included' = e(sample)

    count if `included' == 1 & risk_level == 1
    estadd scalar high_N = r(N)

    count if `included' == 1 & risk_level == 0
    estadd scalar low_N = r(N)

    estimates notes: "`spec_desc'"
    estimates save "`ster_name'", replace

    di as result "Saved: `ster_name'"
}

log close
