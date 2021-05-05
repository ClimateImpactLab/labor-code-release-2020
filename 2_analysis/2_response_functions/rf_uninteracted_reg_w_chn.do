*****************
*	INITIALIZE
*****************

* get functions and paths
run "/home/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"
run "${DIR_REPO_LABOR}/2_analysis/0_subroutines/functions.do"

* select dataset and output folder
loc reg_folder 	"${DIR_STER}/uninteracted_reg_w_chn"
cap mkdir "${DIR_RF}/uninteracted_reg_w_chn"
loc rf_folder 	"${DIR_RF}/uninteracted_reg_w_chn"

* other selections
global ref_temp 27 

* full response function
numlist "-20(0.1)47"
gl full_response `r(numlist)'
* 6 table values
numlist "45 40 35 30 10 5 0"
gl table_values `r(numlist)'
gl spline 21 37 41

***********************************
*	GENERATE RESPONSE FUNCTION CSV
***********************************

foreach row_values in table_values {

	clear 

	* set the ster file names and the output CSV
	local ster			"`reg_folder'/uninteracted_reg_w_chn.ster"
	local rf_name 		"`rf_folder'/uninteracted_reg_w_chn_`row_values'.csv"

	* create the temp list that we want to predict for
	qui make_temp_dist, list($`row_values') ref($ref_temp)

	* need this blank variable to get standard errors in predictnl
	gen mins_worked = .

	********************** BY-RISK RESPONSE **********************

	est use `ster'

	* generate spline terms and collect in macros
	make_spline_terms $spline
	collect_spline_terms, splines(0 1) unint(unint) int(int)

	* predict response function by risk
		predictnl yhat_low =	(T_spline0 - ref_spline0) * (${unint0}) +			///
								(T_spline1 - ref_spline1) * (${unint1}), 			///
								ci(lowerci_low upperci_low) se(se_low)

		predictnl yhat_high =	(T_spline0 - ref_spline0) * (${unint0} + ${int0}) +	///
								(T_spline1 - ref_spline1) * (${unint1} + ${int1}),	///
								ci(lowerci_high upperci_high) se(se_high)

		predictnl yhat_marg =	(T_spline0 - ref_spline0) * (${int0}) +	///
								(T_spline1 - ref_spline1) * (${int1}),	///
								ci(lowerci_marg upperci_marg) se(se_marg)

	drop T* ref_* min*
	export delim `rf_name', replace

}
	   
	  

  
