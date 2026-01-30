
*****************
*  INITIALIZE
*****************

* get functions and paths
run "/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/0_subroutines/paths.do"
run "/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/2_analysis/0_subroutines/functions.do"

* select ster folder and RF output folder
local reg_folder "${DIR_OUTPUT}/interacted_reg_output/ster"
local rf_folder  "${DIR_OUTPUT}/interacted_reg_output/response_function"
cap mkdir `rf_folder'

* here we run the 1_factor model; change to 2_factor if needed
global reg_list 2_factor
global ref_temp 27 

* full response function temp grid
numlist "-20(0.1)47"
global full_response `r(numlist)'

* values used for the “table rows” (optional, you already know this part)
numlist "45 40 35 30 10 5 0 -5 -10"
global table_values `r(numlist)'

***********************************
*  GENERATE 2-FACTOR RF (6 yhat)
***********************************

foreach reg in $reg_list {

    * .ster file (must match your regression naming)
    local ster_name "`reg_folder'/interacted_reg_2_factor_2025_sector.ster"

    * output CSV name for full RF
    local rf_name  "`rf_folder'/interacted_reg_`reg'_full_response_2025_sector.csv"

    * build full temperature grid
    quietly make_temp_dist, list($full_response) ref($ref_temp)

    * load estimates
    estimates use "`ster_name'"

    * spline terms based on temp/ref
    quietly make_spline_terms 27 37 39

    * collect GDP & LRT spline coefficients for risk3
    collect_gdp_spline_terms_level, splines(0 1) unint_gdp(unint_gdp) ag_gdp(ag_gdp) nonag_gdp(nonag_gdp)

    collect_lrt_spline_terms_level, splines(0 1) unint_lrt(unint_lrt) ag_lrt(ag_lrt) nonag_lrt(nonag_lrt)

    * placeholder dependent variable for predictnl
    gen mins_worked = .
    
		predictnl yhat_low_gdp  = (T_spline0 - ref_spline0) * (${unint_gdp0}) + (T_spline1 - ref_spline1) * (${unint_gdp1}), ci(lowerci_low_gdp  upperci_low_gdp)  se(se_low_gdp)
		predictnl yhat_ag_gdp = (T_spline0 - ref_spline0) * (${unint_gdp0} + ${ag_gdp0}) + (T_spline1 - ref_spline1) * (${unint_gdp1} + ${ag_gdp1}), ci(lowerci_ag_gdp upperci_ag_gdp) se(se_ag_gdp)
		predictnl yhat_nonag_gdp = (T_spline0 - ref_spline0) * (${unint_gdp0} + ${nonag_gdp0}) + (T_spline1 - ref_spline1) * (${unint_gdp1} + ${nonag_gdp1}), ci(lowerci_nonag_gdp upperci_nonag_gdp) se(se_nonag_gdp)
		predictnl yhat_low_lrt  = (T_spline0 - ref_spline0) * (${unint_lrt0}) + (T_spline1 - ref_spline1) * (${unint_lrt1}), ci(lowerci_low_lrt  upperci_low_lrt)  se(se_low_lrt)
		predictnl yhat_ag_lrt = (T_spline0 - ref_spline0) * (${unint_lrt0} + ${ag_lrt0}) + (T_spline1 - ref_spline1) * (${unint_lrt1} + ${ag_lrt1}), ci(lowerci_ag_lrt upperci_ag_lrt) se(se_ag_lrt)
		predictnl yhat_nonag_lrt = (T_spline0 - ref_spline0) * (${unint_lrt0} + ${nonag_lrt0}) + (T_spline1 - ref_spline1) * (${unint_lrt1} + ${nonag_lrt1}), ci(lowerci_nonag_lrt upperci_nonag_lrt) se(se_nonag_lrt)



    * clean up and export RF
    drop T* ref_* min*
    export delimited "`rf_name'", replace
    clear
}
