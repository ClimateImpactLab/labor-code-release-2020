********************************************************************************
* FILE:    01bis_empshares_diagnostics.do
*
* PROJECT:
*   Climate Impact Lab — Labor Paper
*
* PURPOSE (optional):
*   Generate diagnostic plots and exploratory response plots for the
*   employment-share analysis using the UPDATED (ag) high-risk definition

*     - This script is not required to reproduce any tables or figures in the paper
*     - Outputs are for internal validation / sanity checking only
*
* WHAT THIS SCRIPT DOES:
*   1) Loads and cleans the merged employment–income–climate dataset using
*      the same rules as the core estimation script
*   2) Restricts to the last available census year per ADM1 (geolev1),
*      with climate data through 2010
*   3) For each of the FOUR model specifications estimated in:
*         01_empshares_reg_predict.do
*      it loads the saved .ster file and produces:
*        - Residual histogram
*        - Predicted vs actual scatter with 45-degree line
*        - (Optional) Response-function plots by terciles:
*            a) High-risk share vs temperature, by income tercile
*            b) High-risk share vs income, by temperature tercile
*
* INPUTS:
*   - Raw merged dataset:
*       ${EMP_SHARE_DIR}/data/emp_inc_clim_merged_new.csv
*   - Saved model estimates (.ster) created by:
*       01_empshares_reg_predict.do
*
* OUTPUTS (in replication repo):
*   output/employment_shares/diagnostics/
*      residuals/
*      scatters/
*      tercile_response/
*
*
* LAST UPDATED:
*   2026-01-09
*
********************************************************************************

clear all
set more off
pause off

****************************************************
* 0) Packages
****************************************************
cap which reghdfe
if _rc ssc install reghdfe, replace
cap which ftools
if _rc ssc install ftools, replace

****************************************************
* 1) Paths 
****************************************************

run "/project/cil/home_dirs/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"


* Input data root
global EMP_SHARE_DIR "${ROOT_INT_DATA}/employment_shares_data"
local data_dir "${EMP_SHARE_DIR}/data"

* Where 01_* wrote outputs
local out_root  "${DIR_OUTPUT}/employment_shares"
local ster_dir "`out_root'/ster"

* Diagnostics output folders (requested)
local diag_root "`out_root'/diagnostics"
local resid_dir "`diag_root'/residuals"
local scat_dir  "`diag_root'/scatters"
local terc_dir  "`diag_root'/tercile_response"

* Create directories if missing
cap mkdir "`ster_dir'"
cap mkdir "`diag_root'"
cap mkdir "`resid_dir'"
cap mkdir "`scat_dir'"
cap mkdir "`terc_dir'"

****************************************************
* 2) Settings: risk definition + specs
****************************************************
* Official diagnostics focus: new high-risk definition
local risklabel "newrisk"
local riskvar   "ind_highrisk_share_new"

* Income variable (already log)
local incvar_raw "log_gdppc_adm1_pwt_ds_15ma"
local incvar     "log_inc"

* Specs (must match names from 01_empshares_reg_predict.do)
local specs ///
    log_inc_poly4_2025_`risklabel' ///
    log_inc_poly4_continent_fes_2025_`risklabel' ///
    log_inc_lrtk_2025_`risklabel' ///
    log_inc_lrtk_continent_fes_2025_`risklabel'

****************************************************
* 3) Load + clean data
****************************************************
import delimited "`data_dir'/emp_inc_clim_merged_new.csv", clear

* Drop problematic / artificial geographies
drop if geolev1 == 1
drop if country == "NA"
drop if gdppc_adm1_pwt_downscaled_13br == "NA"
drop if (inlist(mod(geolev1, 100), 99, 98) & geolev1 != 192099) | geolev1 == 231017

* Destring numeric-looking variables except obvious strings
qui ds
local vars = r(varlist)
local not country continent
local vars : list vars - not
qui destring `vars', replace force

* Ensure risk variable expected by .ster exists
capture confirm variable ind_highrisk_share_new
if _rc {
    capture confirm variable industry_share10
    if _rc {
        di as err "Missing both ind_highrisk_share_new and industry_share10 in source data."
        exit 111
    }
    gen ind_highrisk_share_new = industry_share10
}

* Continent code (for terciles and for consistency)
capture drop continent_code
encode continent, gen(continent_code)

* Keep census years only and climate-available years
keep if !missing(total_pop)
drop if year > 2010

* Last census year per ADM1
bysort geolev1: egen max_year = max(year)
keep if year == max_year

* Rename income variable to log_inc
rename `incvar_raw' `incvar'

* Create terciles (used in response-function plots)
* Income terciles based on GDPpc levels (as in your earlier script)
capture drop inc_tercile temp_tercile
xtile inc_tercile  = gdppc_adm1_pwt_downscaled_13br, nquantiles(3)
xtile temp_tercile = tavg_1_pop_ma_30yr,             nquantiles(3)

* Build explicit powers (used if we want to inspect lrtk models manually)
capture drop temp_poly1 temp_poly2 temp_poly3 temp_poly4
gen temp_poly1 = tavg_1_pop_ma_30yr
gen temp_poly2 = tavg_1_pop_ma_30yr^2
gen temp_poly3 = tavg_1_pop_ma_30yr^3
gen temp_poly4 = tavg_1_pop_ma_30yr^4

* Keep a stable copy
tempfile base
save "`base'", replace

di as txt "Diagnostics sample (last census, newrisk) N = " _N

************************************************************
* 4) Diagnostics loop: load .ster -> predict -> export plots
************************************************************
foreach m of local specs {

    use "`base'", clear

    * Confirm ster exists (hard error if not)
    capture confirm file "`ster_dir'/`m'.ster"
    if _rc {
        di as err "Missing ster file: `ster_dir'/`m'.ster"
        di as err "Run 01_empshares_reg_predict.do first (or update paths)."
        exit 198
    }

    * Load estimates
    estimates use "`ster_dir'/`m'.ster"
    local depvar "`e(depvar)'"

    * Predicted values (xb) and residuals (y - xb)
    * Note: This assumes models were estimated by reghdfe with noabsorb
    predict xb, xb
    gen resid = `riskvar' - xb

    *-------------------------------------------*
    * 4A) Residual histogram
    *-------------------------------------------*
    twoway hist resid, fraction ///
        graphregion(color(white)) plotregion(color(white)) ///
        title("Residuals: `m'") ///
        note("Optional diagnostic output; not used in paper figures/tables.")
    graph export "`resid_dir'/`m'__residuals.pdf", replace

    *-------------------------------------------*
    * 4B) Predicted vs actual scatter (with 45° line)
    *-------------------------------------------*
    twoway ///
        scatter xb `riskvar' if inrange(xb,0,1), msize(tiny) ///
        || function y=x, ///
        xtitle("Actual high-risk share (industry_share10)") ///
        ytitle("Predicted high-risk share") ///
        title("Predicted vs Actual: `m'") ///
        legend(off) graphregion(color(white)) plotregion(color(white)) ///
        note("Optional diagnostic output; not used in paper figures/tables.")
    graph export "`scat_dir'/`m'__predicted_vs_actual.pdf", replace

    *------------------------------------------------*
    * 4C) Tercile response plots (optional but useful)
    *------------------------------------------------*
    *   We compute response curves using coefficient expressions and predictnl.
    *   For continent-FE models, we set continent effects to baseline by
    *   excluding dummy terms in the prediction expression.

    * Identify which temperature term set this model uses
    local uses_tavg = 0
    local uses_poly = 0
    if strpos("`m'", "log_inc_poly4") {
        local uses_tavg = 1
    }
    if strpos("`m'", "log_inc_lrtk") {
        local uses_poly = 1
    }

    * 4C.i) High-risk share vs temperature, by income tercile
    local temp_graphs

    qui sum tavg_1_pop_ma_30yr, detail
    local tmin = floor(r(p5))
    local tmax = ceil(r(p95))

    forvalues i = 1/3 {

        qui sum `incvar' if inc_tercile == `i'
        local log_inc_mean = r(mean)

        preserve
            clear
            set obs `= `tmax' - `tmin' + 1'
            gen temp = _n + (`tmin' - 1)

            * Ensure e(depvar) exists in synthetic data for predictnl
            capture confirm variable `depvar'
            if _rc gen `depvar' = .

            * Build prediction expression
            if `uses_tavg' == 1 {
                local temp_cmd ///
                    _b[_cons] + ///
                    _b[`incvar']*`log_inc_mean' + ///
                    _b[tavg_1_pop_ma_30yr]*temp + ///
                    _b[tavg_2_pop_ma_30yr]*temp^2 + ///
                    _b[tavg_3_pop_ma_30yr]*temp^3 + ///
                    _b[tavg_4_pop_ma_30yr]*temp^4
            }
            if `uses_poly' == 1 {
                local temp_cmd ///
                    _b[_cons] + ///
                    _b[`incvar']*`log_inc_mean' + ///
                    _b[temp_poly1]*temp + ///
                    _b[temp_poly2]*temp^2 + ///
                    _b[temp_poly3]*temp^3 + ///
                    _b[temp_poly4]*temp^4
            }

            predictnl yhat = `temp_cmd', ci(lo hi)

            twoway ///
                rarea hi lo temp || ///
                line yhat temp, ///
                graphregion(color(white)) plotregion(color(white)) ///
                xtitle("Long-run average temperature (°C)") ///
                ytitle("Predicted high-risk share") ///
                title("Income tercile `i'") ///
                legend(off) ///
                name(temp_i`i', replace)

            local temp_graphs "`temp_graphs' temp_i`i'"
        restore
    }

    graph combine `temp_graphs', rows(1) ///
        graphregion(color(white)) plotregion(color(white)) ///
        title("High-risk share vs temperature by income tercile") ///
        note("Model: `m' (optional diagnostic).")

    graph export "`terc_dir'/`m'__Temp_by_IncTercile.pdf", replace

    * 4C.ii) High-risk share vs income, by temperature tercile
    local inc_graphs

    forvalues i = 1/3 {

        * Mean temperature terms in tercile i
        if `uses_tavg' == 1 {
            forvalues k = 1/4 {
                qui sum tavg_`k'_pop_ma_30yr if temp_tercile == `i'
                local T`k' = r(mean)
            }
        }
        if `uses_poly' == 1 {
            forvalues k = 1/4 {
                qui sum temp_poly`k' if temp_tercile == `i'
                local P`k' = r(mean)
            }
        }

        preserve
            clear

            * Income grid (levels -> log) just for plotting a smooth curve
            local inc_min = 500
            local inc_max = 50500
            local npts    = (`inc_max' - `inc_min')/100 + 1

            set obs `npts'
            gen inc     = `inc_min' + 100*(_n - 1)
            gen inc_log = log(inc)

            * Ensure e(depvar) exists in synthetic data for predictnl
            capture confirm variable `depvar'
            if _rc gen `depvar' = .

            if `uses_tavg' == 1 {
                local inc_cmd ///
                    _b[_cons] + ///
                    _b[`incvar']*inc_log + ///
                    _b[tavg_1_pop_ma_30yr]*`T1' + ///
                    _b[tavg_2_pop_ma_30yr]*`T2' + ///
                    _b[tavg_3_pop_ma_30yr]*`T3' + ///
                    _b[tavg_4_pop_ma_30yr]*`T4'
            }
            if `uses_poly' == 1 {
                local inc_cmd ///
                    _b[_cons] + ///
                    _b[`incvar']*inc_log + ///
                    _b[temp_poly1]*`P1' + ///
                    _b[temp_poly2]*`P2' + ///
                    _b[temp_poly3]*`P3' + ///
                    _b[temp_poly4]*`P4'
            }

            predictnl yhat = `inc_cmd', ci(lo hi)

            twoway ///
                rarea hi lo inc_log || ///
                line yhat inc_log, ///
                graphregion(color(white)) plotregion(color(white)) ///
                xtitle("Log income") ///
                ytitle("Predicted high-risk share") ///
                title("Temp tercile `i'") ///
                legend(off) ///
                name(inc_i`i', replace)

            local inc_graphs "`inc_graphs' inc_i`i'"
        restore
    }

    graph combine `inc_graphs', rows(1) ///
        graphregion(color(white)) plotregion(color(white)) ///
        title("High-risk share vs income by temperature tercile") ///
        note("Model: `m' (optional diagnostic).")

    graph export "`terc_dir'/`m'__Inc_by_TempTercile.pdf", replace

    di as res "Finished diagnostics for model: `m'"

} // end model loop

di as res ">> Done: exported optional diagnostics to `diag_root'"
