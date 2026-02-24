********************************************************************************
* uninteracted_reg_sector_table2a.do
*
* PURPOSE:
*   Export Table 2.a (Weekly minutes worked per worker) with 3 sector groups + diffs:
*     (1) All workers
*     (2) Low-risk
*     (3) Agriculture
*     (4) Constr. & Manuf.
*     (5) Constr. & Manuf. − Low-risk        (4) − (2)
*     (6) Agriculture − Low-risk              (3) − (2)
*     (7) Agriculture − Constr. & Manuf.      (3) − (4)
*
*   Reads point estimates/SEs from RF CSV and computes F-tests from .ster 
*
* Udapted by: 
* Maiqi Yu & Marine de Franciosi
********************************************************************************

version 16.0
clear all
set more off

********************************************************************************
* INITIALIZE (PATHS AND INPUTS)
********************************************************************************

run "/project/cil/home_dirs/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"
run "${DIR_REPO_LABOR}/2_analysis/0_subroutines/functions.do"

loc reg_folder     "${DIR_STER}/uninteracted_reg_comlohi"
loc rf_folder      "${DIR_RF}/uninteracted_reg_comlohi"
loc table_folder   "${DIR_TABLE}"


* inputs
local rf_table_csv "`rf_folder'/uninteracted_reg_comlohi_table_values_2026_272841_sector.csv"
local ster_common  "`reg_folder'/uninteracted_reg_common_2026_272841_sector.ster"
local ster_by      "`reg_folder'/uninteracted_reg_by_risk_2026_272841_sector.ster"


********************************************************************************
* READ TABLE VALUES (yhat + se) FROM RF
********************************************************************************

import delimited using "`rf_table_csv'", clear

* Expected columns now:
* temp (numeric)
* yhat_comm se_comm
* yhat_low  se_low
* yhat_ag   se_ag
* yhat_nonag se_nonag
*
* If your CSV uses different names, rename here.

********************************************************************************
* PULL N / Adj.R2 FROM .STER
********************************************************************************

* common regression -> comm col (1)
estimates use "`ster_common'"
local N_common  = e(N)
local R2_common = round(e(r2_a), 0.01)

* by-risk regression -> low/ag/non-ag cols (2)-(4)
* and differences -> nonag - low / ag - low / ag - nonag cols (5)-(7)
estimates use "`ster_by'"
local N_by  = e(N)
local R2_by = round(e(r2_a), 0.01)

* group Ns (added via estadd in reg do-file)
capture local N_low   = e(low_N)
capture local N_ag    = e(ag_N)
capture local N_nonag = e(nonag_N)
if ("`N_low'"   == "") local N_low   = .
if ("`N_ag'"    == "") local N_ag    = .
if ("`N_nonag'" == "") local N_nonag = .

********************************************************************************
* F-TESTS 
********************************************************************************


* Build weekly-sum coefficient expressions using program defined in functions.do
collect_sector_spline_terms, splines(0 1) unint(unint) int_ag(int_ag) int_nonag(int_nonag)

* Define globals (for readibility purposes)
global low0   "$unint0"
global low1   "$unint1"
global ag0    "$int_ag0"
global ag1    "$int_ag1"
global nonag0 "$int_nonag0"
global nonag1 "$int_nonag1"

* -----------------------------
* Common regression:  F-test
* -----------------------------

* (1) Common regression F-test
estimates use "`ster_common'"
test ( $low0 = 0 ) ( $low1 = 0 )
local F_comm = round(r(F), 0.001)
local p_comm = round(r(p), 0.001)

* --------------------------------------------
* By-sector regression: group-specific F-tests
* --------------------------------------------

estimates use "`ster_by'"

* (2) Low-risk:  test low weekly-sum spline terms jointly zero
test ( $low0 = 0 ) ( $low1 = 0 )
local F_low = round(r(F), 0.001)
local p_low = round(r(p), 0.001)

* (3) Agriculture: (low + ag increment) weekly-sum jointly zero
test ( $low0 + $ag0 = 0 ) ( $low1 + $ag1 = 0 )
local F_ag = round(r(F), 0.001)
local p_ag = round(r(p), 0.001)

* (4) Constr&Manuf: (low + nonag increment) weekly-sum jointly zero
test ( $low0 + $nonag0 = 0 ) ( $low1 + $nonag1 = 0 )
local F_nonag = round(r(F), 0.001)
local p_nonag = round(r(p), 0.001)

* (5) ConManuf − Low-risk: nonag increment weekly-sum jointly zero
test ( $nonag0 = 0 ) ( $nonag1 = 0 )
local F_nonag_low = round(r(F), 0.001)
local p_nonag_low = round(r(p), 0.001)

* (6) Ag − Low-risk: ag increment weekly-sum jointly zero
test ( $ag0 = 0 ) ( $ag1 = 0 )
local F_ag_low = round(r(F), 0.001)
local p_ag_low = round(r(p), 0.001)

* (7) Ag − ConManuf: (ag increment − nonag increment) weekly-sum jointly zero
test ( $ag0 - $nonag0 = 0 ) ( $ag1 - $nonag1 = 0 )
local F_ag_nonag = round(r(F), 0.001)
local p_ag_nonag = round(r(p), 0.001)

* Joint row: (Ag−Low)=0 AND (Ag−ConManuf)=0  <=> ag increment = 0 AND nonag increment = 0
test ( $ag0 = 0 ) ( $ag1 = 0 ) ( $nonag0 = 0 ) ( $nonag1 = 0 )
local F_joint = round(r(F), 0.001)
local p_joint = round(r(p), 0.001)

********************************************************************************
* HELPER: format coef + stars (for table cells)
********************************************************************************
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
    if (`t' >= 2.576)      local star "***"
    else if (`t' >= 1.960) local star "**"
    else if (`t' >= 1.645) local star "*"

    local bstr : display %9.2f `b'
    local sstr : display %9.2f `se'
    local bstr = strtrim("`bstr'")
    local sstr = strtrim("`sstr'")

    return local coef "`bstr'`star'"
    return local se   "(`sstr')"
end

********************************************************************************
* WRITE LaTeX TABLE
********************************************************************************
local outtex "`table_folder'/uninteracted_reg_sector_table2a.tex"
file open fh using "`outtex'", write replace text

file write fh "\begin{table}[H]" _n
file write fh "\centering" _n
file write fh "\caption{\textbf{Table 2.a}: Weekly minutes worked per worker (sector-specific responses)}" _n
file write fh "\setlength{\tabcolsep}{4pt}" _n
file write fh "\begin{tabular}{lccccccc}" _n
file write fh "\hline\hline" _n
file write fh " & \multicolumn{7}{c}{Weekly minutes worked per worker} \\" _n
file write fh "\cline{2-8}" _n
file write fh " & (1) & (2) & (3) & (4) & (5) & (6) & (7) \\" _n
file write fh "Daily max. & All & Low-risk & Agriculture & Construction & ConManuf - Low & Ag - Low & Ag - ConManuf \\" _n
file write fh "temperature & workers & workers & workers &  \& Manufacturing & (4)-(2) & (3)-(2) & (3)-(4) \\" _n
file write fh "\hline" _n

local temps "45 40 35 30 27 10 5 0 -5 -10"

foreach T of local temps {

    if (`T' == 27) {
        file write fh "27$^\circ$ & --- & --- & --- & --- & --- & --- & --- \\" _n
        file write fh " & --- & --- & --- & --- & --- & --- & --- \\" _n
        continue
    }

    preserve
        keep if temp == `T'
        if _N == 0 {
            file write fh "`T'$^\circ$ &  &  &  &  &  &  &  \\" _n
            file write fh " &  &  &  &  &  &  &  \\" _n
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

        quietly _fmtcoef, bvar(yhat_nonag_low) sevar(se_nonag_low)
        local c5 = r(coef)
        local s5 = r(se)

        quietly _fmtcoef, bvar(yhat_ag_low) sevar(se_ag_low)
        local c6 = r(coef)
        local s6 = r(se)

        quietly _fmtcoef, bvar(yhat_ag_nonag) sevar(se_ag_nonag)
        local c7 = r(coef)
        local s7 = r(se)

    restore

    file write fh "`T'$^\circ$ & `c1' & `c2' & `c3' & `c4' & `c5' & `c6' & `c7' \\" _n
    file write fh " & `s1' & `s2' & `s3' & `s4' & `s5' & `s6' & `s7' \\" _n
}

file write fh "\hline" _n
file write fh "Adj. R-squared & `R2_common' & `R2_by' & `R2_by' & `R2_by' & `R2_by' & `R2_by' & `R2_by' \\" _n
file write fh "N & `N_common' & `N_low' & `N_ag' & `N_nonag' & `N_by' & `N_by' & `N_by' \\" _n
file write fh "F-test & `F_comm' & `F_low' & `F_ag' & `F_nonag' & `F_nonag_low' & `F_ag_low' & `F_ag_nonag' \\" _n
file write fh "F-test p-value & `p_comm' & `p_low' & `p_ag' & `p_nonag' & `p_nonag_low' & `p_ag_low' & `p_ag_nonag' \\" _n
file write fh "\hline" _n
file write fh "\multicolumn{7}{l}{Joint F-test: (3)-(2)=0 and (3)-(4)=0} & `F_joint' \\" _n
file write fh "\multicolumn{7}{l}{Joint test p-value} & `p_joint' \\" _n
file write fh "\hline\hline" _n
file write fh "\end{tabular}" _n
file write fh "\end{table}" _n

file close fh
di as result "Wrote LaTeX table to: `outtex'"

********************************************************************************
* END
********************************************************************************
