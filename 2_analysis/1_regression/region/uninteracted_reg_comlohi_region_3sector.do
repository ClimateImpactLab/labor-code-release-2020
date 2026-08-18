*-------------------------------------------------------------------------------
* uninteracted_reg_comlohi_region_3sector.do
*-------------------------------------------------------------------------------
* PURPOSE
*   Estimate 3-sector labor-temperature regressions for each region
*
* STEPS
*   1. Loop over EuropeUS, LatinAmerica, and SouthAsia
*   2. Load the regional dataset with the chosen region knots
*   3. Set risk_level from sector: 0 low-risk, 1 agriculture, 2 non-ag
*   4. Estimate common and by-sector reghdfe models
*
* INPUTS
*   ${ROOT_INT_DATA}/regression_ready_data/region_datasets/
*     labor_dataset_region_EuropeUS.dta
*     labor_dataset_region_LatinAmerica.dta
*     labor_dataset_region_SouthAsia.dta
*
*   After the region knot search, spline terms for the chosen knots were
*   calculated at pixel level before admin aggregation
*
* OUTPUTS
*   ${DIR_STER}/uninteracted_reg_region_3sector/<region>/
*     uninteracted_reg_common_<region>_3sector_ag.ster
*     uninteracted_reg_by_risk_<region>_3sector_ag.ster
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
log using "${DIR_OUTPUT}/logs/uninteracted_reg_comlohi_region_3sector.log", replace text

*-------------------------------------------------------------------------------
* Settings
*-------------------------------------------------------------------------------

local data_dir "${ROOT_INT_DATA}/regression_ready_data/region_datasets"
local iso_env = trim("`: env ISO'")

if inlist("`iso_env'", "EuropeUS", "LatinAmerica", "SouthAsia") {
    local regions "`iso_env'"
}
else {
    local regions "EuropeUS LatinAmerica SouthAsia"
}

local reg_list "by_risk common"
local reg_root "${DIR_STER}/uninteracted_reg_region_3sector"

cap mkdir "`reg_root'"

*-------------------------------------------------------------------------------
* Run regressions
*-------------------------------------------------------------------------------

foreach region of local regions {

    di as txt "Running 3-sector region regressions: `region'"

    local infile "`data_dir'/labor_dataset_region_`region'.dta"
    local reg_folder "`reg_root'/`region'"
    cap mkdir "`reg_folder'"

    local knots ""
    if "`region'" == "EuropeUS" local knots "14 20 28"
    if "`region'" == "LatinAmerica" local knots "26 29 34"
    if "`region'" == "SouthAsia" local knots "28 33 41"

    use "`infile'", clear

    keep if mins_worked > 0

    cap drop risk_level
    gen byte risk_level = sector
    assert inlist(risk_level, 0, 1, 2) if !missing(risk_level)

    gen_controls_and_FEs
    gen_treatment_splines rcspl 3 tmax this_week 1

    local treat_by_sector "(${vars_T_splines})##i.risk_level"
    local treat_common "(${vars_T_splines})"
    local controls_all "(${usual_controls})##i.risk_level"

    local fe_macro "fe_adm0_wk"
    if "`region'" == "SouthAsia" {
        local fe_macro "fe_adm0_wk_country_spec"
    }

    local reg_fe ""
    foreach f in $`fe_macro' {
        local reg_fe `reg_fe' `f'#risk_level
    }

    local cluster_var "cluster_adm1yymm"

    foreach spec of local reg_list {

        if "`spec'" == "by_risk" {
            local reg_treatment "`treat_by_sector'"
            local weight "risk_adj_sample_wgt_sector"
        }
        else {
            local reg_treatment "`treat_common'"
            local weight "pop_adj_sample_wgt"
        }

        local ster_name "`reg_folder'/uninteracted_reg_`spec'_`region'_3sector_ag.ster"
        local spec_desc "region=`region'; rcspl3 (`knots'); fe=$`fe_macro'; spec=`spec'; weight=`weight'; risk_level=sector"

        di as txt "Running `spec' regression for `region'"

        reghdfe mins_worked ///
            `reg_treatment' ///
            `controls_all' ///
            [pweight = `weight'], ///
            absorb(`reg_fe') ///
            vce(cl `cluster_var')

        tempvar included
        gen byte `included' = e(sample)

        count if `included' == 1 & risk_level == 1
        estadd scalar ag_N = r(N)

        count if `included' == 1 & risk_level == 0
        estadd scalar low_N = r(N)

        count if `included' == 1 & risk_level == 2
        estadd scalar nonag_N = r(N)

        estimates notes: "`spec_desc'"
        estimates save "`ster_name'", replace

        di as result "Saved: `ster_name'"
    }
}

log close
