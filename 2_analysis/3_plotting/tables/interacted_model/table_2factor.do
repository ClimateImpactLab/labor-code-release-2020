*-------------------------------------------------------------------------------
* table_2factor.do
*-------------------------------------------------------------------------------
* PURPOSE
*   Build the marginal effects table for the 2-factor model
*   The table reports GDP and long-run temperature effects for low-risk and high-risk workers
*
* STEPS
*   1. Load response values and model estimates
*   2. Add F-tests for GDP and long-run temperature terms
*   3. Format coefficients and standard errors
*   4. Write the LaTeX table
*
* INPUTS
*   Table-values CSV from rf_2factor.do
*   Stata estimates file from run_2factor.do
*
* OUTPUTS
*   LaTeX table and CSV copy of the table values
*-------------------------------------------------------------------------------

clear all
set more off

*-------------------------------------------------------------------------------
* Setup
*-------------------------------------------------------------------------------

run "/project/cil/home_dirs/`c(username)'/repos/labor-code-release-2020/2_analysis/1_regression/interacted_model/config.do"

cap log close
log using "${APPG_ROOT}/logs/table_2factor.log", replace

import delimited "${APPG_RF_FOLDER}/${APPG_2FACTOR_NAME}_marg_table_values.csv", clear

tempfile table_data
save `table_data', replace

estimates use "${APPG_REG_FOLDER}/${APPG_2FACTOR_NAME}.ster"
local R2_adj = round(e(r2_a), 0.001)
local N_low = e(low_N)
local N_high = e(high_N)

*-------------------------------------------------------------------------------
* Add F-tests
*-------------------------------------------------------------------------------

collect_gdp_spline_terms, splines(0 1) unint_gdp(unint_gdp) int_gdp(int_gdp)
global APPG_MAIN_GDP = subinstr(subinstr(subinstr("$unint_gdp0 $unint_gdp1", "+", "", .), "_b[", "", .), "]", "", .)
global APPG_INT_GDP = subinstr(subinstr(subinstr("$int_gdp0 $int_gdp1", "+", "", .), "_b[", "", .), "]", "", .)

collect_lrt_spline_terms, splines(0 1) unint_lrt(unint_lrt) int_lrt(int_lrt)
global APPG_MAIN_LRT = subinstr(subinstr(subinstr("$unint_lrt0 $unint_lrt1", "+", "", .), "_b[", "", .), "]", "", .)
global APPG_INT_LRT = subinstr(subinstr(subinstr("$int_lrt0 $int_lrt1", "+", "", .), "_b[", "", .), "]", "", .)

test $APPG_MAIN_GDP
local f_low_gdp : display %9.3f round(r(F), 0.001)
local p_low_gdp : display %9.3f round(r(p), 0.001)
local f_low_gdp = strtrim("`f_low_gdp'")
local p_low_gdp = strtrim("`p_low_gdp'")

test $APPG_MAIN_GDP $APPG_INT_GDP
local f_high_gdp : display %9.3f round(r(F), 0.001)
local p_high_gdp : display %9.3f round(r(p), 0.001)
local f_high_gdp = strtrim("`f_high_gdp'")
local p_high_gdp = strtrim("`p_high_gdp'")

test $APPG_MAIN_LRT
local f_low_lrt : display %9.3f round(r(F), 0.001)
local p_low_lrt : display %9.3f round(r(p), 0.001)
local f_low_lrt = strtrim("`f_low_lrt'")
local p_low_lrt = strtrim("`p_low_lrt'")

test $APPG_MAIN_LRT $APPG_INT_LRT
local f_high_lrt : display %9.3f round(r(F), 0.001)
local p_high_lrt : display %9.3f round(r(p), 0.001)
local f_high_lrt = strtrim("`f_high_lrt'")
local p_high_lrt = strtrim("`p_high_lrt'")

macro drop APPG_MAIN_GDP APPG_INT_GDP APPG_MAIN_LRT APPG_INT_LRT

use `table_data', clear

*-------------------------------------------------------------------------------
* Format table values
*-------------------------------------------------------------------------------

capture program drop _fmtcoef
program define _fmtcoef, rclass
	syntax, BVAR(name) SEVAR(name)

	tempname b se t
	scalar `b' = `bvar'[1]
	scalar `se' = `sevar'[1]

	if missing(`b') | missing(`se') | `se' == 0 {
		return local coef ""
		return local se ""
		exit
	}

	scalar `t' = abs(`b' / `se')

	local star ""
	if (`t' >= 2.576) local star "***"
	else if (`t' >= 1.96) local star "**"
	else if (`t' >= 1.645) local star "*"

	local bstr : display %4.1f `b'
	local sstr : display %3.1f `se'
	local bstr = strtrim("`bstr'")
	local sstr = strtrim("`sstr'")

	return local coef "`bstr'`star'"
	return local se "(`sstr')"
end

*-------------------------------------------------------------------------------
* Write table
*-------------------------------------------------------------------------------

local outtex "${APPG_TABLE_FOLDER}/${APPG_2FACTOR_NAME}_marginal_effect_table.tex"
file open fh using "`outtex'", write replace text

file write fh "\begin{table}[htbp]" _n
file write fh "\centering" _n
file write fh "\begin{tabular}{lcccc}" _n
file write fh "\hline\hline" _n
file write fh "Daily maximum & \multicolumn{2}{c}{Low-risk} & \multicolumn{2}{c}{High-risk} \\" _n
file write fh "temperature & \multicolumn{2}{c}{workers} & \multicolumn{2}{c}{workers} \\" _n
file write fh "\cline{2-3} \cline{4-5}" _n
file write fh " & \textit{LogGDPpc} & \textit{TMEAN} & \textit{LogGDPpc} & \textit{TMEAN} \\" _n
file write fh "\hline" _n

local temps "45 40 35 30 27 10 5 0 -5 -10"
foreach T of local temps {
	if (`T' == 27) {
		file write fh "27$^\circ$ & - & - & - & - \\" _n
		file write fh " & - & - & - & - \\" _n
		continue
	}

	preserve
	keep if temp == `T'
	if _N == 0 {
		file write fh "`T'$^\circ$ &  &  &  &  \\" _n
		file write fh " &  &  &  &  \\" _n
		restore
		continue
	}

	quietly _fmtcoef, bvar(yhat_low_gdp) sevar(se_low_gdp)
	local c1 = r(coef)
	local s1 = r(se)
	quietly _fmtcoef, bvar(yhat_low_lrt) sevar(se_low_lrt)
	local c2 = r(coef)
	local s2 = r(se)
	quietly _fmtcoef, bvar(yhat_high_gdp) sevar(se_high_gdp)
	local c3 = r(coef)
	local s3 = r(se)
	quietly _fmtcoef, bvar(yhat_high_lrt) sevar(se_high_lrt)
	local c4 = r(coef)
	local s4 = r(se)
	restore

	file write fh "`T'$^\circ$ & `c1' & `c2' & `c3' & `c4' \\" _n
	file write fh " & `s1' & `s2' & `s3' & `s4' \\" _n
}

file write fh "\hline" _n
file write fh "Adj \(R\)-squared & `R2_adj' & `R2_adj' & `R2_adj' & `R2_adj' \\" _n

local N_low_str : display %12.0fc `N_low'
local N_low_str = strtrim("`N_low_str'")
local N_high_str : display %12.0fc `N_high'
local N_high_str = strtrim("`N_high_str'")
file write fh "N & `N_low_str' & `N_low_str' & `N_high_str' & `N_high_str' \\" _n

file write fh "F-test & `f_low_gdp' & `f_low_lrt' & `f_high_gdp' & `f_high_lrt' \\" _n
file write fh "F-test p-value & `p_low_gdp' & `p_low_lrt' & `p_high_gdp' & `p_high_lrt' \\" _n

file write fh "\hline\hline" _n
file write fh "\end{tabular}" _n
file write fh "\end{table}" _n

file close fh

*-------------------------------------------------------------------------------
* Export CSV
*-------------------------------------------------------------------------------

export delimited using "${APPG_TABLE_FOLDER}/${APPG_2FACTOR_NAME}_marginal_effect_table_values.csv", replace

di as result "Wrote `outtex'"
di as result "Wrote ${APPG_TABLE_FOLDER}/${APPG_2FACTOR_NAME}_marginal_effect_table_values.csv"

cap log close
