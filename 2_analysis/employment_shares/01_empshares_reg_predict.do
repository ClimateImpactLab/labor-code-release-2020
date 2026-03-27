********************************************************************************
* FILE:    01_empshares_reg_predict.do
*
* PROJECT:
*   Climate Impact Lab — Labor Paper
*
* PURPOSE:
*   Core estimation + prediction pipeline for the employment-share analysis
*   using the UPDATED agriculture-based high-risk definition.
*
*   This script:
*     (1) Loads and cleans the merged employment–income–climate dataset
*     (2) Restricts to last census year per ADM1 (geolev1), with climate through 2010
*     (3) Estimates FOUR regression specifications:
*           Spec 1: log_inc + (tavg_1..tavg_4)                 [poly terms provided]
*           Spec 2: Spec 1 + continent FE (ib3.continent_code)
*           Spec 3: log_inc + (temp_poly1..temp_poly4)         [explicit powers of T]
*           Spec 4: Spec 3 + continent FE
*     (4) Saves each model as a .ster file
*     (5) Exports prediction grids WITH SE/CI for:
*           - Temperature grid: yhat(temp) holding log_inc at its sample mean
*           - Income grid:      yhat(inc_log) holding temperature at its sample mean
*
* DEPENDENT VARIABLE (after revisions):
*   industry_share10   (agriculture employment share)
*
* INPUT DATA:
*   ${EMP_SHARE_DIR}/data/emp_inc_clim_merged_new.csv
*
* OUTPUTS:
*   ${DIR_OUTPUT}/employment_shares/
*       ster/
*           log_inc_poly4_2025_newrisk.ster
*           log_inc_poly4_continent_fes_2025_newrisk.ster
*           log_inc_lrtk_2025_newrisk.ster
*           log_inc_lrtk_continent_fes_2025_newrisk.ster
*
*       yhat_values/
*           *_TempPredMinMax.csv   (temp grid with yhat, se, CI)
*           *_IncPred.csv          (income grid with yhat, se, CI)
*
* RELATION TO OTHER SCRIPTS:
*   - Diagnostics only (not needed downstream):
*         01bis_empshares_reg_diagnostics.do
*   - Regression table:
*         02_empshares_reg_table_E1.do
*   - Figure E.1:
*         03_empshare_reg_figure_E1.R
*   - Figure 5 panels A–B:
*         04_empshares_pred_figure5.R
*   - Figure 5 panels C–D maps:
*         05_empshares_map_figure5.R
*
* LAST UPDATED:
*   2026-01-12
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

* Input data root (employment_shares_data)
global EMP_SHARE_DIR "${ROOT_INT_DATA}/employment_shares_data"
global data_dir "${EMP_SHARE_DIR}/data"

* Repo output dirs (inside labor-code-release)
global out_root  "${DIR_OUTPUT}/employment_shares"
global ster_dir  "${out_root}/ster"
global yhat_dir  "${out_root}/yhat_values"

cap mkdir "${DIR_OUTPUT}"
cap mkdir "${out_root}"
cap mkdir "${ster_dir}"
cap mkdir "${yhat_dir}"

****************************************************
* 2) Settings: riskvar + naming + grids
****************************************************

* We keep the suffix "newrisk" for compatibility with old filenames.
local risklabel "newrisk"
local riskvar ind_highrisk_share_new


* Income variable used in regressions (already log in the data)
local incvar_raw "log_gdppc_adm1_pwt_ds_15ma"
local incvar     "log_inc"

* Temperature prediction grid (legacy hard-coded range)
local temp_min  = floor(-26.22)
local temp_max  = ceil(42.87)
local temp_step = 1

* Income prediction grid in levels -> log
local inc_min  = 650
local inc_max  = 77050
local inc_step = 100

****************************************************
* 3) Load + clean data 
****************************************************

import delimited "${data_dir}/emp_inc_clim_merged_new.csv", clear


** industry_share10 is share of agriculture 
** defining new high risk share
 gen ind_highrisk_share_new = industry_share10


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

* Continent code for FE specs
encode continent, gen(continent_code)

* Keep census years only and climate-available years
keep if !missing(total_pop)
drop if year > 2010

* Last census year per ADM1
bysort geolev1: egen max_year = max(year)
keep if year == max_year

* Rename income variable to log_inc
rename `incvar_raw' `incvar'

* Sanity checks
assert !missing(`riskvar')
*assert !missing(`incvar')
*assert !missing(tavg_1_pop_ma_30yr)

di as txt "Last-census sample N = " _N

* Explicit powers of long-run temperature (for lrtk specs)
gen temp_poly1 = tavg_1_pop_ma_30yr
gen temp_poly2 = tavg_1_pop_ma_30yr^2
gen temp_poly3 = tavg_1_pop_ma_30yr^3
gen temp_poly4 = tavg_1_pop_ma_30yr^4

* Save cleaned sample for reuse
tempfile base
save "`base'", replace

***********************************************************
* 4) Compute means used for prediction holding values fixed
***********************************************************
use "`base'", clear

qui summarize `incvar'
local log_inc_mean = r(mean)

* Means of provided polynomial terms tavg_1..4
forvalues k = 1/4 {
    qui summarize tavg_`k'_pop_ma_30yr
    local tavg`k'_mean = r(mean)
}

* Means of explicit powers temp_poly1..4
forvalues k = 1/4 {
    qui summarize temp_poly`k'
    local temp`k'_mean = r(mean)
}

*******************************************************
* 5) Run 4 models + save ster + export prediction grids
*******************************************************

use "`base'", clear

forvalues spec = 1/4 {

    *-------------------- Estimate model --------------------
    if `spec' == 1 {
        reghdfe `riskvar' `incvar' ///
            tavg_1_pop_ma_30yr tavg_2_pop_ma_30yr tavg_3_pop_ma_30yr tavg_4_pop_ma_30yr, ///
            noabsorb
        local saveas "log_inc_poly4_2025_`risklabel'"
    }

    if `spec' == 2 {
        reghdfe `riskvar' `incvar' ///
            tavg_1_pop_ma_30yr tavg_2_pop_ma_30yr tavg_3_pop_ma_30yr tavg_4_pop_ma_30yr ///
            ib3.continent_code, ///
            noabsorb
        local saveas "log_inc_poly4_continent_fes_2025_`risklabel'"
    }

    if `spec' == 3 {
        reghdfe `riskvar' `incvar' ///
            temp_poly1 temp_poly2 temp_poly3 temp_poly4, ///
            noabsorb
        local saveas "log_inc_lrtk_2025_`risklabel'"
    }

    if `spec' == 4 {
        reghdfe `riskvar' `incvar' ///
            temp_poly1 temp_poly2 temp_poly3 temp_poly4 ///
            ib3.continent_code, ///
            noabsorb
        local saveas "log_inc_lrtk_continent_fes_2025_`risklabel'"
    }

    * Save .ster
    estimates save "${ster_dir}/`saveas'.ster", replace
    di as res "Saved ster: ${ster_dir}/`saveas'.ster"

    *-------------------- Temperature prediction grid --------------------
    * For each fitted model, compute predicted agriculture share over a
    * temperature grid while holding log income fixed at its sample mean
    
	preserve
        clear

        local ntemp = floor((`temp_max' - `temp_min')/`temp_step') + 1
        set obs `ntemp'
        gen temp = `temp_min' + (`temp_step')*(_n - 1)

        * dummy riskvar so predictnl is happy with e(depvar)
        gen `riskvar' = .
		
		* Build the prediction equation manually using estimated coefficients (_b[])
		* so that predictions can be evaluated on the synthetic temperature grid.
        if inlist(`spec', 1, 2) {
            local temp_cmd ///
                _b[_cons] + ///
                _b[`incvar']*`log_inc_mean' + ///
                _b[tavg_1_pop_ma_30yr]*temp + ///
                _b[tavg_2_pop_ma_30yr]*temp^2 + ///
                _b[tavg_3_pop_ma_30yr]*temp^3 + ///
                _b[tavg_4_pop_ma_30yr]*temp^4
        }
        else {
            local temp_cmd ///
                _b[_cons] + ///
                _b[`incvar']*`log_inc_mean' + ///
                _b[temp_poly1]*temp + ///
                _b[temp_poly2]*temp^2 + ///
                _b[temp_poly3]*temp^3 + ///
                _b[temp_poly4]*temp^4
        }

        predictnl yhat = `temp_cmd', se(se) ci(lo hi)
        rename lo lowerci_hi
        rename hi upperci_hi

        keep temp yhat se lowerci_hi upperci_hi
        export delimited "${yhat_dir}/`saveas'_TempPredMinMax.csv", replace
        di as txt "Exported: ${yhat_dir}/`saveas'_TempPredMinMax.csv"
    restore

    *-------------------- Income prediction grid --------------------
    * For each fitted model, compute predicted agriculture share over an
    * income grid (in log GDP per capita space), holding temperature terms
    * fixed at their sample means.
	
    preserve
        clear

        local ninc = floor((`inc_max' - `inc_min')/`inc_step') + 1
        set obs `ninc'
        gen inc     = `inc_min' + (`inc_step')*(_n - 1)
        gen inc_log = log(inc)

        * Critical: dummy riskvar so predictnl is happy with e(depvar)
        gen `riskvar' = .

        if inlist(`spec', 1, 2) {
            local inc_cmd ///
                _b[_cons] + ///
                _b[`incvar']*inc_log + ///
                _b[tavg_1_pop_ma_30yr]*`tavg1_mean' + ///
                _b[tavg_2_pop_ma_30yr]*`tavg2_mean' + ///
                _b[tavg_3_pop_ma_30yr]*`tavg3_mean' + ///
                _b[tavg_4_pop_ma_30yr]*`tavg4_mean'
        }
        else {
            local inc_cmd ///
                _b[_cons] + ///
                _b[`incvar']*inc_log + ///
                _b[temp_poly1]*`temp1_mean' + ///
                _b[temp_poly2]*`temp2_mean' + ///
                _b[temp_poly3]*`temp3_mean' + ///
                _b[temp_poly4]*`temp4_mean'
        }

        predictnl yhat = `inc_cmd', se(se) ci(lo hi)
        rename lo lowerci_hi
        rename hi upperci_hi

        keep inc_log yhat se lowerci_hi upperci_hi
        export delimited "${yhat_dir}/`saveas'_IncPred.csv", replace
        di as txt "Exported: ${yhat_dir}/`saveas'_IncPred.csv"
    restore
}

di as res ">> Done: estimated 4 models, saved ster, exported temp+income grids (with SE/CI)."
