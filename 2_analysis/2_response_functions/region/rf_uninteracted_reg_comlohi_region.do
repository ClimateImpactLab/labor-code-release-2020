*-------------------------------------------------------------------------------
* rf_uninteracted_reg_comlohi_region.do
*-------------------------------------------------------------------------------
* PURPOSE
*   Create temperature-response CSVs from regional low/high estimates
*
* STEPS
*   1. Loop over EuropeUS, LatinAmerica, and SouthAsia
*   2. Build full and table temperature grids
*   3. Load common and by-risk .ster files
*   4. Calculate common, low-risk, high-risk, and difference responses
*   5. Write one full CSV and one table CSV for each region
*
* INPUTS
*   ${DIR_STER}/uninteracted_reg_region/<region>/
*     uninteracted_reg_common_<region>_ag.ster
*     uninteracted_reg_by_risk_<region>_ag.ster
*
* OUTPUTS
*   ${DIR_RF}/uninteracted_reg_region/<region>/
*     rf_<region>_full_ag.csv
*     rf_<region>_table_ag.csv
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
log using "${DIR_OUTPUT}/logs/rf_uninteracted_reg_comlohi_region.log", replace text

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

local reg_root "${DIR_STER}/uninteracted_reg_region"
local rf_root "${DIR_RF}/uninteracted_reg_region"

cap mkdir "`rf_root'"

*-------------------------------------------------------------------------------
* Build response functions
*-------------------------------------------------------------------------------

foreach region of local regions {

    di as txt "Building low/high response functions for `region'"

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

    local common_ster "`reg_folder'/uninteracted_reg_common_`region'_ag.ster"
    local byrisk_ster "`reg_folder'/uninteracted_reg_by_risk_`region'_ag.ster"

    confirm file "`common_ster'"
    confirm file "`byrisk_ster'"

    foreach row_values in full_response table_values {

        clear

        local table_type = cond("`row_values'" == "full_response", "full", "table")
        local rf_name "`rf_folder'/rf_`region'_`table_type'_ag.csv"

        quietly make_temp_dist, list($`row_values') ref($ref_temp)
        gen mins_worked = .
        make_spline_terms `k1' `k2' `k3'

        *-------------------------------------------------------------------------------
        * Common response
        *-------------------------------------------------------------------------------

        estimates use "`common_ster'"

        collect_spline_terms, splines(0 1) unint(common) int(unused)

        predictnl yhat_comm = ///
            (T_spline0 - ref_spline0) * (${common0}) + ///
            (T_spline1 - ref_spline1) * (${common1}), ///
            ci(lowerci_comm upperci_comm) se(se_comm)

        *-------------------------------------------------------------------------------
        * Low/high responses
        *-------------------------------------------------------------------------------

        estimates use "`byrisk_ster'"

        collect_spline_terms, splines(0 1) unint(unint) int(int)

        predictnl yhat_low = ///
            (T_spline0 - ref_spline0) * (${unint0}) + ///
            (T_spline1 - ref_spline1) * (${unint1}), ///
            ci(lowerci_low upperci_low) se(se_low)

        predictnl yhat_high = ///
            (T_spline0 - ref_spline0) * (${unint0} + ${int0}) + ///
            (T_spline1 - ref_spline1) * (${unint1} + ${int1}), ///
            ci(lowerci_high upperci_high) se(se_high)

        * High-risk minus low-risk
        predictnl yhat_marg = ///
            (T_spline0 - ref_spline0) * (${int0}) + ///
            (T_spline1 - ref_spline1) * (${int1}), ///
            ci(lowerci_marg upperci_marg) se(se_marg)

        *-------------------------------------------------------------------------------
        * Write CSV
        *-------------------------------------------------------------------------------

        drop T_spline* ref_spline* min ref mins_worked

        keep temp ///
            yhat_comm se_comm lowerci_comm upperci_comm ///
            yhat_low se_low lowerci_low upperci_low ///
            yhat_high se_high lowerci_high upperci_high ///
            yhat_marg se_marg lowerci_marg upperci_marg

        export delimited using "`rf_name'", replace

        di as result "Wrote: `rf_name'"
    }
}

log close
