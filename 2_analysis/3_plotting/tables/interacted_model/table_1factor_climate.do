*-------------------------------------------------------------------------------
* table_1factor_climate.do
*-------------------------------------------------------------------------------
* PURPOSE
*   Build the marginal effects table for the 1-factor climate model
*   The table reports the high-risk long-run temperature term
*
* STEPS
*   1. Load response values and model estimates
*   2. Format coefficients and standard errors
*   3. Add model statistics and write the LaTeX table
*
* INPUTS
*   Table-values CSV from rf_1factor_climate.do
*   Stata estimates file from run_1factor_climate.do
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
log using "${APPG_ROOT}/logs/table_1factor_climate.log", replace

import delimited "${APPG_RF_FOLDER}/${APPG_OUTPUT_TAG}_table_values.csv", clear

tempfile table_data
save `table_data', replace

estimates use "${APPG_REG_FOLDER}/${APPG_OUTPUT_TAG}.ster"
local R2_adj = round(e(r2_a), 0.001)
local N_high = e(high_N)

local int_terms ""
foreach term in 0 1 {
	foreach suffix in "" "_v1" "_v2" "_v3" "_v4" "_v5" "_v6" {
		local int_terms `int_terms' tmax_rcspl_3kn_t`term'_hr_l`suffix'
	}
}

test `int_terms'
local p_raw = r(p)
local p_pct = 100 * `p_raw'
if missing(`p_pct') {
	local p_show ""
}
else if (`p_pct' < 0.1) {
	local p_show "<0.1"
}
else {
	local p_show : display %4.1f `p_pct'
	local p_show = strtrim("`p_show'")
}

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

local outtex "${APPG_TABLE_FOLDER}/${APPG_OUTPUT_TAG}_marginal_effect_table.tex"
file open fh using "`outtex'", write replace text

file write fh "\begin{table}[htbp]" _n
file write fh "\centering" _n
file write fh "\begin{tabular}{lc}" _n
file write fh "\hline" _n
file write fh "Daily maximum & High-risk \\" _n
file write fh "temperature & workers \\" _n
file write fh " & \textit{TMEAN} \\" _n
file write fh "\hline" _n

local temps "45 40 35 30 27 10 5 0 -5 -10"
foreach T of local temps {
	if (`T' == 27) {
		file write fh "27$^\circ$ & - \\" _n
		file write fh " & - \\" _n
		continue
	}

	preserve
	keep if temp == `T'
	if _N == 0 {
		file write fh "`T'$^\circ$ &  \\" _n
		file write fh " &  \\" _n
		restore
		continue
	}

	quietly _fmtcoef, bvar(yhat_high) sevar(se_high)
	local c = r(coef)
	local s = r(se)
	restore

	file write fh "`T'$^\circ$ & `c' \\" _n
	file write fh " & `s' \\" _n
}

file write fh "\hline" _n
file write fh "Overall significance & \(p = `p_show'\%\) \\" _n
file write fh "Adj \(R\)-squared & `R2_adj' \\" _n

local N_high_str : display %12.0fc `N_high'
local N_high_str = strtrim("`N_high_str'")
file write fh "N & `N_high_str' \\" _n

file write fh "\hline" _n
file write fh "\end{tabular}" _n
file write fh "\end{table}" _n

file close fh

*-------------------------------------------------------------------------------
* Export CSV
*-------------------------------------------------------------------------------

export delimited using "${APPG_TABLE_FOLDER}/${APPG_OUTPUT_TAG}_marginal_effect_table_values.csv", replace

di as result "Wrote `outtex'"
di as result "Wrote ${APPG_TABLE_FOLDER}/${APPG_OUTPUT_TAG}_marginal_effect_table_values.csv"

cap log close
