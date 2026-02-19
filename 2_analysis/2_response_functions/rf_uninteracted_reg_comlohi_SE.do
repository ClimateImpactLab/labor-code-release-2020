********************************************************************************
* rf_uninteracted_reg_comlohi_SE.do
*

* PURPOSE:
*   Generate response-function CSVs for Table A.1 (RF High-Risk and Self-Employment)
*     - by-risk RF for NON-self-employed workers  (noSE)
*     - by-risk RF for self-employed workers      (onlySE)
*
* INPUT (from regression):
*   `reg_folder'/uninteracted_reg_by_risk_noSE_2026.ster
*   `reg_folder'/uninteracted_reg_by_risk_onlySE_2026.ster
*
* OUTPUT (to `rf_folder'):
*   uninteracted_reg_comlohi_full_response_noSE_2026.csv
*   uninteracted_reg_comlohi_full_response_onlySE_2026.csv
*   uninteracted_reg_comlohi_table_values_noSE_2026.csv
*   uninteracted_reg_comlohi_table_values_onlySE_2026.csv
*
********************************************************************************

version 16.0
clear all
set more off

*****************
* INITIALIZE
*****************

* paths + functions
run "/Volumes/project/cil/home_dirs/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"
run "${DIR_REPO_LABOR}/2_analysis/0_subroutines/functions.do"

* folders (match the regression runner)
local reg_folder "${DIR_STER}/uninteracted_reg_comlohi_SE"
local rf_folder  "${DIR_RF}/uninteracted_reg_comlohi_SE"
cap mkdir "`rf_folder'"

* reference temperature
global ref_temp 27

* grids (same as your existing RF code)
numlist "-20(0.1)47"
global full_response `r(numlist)'

numlist "45 40 35 30 10 5 0 -5 -10"
global table_values `r(numlist)'

* Manually defining knots:
local k1 27
local k2 28
local k3 41

***********************************
* GENERATE RESPONSE FUNCTION CSVs
***********************************

foreach se_tag in noSE onlySE {

    di as txt "=============================================="
    di as txt "RF export for sample: `se_tag'"
    di as txt "=============================================="

    local by_risk_ster "`reg_folder'/uninteracted_reg_by_risk_`se_tag'_2026.ster"

    foreach grid in full_response table_values {

        clear

        local rf_name "`rf_folder'/uninteracted_reg_comlohi_`grid'_`se_tag'_2026.csv"

        * prediction grid
        qui make_temp_dist, list($`grid') ref($ref_temp)

        * blank depvar for predictnl
        gen mins_worked = .

        * load estimates
        est use `by_risk_ster'

        * spline basis on temp/ref:
        make_spline_terms `k1' `k2' `k3'

        * collect summed coefficients across v1..v6
        collect_spline_terms, splines(0 1) unint(unint) int(int)

        * Low-risk response
        predictnl yhat_low = ///
            (T_spline0 - ref_spline0) * (${unint0}) + ///
            (T_spline1 - ref_spline1) * (${unint1}), ///
            ci(lowerci_low upperci_low) se(se_low)

        * High-risk response
        predictnl yhat_high = ///
            (T_spline0 - ref_spline0) * (${unint0} + ${int0}) + ///
            (T_spline1 - ref_spline1) * (${unint1} + ${int1}), ///
            ci(lowerci_high upperci_high) se(se_high)

        * keep variables: 
        keep temp ref ///
             yhat_low se_low lowerci_low upperci_low ///
             yhat_high se_high lowerci_high upperci_high
			 
		* export to csv
        export delim using `rf_name', replace
        di as txt "WROTE: `rf_name'"
    }
}

di as txt "DONE: RF CSVs written to `rf_folder'"
