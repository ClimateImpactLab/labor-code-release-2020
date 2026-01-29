/********************************************************************
* Build nested terciles (climate first, then income within climate),
* ranked by rep_unit.
*
* Output (exactly 9 rows):
*   rep_unit_terciles_grid_nested.dta
*   (clim_t, inc_t, cell + mean/min/max for lr_tmax_p1 and log_gdp_pc_adm1)
*
* Optional:
*   rep_unit_terciles_count_nested.dta
********************************************************************/

clear all
set more off

* get functions and paths
run "/project/cil/home_dirs/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"
run "${DIR_REPO_LABOR}/2_analysis/0_subroutines/functions.do"

local savepath "${ROOT_INT_DATA}/xtiles"
cap mkdir "`savepath'"

local indata "/project/cil/battuta_shares/gcp/estimation/labor/code_release_int_data/regression_ready_data/labor_dataset_splines_nochn_tmax_chn_prev_week_no_ll_0_agnonag_272841_0129.dta"

*========================================================
* A) rep_unit-level mapping
*========================================================
use "`indata'", clear

cap drop rep_unit_year
gegen rep_unit_year = tag(rep_unit year)

* collapse to rep_unit level
gcollapse (first) lr_tmax_p1 log_gdp_pc_adm1 (sum) rep_unit_year, by(rep_unit)

* climate terciles across rep_unit
cap drop clim_t
xtile clim_t = lr_tmax_p1, nq(3)

* drop missing clim_t (can't be classified)
drop if missing(clim_t)

* income terciles within each climate tercile (NO by: xtile)
cap drop inc_t
gen byte inc_t = .

forvalues c = 1/3 {
    * count usable obs in this clim group
    quietly count if clim_t == `c' & !missing(log_gdp_pc_adm1)
    local n = r(N)

    * If too few obs, skip (will be filled later in grid via fillin)
    if (`n' < 3) {
        di as error "WARNING: clim_t=`c' has only `n' nonmissing GDP obs; inc_t will remain missing there."
        continue
    }

    * get within-climate p33/p67
    quietly summarize log_gdp_pc_adm1 if clim_t == `c' & !missing(log_gdp_pc_adm1), detail
    local p33 = r(p33)
    local p67 = r(p67)

    * defensive: if p33/p67 missing or equal, fall back to p25/p75 (rare but possible)
    if missing(`p33') | missing(`p67') | (`p33' >= `p67') {
        quietly summarize log_gdp_pc_adm1 if clim_t == `c' & !missing(log_gdp_pc_adm1), detail
        local p33 = r(p25)
        local p67 = r(p75)
    }

    replace inc_t = 1 if clim_t == `c' & log_gdp_pc_adm1 <= `p33' & !missing(log_gdp_pc_adm1)
    replace inc_t = 2 if clim_t == `c' & log_gdp_pc_adm1 >  `p33' & log_gdp_pc_adm1 <= `p67' & !missing(log_gdp_pc_adm1)
    replace inc_t = 3 if clim_t == `c' & log_gdp_pc_adm1 >  `p67' & !missing(log_gdp_pc_adm1)
}

* cell id
cap drop cell
gen byte cell = (clim_t - 1)*3 + inc_t if !missing(inc_t)

* quick check
tab clim_t inc_t, missing

tempfile repunit_map
save `repunit_map', replace


*========================================================
* B) GRID file: force EXACTLY 9 rows
*========================================================
use `repunit_map', clear
keep rep_unit clim_t inc_t lr_tmax_p1 log_gdp_pc_adm1

* collapse summaries by (clim_t, inc_t)
gcollapse ///
    (mean) mean_lrtmax   = lr_tmax_p1 ///
    (min)  min_lrtmax    = lr_tmax_p1 ///
    (max)  max_lrtmax    = lr_tmax_p1 ///
    (mean) mean_loggdppc = log_gdp_pc_adm1 ///
    (min)  min_loggdppc  = log_gdp_pc_adm1 ///
    (max)  max_loggdppc  = log_gdp_pc_adm1 ///
, by(clim_t inc_t)

* ensure all 3x3 combos exist as rows
fillin clim_t inc_t
drop _fill

* recreate cell after fillin
cap drop cell
gen byte cell = (clim_t - 1)*3 + inc_t

count
assert r(N) == 9

sort cell
order clim_t inc_t cell mean_lrtmax min_lrtmax max_lrtmax mean_loggdppc min_loggdppc max_loggdppc

save "`savepath'/rep_unit_terciles_grid_nested.dta", replace
di as txt "SAVED: `savepath'/rep_unit_terciles_grid_nested.dta (9 rows)"


*========================================================
* C) Optional COUNT file: force EXACTLY 9 rows
*========================================================
use "`indata'", clear
merge m:1 rep_unit using `repunit_map', keep(match) nogen

cap drop count_lr count_hr count_rep_unit count_rep_year
gen double count_lr = (high_risk == 0) if !missing(high_risk)
gen double count_hr = (high_risk == 1) if !missing(high_risk)

gegen count_rep_unit = tag(rep_unit)
gegen count_rep_year = tag(rep_unit year)

gcollapse (sum) count_lr count_hr count_rep_unit count_rep_year, by(clim_t inc_t)

fillin clim_t inc_t
drop _fill

cap drop cell
gen byte cell = (clim_t - 1)*3 + inc_t

count
assert r(N) == 9

sort cell
order clim_t inc_t cell count_lr count_hr count_rep_unit count_rep_year
save "`savepath'/rep_unit_terciles_count_nested.dta", replace
di as txt "SAVED: `savepath'/rep_unit_terciles_count_nested.dta (9 rows)"

di as txt "DONE."
