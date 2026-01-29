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

import delimited "`rf_folder'/uninteracted_reg_comlohi_table_values_2025_272841_sector", clear

* Expected columns now:
* temp (numeric)
* yhat_comm se_comm
* yhat_low  se_low
* yhat_ag   se_ag
* yhat_nonag se_nonag
*
* If your CSV uses different names, rename here.

***********************************
*  PULL N / Adj.R2 from .ster
***********************************

* common regression -> comm column
estimates use "`reg_folder'/uninteracted_reg_common_2025_272841_sector.ster"
local N_common   = e(N)
local R2_common  = round(e(r2_a), 0.01)

* by-risk regression -> low/ag/nonag columns
estimates use "`reg_folder'/uninteracted_reg_by_risk_2025_272841_sector.ster"
local R2_by      = round(e(r2_a), 0.01)

* group Ns (these must have been estadd'ed when saving ster)
capture local N_low   = e(low_N)
capture local N_ag    = e(ag_N)
capture local N_nonag = e(nonag_N)

* if missing, leave blank
if ("`N_low'"   == "") local N_low   = .
if ("`N_ag'"    == "") local N_ag    = .
if ("`N_nonag'" == "") local N_nonag = .

***********************************
*  F-tests (same logic; applied to common and by-risk)
***********************************

collect_spline_terms, splines(0 1) unint(unint) int(int)

global main = subinstr( ///
            subinstr( ///
            subinstr( ///
            "$unint0 $unint1", "+", "", .), ///
            "_b[","",.), ///
            "]","",.)

* Column (1): common regression test main
estimates use "`reg_folder'/uninteracted_reg_common_2025_272841_sector.ster"
test $main
local F_comm = round(r(F), 0.001)
local p_comm = round(r(p), 0.001)

* -----------------------------
* By-risk regression: group-specific F-tests
* -----------------------------
estimates use "`reg_folder'/uninteracted_reg_by_risk_2025_272841_sector.ster"

* $main should be the list of temperature spline terms (continuous vars)
* e.g., "tmax_rcspl_3kn_t0 tmax_rcspl_3kn_t0_v1 ... tmax_rcspl_3kn_t1_v6"
di "MAIN TERMS: $main"

* (A) Low group (base: risk_level==0): test main coefficients = 0
test $main
local F_low = round(r(F), 0.001)
local p_low = round(r(p), 0.001)

* helper: build linear constraints for group g=1 (ag) or g=2 (nonag)
local ag_constr ""
local nonag_constr ""

foreach v of global main {
    * for ag (risk_level==1): beta_v + delta1_v = 0
    local ag_constr `"`ag_constr' (`v' + 1.risk_level#c.`v' = 0)"'

    * for nonag (risk_level==2): beta_v + delta2_v = 0
    local nonag_constr `"`nonag_constr' (`v' + 2.risk_level#c.`v' = 0)"'
}

* (B) Ag group
di "TESTING (AG): `ag_constr'"
test `ag_constr'
local F_ag = round(r(F), 0.001)
local p_ag = round(r(p), 0.001)

* (C) Nonag group
di "TESTING (NONAG): `nonag_constr'"
test `nonag_constr'
local F_nonag = round(r(F), 0.001)
local p_nonag = round(r(p), 0.001)


***********************************
*  HELPER: format coef + stars
***********************************

capture program drop _fmtcoef
program define _fmtcoef, rclass
    syntax, BVAR(name) SEVAR(name)

    tempname b se t
    scalar `b'  = `bvar'[1]
    scalar `se' = `sevar'[1]

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
*  WRITE LaTeX TABLE (paper template: comm/low/ag/nonag)
***********************************

local outtex "`table_folder'/uninteracted_reg_comlohi_table2_sector.tex"
file open fh using "`outtex'", write replace text

file write fh "\begin{table}[H]" _n
file write fh "\centering" _n
file write fh "\caption{\textbf{Table 2.a}: Weekly minutes worked per worker}" _n
file write fh "\begin{tabular}{lcccc}" _n
file write fh "\hline\hline" _n
file write fh " & \multicolumn{4}{c}{Weekly minutes worked per worker} \\" _n
file write fh "\cline{2-5}" _n
file write fh " & (1) & (2) & (3) & (4) \\" _n
file write fh "Daily maximum temperature & All workers & Low-risk workers & High-risk workers (Ag) & High-risk workers (Non-ag) \\" _n
file write fh "\hline" _n

local temps "45 40 35 30 27 10 5 0 -5 -10"

foreach T of local temps {

    if (`T' == 27) {
        file write fh "27$^\circ$ & --- & --- & --- & --- \\" _n
        file write fh " & --- & --- & --- & --- \\" _n
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

        quietly _fmtcoef, bvar(yhat_comm) sevar(se_comm)
        local c1 = r(coef)
        local s1 = r(se)

        quietly _fmtcoef, bvar(yhat_low) sevar(se_low)
        local c2 = r(coef)
        local s2 = r(se)

        quietly _fmtcoef, bvar(yhat_ag) sevar(se_ag)
        local c3 = r(coef)
        local s3 = r(se)

        quietly _fmtcoef, bvar(yhat_nonag) sevar(se_nonag)
        local c4 = r(coef)
        local s4 = r(se)

    restore

    file write fh "`T'$^\circ$ & `c1' & `c2' & `c3' & `c4' \\" _n
    file write fh " & `s1' & `s2' & `s3' & `s4' \\" _n
}

file write fh "\hline" _n
file write fh "Adj. R-squared & `R2_common' & `R2_by' & `R2_by' & `R2_by' \\" _n
file write fh "N & `N_common' & `N_low' & `N_ag' & `N_nonag' \\" _n
file write fh "F-test & `F_comm' & `F_low' & `F_ag' & `F_nonag' \\" _n
file write fh "F-test p-value & `p_comm' & `p_low' & `p_ag' & `p_nonag' \\" _n
file write fh "\hline\hline" _n
file write fh "\end{tabular}" _n
file write fh "\end{table}" _n

file close fh
di as result "Wrote LaTeX table to: `outtex'"
