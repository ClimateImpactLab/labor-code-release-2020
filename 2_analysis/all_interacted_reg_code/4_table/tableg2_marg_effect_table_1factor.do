*****************
*  INITIALIZE
*****************
run "/project/cil/home_dirs/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"
run "${DIR_REPO_LABOR}/2_analysis/0_subroutines/functions.do"

loc reg_folder     "${DIR_OUTPUT}/interacted_reg_output/ster"
loc rf_folder      "${DIR_OUTPUT}/interacted_reg_output/response_function"
loc table_folder   "${DIR_TABLE}"

****************************************************
*  USER CONTROL: choose label + which pval in xlsx
****************************************************
* Options: "gdp" or "lrt"
local factor "gdp"

****************************************************
*  READ TABLE VALUES (yhat + se)
*  NOTE: your CSV now has yhat_low/yhat_high (already chosen factor)
****************************************************
import delimited "`rf_folder'/interacted_reg_1_factor_marg_table_values_2026_272841.csv", clear

* Expect columns:
* temp ref yhat_low se_low lowerci_low upperci_low
* yhat_high se_high lowerci_high upperci_high

tempfile table_data
save `table_data', replace

****************************************************
*  PULL N / Adj.R2 from .ster
****************************************************
estimates use "`reg_folder'/interacted_reg_1_factor_2026_272841_income.ster"

local R2_adj  = round(e(r2_a), 0.01)

capture local N_high = e(high_N)
if ("`N_high'" == "") local N_high = e(N)
****************************************************
*  READ F-TEST RESULTS FROM EXCEL (NEW FORMAT)
*  ASSUME: row1 = F, row2 = pval (as your screenshot)
****************************************************
import excel "/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/output/interacted_reg_output/test_spline_results_rep_unit_year_sample_wgt_1_factor.xlsx", ///
    firstrow clear

* p-value is in row 2
local prow = 2

local p_raw = .
if ("`factor'" == "gdp") {
    local p_raw = hl_GDP_interaction[`prow']
}
else if ("`factor'" == "lrt") {
    local p_raw = hl_lrtmax_interaction[`prow']
}
else {
    di as error "ERROR: local factor must be 'gdp' or 'lrt'. You set: `factor'"
    exit 198
}

* Convert to percent and format
local p_pct = `p_raw' * 100
local p_show ""
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

****************************************************
*  Restore table data
****************************************************
use `table_data', clear

****************************************************
*  Helper: format coef + stars
****************************************************
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

    local bstr : display %4.1f `b'
    local sstr : display %3.1f `se'
    local bstr = strtrim("`bstr'")
    local sstr = strtrim("`sstr'")

    return local coef "`bstr'`star'"
    return local se   "(`sstr')"
end

****************************************************
*  Column label (only affects header text)
****************************************************
local collabel ""
if ("`factor'" == "gdp") local collabel "LogGDPpc"
if ("`factor'" == "lrt") local collabel "LRTMAX"   // or "TMEAN" if you prefer

****************************************************
*  WRITE LaTeX TABLE (screenshot-style, High-risk only)
****************************************************
local outtex "`table_folder'/interacted_reg_highrisk_`factor'_table.tex"
file open fh using "`outtex'", write replace text

file write fh "\begin{table}[htbp]" _n
file write fh "\centering" _n
file write fh "\begin{tabular}{lc}" _n
file write fh "\hline" _n
file write fh "Daily maximum & High-risk \\" _n
file write fh "temperature & workers \\" _n
file write fh " & \textit{`collabel'} \\" _n
file write fh "\hline" _n

* Temperature order (match your CSV rows; include 30 if you want it shown)
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
file write fh "Overall significance & $p = `p_show'\%$ \\" _n
file write fh "Adj $R$-squared & `R2_adj' \\" _n

local N_high_str : display %12.0fc `N_high'
local N_high_str = strtrim("`N_high_str'")
file write fh "N & `N_high_str' \\" _n

file write fh "\hline" _n
file write fh "\end{tabular}" _n
file write fh "\end{table}" _n

file close fh

di as result _n "LaTeX table generated (High-risk only, header factor=`factor`): `outtex'"
di as result "p-value used (raw) = `p_raw' ; shown as percent = `p_show'%"
