*****************
*	INITIALIZE
*****************

* get functions and paths
run "/home/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"
run "${DIR_REPO_LABOR}/2_analysis/0_subroutines/functions.do"

* select dataset and output folder
loc reg_folder 		"${DIR_STER}/uninteracted_reg_w_chn"
loc rf_folder 		"${DIR_RF}/uninteracted_reg_w_chn"  
loc table_folder 	"${DIR_TABLE}"

***********************************
*	GENERATE LATEX TABLE
***********************************

import delim "`rf_folder'/uninteracted_reg_w_chn_table_values.csv", clear

* get the N and R squared for each model
	est use "`reg_folder'/uninteracted_reg_w_chn.ster"
	loc N 	= `e(N)'
	cap loc N_high	= `e(high_N)'
	cap loc N_low	= `e(low_N)'

	loc R2	= round(`e(r2_a)', 0.001)


convert_table, categories("low high")		///
	r2(`R2_low' `R2_high')		///
	n(`N_low' `N_high')


*****************
*	ADD F TESTS
*****************

* make new rows for the F test
set obs `=_N+2'
replace temp = "F-test" in `=_N-1'
replace temp = "F-test p-value" in `=_N'


* get and label the terms
collect_spline_terms, splines(0 1) unint(unint) int(int)

gl marg = subinstr(								///
			subinstr(							///
			subinstr(							///
			"$int0 $int1", "+", "", .),			///
			"_b[","",.),						///
			"]","",.)

gl main = subinstr(								///
			subinstr(							///
			subinstr(							///
			"$unint0 $unint1", "+", "", .),		///
			"_b[","",.),						///
			"]","",.)

* get by-risk regression F test
est use "`reg_folder'/uninteracted_reg_w_chn.ster"

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

* get marginal effect F test
di "TESTING $marg"
test $marg

* F test
loc F = round(`r(F)', 0.001)
replace marg = "`F'" in `=_N-1'

* p-value
loc p = round(`r(p)', 0.001)
replace marg = "`p'" in `=_N'



**********
* EXPORT
**********

dataout, save("`table_folder'/uninteracted_reg_w_chn") noauto tex replace
