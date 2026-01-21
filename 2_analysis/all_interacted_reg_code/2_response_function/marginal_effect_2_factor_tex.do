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

import delim "`rf_folder'/interacted_reg_2_factor_marg_table_values.csv", clear

* get the N and R squared for each model

	est use "`reg_folder'/interacted_reg_2_factor.ster"
	cap loc N_high	= `e(high_N)'
	cap loc N_low	= `e(low_N)'

	loc R2	= round(`e(r2_a)', 0.001)

convert_table, categories("low_gdp high_gdp low_lrt high_lrt") r2(`R2' `R2' `R2' `R2') n(`N_low' `N_high' `N_low' `N_high')

*****************
*	ADD F TESTS
*****************

* make new rows for the F test
set obs `=_N+2'
replace temp = "F-test" in `=_N-1'
replace temp = "F-test p-value" in `=_N'


* get and label the terms

* GDP terms
collect_gdp_spline_terms, splines(0 1) unint_gdp(unint_gdp) int_gdp(int_gdp)

gl marg_gdp = subinstr(subinstr(subinstr("$int_gdp0 $int_gdp1", "+", "", .), "_b[","",.), "]","",.)

gl main_gdp = subinstr(subinstr(subinstr("$unint_gdp0 $unint_gdp1", "+", "", .), "_b[","",.), "]","",.)

* LRT terms
collect_lrt_spline_terms, splines(0 1) unint_lrt(unint_lrt) int_lrt(int_lrt)

gl marg_lrt = subinstr(subinstr(subinstr("$int_lrt0 $int_lrt1", "+", "", .), "_b[","",.), "]","",.)

gl main_lrt = subinstr(subinstr(subinstr("$unint_lrt0 $unint_lrt1", "+", "", .), "_b[","",.), "]","",.)

* get regression F test
est use "`reg_folder'/interacted_reg_2_factor.ster"

****** LOW RISK- GDP ******
di "TESTING $main_gdp"
test $main_gdp

* F test
loc F = round(`r(F)', 0.001)
replace low_gdp = "`F'" in `=_N-1'

* p-value
loc p = round(`r(p)', 0.001)
replace low_gdp = "`p'" in `=_N'

****** HIGH RISK - GDP ******
di "TESTING $main_gdp $marg_gdp"
test $main_gdp $marg_gdp

* F test
loc F = round(`r(F)', 0.001)
replace high_gdp = "`F'" in `=_N-1'

* p-value
loc p = round(`r(p)', 0.001)
replace high_gdp = "`p'" in `=_N'

****** LOW RISK - LRT ******
di "TESTING $main_lrt"
test $main_lrt

* F test
loc F = round(`r(F)', 0.001)
replace low_lrt = "`F'" in `=_N-1'

* p-value
loc p = round(`r(p)', 0.001)
replace low_lrt = "`p'" in `=_N'

****** HIGH RISK - LRT ******
di "TESTING $main_lrt $marg_lrt"
test $main_lrt $marg_lrt

* F test
loc F = round(`r(F)', 0.001)
replace high_lrt = "`F'" in `=_N-1'

* p-value
loc p = round(`r(p)', 0.001)
replace high_lrt = "`p'" in `=_N'

**********
* EXPORT
**********

dataout, save("`table_folder'/interacted_reg_2_factor") noauto tex replace
