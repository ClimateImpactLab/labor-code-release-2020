clear all

*****************
*	INITIALIZE
*****************

* get functions and paths
run "/home/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"
run "${DIR_REPO_LABOR}/2_analysis/0_subroutines/functions.do"

* select dataset and output folder
loc reg_folder 	"${DIR_STER}/interacted_splines"
loc rf_folder 	"${DIR_RF}/interacted_splines"
cap mkdir `rf_folder'

* other selections are 2_factor. change here to run 2_factor model
global reg_list 1_factor
global ref_temp 27 

* full response function
numlist "-20(0.1)47"
gl full_response `r(numlist)'
* 6 table values
numlist "45 40 35 30 10 5 0"
gl table_values `r(numlist)'


***********************************
*	GENERATE RESPONSE FUNCTION CSVS
***********************************

foreach row_values in table_values {

	foreach reg in $reg_list {

		* set the ster file name and the output CSV
		local ster_name	"`reg_folder'/interacted_reg_`reg'.ster"
		local rf_name 	"`rf_folder'/interacted_reg_`reg'_marg_`row_values'.csv"
		
		* create the temp list that we want to predict for
		qui make_temp_dist, list($`row_values') ref($ref_temp)
		est use `ster_name'

		* generate spline terms 
		make_spline_terms 27 37 39
		
		* run code based on the model
		if "$reg_list" == "1_factor" {

			* collect spline terms in macros
			collect_gdp_spline_terms, splines(0 1) unint_gdp(unint_gdp) int_gdp(int_gdp)

			* need this blank variable to get standard errors in predictnl
			gen mins_worked = .

			* predict gdp marginal response function by risk
				predictnl yhat_low =	(T_spline0 - ref_spline0) * (${unint_gdp0}) + (T_spline1 - ref_spline1) * (${unint_gdp1}), ci(lowerci_low upperci_low) se(se_low)

				predictnl yhat_high =	(T_spline0 - ref_spline0) * (${unint_gdp0} + ${int_gdp0}) +	(T_spline1 - ref_spline1) * (${unint_gdp1} + ${int_gdp1}), ci(lowerci_high upperci_high) se(se_high)
		}

		if "$reg_list" == "2_factor" {

			* collect spline terms in macros
			collect_gdp_spline_terms, splines(0 1) unint_gdp(unint_gdp) int_gdp(int_gdp)
			collect_lrt_spline_terms, splines(0 1) unint_lrt(unint_lrt) int_lrt(int_lrt)

			* need this blank variable to get standard errors in predictnl
			gen mins_worked = .

			* predict gdp marginal response function by risk
				predictnl yhat_low_gdp =	(T_spline0 - ref_spline0) * (${unint_gdp0}) + (T_spline1 - ref_spline1) * (${unint_gdp1}), ci(lowerci_low_gdp upperci_low_gdp) se(se_low_gdp)

				predictnl yhat_high_gdp =	(T_spline0 - ref_spline0) * (${unint_gdp0} + ${int_gdp0}) +	(T_spline1 - ref_spline1) * (${unint_gdp1} + ${int_gdp1}), ci(lowerci_high_gdp upperci_high_gdp) se(se_high_gdp)

			* predict lrt marginal response function by risk
				predictnl yhat_low_lrt =	(T_spline0 - ref_spline0) * (${unint_lrt0}) + (T_spline1 - ref_spline1) * (${unint_lrt1}), ci(lowerci_low_lrt upperci_low_lrt) se(se_low_lrt)

				predictnl yhat_high_lrt =	(T_spline0 - ref_spline0) * (${unint_lrt0} + ${int_lrt0}) +	(T_spline1 - ref_spline1) * (${unint_lrt1} + ${int_lrt1}), ci(lowerci_high_lrt upperci_high_lrt) se(se_high_lrt)
		}


		drop T* ref_* min*
		export delim `rf_name', replace
		clear

	}
}      
