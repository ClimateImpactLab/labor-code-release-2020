********************************************************************************
* table3_FE_robustness.do
*
* PURPOSE:
*   Build LaTeX Table 3 (FE robustness) showing temperature response estimates
*   for low-risk and high-risk workers under alternative temporal FE structures.
*
*   For each FE specification, this script:
*     (1) Imports a RF CSV of point estimates + standard errors by temp
*     (2) Loads the corresponding .ster file to extract Adj. R^2 and N
*     (3) Merges all FE specs into one wide dataset (8 columns: 4 low + 4 high)
*     (4) Writes a LaTeX table with:
*         - two-line entries per temperature (coef row, then SE row in parentheses)
*         - the 27°C reference row shown as "--"
*         - summary rows (Adj. R^2, N)
*         - indicator rows describing which FE components are included in each col
*
* INPUTS:
*   - RF table-values CSVs (one per FE spec):
*       `rf_folder'/uninteracted_reg_ag_FE_<fe>_table_values.csv
*   - Regression estimates (.ster, one per FE spec):
*       `reg_folder'/uninteracted_reg_ag_FE_<fe>.ster
*
* OUTPUT:
*   - LaTeX table:
*       `table_folder'/table3_FE_robustness.tex
*
* Author: Marine de Franciosi

* Last Updated: 01/12/2026
********************************************************************************


version 16.0
clear all
set more off


********************************************************************************
* PATHS
********************************************************************************

run "/project/cil/home_dirs/mdefranciosi/repos/labor-code-release-2020/0_subroutines/paths.do"
run "${DIR_REPO_LABOR}/2_analysis/0_subroutines/functions.do"

local reg_folder   "${DIR_STER}/uninteracted_reg_FEs"
local rf_folder    "${DIR_RF}/uninteracted_reg_FEs"
local table_folder "${DIR_TABLE}"

********************************************************************************
* SETTINGS
********************************************************************************
* FE specs to appear as columns (1)-(4) low-risk and (5)-(8) high-risk
local fe_list "fe_adm0_m_y fe_adm0_my fe_adm1_y_adm0_w fe_adm0_wk"

* output .tex path
local out_tex  "`table_folder'/table3_FE_robustness.tex"

* formatting controls
local decimals 1
local fmt "%9.`decimals'f"

* LaTeX meta
local title   "Weekly minutes worked per worker"
local caption "Table 3: Labor supply response to temperature: Alternative specifications of temporal controls."
local label   "tab:table3_FE_robustness.tex"

********************************************************************************
* 1) Build wide dataset + collect R2/N
********************************************************************************

* We create a temp-wide file keyed by temperature:
*   b1..b4, se1..se4   for LOW-risk columns (1)-(4)
*   b5..b8, se5..se8   for HIGH-risk columns (5)-(8)
* Each FE spec contributes one low column + one high column.

tempfile base
local i 0
local r2_list ""
local n_list  ""

foreach fe of local fe_list {

    * Import the per-temperature table values for this FE spec
    import delimited "`rf_folder'/uninteracted_reg_ag_FE_`fe'_table_values.csv", clear

    * Expected columns from CSV file:
    confirm variable temp
    confirm variable yhat_low
    confirm variable se_low
    confirm variable yhat_high
    confirm variable se_high

    * Keep only what we need for the table
    keep temp yhat_low se_low yhat_high se_high

    * Ensure temp is numeric
    capture confirm numeric variable temp
    if (_rc) destring temp, replace force

    * Column indexing:
    *   FE #1 -> low col 1, high col 5
    *   FE #2 -> low col 2, high col 6
    *   FE #3 -> low col 3, high col 7
    *   FE #4 -> low col 4, high col 8
    local ++i
    local col_low  = `i'
    local col_high = `i' + 4

    * Rename into the wide-table naming scheme
    rename yhat_low  b`col_low'
    rename se_low    se`col_low'
    rename yhat_high b`col_high'
    rename se_high   se`col_high'

    * Merge into accumulating wide dataset (key = temp)
    if (`i'==1) {
        save `base', replace
    }
    else {
        merge 1:1 temp using `base', nogen
        save `base', replace
    }

    * Load regression estimates for this FE spec to pull summary stats
    est use "`reg_folder'/uninteracted_reg_ag_FE_`fe'.ster"

    * Store Adj. R^2 and N as locals (later duplicated for low/high columns)
    local r2 = round(e(r2_a), 0.01)
    local nn = e(N)

    local r2_list "`r2_list' `r2'"
    local n_list  "`n_list' `nn'"
}

* Load final wide dataset
use `base', clear

* Create numeric temp helper + a LaTeX-formatted label for the temp row
gen double tempnum = temp
gen str20 templab  = strtrim(string(tempnum,"%9.0g")) + "$^{\circ}$"

* Duplicate R2/N lists so we have 8 entries (low 1-4, high 5-8)
local r2_8 "`r2_list' `r2_list'"
local n_8  "`n_list'  `n_list'"

********************************************************************************
* 2) aDD 27C empty row (reference)
********************************************************************************

* Table treats 27°C as reference, shown as "--" in all columns.
* If the CSV grid does not include temp==27, we append an empty row.

quietly count if tempnum == 27
if (r(N)==0) {
    set obs `=_N+1'
    replace temp    = 27 in L
    replace tempnum = 27 in L
    replace templab = "27$^{\circ}$" in L
    forvalues j=1/8 {
        replace b`j'  = . in L
        replace se`j' = . in L
    }
}

********************************************************************************
* 3) FE indicator rows (manual table footer)
********************************************************************************

* These rows are just text indicators that map each column to which FE components
* are included (hard-coded)

local fe_labels "Subnational location FE|Country x Year FE|ADM1 x Year FE|Country x Month-of-year FE|Country x Week-of-year FE|Country x Month x Year"

* Each row is 8 entries corresponding to columns (1)-(8)
local fe_row1 "Yes Yes Yes Yes Yes Yes Yes Yes"
local fe_row2 "Yes -- -- Yes Yes -- -- Yes"
local fe_row3 "-- -- Yes -- -- -- Yes --"
local fe_row4 "Yes -- -- -- Yes -- -- --"
local fe_row5 "-- -- Yes Yes -- -- Yes Yes"
local fe_row6 "-- Yes -- -- -- Yes -- --"

* Pack into a single list separated by semicolons for parsing below
local fe_values "`fe_row1'; `fe_row2'; `fe_row3'; `fe_row4'; `fe_row5'; `fe_row6'"

********************************************************************************
* 4) WRITE LaTeX TABLE
********************************************************************************

* This section writes raw LaTeX lines to `out_tex`.
* Key idea:
*   For each temperature, print TWO lines:
*     - coefficient line:   b1..b8 (or "--")
*     - standard error line: (se1)..(se8) (blank if missing)
*
* Special-case:
*   - temp==27 prints "--" for both lines (reference)

tempname fh
file close _all
file open `fh' using "`out_tex'", write replace text

* Sort rows hottest -> coldest for table presentation
gsort -tempnum

* ---------------------------
* LaTeX header / column titles
* ---------------------------
#delimit ;

file write `fh' "\begin{table}[!htbp]\centering" _n
                "\small" _n
                "\setlength{\tabcolsep}{5pt}" _n
                "\renewcommand{\arraystretch}{1}" _n
                "\setlength{\extrarowheight}{0.40ex}" _n
                "\begin{tabular}{lcccccccc}" _n
                "\hline\hline" _n
                " & \multicolumn{8}{c}{\textbf{" "`title'" "}} \\" _n
                "\cline{2-9}" _n
                "\multirow{2}{*}{\shortstack[l]{Daily maximum\\ temperature}}"
                " & \multicolumn{4}{c}{\shortstack{Low-risk\\ workers}}"
                " & \multicolumn{4}{c}{\shortstack{High-risk\\ workers}} \\" _n
                "\cline{2-5}\cline{6-9}" _n
                " & (1) & (2) & (3) & (4) & (5) & (6) & (7) & (8) \\" _n
                "\cline{2-5}\cline{6-9}" _n
;

#delimit cr

* Number of temperature rows to print
quietly count
local R = r(N)

forvalues r=1/`R' {

    * Check if any coefficient exists in this row (across 8 columns)
    local any 0
    forvalues j=1/8 {
        if (b`j'[`r'] < .) local any 1
    }

    * Start row with temperature label in first column
    file write `fh' "`=templab[`r']'"

    * ---------------------------
    * Special case: reference temp
    * ---------------------------
    if (tempnum[`r'] == 27) {

        * Coef line: all "--"
        forvalues j=1/8 {
            file write `fh' " & --"
        }
        file write `fh' " \\" _n

        * SE line: also all "--" (keeps table visually consistent)
        file write `fh' " "
        forvalues j=1/8 {
            file write `fh' " & --"
        }
        file write `fh' " \\" _n

        continue
    }

    * ---------------------------
    * General case: non-reference temps
    * ---------------------------
    if (`any'==0) {

        * If entire row is empty, print "--" placeholders (single line)
        forvalues j=1/8 {
            file write `fh' " & --"
        }
        file write `fh' " \\" _n
    }
    else {

        * 1) Coefficient line
        forvalues j=1/8 {
            if (b`j'[`r'] < .) {
                local v = strtrim(string(b`j'[`r'],"`fmt'"))
                file write `fh' " & `v'"
            }
            else file write `fh' " & --"
        }
        file write `fh' " \\" _n

        * 2) Standard error line (in parentheses)
        file write `fh' " "
        forvalues j=1/8 {
            if (se`j'[`r'] < .) {
                local s = strtrim(string(se`j'[`r'],"`fmt'"))
                file write `fh' " & (`s')"
            }
            else file write `fh' " & "
        }
        file write `fh' " \\" _n
    }
}

* ---------------------------
* Summary rows: Adj. R2 and N
* ---------------------------
#delimit ;

file write `fh' "\hline" _n
                "Adj. R$^2$"
;

#delimit cr

forvalues j=1/8 {
    local r2j : word `j' of `r2_8'
    file write `fh' " & `=strtrim(string(`r2j',"%9.2f"))'"
}
file write `fh' " \\" _n

file write `fh' "N"
forvalues j=1/8 {
    local nj : word `j' of `n_8'
    file write `fh' " & `=strtrim(string(`nj',"%9.0f"))'"
}
file write `fh' " \\" _n

* ---------------------------
* FE indicator rows (manual)
* ---------------------------
* Parse the label list (split by "|") into felab1...felabK
local L "`fe_labels'"
local V "`fe_values'"

local nfe 0
while ("`L'"!="") {
    gettoken one L : L, parse("|")
    if ("`one'"=="|") continue
    local ++nfe
    local felab`nfe' "`=strtrim("`one'")'"
    if (substr("`L'",1,1)=="|") local L = substr("`L'",2,.)
}

* For each FE label row, pull the matching "Yes/--" row and print across 8 cols
forvalues i=1/`nfe' {
    gettoken row V : V, parse(";")
    if ("`row'"==";") gettoken row V : V, parse(";")
    local row = strtrim("`row'")
    if (substr("`V'",1,1)==";") local V = substr("`V'",2,.)

    file write `fh' "`felab`i''"
    forvalues j=1/8 {
        local w : word `j' of `row'
        if ("`w'"=="") local w="--"
        file write `fh' " & `w'"
    }
    file write `fh' " \\" _n
}

* ---------------------------
* LaTeX footer
* ---------------------------
#delimit ;

file write `fh' "\hline\hline" _n
                "\end{tabular}" _n
                "\caption{" "`caption'" "}" _n
                "\label{" "`label'" "}" _n
                "\end{table}" _n
;

#delimit cr

file close `fh'
di as result "WROTE: `out_tex'"
