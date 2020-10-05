*****************
*	INITIALIZE
*****************

* get functions and paths
run "/home/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"
run "${DIR_REPO_LABOR}/2_analysis/0_subroutines/functions.do"

* log results
cap log close 
log using "${DIR_LOG}/rf_uninteracted_reg_FEs.smcl", replace

* select dataset and output folder
loc reg_folder 	"${DIR_STER}/uninteracted_reg_FEs"
loc rf_folder 	"${DIR_RF}/uninteracted_reg_FEs"

* other selections
global fe_list fe_adm0_y fe_adm0_my fe_adm0_wk fe_adm3_my 
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

foreach row_values in full_response table_values {

	foreach fe in $fe_list {

		* set the ster file name and the output CSV
		local ster_name	"`reg_folder'/uninteracted_reg_FE_`fe'.ster"
		local rf_name 	"`rf_folder'/uninteracted_reg_FE_`fe'_`row_values'.csv"
		
		* create the temp list that we want to predict for
		qui make_temp_dist, list($`row_values') ref($ref_temp)
		est use `ster_name'

		* generate spline terms and collect in macros
		make_spline_terms 27 37 39
		collect_spline_terms, splines(0 1) unint(unint) int(int)

		* need this blank variable to get standard errors in predictnl
		gen mins_worked = .

		* predict response function by risk
			predictnl yhat_low =	(T_spline0 - ref_spline0) * (${unint0}) +			///
									(T_spline1 - ref_spline1) * (${unint1}), 			///
									ci(lowerci_low upperci_low) se(se_low)

			predictnl yhat_high =	(T_spline0 - ref_spline0) * (${unint0} + ${int0}) +	///
									(T_spline1 - ref_spline1) * (${unint1} + ${int1}),	///
									ci(lowerci_high upperci_high) se(se_high)

		drop T* ref_* min*
		export delim `rf_name', replace
		clear

	}
}

cap log close 
      
