*-------------------------------------------------------------------------------
* rf_uninteracted_reg_comlohi_region_3sector_final.do
*-------------------------------------------------------------------------------
* PURPOSE
*   Create temperature-response CSVs from regional 3-sector estimates
*
* STEPS
*   1. Loop over EuropeUS, LatinAmerica, and SouthAsia
*   2. Build full and table temperature grids
*   3. Load common and by-sector .ster files
*   4. Calculate sector responses and pairwise differences
*   5. Write one full CSV and one table CSV for each region
*
* INPUTS
*   ${DIR_STER}/uninteracted_reg_region_3sector/<region>/
*     uninteracted_reg_common_<region>_3sector_ag.ster
*     uninteracted_reg_by_risk_<region>_3sector_ag.ster
*
* OUTPUTS
*   ${DIR_RF}/uninteracted_reg_region_3sector/<region>/
*     rf_<region>_full_3sector_ag.csv
*     rf_<region>_table_3sector_ag.csv
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
log using "${DIR_OUTPUT}/logs/rf_uninteracted_reg_comlohi_region_3sector_final.log", replace text

*-------------------------------------------------------------------------------
* Settings
*-------------------------------------------------------------------------------

global ref_temp 27

numlist "-20(0.1)47"
global full_response `r(numlist)'

numlist "45 40 35 30 10 5 0 -5 -10"
global table_values `r(numlist)'

local iso_env = trim("`: env ISO'")

if inlist("`iso_env'", "EuropeUS", "LatinAmerica", "SouthAsia") {
    local regions "`iso_env'"
}
else {
    local regions "EuropeUS LatinAmerica SouthAsia"
}

local reg_root "${DIR_STER}/uninteracted_reg_region_3sector"
local rf_root "${DIR_RF}/uninteracted_reg_region_3sector"

cap mkdir "`rf_root'"

*-------------------------------------------------------------------------------
* Build response functions
*-------------------------------------------------------------------------------

foreach region of local regions {

    di as txt "Building 3-sector response functions for `region'"

    local reg_folder "`reg_root'/`region'"
    local rf_folder "`rf_root'/`region'"
    cap mkdir "`rf_folder'"

    local knots ""
    if "`region'" == "EuropeUS" local knots "14 20 28"
    if "`region'" == "LatinAmerica" local knots "26 29 34"
    if "`region'" == "SouthAsia" local knots "28 33 41"

    local k1 : word 1 of `knots'
    local k2 : word 2 of `knots'
    local k3 : word 3 of `knots'

    local common_ster "`reg_folder'/uninteracted_reg_common_`region'_3sector_ag.ster"
    local bysector_ster "`reg_folder'/uninteracted_reg_by_risk_`region'_3sector_ag.ster"

    confirm file "`common_ster'"
    confirm file "`bysector_ster'"

    foreach row_values in full_response table_values {

        clear

        local table_type = cond("`row_values'" == "full_response", "full", "table")
        local rf_name "`rf_folder'/rf_`region'_`table_type'_3sector_ag.csv"

        quietly make_temp_dist, list($`row_values') ref($ref_temp)
        gen mins_worked = .
        make_spline_terms `k1' `k2' `k3'

        *-------------------------------------------------------------------------------
        * Common response
        *-------------------------------------------------------------------------------

        estimates use "`common_ster'"

        collect_sector_spline_terms, ///
            splines(0 1) ///
            unint(common) ///
            int_ag(unused) ///
            int_nonag(unused)

        foreach g in common0 common1 {
            local L_`g' = "${`g'}"
            if "`L_`g''" == "" local L_`g' 0
        }

        predictnl yhat_comm = ///
            (T_spline0 - ref_spline0) * (`L_common0') + ///
            (T_spline1 - ref_spline1) * (`L_common1'), ///
            ci(lowerci_comm upperci_comm) se(se_comm)

        *-------------------------------------------------------------------------------
        * Sector responses
        *-------------------------------------------------------------------------------

        estimates use "`bysector_ster'"

        collect_sector_spline_terms, ///
            splines(0 1) ///
            unint(unint) ///
            int_ag(int_ag) ///
            int_nonag(int_nonag)

        foreach g in unint0 unint1 int_ag0 int_ag1 int_nonag0 int_nonag1 {
            local L_`g' = "${`g'}"
            if "`L_`g''" == "" local L_`g' 0
        }

        * Low-risk baseline
        predictnl yhat_low = ///
            (T_spline0 - ref_spline0) * (`L_unint0') + ///
            (T_spline1 - ref_spline1) * (`L_unint1'), ///
            ci(lowerci_low upperci_low) se(se_low)

        * Agriculture
        predictnl yhat_ag = ///
            (T_spline0 - ref_spline0) * (`L_unint0' + `L_int_ag0') + ///
            (T_spline1 - ref_spline1) * (`L_unint1' + `L_int_ag1'), ///
            ci(lowerci_ag upperci_ag) se(se_ag)

        * Non-ag
        predictnl yhat_nonag = ///
            (T_spline0 - ref_spline0) * (`L_unint0' + `L_int_nonag0') + ///
            (T_spline1 - ref_spline1) * (`L_unint1' + `L_int_nonag1'), ///
            ci(lowerci_nonag upperci_nonag) se(se_nonag)

        *-------------------------------------------------------------------------------
        * Pairwise differences
        *-------------------------------------------------------------------------------

        predictnl yhat_nonag_low = ///
            (T_spline0 - ref_spline0) * (`L_int_nonag0') + ///
            (T_spline1 - ref_spline1) * (`L_int_nonag1'), ///
            ci(lowerci_nonag_low upperci_nonag_low) se(se_nonag_low)

        predictnl yhat_ag_low = ///
            (T_spline0 - ref_spline0) * (`L_int_ag0') + ///
            (T_spline1 - ref_spline1) * (`L_int_ag1'), ///
            ci(lowerci_ag_low upperci_ag_low) se(se_ag_low)

        predictnl yhat_ag_nonag = ///
            (T_spline0 - ref_spline0) * (`L_int_ag0' - `L_int_nonag0') + ///
            (T_spline1 - ref_spline1) * (`L_int_ag1' - `L_int_nonag1'), ///
            ci(lowerci_ag_nonag upperci_ag_nonag) se(se_ag_nonag)

        *-------------------------------------------------------------------------------
        * Write CSV
        *-------------------------------------------------------------------------------

        drop T_spline* ref_spline* min ref mins_worked

        keep temp ///
            yhat_comm se_comm lowerci_comm upperci_comm ///
            yhat_low se_low lowerci_low upperci_low ///
            yhat_ag se_ag lowerci_ag upperci_ag ///
            yhat_nonag se_nonag lowerci_nonag upperci_nonag ///
            yhat_nonag_low se_nonag_low lowerci_nonag_low upperci_nonag_low ///
            yhat_ag_low se_ag_low lowerci_ag_low upperci_ag_low ///
            yhat_ag_nonag se_ag_nonag lowerci_ag_nonag upperci_ag_nonag

        export delimited using "`rf_name'", replace

        di as result "Wrote: `rf_name'"
    }
}

log close
