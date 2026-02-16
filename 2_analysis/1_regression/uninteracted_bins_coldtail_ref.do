********************************************************************************
* uninteracted_bins_coldtail_ref.do
*
* PURPOSE:
*   Run uninteracted 3°C bin regressions using the cold-tail merged dataset
*   (cold tail <= 9°C), under two alternative reference bins:
*
*       (1) Reference = 24–27°C  (b3C_24 omitted)
*       (2) Reference = 27–30°C  (b3C_27 omitted)
*
*   Bin variables are temperature-based (b3C_9, b3C_12, ..., b3C_39),
*   as constructed in 1_assemble_dataset/merge/time_use/transform_bins_ag_coldtail.do.
*
*   Cold-tail structure:
*       below9, 9–12, 12–15, ..., 39–42, above42
*
* DATA:
*   labor_dataset_bins_nochn_tmax_chn_prev_week_no_ll_0_coldle9_3Cbins_9to42_plusTails.dta
*
********************************************************************************

*****************
* INITIALIZE
*****************

run "/project/cil/home_dirs/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"
run "${DIR_REPO_LABOR}/2_analysis/0_subroutines/functions.do"

cap log close
log using "${DIR_LOG}/uninteracted_bins_ag_coldle9_refs.smcl", replace

*****************
* SETTINGS
*****************

local coldcut 9
local fe fe_adm0_wk
global test_code "no"
global bin_width 3C

local reg_folder "${DIR_STER}/uninteracted_bins"
cap mkdir "`reg_folder'"

global dataset ///
"${ROOT_INT_DATA}/regression_ready_data/labor_dataset_bins_nochn_tmax_chn_prev_week_no_ll_0_coldle9_3Cbins_9to42_plusTails.dta"

*****************
* LOAD DATA
*****************

use $dataset, clear

if "${test_code}"=="yes" {
    sample 0.1
}

cap drop if iso == "CHN"
keep if mins_worked > 0

gen_controls_and_FEs

********************************************************************************
* PROGRAM: gen_treatment_bins_coldtail
* Generates temperature-based treatment bin list
********************************************************************************

cap program drop gen_treatment_bins_coldtail
program define gen_treatment_bins_coldtail
    * args:
    *   start_temp end_temp ref_temp coldcut uppercut step
    *
    * Example:
    *   gen_treatment_bins_coldtail 9 39 24 9 42 3

    args start_temp end_temp ref_temp coldcut uppercut step
    if "`step'" == "" local step 3

    global varlist_bins_${bin_width}

    * interior bins
    forval t = `start_temp'(`step')`end_temp' {
        if `t' == `ref_temp' continue
        global varlist_bins_${bin_width} ///
        ${varlist_bins_${bin_width}} c.b3C_`t'
    }

    * tails
    global varlist_bins_${bin_width} ///
    ${varlist_bins_${bin_width}} c.below`coldcut' c.above`uppercut'

    * add lags
    local base "${varlist_bins_${bin_width}}"
    foreach v in `base' {
        forval lag = 1/6 {
            global varlist_bins_${bin_width} ///
            ${varlist_bins_${bin_width}} `v'_v`lag'
        }
    }

    di "${varlist_bins_${bin_width}}"
end

********************************************************************************
* PROGRAM: run_spec
********************************************************************************
cap program drop _run_spec
program define _run_spec
    args ref_temp ref_label coldcut fe reg_folder

    * clear previous bin list
    global varlist_bins_${bin_width}

    gen_treatment_bins_coldtail ///
        `coldcut' 39 `ref_temp' `coldcut' 42 3

    local reg_treatment (${varlist_bins_${bin_width}})##i.high_risk
    local reg_control   (${usual_controls})##i.high_risk

    local reg_fe ""
    foreach f in $`fe' {
        local reg_fe `reg_fe' `f'#high_risk
    }

    local ster_name ///
    "`reg_folder'/uninteracted_bins_nochn_${bin_width}_coldle`coldcut'_ref`ref_temp'_ag.ster"

    di "Running coldle`coldcut' spec with ref = `ref_label'"
    reghdfe mins_worked `reg_treatment' `reg_control' ///
        [pweight = risk_adj_sample_wgt], ///
        absorb(`reg_fe') ///
        vce(cl cluster_adm1yymm)

    estimates save "`ster_name'", replace
end

********************************************************************************
* RUN BOTH REFERENCE BIN SPECIFICATIONS
********************************************************************************

* (1) Reference 24–27C
_run_spec 24 "24-27C" `coldcut' `fe' "`reg_folder'"

* (2) Reference 27–30C
_run_spec 27 "27-30C" `coldcut' `fe' "`reg_folder'"

cap log close
