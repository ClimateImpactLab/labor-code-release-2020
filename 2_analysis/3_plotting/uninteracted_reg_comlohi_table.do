*****************
*	INITIALIZE
*****************

* get functions and paths
run "/home/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"
run "${DIR_REPO_LABOR}/2_analysis/0_subroutines/functions.do"

* select dataset and output folder
loc reg_folder 		"${DIR_STER}/uninteracted_reg_comlohi"
loc rf_folder 		"${DIR_RF}/uninteracted_reg_comlohi"  
loc table_folder 	"${DIR_TABLE}"

***********************************
*	GENERATE LATEX TABLE
***********************************

import delim "`rf_folder'/uninteracted_reg_comlohi_table_values.csv", clear

* get the N and R squared for each model
foreach reg in by_risk common {

	est use "`reg_folder'/uninteracted_reg_`reg'.ster"
	loc N_`reg' 	= `e(N)'
	cap loc N_high	= `e(high_N)'
	cap loc N_low	= `e(low_N)'

	loc R2_`reg'	= round(`e(r2_a)', 0.001)

}

convert_table, categories("comm low high marg")		///
	r2(`R2_common' `R2_by_risk' `R2_by_risk')		///
	n(`N_common' `N_low' `N_high')

*********************************************
*	ADD F TEST OF TREATMENT-RISK INTERACTION
*********************************************

* get an F-test of the temp * high_risk interaction
set obs `=_N+2'
est use "`reg_folder'/uninteracted_reg_by_risk.ster"
collect_spline_terms, splines(0 1) unint(unint) int(int)
test ($int0 + $int1) = 0

* F test
loc F = round(`r(F)', 0.001)
replace marg = "`F'" in `=_N-1'
replace temp = "F-test" in `=_N-1'

* p-value
loc p = round(`r(p)', 0.001)
replace marg = "`p'" in `=_N'
replace temp = "F-test p-value" in `=_N'

**********
* EXPORT
**********

dataout, save("`table_folder'/uninteracted_reg_comlohi") noauto tex replace
