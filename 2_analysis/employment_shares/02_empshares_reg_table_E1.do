********************************************************************************
* FILE:    02_empshares_reg_table_E1.do
*
* PURPOSE:
*   Replicate Table E.1 and export a LaTeX table of regression results.
*
*   Estimates agriculture (high-risk) employment share as a function of
*   income and long-run temperature (polynomial), across alternative
*   fixed-effects specifications.
*
* DEPENDENT VARIABLE:
*   - ind_highrisk_share (industry_share10; ag-only high-risk share)
*
* SPECIFICATIONS:
*   (1) No FE | (2) Year FE | (3) Continent FE
*   (4) Continent + year FE | (5) Country FE
*   (6) Country + year FE (1980–2010 panel)
*
* SAMPLE:
*   - (1)–(5): last census year per ADM1
*   - (6): 1980–2010 panel
*
* INPUT:
*   - ${EMP_SHARE_DIR}/data/emp_inc_clim_merged_new.csv
*
* OUTPUT:
*   - ${DIR_OUTPUT}/employment_shares/tables/
*       table_E1_newrisk.tex
*
********************************************************************************


****************************************************
* 0. BASIC SETUP: CLEAR, PACKAGES, PATHS
****************************************************

clear all
set more off

cap which reghdfe
if _rc ssc install reghdfe, replace
cap which ftools
if _rc ssc install ftools, replace

****************************************************
* 1. PATHS 
****************************************************

run "/project/cil/home_dirs/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"

* Input data root (employment_shares_data)
global EMP_SHARE_DIR "${ROOT_INT_DATA}/employment_shares_data"
global data_dir "${EMP_SHARE_DIR}/data"

* Output folder INSIDE the labor-code-release repo
local out_root "${DIR_OUTPUT}/employment_shares"
local table_folder "`out_root'/tables"

cap mkdir "${DIR_OUTPUT}"
cap mkdir "`out_root'"
cap mkdir "`table_folder'"

* Output LaTeX file
local outtex "`table_folder'/table_E1_newrisk.tex"

****************************************************
* 2. LOAD AND PREP DATA 
****************************************************

import delimited "${data_dir}/emp_inc_clim_merged_new.csv", clear

* --- UPDATED DV (ag-only high risk) ---
* Keep the regression code unchanged by overwriting ind_highrisk_share.
capture confirm variable industry_share10
if _rc {
    di as err "industry_share10 not found in dataset."
    exit 111
}
capture confirm variable ind_highrisk_share
if !_rc {
    rename ind_highrisk_share ind_highrisk_share_old
}
gen ind_highrisk_share = industry_share10

* Drop problematic / artificial geographies
drop if geolev1 == 1
drop if country == "NA"
drop if gdppc_adm1_pwt_downscaled_13br == "NA"
drop if (inlist(mod(geolev1, 100), 99, 98) & geolev1 != 192099) | geolev1 == 231017

* Destring all numeric-looking variables except the obvious strings
qui ds
local vars = r(varlist)
local not country continent
local vars : list vars - not
qui destring `vars', replace force

* Continent code for FEs
encode continent, gen(continent_code)

* Keep census years only and climate-available years
keep if !missing(total_pop)
drop if year > 2010

* Last census year per ADM1
bysort geolev1: egen max_year = max(year)

* Income variable: rename to log_inc to match regression code
rename log_gdppc_adm1_pwt_ds_15ma log_inc

* Save cleaned dataset to a tempfile for reuse
tempfile base
save "`base'", replace

****************************************************
* 3. RUN REGRESSIONS FOR TABLE E.1
****************************************************

local coefvars "log_inc tavg_1_pop_ma_30yr tavg_2_pop_ma_30yr tavg_3_pop_ma_30yr tavg_4_pop_ma_30yr"

forvalues c = 1/6 {
    local R2_`c' ""
    local N_`c'  ""
}

*---------------------------------------------------
* 3A. COLUMNS (1)–(5): LAST CENSUS YEAR PER ADM1
*---------------------------------------------------
use "`base'", clear
keep if year == max_year
di as txt "Last-census sample N = " _N

*--- Column (1): no fixed effects
quietly reghdfe ind_highrisk_share ///
    `coefvars'
local col = 1
local R2_`col' : display %4.2f e(r2_a)
local N_`col'  : display %9.0fc e(N)

foreach v of local coefvars {
    local b   = _b[`v']
    local se  = _se[`v']
    local t   = `b'/`se'
    local star ""
    if abs(`t') > 1.645 & abs(`t') <= 1.96  local star "*"
    if abs(`t') > 1.96  & abs(`t') <= 2.576 local star "**"
    if abs(`t') > 2.576                      local star "***"
    local bstr  : display %10.7f `b'
    local sestr : display %10.7f `se'
    local coef_`v'_`col' "`bstr'`star'"
    local se_`v'_`col'   "(`sestr')"
}

*--- Column (2): year fixed effects
quietly reghdfe ind_highrisk_share ///
    `coefvars', ///
    absorb(year)
local col = 2
local R2_`col' : display %4.2f e(r2_a)
local N_`col'  : display %9.0fc e(N)

foreach v of local coefvars {
    local b   = _b[`v']
    local se  = _se[`v']
    local t   = `b'/`se'
    local star ""
    if abs(`t') > 1.645 & abs(`t') <= 1.96  local star "*"
    if abs(`t') > 1.96  & abs(`t') <= 2.576 local star "**"
    if abs(`t') > 2.576                      local star "***"
    local bstr  : display %10.7f `b'
    local sestr : display %10.7f `se'
    local coef_`v'_`col' "`bstr'`star'"
    local se_`v'_`col'   "(`sestr')"
}

*--- Column (3): continent fixed effects
quietly reghdfe ind_highrisk_share ///
    `coefvars', ///
    absorb(continent_code)
local col = 3
local R2_`col' : display %4.2f e(r2_a)
local N_`col'  : display %9.0fc e(N)

foreach v of local coefvars {
    local b   = _b[`v']
    local se  = _se[`v']
    local t   = `b'/`se'
    local star ""
    if abs(`t') > 1.645 & abs(`t') <= 1.96  local star "*"
    if abs(`t') > 1.96  & abs(`t') <= 2.576 local star "**"
    if abs(`t') > 2.576                      local star "***"
    local bstr  : display %10.7f `b'
    local sestr : display %10.7f `se'
    local coef_`v'_`col' "`bstr'`star'"
    local se_`v'_`col'   "(`sestr')"
}

*--- Column (4): continent + year fixed effects
quietly reghdfe ind_highrisk_share ///
    `coefvars', ///
    absorb(continent_code year)
local col = 4
local R2_`col' : display %4.2f e(r2_a)
local N_`col'  : display %9.0fc e(N)

foreach v of local coefvars {
    local b   = _b[`v']
    local se  = _se[`v']
    local t   = `b'/`se'
    local star ""
    if abs(`t') > 1.645 & abs(`t') <= 1.96  local star "*"
    if abs(`t') > 1.96  & abs(`t') <= 2.576 local star "**"
    if abs(`t') > 2.576                      local star "***"
    local bstr  : display %10.7f `b'
    local sestr : display %10.7f `se'
    local coef_`v'_`col' "`bstr'`star'"
    local se_`v'_`col'   "(`sestr')"
}

*--- Column (5): country fixed effects
quietly reghdfe ind_highrisk_share ///
    `coefvars', ///
    absorb(country)
local col = 5
local R2_`col' : display %4.2f e(r2_a)
local N_`col'  : display %9.0fc e(N)

foreach v of local coefvars {
    local b   = _b[`v']
    local se  = _se[`v']
    local t   = `b'/`se'
    local star ""
    if abs(`t') > 1.645 & abs(`t') <= 1.96  local star "*"
    if abs(`t') > 1.96  & abs(`t') <= 2.576 local star "**"
    if abs(`t') > 2.576                      local star "***"
    local bstr  : display %10.7f `b'
    local sestr : display %10.7f `se'
    local coef_`v'_`col' "`bstr'`star'"
    local se_`v'_`col'   "(`sestr')"
}

*-------------------------------------------------------
* 3B. COLUMN (6): FULL 1980–2010 SAMPLE, COUNTRY+YEAR FE
*-------------------------------------------------------
use "`base'", clear
keep if inrange(year, 1980, 2010)
di as txt "Full 1980–2010 sample N = " _N

quietly reghdfe ind_highrisk_share ///
    `coefvars', ///
    absorb(country year)
local col = 6
local R2_`col' : display %4.2f e(r2_a)
local N_`col'  : display %9.0fc e(N)

foreach v of local coefvars {
    local b   = _b[`v']
    local se  = _se[`v']
    local t   = `b'/`se'
    local star ""
    if abs(`t') > 1.645 & abs(`t') <= 1.96  local star "*"
    if abs(`t') > 1.96  & abs(`t') <= 2.576 local star "**"
    if abs(`t') > 2.576                      local star "***"
    local bstr  : display %10.7f `b'
    local sestr : display %10.7f `se'
    local coef_`v'_`col' "`bstr'`star'"
    local se_`v'_`col'   "(`sestr')"
}

****************************************************
* 4. BUILD AND WRITE LaTeX TABLE
****************************************************

local dlr = char(36)

local row_log_inc "Log income"
local row_t1      "Temperature"
local row_t2      "Temperature`dlr'^2`dlr'"
local row_t3      "Temperature`dlr'^3`dlr'"
local row_t4      "Temperature`dlr'^4`dlr'"

file close _all
file open fh using "`outtex'", write replace text

file write fh "\begin{table}[htbp]" _n
file write fh "\centering" _n
file write fh "  \caption{Determinants of High-Risk (Ag) Employment Share}" _n
file write fh "  \label{tab:highrisk_reg_tableE1_newrisk}" _n
file write fh "  \begin{tabular}{l*{6}{c}}" _n
file write fh "    \toprule" _n
file write fh "    & \multicolumn{6}{c}{Share of high-risk (ag) workers} \\" _n
file write fh "    \cmidrule(lr){2-7}" _n
file write fh "    & (1) & (2) & (3) & (4) & (5) & (6) \\" _n
file write fh "    & No FE & Year FE & Continent FE & Continent \& year FE & Country FE & Country \& year FE \\" _n
file write fh "    \midrule" _n

local vlist "log_inc tavg_1_pop_ma_30yr tavg_2_pop_ma_30yr tavg_3_pop_ma_30yr tavg_4_pop_ma_30yr"

foreach v of local vlist {

    if "`v'" == "log_inc"                 local lab "`row_log_inc'"
    else if "`v'" == "tavg_1_pop_ma_30yr" local lab "`row_t1'"
    else if "`v'" == "tavg_2_pop_ma_30yr" local lab "`row_t2'"
    else if "`v'" == "tavg_3_pop_ma_30yr" local lab "`row_t3'"
    else if "`v'" == "tavg_4_pop_ma_30yr" local lab "`row_t4'"

    file write fh "    `lab'"
    forvalues c = 1/6 {
        local coef "`coef_`v'_`c''"
        file write fh " & `coef'"
    }
    file write fh " \\" _n

    file write fh "    &"
    forvalues c = 1/6 {
        local se "`se_`v'_`c''"
        if `c' == 1 file write fh " `se'"
        else        file write fh " & `se'"
    }
    file write fh " \\" _n
}

file write fh "    \midrule" _n

file write fh "    Adj. \$R^2\$"
forvalues c = 1/6 {
    file write fh " & `R2_`c''"
}
file write fh " \\" _n

file write fh "    Observations"
forvalues c = 1/6 {
    file write fh " & `N_`c''"
}
file write fh " \\" _n

file write fh "    \bottomrule" _n
file write fh "  \end{tabular}" _n
file write fh "\end{table}" _n

file close fh

di as res "Wrote LaTeX table to: `outtex'"
