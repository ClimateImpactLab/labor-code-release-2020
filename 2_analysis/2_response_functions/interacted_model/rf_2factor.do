*-------------------------------------------------------------------------------
* rf_2factor.do
*-------------------------------------------------------------------------------
* PURPOSE
*   Build table values for the 2-factor model
*   The script calculates GDP and long-run temperature rows at the table temperatures
*
* STEPS
*   1. Load the shared interacted model settings
*   2. Load the 2-factor estimates
*   3. Predict GDP and long-run temperature effects by risk group
*   4. Export the table-values CSV
*
* INPUTS
*   Stata estimates file from run_2factor.do
*
* OUTPUTS
*   CSV with values for the 2-factor table
*-------------------------------------------------------------------------------

clear all

*-------------------------------------------------------------------------------
* Setup
*-------------------------------------------------------------------------------

run "/project/cil/home_dirs/`c(username)'/repos/labor-code-release-2020/2_analysis/1_regression/interacted_model/config.do"

numlist "45 40 35 30 27 10 5 0 -5 -10"
global APPG_TABLE_VALUES_2F `r(numlist)'

tempname posth
postfile `posth' temp ref ///
	yhat_low_gdp se_low_gdp lowerci_low_gdp upperci_low_gdp ///
	yhat_high_gdp se_high_gdp lowerci_high_gdp upperci_high_gdp ///
	yhat_low_lrt se_low_lrt lowerci_low_lrt upperci_low_lrt ///
	yhat_high_lrt se_high_lrt lowerci_high_lrt upperci_high_lrt ///
	using "${APPG_RF_FOLDER}/__tmp_2factor_table.dta", replace

*-------------------------------------------------------------------------------
* Predict table values
*-------------------------------------------------------------------------------

foreach row_values in $APPG_TABLE_VALUES_2F {
	qui make_temp_dist, list(`row_values') ref(${APPG_REF_TEMP})
	estimates use "${APPG_REG_FOLDER}/${APPG_2FACTOR_NAME}.ster"
	make_spline_terms ${APPG_KNOT1} ${APPG_KNOT2} ${APPG_KNOT3}

	collect_gdp_spline_terms, splines(0 1) unint_gdp(unint_gdp) int_gdp(int_gdp)
	collect_lrt_spline_terms, splines(0 1) unint_lrt(unint_lrt) int_lrt(int_lrt)

	gen mins_worked = .

	predictnl yhat_low_gdp = (T_spline0 - ref_spline0) * (${unint_gdp0}) + ///
		(T_spline1 - ref_spline1) * (${unint_gdp1}), ///
		ci(lowerci_low_gdp upperci_low_gdp) se(se_low_gdp)

	predictnl yhat_high_gdp = (T_spline0 - ref_spline0) * (${unint_gdp0} + ${int_gdp0}) + ///
		(T_spline1 - ref_spline1) * (${unint_gdp1} + ${int_gdp1}), ///
		ci(lowerci_high_gdp upperci_high_gdp) se(se_high_gdp)

	predictnl yhat_low_lrt = (T_spline0 - ref_spline0) * (${unint_lrt0}) + ///
		(T_spline1 - ref_spline1) * (${unint_lrt1}), ///
		ci(lowerci_low_lrt upperci_low_lrt) se(se_low_lrt)

	predictnl yhat_high_lrt = (T_spline0 - ref_spline0) * (${unint_lrt0} + ${int_lrt0}) + ///
		(T_spline1 - ref_spline1) * (${unint_lrt1} + ${int_lrt1}), ///
		ci(lowerci_high_lrt upperci_high_lrt) se(se_high_lrt)

	post `posth' (`row_values') (${APPG_REF_TEMP}) ///
		(yhat_low_gdp[1]) (se_low_gdp[1]) (lowerci_low_gdp[1]) (upperci_low_gdp[1]) ///
		(yhat_high_gdp[1]) (se_high_gdp[1]) (lowerci_high_gdp[1]) (upperci_high_gdp[1]) ///
		(yhat_low_lrt[1]) (se_low_lrt[1]) (lowerci_low_lrt[1]) (upperci_low_lrt[1]) ///
		(yhat_high_lrt[1]) (se_high_lrt[1]) (lowerci_high_lrt[1]) (upperci_high_lrt[1])

	clear
}

postclose `posth'

*-------------------------------------------------------------------------------
* Export CSV
*-------------------------------------------------------------------------------

use "${APPG_RF_FOLDER}/__tmp_2factor_table.dta", clear
sort temp
export delimited using "${APPG_RF_FOLDER}/${APPG_2FACTOR_NAME}_marg_table_values.csv", replace
cap erase "${APPG_RF_FOLDER}/__tmp_2factor_table.dta"

di as result "Wrote ${APPG_RF_FOLDER}/${APPG_2FACTOR_NAME}_marg_table_values.csv"
