****************************************************
* rf_uninteracted_reg_comlohi_3sector.do
*
* PURPOSE:
*   Generate response-function CSVs (0.1°C grid + paper table temps)
*   from the 3-group (Low-risk / Agriculture / Constr.&Manuf.) pooled model,
*   and add three difference columns with SEs :
*
*     (5) Constr.&Manuf. − Low-risk  = (4) − (2)
*     (6) Agriculture − Low-risk    = (3) − (2)
*     (7) Agriculture − Constr.&Manuf. = (3) − (4)
*
* INPUTS:
*   - Ensure the .ster files exist:
*       uninteracted_reg_common_2026_272841_sector.ster
*       uninteracted_reg_by_risk_2026_272841_sector.ster
*
* OUTPUT:
*   - Two CSVs:
*       uninteracted_reg_comlohi_full_response_2026_272841_sector.csv
*       uninteracted_reg_comlohi_table_values_2026_272841_sector.csv
*
* Written/Reorganized by: 
* Maiqi Yu (maiqi@uchicago.edu)
****************************************************


version 16.0
clear all
set more off

*****************
* INITIALIZE
*****************

* get functions and paths
run "/project/cil/home_dirs/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"
run "${DIR_REPO_LABOR}/2_analysis/0_subroutines/functions.do"

* select dataset and output folder
loc reg_folder 	"${DIR_STER}/uninteracted_reg_comlohi"
loc rf_folder 	"${DIR_RF}/uninteracted_reg_comlohi"
capture mkdir "`rf_folder'"

* reference temperature
global ref_temp 27

* full response function grid
numlist "-20(0.1)47"
global full_response `r(numlist)'

* table values used in paper
numlist "45 40 35 30 10 5 0 -5 -10"
global table_values `r(numlist)'

*****************
* FILE NAMES
*****************
local comm_ster    "`reg_folder'/uninteracted_reg_common_2026_272841_sector.ster"
local by_risk_ster "`reg_folder'/uninteracted_reg_by_risk_2026_272841_sector.ster"

capture confirm file "`comm_ster'"
if _rc {
    di as error "Missing common .ster: `comm_ster'"
    exit 198
}
capture confirm file "`by_risk_ster'"
if _rc {
    di as error "Missing by-risk .ster: `by_risk_ster'"
    exit 198
}

***********************************
* GENERATE RESPONSE FUNCTION CSVs
***********************************
foreach row_values in full_response table_values {

    clear

    * output file name
    local rf_name "`rf_folder'/uninteracted_reg_comlohi_`row_values'_2026_272841_sector.csv"

	* create the temp list that we want to predict for
    qui make_temp_dist, list($`row_values') ref($ref_temp)

	* need this blank variable to get standard errors in predictnl
    gen mins_worked = .

    * ------------------------------------------------------------
    * Spline Terms: generate once
    * ------------------------------------------------------------
    make_spline_terms 27 28 41

	
    /******************************************************************
     * (1) COMMON RESPONSE (All workers)
     ******************************************************************/
    est use "`comm_ster'"

    * collect coefficient macros for common regression: ${common0} ${common1}
    collect_sector_spline_terms, splines(0 1) unint(common) int_ag(unused) int_nonag(unused)

    * safe locals (in case a term is absent)
    foreach g in common0 common1 {
        local L_`g' = "${`g'}"
        if "`L_`g''" == "" local L_`g' 0
        di as txt "`g' -> `L_`g''"
    }

    predictnl yhat_comm = ///
        (T_spline0 - ref_spline0) * (`L_common0') + ///
        (T_spline1 - ref_spline1) * (`L_common1'), ///
        ci(lowerci_comm upperci_comm) se(se_comm)

    /******************************************************************
     * (2)-(7) BY-RISK RESPONSE + DIFFERENCES
     ******************************************************************/
    est use "`by_risk_ster'"

    * collect coefficient macros for pooled by-risk regression:
    *   ${unint0} ${unint1}         baseline (Low-risk)
    *   ${int_ag0} ${int_ag1}       increment for Agriculture (risk_level==1)
    *   ${int_nonag0} ${int_nonag1} increment for Constr.&Manuf. (risk_level==2)
    collect_sector_spline_terms, splines(0 1) unint(unint) int_ag(int_ag) int_nonag(int_nonag)

    * safe locals (can handle missing coefficients)
    foreach g in unint0 unint1 int_ag0 int_ag1 int_nonag0 int_nonag1 {
        local L_`g' = "${`g'}"
        if "`L_`g''" == "" local L_`g' 0
        di as txt "`g' -> `L_`g''"
    }

    * (2) Low-risk (baseline)
    predictnl yhat_low = ///
        (T_spline0 - ref_spline0) * (`L_unint0') + ///
        (T_spline1 - ref_spline1) * (`L_unint1'), ///
        ci(lowerci_low upperci_low) se(se_low)

    * (3) Agriculture (baseline + int_ag)
    predictnl yhat_ag = ///
        (T_spline0 - ref_spline0) * (`L_unint0' + `L_int_ag0') + ///
        (T_spline1 - ref_spline1) * (`L_unint1' + `L_int_ag1'), ///
        ci(lowerci_ag upperci_ag) se(se_ag)

    * (4) Constr. & Manuf. (baseline + int_nonag)
    predictnl yhat_nonag = ///
        (T_spline0 - ref_spline0) * (`L_unint0' + `L_int_nonag0') + ///
        (T_spline1 - ref_spline1) * (`L_unint1' + `L_int_nonag1'), ///
        ci(lowerci_nonag upperci_nonag) se(se_nonag)

    * (5) Constr.&Manuf. − Low-risk (int_nonag only)
    predictnl yhat_nonag_low = ///
        (T_spline0 - ref_spline0) * (`L_int_nonag0') + ///
        (T_spline1 - ref_spline1) * (`L_int_nonag1'), ///
        ci(lowerci_nonag_low upperci_nonag_low) se(se_nonag_low)

    * (6) Agriculture − Low-risk (int_ag only)
    predictnl yhat_ag_low = ///
        (T_spline0 - ref_spline0) * (`L_int_ag0') + ///
        (T_spline1 - ref_spline1) * (`L_int_ag1'), ///
        ci(lowerci_ag_low upperci_ag_low) se(se_ag_low)

    * (7) Agriculture − Constr.&Manuf. (int_ag − int_nonag)
    predictnl yhat_ag_nonag = ///
        (T_spline0 - ref_spline0) * (`L_int_ag0' - `L_int_nonag0') + ///
        (T_spline1 - ref_spline1) * (`L_int_ag1' - `L_int_nonag1'), ///
        ci(lowerci_ag_nonag upperci_ag_nonag) se(se_ag_nonag)

    /******************************************************************
     * CLEAN + EXPORT
     ******************************************************************/
    * remove construction vars from the prediction dataset
    drop T_spline* ref_spline* min ref mins_worked

    * keep output columns (temp plus yhat/se/cis)
    keep temp ///
         yhat_comm se_comm lowerci_comm upperci_comm ///
         yhat_low  se_low  lowerci_low  upperci_low  ///
         yhat_ag   se_ag   lowerci_ag   upperci_ag   ///
         yhat_nonag se_nonag lowerci_nonag upperci_nonag ///
         yhat_nonag_low se_nonag_low lowerci_nonag_low upperci_nonag_low ///
         yhat_ag_low    se_ag_low    lowerci_ag_low    upperci_ag_low ///
         yhat_ag_nonag  se_ag_nonag  lowerci_ag_nonag  upperci_ag_nonag

    export delimited using "`rf_name'", replace
    di as result "COMPLETED: RF + diffs for `row_values' -> `rf_name'"
}
