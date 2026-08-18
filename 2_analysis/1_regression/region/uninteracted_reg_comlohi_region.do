*-------------------------------------------------------------------------------
* uninteracted_reg_comlohi_region.do
*-------------------------------------------------------------------------------
* PURPOSE
*   Estimate regional low-risk and high-risk labor-temperature regressions
*
* STEPS
*   1. Loop over EuropeUS, LatinAmerica, and SouthAsia
*   2. Load the regression-ready dataset for each region
*   3. Generate controls, fixed effects, and 3-knot spline terms
*   4. Estimate common and by-risk reghdfe models
*   5. Save .ster files used by the regional low/high response script
*
* INPUTS
*   ${ROOT_INT_DATA}/regression_ready_data/region_datasets/
*     labor_dataset_region_EuropeUS.dta
*     labor_dataset_region_LatinAmerica.dta
*     labor_dataset_region_SouthAsia.dta
*
* OUTPUTS
*   ${DIR_STER}/uninteracted_reg_region/<region>/
*     uninteracted_reg_common_<region>_ag.ster
*     uninteracted_reg_by_risk_<region>_ag.ster
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
log using "${DIR_OUTPUT}/logs/uninteracted_reg_comlohi_region.log", replace text

*-------------------------------------------------------------------------------
* Settings
*-------------------------------------------------------------------------------

local data_dir "${ROOT_INT_DATA}/regression_ready_data/region_datasets"
local reg_root "${DIR_STER}/uninteracted_reg_region"
local reg_list "by_risk common"

local iso_env = trim("`: env ISO'")

if inlist("`iso_env'", "EuropeUS", "LatinAmerica", "SouthAsia") {
    local regions "`iso_env'"
}
else {
    local regions "EuropeUS LatinAmerica SouthAsia"
}

cap mkdir "`reg_root'"

*-------------------------------------------------------------------------------
* Run regressions
*-------------------------------------------------------------------------------

foreach region of local regions {

    di as txt "Running low/high region regressions for `region'"

    local dataset "`data_dir'/labor_dataset_region_`region'.dta"
    local reg_folder "`reg_root'/`region'"

    cap mkdir "`reg_folder'"

    local knots ""
    if "`region'" == "EuropeUS" local knots "14 20 28"
    if "`region'" == "LatinAmerica" local knots "26 29 34"
    if "`region'" == "SouthAsia" local knots "28 33 41"

    local k1 : word 1 of `knots'
    local k2 : word 2 of `knots'
    local k3 : word 3 of `knots'

    foreach reg of local reg_list {

        use "`dataset'", clear

        keep if mins_worked > 0
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
        local fe_macro "fe_adm0_wk"

        if "`region'" == "SouthAsia" {
            local fe_macro "fe_adm0_wk_country_spec"
        }

        local reg_fe ""
        foreach f in $`fe_macro' {
            local reg_fe `reg_fe' `f'#risk_level
        }

        local ster_name "`reg_folder'/uninteracted_reg_`reg'_`region'_ag.ster"
        local spec_desc "Region low/high-risk model; region=`region'; knots `k1' `k2' `k3'; fe=$`fe_macro'; spec=`reg'; weight=`weight'"

        di as txt "Running `reg' regression for `region'"

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
}

log close
