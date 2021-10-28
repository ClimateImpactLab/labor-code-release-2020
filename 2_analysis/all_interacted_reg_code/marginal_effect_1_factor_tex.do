clear all

*****************
*	INITIALIZE
*****************

* get functions and paths
run "/home/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"
run "${DIR_REPO_LABOR}/2_analysis/0_subroutines/functions.do"

* select dataset and output folder
loc reg_folder 		"${DIR_OUTPUT}/interacted_reg_output/ster"
loc rf_folder 		"${DIR_OUTPUT}/interacted_reg_output/response_function"
loc table_folder 	"${DIR_OUTPUT}/interacted_reg_output"

***********************************
*	GENERATE LATEX TABLE
***********************************

import delim "`rf_folder'/interacted_reg_1_factor_marg_table_values.csv", clear

* get the N and R squared for each model

	est use "`reg_folder'/interacted_reg_1_factor.ster"
	cap loc N_high	= `e(high_N)'
	cap loc N_low	= `e(low_N)'

	loc R2	= round(`e(r2_a)', 0.001)

convert_table, categories("low high") r2(`R2' `R2') n(`N_low' `N_high')

*****************
*	ADD F TESTS
*****************

* make new rows for the F test
set obs `=_N+2'
replace temp = "F-test" in `=_N-1'
replace temp = "F-test p-value" in `=_N'


* get and label the terms
collect_gdp_spline_terms, splines(0 1) unint_gdp(unint_gdp) int_gdp(int_gdp)

gl marg = subinstr(subinstr(subinstr("$int_gdp0 $int_gdp1", "+", "", .), "_b[","",.), "]","",.)

gl main = subinstr(subinstr(subinstr("$unint_gdp0 $unint_gdp1", "+", "", .), "_b[","",.), "]","",.)

* get by-risk regression F test
est use "`reg_folder'/interacted_reg_1_factor.ster"

di "TESTING $main"
test $main

* F test
loc F = round(`r(F)', 0.001)
replace low = "`F'" in `=_N-1'

* p-value
loc p = round(`r(p)', 0.001)
replace low = "`p'" in `=_N'

di "TESTING $main $marg"
test $main $marg

* F test
loc F = round(`r(F)', 0.001)
replace high = "`F'" in `=_N-1'

* p-value
loc p = round(`r(p)', 0.001)
replace high = "`p'" in `=_N'

**********
* EXPORT
**********

dataout, save("`table_folder'/interacted_reg_1_factor_test") noauto tex replace
