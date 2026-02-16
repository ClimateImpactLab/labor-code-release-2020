********************************************************************************
* uninteracted_bins.do
*
* PURPOSE:
*   Run baseline 3°C bin regressions (below0 + 0–3 ... 39–42 + above42)

*   Always runs:
*       - high_risk      (Agriculture only)
*   Optionally runs:
*       - high_risk_old  (Agriculture + Construction + Manufacturing)
*
* BIN NAMING CONVENTION (INDEX-BASED)
* ------------------------------------------------
*   This baseline dataset uses index-based 3°C bin names inherited from the
*   original transform_bins.do construction.
*
*   Bin variables are named:
*       b3C_14, b3C_15, ..., b3C_27
*
*   These numbers are positional indices in the full 3°C grid,
*   NOT temperature lower bounds.
*
*   Mapping (selected examples):
*       b3C_14  →  0–3°C
*       b3C_15  →  3–6°C
*       ...
*       b3C_22  →  24–27°C   (reference bin in this file)
*       b3C_27  →  39–42°C
*
*   Tails:
*       below0   = all temperatures < 0°C
*       above42  = all temperatures ≥ 42°C
*
*   This differs from the cold-tail specifications, which use
*   temperature-based bin names (e.g., b3C_9, b3C_12, ...).
*
* REFERENCE BIN:
*   b3C_22 (24–27°C) is omitted as the reference category.
*
*
* DATA:
*   labor_dataset_bins_nochn_tmax_chn_prev_week_no_ll_0_0Cto42C_3Cbins_ag.dta
*
********************************************************************************


*****************
* INITIALIZE
*****************

run "/project/cil/home_dirs/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"
run "${DIR_REPO_LABOR}/2_analysis/0_subroutines/functions.do"

cap log close
log using "${DIR_LOG}/uninteracted_bins.smcl", replace

*****************
* SETTINGS
*****************

* ---- run old risk spec? (yes/no) ----
local run_old_risk "no"    // default: no

* dataset
global dataset "${ROOT_INT_DATA}/regression_ready_data/labor_dataset_bins_nochn_tmax_chn_prev_week_no_ll_0_0Cto42C_3Cbins_ag.dta"

* output folder
local reg_folder "${DIR_STER}/uninteracted_bins"
cap mkdir "`reg_folder'"

* other selections
global test_code "no"
local fe fe_adm0_wk
global bin_width 3C

*****************
* LOAD DATA
*****************

use $dataset, clear

if "${test_code}"=="yes" {
    sample 0.1
}

* drop China
drop if iso == "CHN"

* working sample only
keep if mins_worked > 0

*****************
* COMMON SETUP
*****************

gen_controls_and_FEs

* Baseline 3C bins
* start = 14, end = 27, ref = 22 (24–27C), tails below0/above42
gen_treatment_bins 14 27 22 0 42

* -----------------------------
* Build FE interaction list 
* -----------------------------
local fe_list "$`fe'"
local fe_int_new ""
foreach f of local fe_list {
    local fe_int_new `fe_int_new' `f'#high_risk
}

local fe_int_old ""
foreach f of local fe_list {
    local fe_int_old `fe_int_old' `f'#high_risk_old
}

*****************
* RUN NEW RISK (AG): high_risk
*****************


local suffix "ag"
local ster_name "`reg_folder'/uninteracted_bins_nochn_${bin_width}_`suffix'.ster"

local reg_treatment_new "(${varlist_bins_${bin_width}})##i.high_risk"
local reg_control_new   "(${usual_controls})##i.high_risk"

local spec_desc_new ///
"${bin_width} baseline bin regression (ref=24-27C), differentiated by high_risk, no China, fe=`fe'"

di as txt "=================================================="
di as txt "Running NEW risk spec: high_risk"
di as txt "STER: `ster_name'"
di as txt "absorb(): `fe_int_new'"
di as txt "CMD:"
di as txt "reghdfe mins_worked `reg_treatment_new' `reg_control_new' [pw=risk_adj_sample_wgt], absorb(`fe_int_new') vce(cl cluster_adm1yymm)"
di as txt "=================================================="

reghdfe mins_worked `reg_treatment_new' `reg_control_new' ///
    [pweight = risk_adj_sample_wgt], ///
    absorb(`fe_int_new') ///
    vce(cl cluster_adm1yymm)

estimates notes: "`spec_desc_new'"
estimates save "`ster_name'", replace



*****************
* RUN OLD RISK (OPTIONAL): high_risk_old
*****************

if "`run_old_risk'" == "yes" {

    local suffix "oldrisk"
    local ster_name "`reg_folder'/uninteracted_bins_nochn_${bin_width}_`suffix'.ster"

    local reg_treatment_old "(${varlist_bins_${bin_width}})##i.high_risk_old"
    local reg_control_old   "(${usual_controls})##i.high_risk_old"

    local spec_desc_old ///
    "${bin_width} baseline bin regression (ref=24-27C), differentiated by high_risk_old, no China, fe=`fe'"

    di as txt "=================================================="
    di as txt "Running OLD risk spec: high_risk_old"
    di as txt "STER: `ster_name'"
    di as txt "absorb(): `fe_int_old'"
    di as txt "CMD:"
    di as txt "reghdfe mins_worked `reg_treatment_old' `reg_control_old' [pw=risk_adj_sample_wgt], absorb(`fe_int_old') vce(cl cluster_adm1yymm)"
    di as txt "=================================================="

    reghdfe mins_worked `reg_treatment_old' `reg_control_old' ///
        [pweight = risk_adj_sample_wgt], ///
        absorb(`fe_int_old') ///
        vce(cl cluster_adm1yymm)

    estimates notes: "`spec_desc_old'"
    estimates save "`ster_name'", replace
}

cap log close
