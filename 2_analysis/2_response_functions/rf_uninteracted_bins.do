*****************
*	INITIALIZE
*****************

* get functions and paths
run "/home/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"
run "${DIR_REPO_LABOR}/2_analysis/0_subroutines/functions.do"

* select dataset and output folder
loc reg_folder 	"${DIR_STER}/uninteracted_bins"
cap mkdir "${DIR_RF}/uninteracted_bins"
loc rf_folder 	"${DIR_RF}/uninteracted_bins"

* other selections
* this ref bin is 24-26 C
gl ref_bin 22 
gl reg_list wchn nochn

* full response function
numlist "-20(0.1)47"
* bins version (for comparison with old data)
* numlist "-30(1)60"
gl full_response `r(numlist)'
* 6 table values
numlist "40 35 30 10 5 0"
gl table_values `r(numlist)' 

***********************************
*	GENERATE RESPONSE FUNCTION CSV
***********************************

foreach reg in $reg_list {
	foreach row_values in full_response {

		clear 

		* set the ster file names and the output CSV
		local ster			"`reg_folder'/uninteracted_bins_`reg'_3C.ster"
		local rf_name 		"`rf_folder'/uninteracted_bins_`reg'_`row_values'.csv"

		* create the temp list that we want to predict for
		qui make_temp_dist, list($`row_values') ref($ref_bin)

		* need this blank variable to get standard errors in predictnl
		gen mins_worked = .

		********************** BY-RISK RESPONSE **********************

		est use `ster'

		* collect polynomials in macros
		collect_bin_terms, bins(bins) unint(unint) int(int)

		* check the names inside the new 'bins' global
		di "YOUR BIN NAMES ARE: $bins"

		* generate the empty variables that we will add the
		* temporary variables into (this is necessary because
		* predictnl only allows generation of a new variable)
		foreach risk in low high {
			gen yhat_`risk' 	= .
			gen se_`risk' 		= .
			gen lowerci_`risk' 	= .
			gen upperci_`risk' 	= .
		} 

		foreach bin in $bins {

			* don't predict reference bin (no coefficients
			* since it's dropped from the regression)
			if "`bin'" == "$ref_bin" continue

			* predict responses for the temps in that specific bin
			predictnl yhat_`bin'_low = ${unint`bin'}							///
				if temp < ${max_`bin'} & temp >= ${min_`bin'},					///
				ci(lowerci_`bin'_low upperci_`bin'_low) se(se_`bin'_low)

			sum yhat_`bin'_low
				
			predictnl yhat_`bin'_high = ${unint`bin'} + ${int`bin'}				///
				if temp < ${max_`bin'} & temp >= ${min_`bin'},					///
				ci(lowerci_`bin'_high upperci_`bin'_high) se(se_`bin'_high)	
			

			* put these temp values into the permanent variables
			foreach risk in low high {
				replace yhat_`risk' 	= yhat_`bin'_`risk' 	if yhat_`risk' ==.
				replace se_`risk' 		= se_`bin'_`risk'		if se_`risk' ==.
				replace lowerci_`risk' 	= lowerci_`bin'_`risk'	if lowerci_`risk' ==.
				replace upperci_`risk' 	= upperci_`bin'_`risk'	if upperci_`risk' ==.
				drop *_`bin'_`risk'
			}
		}

		drop mins
		export delim `rf_name', replace
	}

}  


cap log close
