clear all

*****************
* CHANGE HERE
*****************
* Get functions and paths
run "/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/0_subroutines/paths.do"
run "${DIR_REPO_LABOR}/2_analysis/0_subroutines/functions.do"

* Select dataset and output folder
loc reg_folder "${DIR_OUTPUT}/interacted_reg_output/ster"
loc rf_folder "${DIR_OUTPUT}/interacted_reg_output/response_function"
cap mkdir `rf_folder'

* Other selections are 2_factor. Change here to run 2_factor model
global reg_list 1_factor
global the_factor climate
*  if reg_list = 2_factor, the_factor will not enter the regression
*  if reg_list = 1_factor, set the_factor = income or climate
global ref_temp 27

* Full response function
numlist "-20(0.1)47"
gl full_response `r(numlist)'

* Table values
numlist "45 40 35 30 10 5 0 -5 -10"
gl table_values `r(numlist)'

***********************************
* GENERATE RESPONSE FUNCTION CSVS
***********************************

foreach reg in $reg_list {
    
    * Set the ster file name
    if "$reg_list" == "1_factor" {
        local ster_name "`reg_folder'/interacted_reg_1_factor_2026_272841_climate_appro.ster"
        local rf_name "`rf_folder'/interacted_reg_`reg'_${the_factor}_2026_272841_appro.csv"
    }
    else if "$reg_list" == "2_factor" {
        local ster_name "`reg_folder'/interacted_reg_`reg'_2026_272841.ster"
        local rf_name "`rf_folder'/interacted_reg_`reg'_2026_272841.csv"
    }
    
    * Create postfile to store results
    tempname posth
    
    if "$reg_list" == "1_factor" {
        postfile `posth' temp ref yhat_low se_low lowerci_low upperci_low ///
            yhat_high se_high lowerci_high upperci_high ///
            using "`rf_folder'/__tmp_table.dta", replace
    }
    else if "$reg_list" == "2_factor" {
        postfile `posth' temp ref ///
            yhat_low_gdp se_low_gdp lowerci_low_gdp upperci_low_gdp ///
            yhat_high_gdp se_high_gdp lowerci_high_gdp upperci_high_gdp ///
            yhat_low_lrt se_low_lrt lowerci_low_lrt upperci_low_lrt ///
            yhat_high_lrt se_high_lrt lowerci_high_lrt upperci_high_lrt ///
            using "`rf_folder'/__tmp_table.dta", replace
    }
    
    * Loop through each temperature value
    foreach row_values in $table_values {
        
        * Create the temp list that we want to predict for
        qui make_temp_dist, list(`row_values') ref($ref_temp)
        
        est use `ster_name'
        
        * Generate spline terms
        make_spline_terms 27 28 41
        
        * Run code based on the model
        if "$reg_list" == "1_factor" {
            
            if "${the_factor}" == "income" {
                collect_mix_spline_terms, splines(0 1) unint_gdp(unint_gdp) int_gdp(int_gdp)
                
                * Need this blank variable to get standard errors in predictnl
                gen mins_worked = .
                
                predictnl yhat_low = (T_spline0 - ref_spline0) * (${unint_gdp0}) + ///
                    (T_spline1 - ref_spline1) * (${unint_gdp1}), ///
                    ci(lowerci_low upperci_low) se(se_low)
                
                predictnl yhat_high = (T_spline0 - ref_spline0) * (${int_gdp0}) + ///
                    (T_spline1 - ref_spline1) * (${int_gdp1}), ///
                    ci(lowerci_high upperci_high) se(se_high)
            }
            else if "${the_factor}" == "climate" {
                collect_mix_lrt_spline_terms, splines(0 1) unint(unint) int_lrt(int_lrt)
                
                gen mins_worked = .
                
                predictnl yhat_low = (T_spline0 - ref_spline0) * (${unint0}) + ///
                    (T_spline1 - ref_spline1) * (${unint1}), ///
                    ci(lowerci_low upperci_low) se(se_low)
                
                predictnl yhat_high = (T_spline0 - ref_spline0) * (${int_lrt0}) + ///
                    (T_spline1 - ref_spline1) * (${int_lrt1}), ///
                    ci(lowerci_high upperci_high) se(se_high)
            }
            
            * Post the results for this temperature
            post `posth' (`row_values') ($ref_temp) ///
                (yhat_low[1]) (se_low[1]) (lowerci_low[1]) (upperci_low[1]) ///
                (yhat_high[1]) (se_high[1]) (lowerci_high[1]) (upperci_high[1])
        }
        else if "$reg_list" == "2_factor" {
            collect_gdp_spline_terms, splines(0 1) unint_gdp(unint_gdp) int_gdp(int_gdp)
            collect_lrt_spline_terms, splines(0 1) unint_lrt(unint_lrt) int_lrt(int_lrt)
            
            * Need this blank variable to get standard errors in predictnl
            gen mins_worked = .
            
            predictnl yhat_low_gdp = (T_spline0 - ref_spline0) * (${unint_gdp0}) + ///
                (T_spline1 - ref_spline1) * (${unint_gdp1}), ///
                ci(lowerci_low_gdp upperci_low_gdp) se(se_low_gdp)
            
            predictnl yhat_high_gdp = (T_spline0 - ref_spline0) * (${unint_gdp0} + ${int_gdp0}) + ///
                (T_spline1 - ref_spline1) * (${unint_gdp1} + ${int_gdp1}), ///
                ci(lowerci_high_gdp upperci_high_gdp) se(se_high_gdp)
            
            predictnl yhat_low_lrt = (T_spline0 - ref_spline0) * (${unint_lrt0}) + ///
                (T_spline1 - ref_spline1) * (${unint_lrt1}), ///
                ci(lowerci_low_lrt upperci_low_lrt) se(se_low_lrt)
            
            predictnl yhat_high_lrt = (T_spline0 - ref_spline0) * (${unint_lrt0} + ${int_lrt0}) + ///
                (T_spline1 - ref_spline1) * (${unint_lrt1} + ${int_lrt1}), ///
                ci(lowerci_high_lrt upperci_high_lrt) se(se_high_lrt)
            
            * Post the results for this temperature
            post `posth' (`row_values') ($ref_temp) ///
                (yhat_low_gdp[1]) (se_low_gdp[1]) (lowerci_low_gdp[1]) (upperci_low_gdp[1]) ///
                (yhat_high_gdp[1]) (se_high_gdp[1]) (lowerci_high_gdp[1]) (upperci_high_gdp[1]) ///
                (yhat_low_lrt[1]) (se_low_lrt[1]) (lowerci_low_lrt[1]) (upperci_low_lrt[1]) ///
                (yhat_high_lrt[1]) (se_high_lrt[1]) (lowerci_high_lrt[1]) (upperci_high_lrt[1])
        }
        
        clear
    }
    
    * Close postfile and export
    postclose `posth'
    
    use "`rf_folder'/__tmp_table.dta", clear
    sort temp
    
    export delim "`rf_name'", replace
    
    * Clean up temporary file
    cap erase "`rf_folder'/__tmp_table.dta"
    
    di "Completed: `rf_name'"
}
