
* Updated by: 
* Maiqi Yu (maiqi@uchicago.edu)

clear all
*****************
*  INITIALIZE
*****************

run "/project/cil/home_dirs/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"
run "${DIR_REPO_LABOR}/2_analysis/0_subroutines/functions.do"

loc reg_folder     "${DIR_STER}/uninteracted_reg_comlohi"
loc rf_folder      "${DIR_RF}/uninteracted_reg_comlohi"
loc table_folder   "${DIR_TABLE}"

***********************************
*  READ TABLE VALUES (yhat + se)
***********************************

import delimited "`rf_folder'/uninteracted_reg_comlohi_table_values_2026_272841.csv", clear

* Assumption: dataset has numeric temp and variables:
* temp 
* yhat_comm se_comm
* yhat_low se_low
* yhat_high se_high
* yhat_marg se_marg
* If your file uses different names, rename them here.

***********************************
*  PULL N / Adj.R2 / F-tests from .ster
***********************************

* common regression: fills column (1) and also N for marg column
estimates use "`reg_folder'/uninteracted_reg_common_2026_272841.ster"
local N_common   = e(N)
local R2_common  = round(e(r2_a), 0.01)

* by-risk regression: fills columns (2)(3) and F-tests for low/high/marg as you wish
estimates use "`reg_folder'/uninteracted_reg_by_risk_2026_272841.ster"
local R2_by      = round(e(r2_a), 0.01)

* If you stored group Ns as scalars via estadd scalar low_N/high_N, grab them:
capture local N_low  = e(low_N)
capture local N_high = e(high_N)

* If not available, set missing to blank
if ("`N_low'"  == "") local N_low  = .
if ("`N_high'" == "") local N_high = .

***********************************
*  F-tests (match your current logic)
***********************************

collect_spline_terms, splines(0 1) unint(unint) int(int)

global marg = subinstr( ///
            subinstr( ///
            subinstr( ///
            "$int0 $int1", "+", "", .), ///
            "_b[","",.), ///
            "]","",.)

global main = subinstr( ///
            subinstr( ///
            subinstr( ///
            "$unint0 $unint1", "+", "", .), ///
            "_b[","",.), ///
            "]","",.)

* Column (1): common regression test main
estimates use "`reg_folder'/uninteracted_reg_common_2026_272841.ster"
test $main
local F_comm = round(r(F), 0.001)
local p_comm = round(r(p), 0.001)

* Column (2): by-risk regression test main (low)
estimates use "`reg_folder'/uninteracted_reg_by_risk_2026_272841.ster"
test $main
local F_low = round(r(F), 0.001)
local p_low = round(r(p), 0.001)

* Column (3): by-risk regression test main + marg (high)
test $main $marg
local F_high = round(r(F), 0.001)
local p_high = round(r(p), 0.001)

* Column (4): marginal effect test marg
test $marg
local F_marg = round(r(F), 0.001)
local p_marg = round(r(p), 0.001)

***********************************
*  HELPER: format coef + stars
***********************************

* star rule (large sample normal approx):
* *  : |t| >= 1.645
* ** : |t| >= 1.96
* ***: |t| >= 2.576
capture program drop _fmtcoef
program define _fmtcoef, rclass
    // pass variable names, not numeric expressions
    syntax, BVAR(name) SEVAR(name)

    tempname b se t
    scalar `b'  = `bvar'[1]
    scalar `se' = `sevar'[1]

    // guard against missing or zero SE
    if missing(`b') | missing(`se') | `se'==0 {
        return local coef ""
        return local se   ""
        exit
    }

    scalar `t' = abs(`b'/`se')

    local star ""
    if (`t' >= 2.576) local star "***"
    else if (`t' >= 1.96) local star "**"
    else if (`t' >= 1.645) local star "*"

    local bstr : display %9.2f `b'
    local sstr : display %9.2f `se'
    local bstr = strtrim("`bstr'")
    local sstr = strtrim("`sstr'")

    return local coef "`bstr'`star'"
    return local se   "(`sstr')"
end


***********************************
*  WRITE LaTeX TABLE (paper template)
***********************************

local outtex "`table_folder'/uninteracted_reg_comlohi_table2.tex"
file open fh using "`outtex'", write replace text

file write fh "\begin{table}[H]" _n
file write fh "\centering" _n
file write fh "\caption{\textbf{Table 2}: Weekly minutes worked per worker}" _n
file write fh "\begin{tabular}{lcccc}" _n
file write fh "\hline\hline" _n
file write fh " & \multicolumn{4}{c}{Weekly minutes worked per worker} \\" _n
file write fh "\cline{2-5}" _n
file write fh " & (1) & (2) & (3) & (4) \\" _n
file write fh "Daily maximum temperature & All workers & Low-risk workers & High-risk workers & High minus Low \\" _n
file write fh "\hline" _n

* temperature order: 45 down to -10, with baseline 27 shown as --- (even if absent in data)
local temps "45 40 35 30 27 10 5 0 -5 -10"

foreach T of local temps {

    if (`T' == 27) {
        file write fh "27$^\circ$ & --- & --- & --- & --- \\" _n
        file write fh " & --- & --- & --- & --- \\" _n
        continue
    }

    * find row in data
    preserve
        keep if temp == `T'
        if _N == 0 {
            * if missing row, still print blank
            file write fh "`T'$^\circ$ &  &  &  &  \\" _n
            file write fh " &  &  &  &  \\" _n
            restore
            continue
        }

        * format each column
	quietly _fmtcoef, bvar(yhat_comm) sevar(se_comm)
	local c1 = r(coef)
	local s1 = r(se)

	quietly _fmtcoef, bvar(yhat_low) sevar(se_low)
	local c2 = r(coef)
	local s2 = r(se)

	quietly _fmtcoef, bvar(yhat_high) sevar(se_high)
	local c3 = r(coef)
	local s3 = r(se)

	quietly _fmtcoef, bvar(yhat_marg) sevar(se_marg)
	local c4 = r(coef)
	local s4 = r(se)


    restore

    file write fh "`T'$^\circ$ & `c1' & `c2' & `c3' & `c4' \\" _n
    file write fh " & `s1' & `s2' & `s3' & `s4' \\" _n
}

file write fh "\hline" _n
file write fh "Adj. R-squared & `R2_common' & `R2_by' & `R2_by' & `R2_by' \\" _n
file write fh "N & `N_common' & `N_low' & `N_high' & `N_common' \\" _n
file write fh "F-test & `F_comm' & `F_low' & `F_high' & `F_marg' \\" _n
file write fh "F-test p-value & `p_comm' & `p_low' & `p_high' & `p_marg' \\" _n
file write fh "\hline\hline" _n
file write fh "\end{tabular}" _n
file write fh "\end{table}" _n

file close fh
di as result "Wrote LaTeX table to: `outtex'"
