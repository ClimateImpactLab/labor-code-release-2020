*****************
*	INITIALIZE
*****************

* get functions and paths
run "/project/cil/home_dirs/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"
run "${DIR_REPO_LABOR}/2_analysis/0_subroutines/functions.do"

* select dataset and output folder
loc reg_folder 	"${DIR_OUTPUT}/interacted_reg_output/2_factor_poly/ster"
loc rf_folder 	"${DIR_OUTPUT}/interacted_reg_output/2_factor_poly/rf"

* other selections
global reg_list 2_factor // 1_factor
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

foreach row_values in full_response {
	foreach reg in $reg_list {
		forval N_order=2(1)4 { 

		* set the ster file name and the output CSV
		local ster_name	"`reg_folder'/interacted_polynomials_`reg'_`N_order'.ster" "
		local rf_name 	"`rf_folder'/interacted_polynomials_`reg'_`N_order'_`row_values'_2025.csv"
		
		* create the temp list that we want to predict for
		qui make_temp_dist, list($`row_values') ref($ref_temp)
		est use `ster_name'

		* collect polynomial terms in macros
		collect_polynomial_terms, order(`N_order') unint(unint) int(int)
		collect_polynomial_terms_gdp, order(`N_order') unint(unint_gdp) int(int_gdp)
		collect_polynomial_terms_lrtmax, order(`N_order') unint(unint_lrtmax) int(int_lrtmax)

		* need this blank variable to get standard errors in predictnl
		gen mins_worked = .

		* predict response function by risk
		forval p=1(1)`N_order' {
			gl low_predict = "$low_predict" + "(${unint`p'}) * (temp ^`p' - ref ^`p')"
			if `p'!=`N_order' gl low_predict = "$low_predict" + " + "

			gl high_predict = "$high_predict" + "(${unint`p'} + ${int`p'}) * (temp ^`p' - ref ^`p')"
			if `p'!=`N_order' gl high_predict = "$high_predict" + " + "
			}

			* predict response function by risk

			di "LOW PREDICTION: $low_predict"
			predictnl yhat_low =	$low_predict, ci(lowerci_low upperci_low) se(se_low)

			di "HIGH PREDICTION: $high_predict"
			predictnl yhat_high =	$high_predict, ci(lowerci_high upperci_high) se(se_high)


		drop T* ref_* min*
		export delim `rf_name', replace
		clear
		
		}
	}
}      
