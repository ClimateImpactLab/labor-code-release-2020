********************************************************************************
* rmse_functional_forms_tableD1.do
* ------------------------------------------------------------------------------
* Compute RMSE of parametric RFs relative to the binned benchmark,
* separately for low- and high-risk groups, weighted by population temperature
* distributions (2010 and 2099).
*
*
* Inputs:
*   1) Functional form RF CSV (temp x risk):
*        ${DIR_RF}/functional_form_comparison_2026.csv
*
*   2) Population-weighted daily binned temps (old 3C bins):
*        ${DIR_OUTPUT}/temp_dist/pop_weighted_daily_binned_temps.csv
*
* Output:
*   - LaTeX table: ${DIR_TABLE}/tableD1_rmse_functional_forms_2026.tex
********************************************************************************

version 16.1
clear all
set more off

*****************
* INITIALIZE
*****************
run "/project/cil/home_dirs/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"
run "${DIR_REPO_LABOR}/2_analysis/0_subroutines/functions.do"

cap mkdir "${DIR_TABLE}"

* ---------------------------
* USER SETTINGS
* ---------------------------
global FF_FILE     "${DIR_RF}/functional_form_comparison_2026.csv"
global POPWGT_FILE "${DIR_OUTPUT}/temp_dist/pop_weighted_daily_binned_temps.csv"
global OUT_TEX     "${DIR_TABLE}/tableD1_rmse_functional_forms.tex"

* AG bins spec
global coldcut 9
global hotcut  42
global step    3

********************************************************************************
* Helper: map continuous temp -> AG bin id
* 9-12    -> 9
* ...
* 39-42   -> 39
* >=42    -> 42
********************************************************************************
cap program drop make_temp_bin_ag
program define make_temp_bin_ag
    cap drop temp_bin
    gen double temp_bin = .
    replace temp_bin = -${coldcut} if temp <  ${coldcut}
    replace temp_bin =  ${hotcut}  if temp >= ${hotcut}
    replace temp_bin = floor((temp - ${coldcut})/${step})*${step} + ${coldcut} ///
        if temp >= ${coldcut} & temp < ${hotcut}
end

********************************************************************************
* 0) Read functional forms and define model list
********************************************************************************
import delimited using "${FF_FILE}", clear
confirm variable temp
confirm variable risk
confirm variable bins

* model_list = all columns except temp, risk, and bins
ds temp risk bins, not
local model_list "`r(varlist)'"

tempfile ff
save `ff', replace

********************************************************************************
* 1) Read pop weights and collapse old 3C bins -> AG bins
********************************************************************************
import delimited using "${POPWGT_FILE}", clear
confirm variable bin_3c
confirm variable pop_10_times_temp_10
confirm variable pop_95_times_temp_99

gen double temp_bin = .
replace temp_bin = -${coldcut} if bin_3c <  ${coldcut}
replace temp_bin =  ${hotcut}  if bin_3c >= ${hotcut}
replace temp_bin =  bin_3c     if bin_3c >= ${coldcut} & bin_3c < ${hotcut}

collapse (sum) pop_10_times_temp_10 pop_95_times_temp_99, by(temp_bin)

* Normalize to sum to 1 (so sums of weighted MSE are weighted means)
egen tot10 = total(pop_10_times_temp_10)
egen tot99 = total(pop_95_times_temp_99)
replace pop_10_times_temp_10 = pop_10_times_temp_10 / tot10 if tot10>0
replace pop_95_times_temp_99 = pop_95_times_temp_99 / tot99 if tot99>0
drop tot10 tot99

tempfile popagg
save `popagg', replace

********************************************************************************
* 2) RMSE by risk
********************************************************************************
tempfile out_low out_high

foreach RISK in low high {

    use `ff', clear
    keep if risk=="`RISK'"

    * Map RF grid temps to AG bins
    make_temp_bin_ag

    * Collapse RF values to AG bins:
    * - mean within bin for each functional form column
    * - bins should be constant within each bin 
    collapse (mean) bins `model_list', by(temp_bin)

    * Merge pop weights (AG bins)
    merge 1:1 temp_bin using `popagg', nogen

    * Compute weighted MSE and RMSE for each model (relative to bins)
    foreach m of local model_list {
        gen double mse_`m'      = (bins - `m')^2
        gen double mse10_`m'    = mse_`m' * pop_10_times_temp_10
        gen double mse99_`m'    = mse_`m' * pop_95_times_temp_99
    }

    collapse (sum) mse10_* mse99_*

    foreach m of local model_list {
        gen rmse_2010_`m' = sqrt(mse10_`m')
        gen rmse_2099_`m' = sqrt(mse99_`m')
    }

    keep rmse_2010_* rmse_2099_*
    gen one=1
    reshape long rmse_2010_ rmse_2099_, i(one) j(model) string
    drop one

    rename rmse_2010_ rmse_2010
    rename rmse_2099_ rmse_2099

    * If "bins" or "ref" is in model list somehow, drop it
    drop if model=="bins" | model == "ref"

    * Labels for table
    replace model = "Second-order polynomial"  if model=="poly2"
    replace model = "Third-order polynomial"   if model=="poly3"
    replace model = "Fourth-order polynomial"  if model=="poly4"
    replace model = "Restricted cubic spline"  if model=="rcs"

    if "`RISK'"=="low"  save `out_low',  replace
    if "`RISK'"=="high" save `out_high', replace
}

********************************************************************************
* 3) Combine + write LaTeX table
********************************************************************************
use `out_low', clear
rename rmse_2010 rmse_2010_low
rename rmse_2099 rmse_2099_low

merge 1:1 model using `out_high', nogen
rename rmse_2010 rmse_2010_high
rename rmse_2099 rmse_2099_high

* Order rows like paper
gen ord=.
replace ord=1 if model=="Second-order polynomial"
replace ord=2 if model=="Third-order polynomial"
replace ord=3 if model=="Fourth-order polynomial"
replace ord=4 if model=="Restricted cubic spline"
sort ord
drop ord

* Format numbers to 2 decimals for LaTeX
foreach v in rmse_2010_low rmse_2099_low rmse_2010_high rmse_2099_high {
    replace `v' = round(`v', .01)
    tostring `v', replace format(%9.2f) force
}

file open fh using "${OUT_TEX}", write replace text
file write fh "\begin{table}[!htbp]\centering" _n
file write fh "\caption{Updated Table D1: RMSE Functional Forms Comparison}" _n
file write fh "\begin{tabular}{lcccc}" _n
file write fh "\toprule" _n
file write fh "\toprule" _n
file write fh " & \multicolumn{4}{c}{\textbf{\shortstack{Root mean square error relative to\\non-parametric, binned labor supply-temperature response}}} \\\\" _n
file write fh "\cmidrule(lr){2-5}" _n
file write fh " & \multicolumn{2}{c}{\shortstack{Low-risk\\workers}} & \multicolumn{2}{c}{\shortstack{High-risk\\workers}} \\\\" _n
file write fh "\cmidrule(lr){2-3}\cmidrule(lr){4-5}" _n
file write fh "Functional form & \shortstack{Weighted by\\2010 temperature} & \shortstack{Weighted by\\2090 temperature} & \shortstack{Weighted by\\2010 temperature} & \shortstack{Weighted by\\2090 temperature} \\\\" _n
file write fh "\midrule" _n

quietly {
    forval i=1/`=_N' {
        local m = model[`i']
        local a = rmse_2010_low[`i']
        local b = rmse_2099_low[`i']
        local c = rmse_2010_high[`i']
        local d = rmse_2099_high[`i']
        file write fh "`m' & `a' & `b' & `c' & `d' \\\\" _n
    }
}

file write fh "\bottomrule" _n
file write fh "\end{tabular}" _n
file write fh "\end{table}" _n
file close fh

di as result "Wrote LaTeX table: ${OUT_TEX}"
