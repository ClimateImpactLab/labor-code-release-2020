*-------------------------------------------------------------------------------
* uninteracted_reg_region_ag_equal_3sector.do
*-------------------------------------------------------------------------------
* PURPOSE
*   Build an agriculture response table from the stacked 3-sector model and test
*   whether the agriculture response is equal across regions
*
* STEPS
*   1. Load the stacked 3-sector .ster file
*   2. Test pairwise and joint equality of agriculture spline terms
*   3. Build table-value agriculture response functions by region
*   4. Write CSV and LaTeX table outputs
*
* INPUTS
*   ${DIR_STER}/uninteracted_reg_region_stack_3sector/
*     uninteracted_reg_by_risk_region_stack_3sector.ster
*
* OUTPUTS
*   ${DIR_RF}/uninteracted_reg_region_stack_3sector/
*     region_ag_table_values_3sector.csv
*   ${DIR_TABLE}/uninteracted_reg_region_ag_equal_3sector.tex
*-------------------------------------------------------------------------------

version 16.1
clear all
set more off

run "/project/cil/home_dirs/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"
run "${DIR_REPO_LABOR}/2_analysis/0_subroutines/functions.do"

local reg_folder   "${DIR_STER}/uninteracted_reg_region_stack_3sector"
local rf_folder    "${DIR_RF}/uninteracted_reg_region_stack_3sector"
local table_folder "${DIR_TABLE}"

cap mkdir "${DIR_RF}"
cap mkdir "`rf_folder'"
cap mkdir "`table_folder'"

local ster_by "`reg_folder'/uninteracted_reg_by_risk_region_stack_3sector.ster"

*-------------------------------------------------------------------------------
* Helpers
*-------------------------------------------------------------------------------

cap program drop _knots_for_region
program define _knots_for_region, rclass
    syntax , region(string)

    if "`region'" == "EuropeUS" {
        return scalar k1 = 14
        return scalar k2 = 20
        return scalar k3 = 28
        return local short "eu"
    }
    if "`region'" == "LatinAmerica" {
        return scalar k1 = 26
        return scalar k2 = 29
        return scalar k3 = 34
        return local short "la"
    }
    if "`region'" == "SouthAsia" {
        return scalar k1 = 28
        return scalar k2 = 33
        return scalar k3 = 41
        return local short "sa"
    }
end

cap program drop _collect_region_ag_terms
program define _collect_region_ag_terms

    foreach i in 0 1 {
        #delimit ;
        global ag_eu`i'
            _b[tmax_rcspl_3kn_t`i'] +
            _b[tmax_rcspl_3kn_t`i'_v1] +
            _b[tmax_rcspl_3kn_t`i'_v2] +
            _b[tmax_rcspl_3kn_t`i'_v3] +
            _b[tmax_rcspl_3kn_t`i'_v4] +
            _b[tmax_rcspl_3kn_t`i'_v5] +
            _b[tmax_rcspl_3kn_t`i'_v6] +
            _b[1.risk_level#c.tmax_rcspl_3kn_t`i'] +
            _b[1.risk_level#c.tmax_rcspl_3kn_t`i'_v1] +
            _b[1.risk_level#c.tmax_rcspl_3kn_t`i'_v2] +
            _b[1.risk_level#c.tmax_rcspl_3kn_t`i'_v3] +
            _b[1.risk_level#c.tmax_rcspl_3kn_t`i'_v4] +
            _b[1.risk_level#c.tmax_rcspl_3kn_t`i'_v5] +
            _b[1.risk_level#c.tmax_rcspl_3kn_t`i'_v6] ;
        #delimit cr

        foreach R in la sa {
            local rid = cond("`R'"=="la", 2, 3)

            #delimit ;
            global ag_`R'`i'
                ${ag_eu`i'} +
                _b[`rid'.region_id#c.tmax_rcspl_3kn_t`i'] +
                _b[`rid'.region_id#c.tmax_rcspl_3kn_t`i'_v1] +
                _b[`rid'.region_id#c.tmax_rcspl_3kn_t`i'_v2] +
                _b[`rid'.region_id#c.tmax_rcspl_3kn_t`i'_v3] +
                _b[`rid'.region_id#c.tmax_rcspl_3kn_t`i'_v4] +
                _b[`rid'.region_id#c.tmax_rcspl_3kn_t`i'_v5] +
                _b[`rid'.region_id#c.tmax_rcspl_3kn_t`i'_v6] +
                _b[1.risk_level#`rid'.region_id#c.tmax_rcspl_3kn_t`i'] +
                _b[1.risk_level#`rid'.region_id#c.tmax_rcspl_3kn_t`i'_v1] +
                _b[1.risk_level#`rid'.region_id#c.tmax_rcspl_3kn_t`i'_v2] +
                _b[1.risk_level#`rid'.region_id#c.tmax_rcspl_3kn_t`i'_v3] +
                _b[1.risk_level#`rid'.region_id#c.tmax_rcspl_3kn_t`i'_v4] +
                _b[1.risk_level#`rid'.region_id#c.tmax_rcspl_3kn_t`i'_v5] +
                _b[1.risk_level#`rid'.region_id#c.tmax_rcspl_3kn_t`i'_v6] ;
            #delimit cr
        }
    }
end

cap program drop _fmtcoef
program define _fmtcoef, rclass
    syntax, BVAR(name) SEVAR(name)

    tempname b se t
    scalar `b'  = `bvar'[1]
    scalar `se' = `sevar'[1]

    if missing(`b') | missing(`se') {
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

*-------------------------------------------------------------------------------
* Pull model statistics and F-tests
*-------------------------------------------------------------------------------

estimates use "`ster_by'"
local N_by  = e(N)
local R2_by = round(e(r2_a), 0.01)

foreach short in eu la sa {
    capture local N_`short' = e(N_`short')
    capture local ag_N_`short' = e(ag_N_`short')
    if ("`N_`short''" == "") local N_`short' = .
    if ("`ag_N_`short''" == "") local ag_N_`short' = .
}

_collect_region_ag_terms

test ( ($ag_eu0) - ($ag_la0) = 0 ) ( ($ag_eu1) - ($ag_la1) = 0 )
local F_eu_la = round(r(F), 0.001)
local p_eu_la = round(r(p), 0.001)

test ( ($ag_eu0) - ($ag_sa0) = 0 ) ( ($ag_eu1) - ($ag_sa1) = 0 )
local F_eu_sa = round(r(F), 0.001)
local p_eu_sa = round(r(p), 0.001)

test ( ($ag_la0) - ($ag_sa0) = 0 ) ( ($ag_la1) - ($ag_sa1) = 0 )
local F_la_sa = round(r(F), 0.001)
local p_la_sa = round(r(p), 0.001)

test ///
    ( ($ag_eu0) - ($ag_la0) = 0 ) ///
    ( ($ag_eu1) - ($ag_la1) = 0 ) ///
    ( ($ag_eu0) - ($ag_sa0) = 0 ) ///
    ( ($ag_eu1) - ($ag_sa1) = 0 )
local F_joint = round(r(F), 0.001)
local p_joint = round(r(p), 0.001)

*-------------------------------------------------------------------------------
* Build region-specific agriculture response functions
*-------------------------------------------------------------------------------

global ref_temp 27
numlist "45 40 35 30 10 5 0 -5 -10"
global table_values `r(numlist)'

local regions "EuropeUS LatinAmerica SouthAsia"
tempfile rf_eu rf_la rf_sa

foreach REG of local regions {

    quietly _knots_for_region, region("`REG'")
    local k1 = r(k1)
    local k2 = r(k2)
    local k3 = r(k3)
    local short = r(short)

    clear
    quietly make_temp_dist, list($table_values) ref($ref_temp)
    gen mins_worked = .
    make_spline_terms `k1' `k2' `k3'

    estimates use "`ster_by'"
    _collect_region_ag_terms

    local g0 "ag_`short'0"
    local g1 "ag_`short'1"
    local L0 "${`g0'}"
    local L1 "${`g1'}"

    predictnl yhat_`short' = ///
        (T_spline0 - ref_spline0) * (`L0') + ///
        (T_spline1 - ref_spline1) * (`L1'), ///
        ci(lowerci_`short' upperci_`short') se(se_`short')

    keep temp yhat_`short' se_`short' lowerci_`short' upperci_`short'
    save "`rf_`short''", replace
}

use "`rf_eu'", clear
merge 1:1 temp using "`rf_la'", nogen assert(match)
merge 1:1 temp using "`rf_sa'", nogen assert(match)

export delimited using "`rf_folder'/region_ag_table_values_3sector.csv", replace

*-------------------------------------------------------------------------------
* Write LaTeX table
*-------------------------------------------------------------------------------

local outtex "`table_folder'/uninteracted_reg_region_ag_equal_3sector.tex"
file open fh using "`outtex'", write replace text

file write fh "\begin{table}[H]" _n
file write fh "\centering" _n
file write fh "\caption{Agriculture temperature response by region}" _n
file write fh "\setlength{\tabcolsep}{8pt}" _n
file write fh "\begin{tabular}{lccc}" _n
file write fh "\hline\hline" _n
file write fh " & \multicolumn{3}{c}{Weekly minutes worked per worker} \\" _n
file write fh "\cline{2-4}" _n
file write fh "Daily max. temperature & Europe/US & Latin America & South Asia \\" _n
file write fh "\hline" _n

local temps "45 40 35 30 27 10 5 0 -5 -10"

foreach T of local temps {

    if (`T' == 27) {
        file write fh "27$^\circ$ & --- & --- & --- \\" _n
        file write fh " & --- & --- & --- \\" _n
        continue
    }

    preserve
        keep if temp == `T'
        if _N == 0 {
            file write fh "`T'$^\circ$ &  &  &  \\" _n
            file write fh " &  &  &  \\" _n
            restore
            continue
        }

        quietly _fmtcoef, bvar(yhat_eu) sevar(se_eu)
        local c1 = r(coef)
        local s1 = r(se)

        quietly _fmtcoef, bvar(yhat_la) sevar(se_la)
        local c2 = r(coef)
        local s2 = r(se)

        quietly _fmtcoef, bvar(yhat_sa) sevar(se_sa)
        local c3 = r(coef)
        local s3 = r(se)
    restore

    file write fh "`T'$^\circ$ & `c1' & `c2' & `c3' \\" _n
    file write fh " & `s1' & `s2' & `s3' \\" _n
}

file write fh "\hline" _n
file write fh "Adj. R-squared & `R2_by' & `R2_by' & `R2_by' \\" _n
file write fh "Agriculture N & `ag_N_eu' & `ag_N_la' & `ag_N_sa' \\" _n
file write fh "Model N & `N_eu' & `N_la' & `N_sa' \\" _n
file write fh "\hline" _n
file write fh "\multicolumn{3}{l}{F-test: Europe/US = Latin America} & `F_eu_la' \\" _n
file write fh "\multicolumn{3}{l}{p-value} & `p_eu_la' \\" _n
file write fh "\multicolumn{3}{l}{F-test: Europe/US = South Asia} & `F_eu_sa' \\" _n
file write fh "\multicolumn{3}{l}{p-value} & `p_eu_sa' \\" _n
file write fh "\multicolumn{3}{l}{F-test: Latin America = South Asia} & `F_la_sa' \\" _n
file write fh "\multicolumn{3}{l}{p-value} & `p_la_sa' \\" _n
file write fh "\multicolumn{3}{l}{Joint F-test: agriculture response equal across regions} & `F_joint' \\" _n
file write fh "\multicolumn{3}{l}{Joint test p-value} & `p_joint' \\" _n
file write fh "\hline\hline" _n
file write fh "\end{tabular}" _n
file write fh "\begin{flushleft}" _n
file write fh "\footnotesize Notes: Estimates come from one stacked regional 3-sector regression. The displayed response is for agriculture workers. F-tests compare the weekly summed agriculture spline terms across regions." _n
file write fh "\end{flushleft}" _n
file write fh "\end{table}" _n

file close fh

di as result "Wrote RF CSV to: `rf_folder'/region_ag_table_values_3sector.csv"
di as result "Wrote LaTeX table to: `outtex'"
