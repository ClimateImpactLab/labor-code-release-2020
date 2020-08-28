*****************
*	INITIALIZE
*****************

* get functions and paths
run "/home/kschwarz/repos/labor-code-release-2020/0_subroutines/paths.do"
run "${DIR_REPO_LABOR}/2_analysis/0_subroutines/functions.do"

* select dataset and output folder
loc reg_folder 	"${DIR_STER}/uninteracted_reg_comlohi"
loc rf_folder 	"${DIR_RF}/uninteracted_reg_comlohi"

* other selections
global ref_temp 27 

* full response function
numlist "-20(0.1)47"
gl full_response `r(numlist)'
* 6 table values
numlist "40 35 30 10 5 0"
gl table_values `r(numlist)'

***********************************
*	GENERATE RESPONSE FUNCTION CSV
***********************************

foreach row_values in full_response table_values {

	clear 

	* set the ster file names and the output CSV
	local comm_ster		"`reg_folder'/uninteracted_reg_common.ster"
	local by_risk_ster	"`reg_folder'/uninteracted_reg_by_risk.ster"
	local rf_name 		"`rf_folder'/uninteracted_reg_comlohi_`row_values'.csv"

	* create the temp list that we want to predict for
	qui make_temp_dist, list($`row_values') ref($ref_temp)

	* need this blank variable to get standard errors in predictnl
	gen mins_worked = .

	********************** COMMON RESPONSE	**********************

	est use `comm_ster'

	* generate spline terms and collect in macros
	make_spline_terms 27 37 39
	collect_spline_terms, splines(0 1) unint(common) int(unused)

	* predict common response
	predictnl yhat_comm =	(T_spline0 - ref_spline0) * (${common0}) +			///
							(T_spline1 - ref_spline1) * (${common1}), 			///
							ci(lowerci_comm upperci_comm) se(se_comm)

	* drop estimated spline terms
	keep *_comm min temp ref



	********************** BY-RISK RESPONSE **********************

	est use `by_risk_ster'

	* generate spline terms and collect in macros
	make_spline_terms 27 37 39
	collect_spline_terms, splines(0 1) unint(unint) int(int)

	* predict response function by risk
		predictnl yhat_low =	(T_spline0 - ref_spline0) * (${unint0}) +			///
								(T_spline1 - ref_spline1) * (${unint1}), 			///
								ci(lowerci_low upperci_low) se(se_low)

		predictnl yhat_high =	(T_spline0 - ref_spline0) * (${unint0} + ${int0}) +	///
								(T_spline1 - ref_spline1) * (${unint1} + ${int1}),	///
								ci(lowerci_high upperci_high) se(se_high)

	drop T* ref_* min*
	export delim `rf_name', replace

}
	   
	  

