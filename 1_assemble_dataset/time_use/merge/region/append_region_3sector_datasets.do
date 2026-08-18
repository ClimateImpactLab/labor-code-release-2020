*-------------------------------------------------------------------------------
* append_region_3sector_datasets.do
*-------------------------------------------------------------------------------
* PURPOSE
*   Stack the three regional 3-sector labor datasets into one file. This lets
*   the regression run F-tests on agriculture responses across regions
*
* STEPS
*   1. Check that the three files have the same variables in the same order
*   2. Add region_id to each file
*   3. Append the files
*   4. Save one stacked file for the regional equality regression
*
* INPUTS
*   ${ROOT_INT_DATA}/regression_ready_data/region_datasets/
*     labor_dataset_region_EuropeUS.dta
*     labor_dataset_region_LatinAmerica.dta
*     labor_dataset_region_SouthAsia.dta
*
* OUTPUTS
*   ${ROOT_INT_DATA}/regression_ready_data/region_datasets/
*     labor_dataset_region_stack_3sector.dta
*-------------------------------------------------------------------------------

version 16.1
clear all
set more off
set rmsg on
set trace off

*-------------------------------------------------------------------------------
* Setup
*-------------------------------------------------------------------------------
run "/project/cil/home_dirs/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"

cap log close
cap mkdir "${DIR_REPO_LABOR}/1_assemble_dataset/time_use/merge/region/logs"
log using "${DIR_REPO_LABOR}/1_assemble_dataset/time_use/merge/region/logs/append_region_3sector_datasets.log", replace text

local data_dir "${ROOT_INT_DATA}/regression_ready_data/region_datasets"
local regions  "EuropeUS LatinAmerica SouthAsia"
local outfile  "`data_dir'/labor_dataset_region_stack_3sector.dta"

*-------------------------------------------------------------------------------
* Check variables
*-------------------------------------------------------------------------------

local first_region : word 1 of `regions'
local first_file "`data_dir'/labor_dataset_region_`first_region'.dta"

use "`first_file'", clear
ds
local master_vars `r(varlist)'
local master_nvars : word count `master_vars'

di as txt "Base region: `first_region'"
di as txt "Base variable count: `master_nvars'"

foreach region of local regions {

    local infile "`data_dir'/labor_dataset_region_`region'.dta"
    use "`infile'", clear
    ds
    local this_vars `r(varlist)'
    local this_nvars : word count `this_vars'

    di as txt "Variable check: `region' has `this_nvars' variables"

    assert `this_nvars' == `master_nvars'
    assert "`this_vars'" == "`master_vars'"
}

di as result "Variable check passed: all regional datasets have the same variables"

*-------------------------------------------------------------------------------
* Append datasets
*-------------------------------------------------------------------------------

tempfile stacked
local first = 1
local region_id = 0

foreach region of local regions {

    local ++region_id
    local infile "`data_dir'/labor_dataset_region_`region'.dta"
    use "`infile'", clear

    gen byte region_id = `region_id'
    gen str20 region_name = "`region'"

    label define region_id 1 "EuropeUS" 2 "LatinAmerica" 3 "SouthAsia", replace
    label values region_id region_id

    order region_id region_name, after(iso)

    quietly count
    di as txt "`region' rows before append: " r(N)

    if `first' {
        save "`stacked'", replace
        local first = 0
    }
    else {
        append using "`stacked'"
        save "`stacked'", replace
    }
}

use "`stacked'", clear
compress
save "`outfile'", replace

describe, short
tab region_id

di as result "Saved appended regional 3-sector dataset: `outfile'"

log close
