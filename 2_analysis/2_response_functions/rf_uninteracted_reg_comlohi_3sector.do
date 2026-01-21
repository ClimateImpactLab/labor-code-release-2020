****************************************************
* This file generates the full response table (at 0.1-degree resolution)
* as well as the table values used in the paper.
*
* How to use:
*   1. Log in to a computing node.
*   2. Update the following settings in this file:
*        - comm_ster
*        - by_risk_ster
*        - rf_name
*	 - !!!! Here is a function with knots (make_spline_terms). Check it!
*
* Runtime:
*   - Runs immediately.
****************************************************




*****************
*	INITIALIZE
*****************
* get functions and paths
run "/project/cil/home_dirs/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"
run "${DIR_REPO_LABOR}/2_analysis/0_subroutines/functions.do"

* select dataset and output folder
loc reg_folder 	"${DIR_STER}/uninteracted_reg_comlohi"
loc rf_folder 	"${DIR_RF}/uninteracted_reg_comlohi"

* create output directory if it doesn't exist
capture mkdir "`rf_folder'"

* other selections
global ref_temp 27 

* full response function
numlist "-20(0.1)47"
gl full_response `r(numlist)'

* table values
numlist "45 40 35 30 10 5 0 -5 -10"
gl table_values `r(numlist)'

***********************************
*	GENERATE RESPONSE FUNCTION CSV
***********************************

foreach row_values in full_response table_values {
	clear 
	
	* set the ster file names and the output CSV
	local comm_ster		"`reg_folder'/uninteracted_reg_common_2025_272841_sector.ster"
	local by_risk_ster	"`reg_folder'/uninteracted_reg_by_risk_2025_272841_sector.ster"
	local rf_name 		"`rf_folder'/uninteracted_reg_comlohi_`row_values'_2025_272841_sector.csv"
	
	* create the temp list that we want to predict for
	qui make_temp_dist, list($`row_values') ref($ref_temp)
	
	* need this blank variable to get standard errors in predictnl
	gen mins_worked = .
	
	********************** COMMON RESPONSE	**********************
	est use `comm_ster'
	
	* generate spline terms and collect in macros
	make_spline_terms 27 28 41
	collect_sector_spline_terms, splines(0 1) unint(common) int_ag(unused) int_nonag(unused)
	
	* predict common response
	predictnl yhat_comm =	(T_spline0 - ref_spline0) * (${common0}) +	///
							(T_spline1 - ref_spline1) * (${common1}), 	///
							ci(lowerci_comm upperci_comm) se(se_comm)
	
	* drop estimated spline terms
	keep *_comm min temp ref mins_worked
	
	********************** BY-RISK RESPONSE **********************
	est use `by_risk_ster'
	
	* generate spline terms and collect in macros
	make_spline_terms 27 28 41
	collect_sector_spline_terms, splines(0 1) unint(unint) int_ag(int_ag) int_nonag(int_nonag)
	
	* make safe locals (handle missing coefficients)
	foreach g in unint0 unint1 int_ag0 int_ag1 int_nonag0 int_nonag1 {
	    local L_`g' = "${`g'}"
	    if "`L_`g''" == "" local L_`g' 0
	    di as txt "`g' -> `L_`g''"
	}

	
	* Low risk (baseline: manuf=0, high_risk3=0)
	* Low risk (baseline: risk_level=0)
	predictnl yhat_low = (T_spline0 - ref_spline0) * (`L_unint0') + ///
			     (T_spline1 - ref_spline1) * (`L_unint1'), ///
			     ci(lowerci_low upperci_low) se(se_low)

	* Ag (risk_level=1)
	predictnl yhat_ag = (T_spline0 - ref_spline0) * (`L_unint0' + `L_int_ag0') + ///
			    (T_spline1 - ref_spline1) * (`L_unint1' + `L_int_ag1'), ///
			    ci(lowerci_ag upperci_ag) se(se_ag)

	* Nonag (risk_level=2)
	predictnl yhat_nonag = (T_spline0 - ref_spline0) * (`L_unint0' + `L_int_nonag0') + ///
			       (T_spline1 - ref_spline1) * (`L_unint1' + `L_int_nonag1'), ///
			       ci(lowerci_nonag upperci_nonag) se(se_nonag)

	
	drop T* ref_* min*
	
	export delim "`rf_name'", replace
	
	di "COMPLETED: Response function for `row_values'."
}
