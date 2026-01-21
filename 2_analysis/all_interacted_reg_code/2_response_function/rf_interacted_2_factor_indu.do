*****************
*	INITIALIZE
*****************

* get functions and paths
run "/project/cil/home_dirs/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"
run "${DIR_REPO_LABOR}/2_analysis/0_subroutines/functions.do"

* select ster and output folder
loc reg_folder 	"${DIR_OUTPUT}/interacted_reg_output/ster"
loc rf_folder 	"${DIR_OUTPUT}/interacted_reg_output/rf"
cap mkdir `rf_folder'

* other selections
global reg_list 2_factor
global ref_temp 27 

* full response function grid
numlist "-20(0.1)47"
gl full_response `r(numlist)'

* values for tables
numlist "45 40 35 30 10 5 0 -5 -10"
gl table_values `r(numlist)'


***********************************
*	GENERATE RESPONSE FUNCTION CSVS
***********************************

foreach row_values in full_response {

	foreach reg in $reg_list {

		* set the ster file name and the output CSV
		local ster_name	"`reg_folder'/interacted_reg_`reg'_2025_indu_correct.ster"
		local rf_name 	"`rf_folder'/interacted_reg_`reg'_`row_values'_2025_indu_correct.csv"
		
		* create the temp list that we want to predict for
		quietly make_temp_dist, list($`row_values') ref($ref_temp)

		* load estimates
		est use `ster_name'
		
		* generate spline terms (T_spline0/1, ref_spline0/1, etc.)
		make_spline_terms 27 37 39

		* collect spline coefficient sums for 3 risk groups
		*   ${unint0}, ${unint1}    : low risk
		*   ${int_ag0}, ${int_ag1}  : high-risk agriculture (risk3==1)
		*   ${int_noag0},${int_noag1}: high-risk non-ag (risk3==2)
		collect_indu_spline_terms_2f, splines(0 1) ///
			unint(unint) int1(int_ag) int2(int_noag) gdp(real) lrt(real)

		* blank dep. variable needed for predictnl
		gen mins_worked = .

		* ---------- 1) Low-risk response function ----------
		predictnl yhat_low = ///
			(T_spline0 - ref_spline0) * (${unint0}) + ///
			(T_spline1 - ref_spline1) * (${unint1}), ///
			ci(lowerci_low  upperci_low)  se(se_low)

		* ---------- 2) High-risk agriculture (risk3==1) ----------
		predictnl yhat_hr_ag = ///
			(T_spline0 - ref_spline0) * (${unint0} + ${int_ag0}) + ///
			(T_spline1 - ref_spline1) * (${unint1} + ${int_ag1}), ///
			ci(lowerci_hr_ag  upperci_hr_ag)  se(se_hr_ag)

		* ---------- 3) High-risk non-agriculture (risk3==2) ----------
		predictnl yhat_hr_noag = ///
			(T_spline0 - ref_spline0) * (${unint0} + ${int_noag0}) + ///
			(T_spline1 - ref_spline1) * (${unint1} + ${int_noag1}), ///
			ci(lowerci_hr_noag  upperci_hr_noag) se(se_hr_noag)

		* cleanup & export
		drop T* ref_* min*
		export delim `rf_name', replace
		clear

	}
}
