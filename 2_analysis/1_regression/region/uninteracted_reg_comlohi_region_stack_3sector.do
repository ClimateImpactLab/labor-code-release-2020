*-------------------------------------------------------------------------------
* uninteracted_reg_comlohi_region_stack_3sector.do
*-------------------------------------------------------------------------------
* PURPOSE
*   Estimate one stacked 3-sector model across regions. The output is used for
*   F-tests on whether agriculture temperature responses differ across regions
*
* STEPS
*   1. Load the appended regional 3-sector dataset
*   2. Set risk_level from sector: 0 low-risk, 1 agriculture, 2 non-ag
*   3. Interact spline terms with sector and region
*   4. Estimate the stacked by-sector model with region-specific FE and clusters
*
* INPUTS
*   ${ROOT_INT_DATA}/regression_ready_data/region_datasets/
*     labor_dataset_region_stack_3sector.dta
*
*   Built by:
*     1_assemble_dataset/time_use/merge/region/append_region_3sector_datasets.do
*
* OUTPUTS
*   ${DIR_STER}/uninteracted_reg_region_stack_3sector/
*     uninteracted_reg_by_risk_region_stack_3sector.ster
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
log using "${DIR_OUTPUT}/logs/uninteracted_reg_comlohi_region_stack_3sector.log", replace text

*-------------------------------------------------------------------------------
* Settings
*-------------------------------------------------------------------------------

local data_dir "${ROOT_INT_DATA}/regression_ready_data/region_datasets"
local regions "EuropeUS LatinAmerica SouthAsia"
local dataset "`data_dir'/labor_dataset_region_stack_3sector.dta"

local reg_root "${DIR_STER}/uninteracted_reg_region_stack_3sector"
local ster_name "`reg_root'/uninteracted_reg_by_risk_region_stack_3sector.ster"

cap mkdir "${DIR_STER}"
cap mkdir "`reg_root'"

*-------------------------------------------------------------------------------
* Load appended dataset
*-------------------------------------------------------------------------------

use "`dataset'", clear

label define region_id 1 "EuropeUS" 2 "LatinAmerica" 3 "SouthAsia", replace
label values region_id region_id

keep if mins_worked > 0

cap drop risk_level
gen byte risk_level = sector
assert inlist(risk_level, 0, 1, 2) if !missing(risk_level)

*-------------------------------------------------------------------------------
* Regression variables
*-------------------------------------------------------------------------------

gen_controls_and_FEs
gen_treatment_splines rcspl 3 tmax this_week 1

local reg_treatment "(${vars_T_splines})##i.risk_level##i.region_id"
local reg_control "(${usual_controls})##i.risk_level"

egen fe_adm3_region = group(region_id adm3_id), missing
egen fe_dow_region = group(region_id dow_week), missing
egen fe_adm0_year_region = group(region_id adm0_id year), missing
egen fe_adm0_week_region = group(region_id adm0_id week_fe), missing
egen cluster_region = group(region_id cluster_adm1yymm), missing

local reg_fe ///
    fe_adm3_region#risk_level ///
    fe_dow_region#risk_level ///
    fe_adm0_year_region#risk_level ///
    fe_adm0_week_region#risk_level

local weight "risk_adj_sample_wgt_sector"

*-------------------------------------------------------------------------------
* Run stacked model
*-------------------------------------------------------------------------------

di as txt "Running stacked 3-sector region regression"

reghdfe mins_worked ///
    `reg_treatment' ///
    `reg_control' ///
    [pweight = `weight'], ///
    absorb(`reg_fe') ///
    vce(cl cluster_region)

tempvar included
gen byte `included' = e(sample)

foreach region of local regions {

    if "`region'" == "EuropeUS" {
        local region_id = 1
        local short "eu"
    }
    if "`region'" == "LatinAmerica" {
        local region_id = 2
        local short "la"
    }
    if "`region'" == "SouthAsia" {
        local region_id = 3
        local short "sa"
    }

    count if `included' == 1 & region_id == `region_id'
    estadd scalar N_`short' = r(N)

    count if `included' == 1 & region_id == `region_id' & risk_level == 0
    estadd scalar low_N_`short' = r(N)

    count if `included' == 1 & region_id == `region_id' & risk_level == 1
    estadd scalar ag_N_`short' = r(N)

    count if `included' == 1 & region_id == `region_id' & risk_level == 2
    estadd scalar nonag_N_`short' = r(N)
}

estimates notes: "Stacked regional 3-sector model; region-specific knots from input datasets; treatment by sector and region; controls by sector; FEs by sector within region."
estimates save "`ster_name'", replace

di as result "Saved: `ster_name'"

log close
