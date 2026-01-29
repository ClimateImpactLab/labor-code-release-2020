*****************
*  INITIALIZE
*****************

run "/project/cil/home_dirs/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"
run "${DIR_REPO_LABOR}/2_analysis/0_subroutines/functions.do"

loc reg_folder     "${DIR_OUTPUT}/interacted_reg_output/ster"
loc rf_folder      "${DIR_OUTPUT}/interacted_reg_output/response_function"
loc table_folder   "${DIR_TABLE}"

***********************************
*  READ TABLE VALUES (yhat + se)
***********************************

* Import CSV with predicted marginal effects for 2-factor model
import delimited "`rf_folder'/interacted_reg_2_factor_marg_table_values_272841.csv", clear

* Expected variables from your prediction code:
* temp ref yhat_low_gdp se_low_gdp lowerci_low_gdp upperci_low_gdp 
* yhat_high_gdp se_high_gdp lowerci_high_gdp upperci_high_gdp
* yhat_low_lrt se_low_lrt lowerci_low_lrt upperci_low_lrt
* yhat_high_lrt se_high_lrt lowerci_high_lrt upperci_high_lrt

* Save table values temporarily
tempfile table_data
save `table_data', replace

***********************************
*  PULL N / Adj.R2 from .ster
***********************************

* Load 2-factor interacted regression
estimates use "`reg_folder'/interacted_reg_2_factor_2026_272841.ster"

local N_total = e(N)
local R2_adj  = round(e(r2_a), 0.01)

* If you stored group Ns as scalars, grab them:
capture local N_low  = e(low_N)
capture local N_high = e(high_N)

* Set to missing if not available
if ("`N_low'"  == "") local N_low  = .
if ("`N_high'" == "") local N_high = .

***********************************
*  READ F-TEST RESULTS FROM EXCEL
***********************************

* Import F-test results from Excel file
import excel "/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/output/interacted_reg_output/test_spline_results_rep_unit_year_sample_wgt_2_factor.xlsx", firstrow clear

* List data to verify structure
list in 1/2

* The Excel file has:
* Row 1: F statistics
* Row 2: p-values
* Columns: lr_GDP_interaction, lr_lrtmax_interaction, lr_joint_interaction, 
*          hl_GDP_interaction, hl_lrtmax_interaction, hl_joint_interaction

* Extract F-statistics from row 1
local F_low_gdp    = lr_GDP_interaction[1]
local F_low_lrt    = lr_lrtmax_interaction[1]
local F_low_joint  = lr_joint_interaction[1]
local F_high_gdp   = hl_GDP_interaction[1]
local F_high_lrt   = hl_lrtmax_interaction[1]
local F_high_joint = hl_joint_interaction[1]

* Extract p-values from row 2 and convert to percentages
local p_low_gdp    = round(lr_GDP_interaction[2] * 100, 0.1)
local p_low_lrt    = round(lr_lrtmax_interaction[2] * 100, 0.1)
local p_low_joint  = round(lr_joint_interaction[2] * 100, 0.1)
local p_high_gdp   = round(hl_GDP_interaction[2] * 100, 0.1)
local p_high_lrt   = round(hl_lrtmax_interaction[2] * 100, 0.1)
local p_high_joint = round(hl_joint_interaction[2] * 100, 0.1)

* Restore table data
use `table_data', clear

***********************************
*  HELPER: format coef + stars
***********************************

capture program drop _fmtcoef
program define _fmtcoef, rclass
    syntax, BVAR(name) SEVAR(name)

    tempname b se t
    scalar `b'  = `bvar'[1]
    scalar `se' = `sevar'[1]

    // Guard against missing or zero SE
    if missing(`b') | missing(`se') | `se'==0 {
        return local coef ""
        return local se   ""
        exit
    }

    scalar `t' = abs(`b'/`se')

    // Star rule (large sample normal approx):
    // *   : |t| >= 1.645 (p<0.10)
    // **  : |t| >= 1.96  (p<0.05)
    // ***: |t| >= 2.576 (p<0.01)
    local star ""
    if (`t' >= 2.576) local star "***"
    else if (`t' >= 1.96) local star "**"
    else if (`t' >= 1.645) local star "*"

    local bstr : display %4.1f `b'
    local sstr : display %3.1f `se'
    local bstr = strtrim("`bstr'")
    local sstr = strtrim("`sstr'")

    return local coef "`bstr'`star'"
    return local se   "(`sstr')"
end

***********************************
*  WRITE LaTeX TABLE
***********************************

local outtex "`table_folder'/interacted_reg_2factor_table.tex"
file open fh using "`outtex'", write replace text

file write fh "\begin{table}[htbp]" _n
file write fh "\centering" _n
file write fh "\caption{Temperature Effects on Weekly Minutes Worked: 2-Factor Interacted Model}" _n
file write fh "\label{tab:interacted_2factor}" _n
file write fh "\begin{tabular}{lcccc}" _n
file write fh "\hline\hline" _n
file write fh "Daily maximum & \multicolumn{2}{c}{Low-risk} & \multicolumn{2}{c}{High-risk} \\" _n
file write fh "temperature & \multicolumn{2}{c}{workers} & \multicolumn{2}{c}{workers} \\" _n
file write fh "\cline{2-3} \cline{4-5}" _n
file write fh " & \textit{LogGDPpc} & \textit{TMEAN} & \textit{LogGDPpc} & \textit{TMEAN} \\" _n
file write fh "\hline" _n

* Temperature order: 45 down to -10, with baseline 27 shown as ---
local temps "45 40 35 30 27 10 5 0 -5 -10"

foreach T of local temps {

    if (`T' == 27) {
        file write fh "27$^\circ$ & --- & --- & --- & --- \\" _n
        file write fh " & --- & --- & --- & --- \\" _n
        continue
    }

    * Find row in data
    preserve
        keep if temp == `T'
        
        if _N == 0 {
            * If missing row, print blank
            file write fh "`T'$^\circ$ &  &  &  &  \\" _n
            file write fh " &  &  &  &  \\" _n
            restore
            continue
        }

        * Format each column using helper function
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

    * Write coefficient row
    file write fh "`T'$^\circ$ & `c1' & `c2' & `c3' & `c4' \\" _n
    * Write standard error row
    file write fh " & `s1' & `s2' & `s3' & `s4' \\" _n
}

file write fh "\hline" _n

* Write overall significance (p-values as percentages)
file write fh "Overall significance & "
file write fh "$p = `p_low_gdp'\%$ & "
file write fh "$p = `p_low_lrt'\%$ & "
file write fh "$p = `p_high_gdp'\%$ & "
file write fh "$p = `p_high_lrt'\%$ \\" _n

* Write Adjusted R-squared
file write fh "Adj $R$-squared & `R2_adj' & `R2_adj' & `R2_adj' & `R2_adj' \\" _n

* Write N (format with commas)
if `N_low' == . {
    local N_low_str ""
}
else {
    local N_low_str : display %12.0fc `N_low'
    local N_low_str = strtrim("`N_low_str'")
}

if `N_high' == . {
    local N_high_str ""
}
else {
    local N_high_str : display %12.0fc `N_high'
    local N_high_str = strtrim("`N_high_str'")
}

file write fh " N & `N_low_str' & `N_low_str' & `N_high_str' & `N_high_str' \\" _n

file write fh "\hline\hline" _n
file write fh "\end{tabular}" _n
file write fh "\end{table}" _n

file close fh

di as result _n "LaTeX table successfully generated: `outtex'"
di as result "F-test results used:"
di as result "  Low-risk GDP:  F = `F_low_gdp',  p = `p_low_gdp'%"
di as result "  High-risk GDP: F = `F_high_gdp', p = `p_high_gdp'%"
di as result "  Low-risk LRT:  F = `F_low_lrt',  p = `p_low_lrt'%"
di as result "  High-risk LRT: F = `F_high_lrt', p = `p_high_lrt'%"
