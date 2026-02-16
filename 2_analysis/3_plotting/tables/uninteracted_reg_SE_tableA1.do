********************************************************************************
* uninteracted_reg_SE_tableA1.do
*
* PURPOSE:
*   Construct Appendix Table A.1 (Self-employed vs. Non-self-employed) from
*   RF CSVs 

* INPUTS:
*   1) RF table values CSVs:
*        - `rf_noSE'    : non-self-employed subsample (self_emp==0)
*        - `rf_onlySE'  : self-employed subsample (self_emp==1)
*
*   2) Regression .ster files for summary stats (Adj. R^2 and risk-group N):
*        - `ster_noSE'
*        - `ster_onlySE'
*
* OUTPUT:
*   Writes LaTeX table to:
*     `table_folder'/tableA1_selfemp.tex
*
* TABLE LAYOUT (COLUMNS):
*   (1) Low-risk,  Non-self-employed  (noSE  yhat_low)
*   (2) Low-risk,  Self-employed      (onlySE yhat_low)
*   (3) High-risk, Non-self-employed  (noSE  yhat_high)
*   (4) High-risk, Self-employed      (onlySE yhat_high)
*
* AUTHOR: Marine de Franciosi (mdefranciosi@uchicago.edu)

* LAST UPDATED: 01/13/2026
********************************************************************************


version 16.0
clear all
set more off

********************************************************************************
* Paths
********************************************************************************

run "/project/cil/home_dirs/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"
run "${DIR_REPO_LABOR}/2_analysis/0_subroutines/functions.do"

* >>> Edit these folders to match where you wrote outputs <<<
local reg_folder   "${DIR_STER}/uninteracted_reg_comlohi_SE"
local rf_folder    "${DIR_RF}/uninteracted_reg_comlohi_SE"
local table_folder "${DIR_TABLE}"


********************************************************************************
* Input Files
********************************************************************************

local rf_noSE   "`rf_folder'/uninteracted_reg_comlohi_table_values_noSE_2026.csv"
local rf_onlySE "`rf_folder'/uninteracted_reg_comlohi_table_values_onlySE_2026.csv"

local ster_noSE   "`reg_folder'/uninteracted_reg_by_risk_noSE_2026.ster"
local ster_onlySE "`reg_folder'/uninteracted_reg_by_risk_onlySE_2026.ster"


********************************************************************************
* Output File
********************************************************************************

local out_tex "`table_folder'/tableA1_selfemp.tex"

********************************************************************************
* Table Text
********************************************************************************
local title   "Weekly minutes worked per worker"
local caption "Labor supply response to temperature: Self-employed vs. non-self-employed workers."
local label   "tab:tabA1_temp_response_selfemp"

* formatting
local decimals 1
local fmt "%9.`decimals'f"

********************************************************************************
* 1) Build 4-column wide dataset from two RF CSVs
*    Columns
*      (1) Low-risk, Non-self   = noSE yhat_low
*      (2) Low-risk, Self       = onlySE yhat_low
*      (3) High-risk, Non-self  = noSE yhat_high
*      (4) High-risk, Self      = onlySE yhat_high
********************************************************************************

tempfile base

* ---- Not Self-Employed RF ----
import delimited using "`rf_noSE'", clear
confirm variable temp yhat_low se_low yhat_high se_high

keep temp yhat_low se_low yhat_high se_high
capture confirm numeric variable temp
if (_rc) destring temp, replace force

rename yhat_low  b1
rename se_low    se1
rename yhat_high b3
rename se_high   se3

save `base', replace

* ---- Self-Employed RF ----
import delimited using "`rf_onlySE'", clear
confirm variable temp yhat_low se_low yhat_high se_high

keep temp yhat_low se_low yhat_high se_high
capture confirm numeric variable temp
if (_rc) destring temp, replace force

rename yhat_low  b2
rename se_low    se2
rename yhat_high b4
rename se_high   se4

merge 1:1 temp using `base', nogen
save `base', replace

use `base', clear

* format temperature label
gen double tempnum = temp
gen str20 templab  = strtrim(string(tempnum,"%9.0g")) + "$^{\circ}$"

********************************************************************************
* 2) Ordering Temperatures
********************************************************************************

* rows: 45 40 35 27 10 5 0 -5 -10  
keep if inlist(tempnum, 45,40,35,27,10,5,0,-5,-10)

* enforce order explicitly
gen byte ord = .
replace ord = 1 if tempnum==45
replace ord = 2 if tempnum==40
replace ord = 3 if tempnum==35
replace ord = 4 if tempnum==27
replace ord = 5 if tempnum==10
replace ord = 6 if tempnum==5
replace ord = 7 if tempnum==0
replace ord = 8 if tempnum==-5
replace ord = 9 if tempnum==-10
sort ord
drop ord

********************************************************************************
* 3) Ensure 27C reference row exists and print as "--"
********************************************************************************
quietly count if tempnum == 27
if (r(N)==0) {
    set obs `=_N+1'
    replace temp    = 27 in L
    replace tempnum = 27 in L
    replace templab = "27$^{\circ}$" in L
    forvalues j=1/4 {
        replace b`j'  = . in L
        replace se`j' = . in L
    }
    * put it in correct spot (after 35, before 10)
    gen byte ord = .
    replace ord = 1 if tempnum==45
    replace ord = 2 if tempnum==40
    replace ord = 3 if tempnum==35
    replace ord = 4 if tempnum==27
    replace ord = 5 if tempnum==10
    replace ord = 6 if tempnum==5
    replace ord = 7 if tempnum==0
    replace ord = 8 if tempnum==-5
    replace ord = 9 if tempnum==-10
    sort ord
    drop ord
}

********************************************************************************
* 4) Collect R2 + N for bottom rows
********************************************************************************
* Adj R2: use e(r2_a) from each regression
* N: prefer e(low_N), e(high_N) 
local r2_1 .
local r2_2 .
local r2_3 .
local r2_4 .

local N1 .
local N2 .
local N3 .
local N4 .

* ---- from noSE ster: columns (1) and (3)
est use "`ster_noSE'"
* R2
local r2_noSE = round(e(r2_a), 0.01)
* N
capture local lowN_noSE  = e(low_N)
capture local highN_noSE = e(high_N)

* fallback if not present
if (_rc) {
    local lowN_noSE  = .
    local highN_noSE = .
}

local r2_1 `r2_noSE'
local r2_3 `r2_noSE'
local N1   `lowN_noSE'
local N3   `highN_noSE'

* ---- from onlySE ster: columns (2) and (4)
est use "`ster_onlySE'"
* R2
local r2_onlySE = round(e(r2_a), 0.01)
* N
capture local lowN_onlySE  = e(low_N)
capture local highN_onlySE = e(high_N)
if (_rc) {
    local lowN_onlySE  = .
    local highN_onlySE = .
}

local r2_2 `r2_onlySE'
local r2_4 `r2_onlySE'
local N2   `lowN_onlySE'
local N4   `highN_onlySE'

********************************************************************************
* 5) Write LaTeX table 
********************************************************************************
tempname fh
file close _all
file open `fh' using "`out_tex'", write replace text

* table header and columns 
#delimit ;
file write `fh'
"\begin{table}[!htbp]\centering" _n
"\small" _n
"\setlength{\tabcolsep}{6pt}" _n
"\renewcommand{\arraystretch}{1}" _n
"\setlength{\extrarowheight}{0.35ex}" _n
"\begin{tabular}{lcccc}" _n
"\hline\hline" _n
" & \multicolumn{4}{c}{\textbf{`title'}} \\" _n
"\cline{2-5}" _n
"\multirow{2}{*}{\shortstack[l]{Daily maximum\\ temperature}}"
" & \multicolumn{2}{c}{\shortstack{Low-risk\\ workers}}"
" & \multicolumn{2}{c}{\shortstack{High-risk\\ workers}} \\" _n
"\cline{2-3}\cline{4-5}" _n
" & (1) & (2) & (3) & (4) \\" _n
"\cline{2-3}\cline{4-5}" _n
" & \shortstack{Non-self\\ employed}"
" & \shortstack{Self-\\ employed}"
" & \shortstack{Non-self\\ employed}"
" & \shortstack{Self-\\ employed} \\" _n
"\hline" _n
;
#delimit cr

quietly count
local R = r(N)

forvalues r=1/`R' {

    file write `fh' "`=templab[`r']'"

    * 27C row: show "--" on both coef and SE line
    if (tempnum[`r'] == 27) {
        forvalues j=1/4 {
            file write `fh' " & --"
        }
        file write `fh' " \\" _n
        file write `fh' " "
        forvalues j=1/4 {
            file write `fh' " & --"
        }
        file write `fh' " \\" _n
        continue
    }

    * coef line
    forvalues j=1/4 {
        if (b`j'[`r'] < .) {
            local v = strtrim(string(b`j'[`r'],"`fmt'"))
            file write `fh' " & `v'"
        }
        else file write `fh' " & --"
    }
    file write `fh' " \\" _n

    * SE line
    file write `fh' " "
    forvalues j=1/4 {
        if (se`j'[`r'] < .) {
            local s = strtrim(string(se`j'[`r'],"`fmt'"))
            file write `fh' " & (`s')"
        }
        else file write `fh' " & "
    }
    file write `fh' " \\" _n
}

* bottom panel
file write `fh' "\hline" _n

file write `fh' "Adj. R-squared"
file write `fh' " & `=strtrim(string(`r2_1',"%9.2f"))'"
file write `fh' " & `=strtrim(string(`r2_2',"%9.2f"))'"
file write `fh' " & `=strtrim(string(`r2_3',"%9.2f"))'"
file write `fh' " & `=strtrim(string(`r2_4',"%9.2f"))'"
file write `fh' " \\" _n

file write `fh' "N"
file write `fh' " & `=strtrim(string(`N1',"%9.0f"))'"
file write `fh' " & `=strtrim(string(`N2',"%9.0f"))'"
file write `fh' " & `=strtrim(string(`N3',"%9.0f"))'"
file write `fh' " & `=strtrim(string(`N4',"%9.0f"))'"
file write `fh' " \\" _n

#delimit ;
file write `fh'
"\hline\hline" _n
"\end{tabular}" _n
"\caption{`caption'}" _n
"\label{`label'}" _n
"\end{table}" _n
;
#delimit cr

file close `fh'
di as result "WROTE: `out_tex'"
