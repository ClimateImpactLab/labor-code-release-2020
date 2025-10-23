*****************
*	INITIALIZE
*****************

* get functions and paths
run "/home/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"
run "${DIR_REPO_LABOR}/2_analysis/0_subroutines/functions.do"

* select dataset and output folder
loc reg_folder 	"${DIR_STER}/uninteracted_polynomials"
cap mkdir "${DIR_RF}/uninteracted_polynomials"
loc rf_folder 	"${DIR_RF}/uninteracted_polynomials"

* other selections
gl ref_temp 27 
gl reg_list nochn wchn

* full response function
numlist "-20(0.1)47"
gl full_response `r(numlist)'
* 6 table values
numlist "40 35 30 10 5 0"
gl table_values `r(numlist)'

***********************************
*	GENERATE RESPONSE FUNCTION CSV
***********************************

foreach reg in $reg_list {
	forval N_order=2(1)4 {
		foreach row_values in full_response {

			clear 

			* set the ster file names and the output CSV
			local ster			"`reg_folder'/uninteracted_polynomials_`reg'_`N_order'.ster"
			local rf_name 		"`rf_folder'/uninteracted_polynomials_`reg'_`N_order'_`row_values'.csv"

			* create the temp list that we want to predict for
			qui make_temp_dist, list($`row_values') ref($ref_temp)

			* need this blank variable to get standard errors in predictnl
			gen mins_worked = .

			********************** BY-RISK RESPONSE **********************

			est use `ster'

			* collect polynomials in macros
			collect_polynomial_terms, order(`N_order') unint(unint) int(int)

			* empty macros
			gl low_predict
			gl high_predict

			* add coefficients terms for predict command
			forval p=1(1)`N_order' {
				gl low_predict = 	"$low_predict" + "(${unint`p'}) * (temp ^`p' - ref ^`p')"
				if `p'!=`N_order' gl low_predict = "$low_predict" + " + "

				gl high_predict = 	"$high_predict" + "(${unint`p'} + ${int`p'}) * (temp ^`p' - ref ^`p')"
				if `p'!=`N_order' gl high_predict = "$high_predict" + " + "
			}

			* predict response function by risk

				di "LOW PREDICTION: $low_predict"
				predictnl yhat_low =	$low_predict,	///
										ci(lowerci_low upperci_low) se(se_low)

				di "HIGH PREDICTION: $high_predict"
				predictnl yhat_high =	$high_predict,	///
										ci(lowerci_high upperci_high) se(se_high)

			drop ref* min*
			export delim `rf_name', replace

		}
	}
}
