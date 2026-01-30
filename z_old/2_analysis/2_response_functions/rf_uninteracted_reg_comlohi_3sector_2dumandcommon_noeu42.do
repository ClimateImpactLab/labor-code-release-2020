***********************
* Paths & grids
***********************
run "/project/cil/home_dirs/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"
run "${DIR_REPO_LABOR}/2_analysis/0_subroutines/functions.do"

local reg_folder  "${DIR_STER}/uninteracted_reg_comlohi"
local rf_folder   "${DIR_RF}/uninteracted_reg_comlohi"
cap mkdir "`rf_folder'"

global ref_temp 27

numlist "-20(0.1)47"
global full_response `r(numlist)'

numlist "45 40 35 30 10 5 0 -5 -10"
global table_values `r(numlist)'

******************************
* Main loop: export both grids to CSV
******************************
foreach row_values in full_response table_values {
    clear

    *1) Construct temperature grid
    quietly make_temp_dist, list($`row_values') ref($ref_temp)

    *2) Generate a placeholder dependent variable for predictnl
    gen double mins_worked = .

    *3) Generate spline terms (based on temp/ref)
    quietly make_spline_terms 27 37 39

    *============ COMMON ============
    *Load the common .ster
    local comm_ster "`reg_folder'/uninteracted_reg_common_2025_manuf_noeu.ster"
    estimates use "`comm_ster'"

    *Collect non-interacted spline coefficients (t0 and t1 each include 6 lags)
    collect_sector_spline_terms, splines(0 1) unint(common) int_hr3(unused) int_manuf(unused)

    *Predict common response
    predictnl double yhat_comm = ///
        (T_spline0 - ref_spline0) * (${common0}) + ///
        (T_spline1 - ref_spline1) * (${common1}), ///
        ci(lowerci_comm upperci_comm) se(se_comm)

    *============ BY-RISK ============
    *Load the by_risk .ster
    local by_risk_ster "`reg_folder'/uninteracted_reg_by_risk_2025_manuf2_noeu.ster"
    estimates use "`by_risk_ster'"

    *Collect: non-interacted, manuf interaction, hr3 interaction coefficients
    collect_sector_spline_terms, splines(0 1) unint(unint) int_hr3(int_hr3) int_manuf(int_manuf)

    *Define safe local macros for potentially missing coefficients
    foreach g in unint0 unint1 int_hr30 int_hr31 int_manuf0 int_manuf1 {
        local L_`g' = "${`g'}"
        if "`L_`g''" == "" local L_`g' 0
        di as txt "`g' -> `L_`g''"
    }

    *Baseline: manuf=0 & high_risk3=0
    predictnl double yhat_low = ///
        (T_spline0 - ref_spline0) * (`L_unint0') + ///
        (T_spline1 - ref_spline1) * (`L_unint1'), ///
        ci(lowerci_low upperci_low) se(se_low)

    * manuf=1, hr3=0
    predictnl double yhat_manuf = ///
        (T_spline0 - ref_spline0) * (`L_unint0' + `L_int_manuf0') + ///
        (T_spline1 - ref_spline1) * (`L_unint1' + `L_int_manuf1'), ///
        ci(lowerci_manuf upperci_manuf) se(se_manuf)

    * manuf=0, hr3=1
    predictnl double yhat_hr3 = ///
        (T_spline0 - ref_spline0) * (`L_unint0' + `L_int_hr30') + ///
        (T_spline1 - ref_spline1) * (`L_unint1' + `L_int_hr31'), ///
        ci(lowerci_hr3 upperci_hr3) se(se_hr3)

    * 4) Keep only the necessary columns (drop after predictnl)
    keep temp ref ///
         yhat_comm lowerci_comm upperci_comm se_comm ///
         yhat_low  lowerci_low  upperci_low  se_low  ///
         yhat_manuf lowerci_manuf upperci_manuf se_manuf ///
         yhat_hr3 lowerci_hr3 upperci_hr3 se_hr3

    * 5) Export results
    local rf_name "`rf_folder'/uninteracted_reg_comlohi_`row_values'_2025_manu_noeu_42.csv"
    export delimited using "`rf_name'", replace

    di as res "COMPLETED: Response function for `row_values'. -> `rf_name'"
}
