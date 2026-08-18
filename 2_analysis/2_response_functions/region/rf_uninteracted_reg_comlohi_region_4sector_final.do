*-------------------------------------------------------------------------------
* rf_uninteracted_reg_comlohi_region_4sector_final.do
*-------------------------------------------------------------------------------
* PURPOSE
*   Create temperature-response CSVs from regional 4-sector estimates
*
* STEPS
*   1. Choose the standard estimates, or temp_split when requested
*   2. Loop over EuropeUS, LatinAmerica, and SouthAsia
*   3. Build full and table temperature grids
*   4. Load common and by-sector .ster files
*   5. Calculate sector responses and pairwise differences
*   6. Write one full CSV and one table CSV for each region
*
* INPUTS
*   ${DIR_STER}/uninteracted_reg_region_4sector/<region>/
*     uninteracted_reg_common_<region>_4sector.ster
*     uninteracted_reg_by_risk_<region>_4sector.ster
*
* OUTPUTS
*   ${DIR_RF}/uninteracted_reg_region_4sector/<region>/
*     rf_<region>_full_4sector.csv
*     rf_<region>_table_4sector.csv
*
*   With arg "temp_split", input/output folders use
*   uninteracted_reg_region_4sector_temp_split and suffix 4sector_temp_split
*-------------------------------------------------------------------------------

version 16.1
args model_variant
clear all
set more off
set rmsg on
set trace off

if "`model_variant'" == "" {
    local model_variant "standard"
}

assert inlist("`model_variant'", "standard", "temp_split")

run "/project/cil/home_dirs/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"
run "${DIR_REPO_LABOR}/2_analysis/0_subroutines/functions.do"

if "`model_variant'" == "temp_split" {
    local model_dir "uninteracted_reg_region_4sector_temp_split"
    local file_suffix "4sector_temp_split"
    local log_suffix "_temp_split"
}
else {
    local model_dir "uninteracted_reg_region_4sector"
    local file_suffix "4sector"
    local log_suffix ""
}

cap log close
cap mkdir "${DIR_OUTPUT}/logs"
log using "${DIR_OUTPUT}/logs/rf_uninteracted_reg_comlohi_region_4sector_final`log_suffix'.log", replace text

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

local reg_root "${DIR_STER}/`model_dir'"
local rf_root "${DIR_RF}/`model_dir'"

cap mkdir "`rf_root'"

*-------------------------------------------------------------------------------
* Sum current-week and lag coefficients
*-------------------------------------------------------------------------------

cap program drop _collect_4sector_spline_terms
program define _collect_4sector_spline_terms

    syntax , splines(numlist) unint(name) int_ag(name) int_mt(name) int_cm(name)

    foreach i of numlist `splines' {

        #delimit ;
        global `unint'`i'  ///
            _b[tmax_rcspl_3kn_t`i']     + ///
            _b[tmax_rcspl_3kn_t`i'_v1]  + ///
            _b[tmax_rcspl_3kn_t`i'_v2]  + ///
            _b[tmax_rcspl_3kn_t`i'_v3]  + ///
            _b[tmax_rcspl_3kn_t`i'_v4]  + ///
            _b[tmax_rcspl_3kn_t`i'_v5]  + ///
            _b[tmax_rcspl_3kn_t`i'_v6]  ;

        global `int_ag'`i'  ///
            _b[1.risk_level#c.tmax_rcspl_3kn_t`i']     + ///
            _b[1.risk_level#c.tmax_rcspl_3kn_t`i'_v1]  + ///
            _b[1.risk_level#c.tmax_rcspl_3kn_t`i'_v2]  + ///
            _b[1.risk_level#c.tmax_rcspl_3kn_t`i'_v3]  + ///
            _b[1.risk_level#c.tmax_rcspl_3kn_t`i'_v4]  + ///
            _b[1.risk_level#c.tmax_rcspl_3kn_t`i'_v5]  + ///
            _b[1.risk_level#c.tmax_rcspl_3kn_t`i'_v6]  ;

        global `int_mt'`i'  ///
            _b[2.risk_level#c.tmax_rcspl_3kn_t`i']     + ///
            _b[2.risk_level#c.tmax_rcspl_3kn_t`i'_v1]  + ///
            _b[2.risk_level#c.tmax_rcspl_3kn_t`i'_v2]  + ///
            _b[2.risk_level#c.tmax_rcspl_3kn_t`i'_v3]  + ///
            _b[2.risk_level#c.tmax_rcspl_3kn_t`i'_v4]  + ///
            _b[2.risk_level#c.tmax_rcspl_3kn_t`i'_v5]  + ///
            _b[2.risk_level#c.tmax_rcspl_3kn_t`i'_v6]  ;

        global `int_cm'`i'  ///
            _b[3.risk_level#c.tmax_rcspl_3kn_t`i']     + ///
            _b[3.risk_level#c.tmax_rcspl_3kn_t`i'_v1]  + ///
            _b[3.risk_level#c.tmax_rcspl_3kn_t`i'_v2]  + ///
            _b[3.risk_level#c.tmax_rcspl_3kn_t`i'_v3]  + ///
            _b[3.risk_level#c.tmax_rcspl_3kn_t`i'_v4]  + ///
            _b[3.risk_level#c.tmax_rcspl_3kn_t`i'_v5]  + ///
            _b[3.risk_level#c.tmax_rcspl_3kn_t`i'_v6]  ;
        #delimit cr
    }
end

*-------------------------------------------------------------------------------
* Build response functions
*-------------------------------------------------------------------------------

foreach region of local regions {

    di as txt "Building 4-sector response functions for `region'"

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

    local common_ster "`reg_folder'/uninteracted_reg_common_`region'_`file_suffix'.ster"
    local bysector_ster "`reg_folder'/uninteracted_reg_by_risk_`region'_`file_suffix'.ster"

    confirm file "`common_ster'"
    confirm file "`bysector_ster'"

    foreach row_values in full_response table_values {

        clear

        local table_type = cond("`row_values'" == "full_response", "full", "table")
        local rf_name "`rf_folder'/rf_`region'_`table_type'_`file_suffix'.csv"

        quietly make_temp_dist, list($`row_values') ref($ref_temp)
        gen mins_worked = .
        make_spline_terms `k1' `k2' `k3'

        *-------------------------------------------------------------------------------
        * Common response
        *-------------------------------------------------------------------------------

        estimates use "`common_ster'"

        _collect_4sector_spline_terms, ///
            splines(0 1) ///
            unint(common) ///
            int_ag(unused_ag) ///
            int_mt(unused_mt) ///
            int_cm(unused_cm)

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

        _collect_4sector_spline_terms, ///
            splines(0 1) ///
            unint(unint) ///
            int_ag(int_ag) ///
            int_mt(int_mt) ///
            int_cm(int_cm)

        foreach g in unint0 unint1 int_ag0 int_ag1 int_mt0 int_mt1 int_cm0 int_cm1 {
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

        * Manufacturing, transport, utilities
        predictnl yhat_mt = ///
            (T_spline0 - ref_spline0) * (`L_unint0' + `L_int_mt0') + ///
            (T_spline1 - ref_spline1) * (`L_unint1' + `L_int_mt1'), ///
            ci(lowerci_mt upperci_mt) se(se_mt)

        * Construction and mining
        predictnl yhat_cm = ///
            (T_spline0 - ref_spline0) * (`L_unint0' + `L_int_cm0') + ///
            (T_spline1 - ref_spline1) * (`L_unint1' + `L_int_cm1'), ///
            ci(lowerci_cm upperci_cm) se(se_cm)

        *-------------------------------------------------------------------------------
        * Pairwise differences
        *-------------------------------------------------------------------------------

        predictnl yhat_ag_low = ///
            (T_spline0 - ref_spline0) * (`L_int_ag0') + ///
            (T_spline1 - ref_spline1) * (`L_int_ag1'), ///
            ci(lowerci_ag_low upperci_ag_low) se(se_ag_low)

        predictnl yhat_mt_low = ///
            (T_spline0 - ref_spline0) * (`L_int_mt0') + ///
            (T_spline1 - ref_spline1) * (`L_int_mt1'), ///
            ci(lowerci_mt_low upperci_mt_low) se(se_mt_low)

        predictnl yhat_cm_low = ///
            (T_spline0 - ref_spline0) * (`L_int_cm0') + ///
            (T_spline1 - ref_spline1) * (`L_int_cm1'), ///
            ci(lowerci_cm_low upperci_cm_low) se(se_cm_low)

        predictnl yhat_ag_mt = ///
            (T_spline0 - ref_spline0) * (`L_int_ag0' - `L_int_mt0') + ///
            (T_spline1 - ref_spline1) * (`L_int_ag1' - `L_int_mt1'), ///
            ci(lowerci_ag_mt upperci_ag_mt) se(se_ag_mt)

        predictnl yhat_ag_cm = ///
            (T_spline0 - ref_spline0) * (`L_int_ag0' - `L_int_cm0') + ///
            (T_spline1 - ref_spline1) * (`L_int_ag1' - `L_int_cm1'), ///
            ci(lowerci_ag_cm upperci_ag_cm) se(se_ag_cm)

        predictnl yhat_mt_cm = ///
            (T_spline0 - ref_spline0) * (`L_int_mt0' - `L_int_cm0') + ///
            (T_spline1 - ref_spline1) * (`L_int_mt1' - `L_int_cm1'), ///
            ci(lowerci_mt_cm upperci_mt_cm) se(se_mt_cm)

        *-------------------------------------------------------------------------------
        * Write CSV
        *-------------------------------------------------------------------------------

        drop T_spline* ref_spline* min ref mins_worked

        keep temp ///
            yhat_comm se_comm lowerci_comm upperci_comm ///
            yhat_low se_low lowerci_low upperci_low ///
            yhat_ag se_ag lowerci_ag upperci_ag ///
            yhat_mt se_mt lowerci_mt upperci_mt ///
            yhat_cm se_cm lowerci_cm upperci_cm ///
            yhat_ag_low se_ag_low lowerci_ag_low upperci_ag_low ///
            yhat_mt_low se_mt_low lowerci_mt_low upperci_mt_low ///
            yhat_cm_low se_cm_low lowerci_cm_low upperci_cm_low ///
            yhat_ag_mt se_ag_mt lowerci_ag_mt upperci_ag_mt ///
            yhat_ag_cm se_ag_cm lowerci_ag_cm upperci_ag_cm ///
            yhat_mt_cm se_mt_cm lowerci_mt_cm upperci_mt_cm

        export delimited using "`rf_name'", replace

        di as result "Wrote: `rf_name'"
    }
}

log close
