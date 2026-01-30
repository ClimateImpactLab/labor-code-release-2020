clear all

*****************
*	INITIALIZE
*****************

* get functions and paths
run "/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/0_subroutines/paths.do"
run "${DIR_REPO_LABOR}/2_analysis/0_subroutines/functions.do"

* select dataset and output folder
loc reg_folder 	"${DIR_OUTPUT}/interacted_reg_output/ster"
loc rf_folder 	"${DIR_OUTPUT}/interacted_reg_output/response_function"
cap mkdir `rf_folder'

* other selections are 2_factor. change here to run 2_factor model
global reg_list 1_factor
global ref_temp 27 

* full response function
numlist "-20(0.1)47"
gl full_response `r(numlist)'
* 6 table values
numlist "45 40 35 30 10 5 0 -5 -10"
gl table_values `r(numlist)'


***********************************
*	GENERATE RESPONSE FUNCTION CSVS
***********************************
* --- add before loops ---
tempname posth
postfile `posth' temp ref yhat_low se_low lowerci_low upperci_low ///
                 yhat_high se_high lowerci_high upperci_high ///
                 using "`rf_folder'/__tmp_table.dta", replace

foreach row_values in $table_values {

    foreach reg in $reg_list {

        local ster_name "`reg_folder'/interacted_reg_1_factor_2026_climate.ster"

        qui make_temp_dist, list(`row_values') ref($ref_temp)
        est use `ster_name'
        make_spline_terms 27 28 41

        collect_mix_lrt_spline_terms, splines(0 1) unint(unint) int_lrt(int_lrt)

        gen mins_worked = .

        predictnl yhat_low  = (T_spline0 - ref_spline0) * (${unint0}) + ///
                             (T_spline1 - ref_spline1) * (${unint1}), ///
                             ci(lowerci_low upperci_low) se(se_low)

        predictnl yhat_high = (T_spline0 - ref_spline0) * (${int_lrt0}) + ///
                             (T_spline1 - ref_spline1) * (${int_lrt1}), ///
                             ci(lowerci_high upperci_high) se(se_high)

        * --- post ONE row ---
        post `posth' (`row_values') ($ref_temp) ///
            (yhat_low[1])  (se_low[1])  (lowerci_low[1])  (upperci_low[1]) ///
            (yhat_high[1]) (se_high[1]) (lowerci_high[1]) (upperci_high[1])

        clear
    }
}

postclose `posth'

use "`rf_folder'/__tmp_table.dta", clear
sort temp
local rf_name "`rf_folder'/interacted_reg_1_factor_2026_climate.csv"
export delim using "`rf_name'", replace
cap erase "`rf_folder'/__tmp_table.dta"
