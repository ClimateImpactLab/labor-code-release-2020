****************************************************
* Build "cell" labels using tercile (1,2) thresholds
****************************************************

* Paths
local grid_path "/Volumes/cil/battuta_shares/gcp/estimation/labor/code_release_int_data/xtiles/rep_unit_terciles_grid.dta"
local data_path "/Volumes/cil/battuta_shares/gcp/estimation/labor/code_release_int_data/regression_ready_data/labor_dataset_splines_nochn_tmax_chn_prev_week_no_ll_0_agnonag_272841_0129.dta"

* -----------------------------
* 1) Read grid and store cutoffs
* -----------------------------
preserve
use "`grid_path'", clear

* Keep only tercile 1 and 2
keep if inlist(tercile, 1, 2)

* Safety checks (optional but helpful)
isid tercile

* Store max cutoffs into locals
forvalues m = 1/2 {
    quietly summarize max_loggdppc if tercile == `m', meanonly
    local gdpmax`m' = r(mean)

    quietly summarize max_lrtmax if tercile == `m', meanonly
    local tmax`m' = r(mean)
}

restore

* -----------------------------
* 2) Load main data and create cell
* -----------------------------
use "`data_path'", clear

* Create empty string cell
gen str2 cell = ""

* Assign mn for m,n in {1,2}
forvalues m = 1/2 {
    forvalues n = 1/2 {
        replace cell = "`m'`n'" ///
            if !missing(log_gdp_pc_adm1, real_temperature) ///
            & log_gdp_pc_adm1 < `gdpmax`m'' ///
            & real_temperature < `tmax`n''
    }
}

* (Optional) If you want to see counts
tab cell, missing

* (Optional) Save to a new file (recommended)
local out_path "/Volumes/cil/battuta_shares/gcp/estimation/labor/code_release_int_data/regression_ready_data/labor_dataset_splines_nochn_tmax_chn_prev_week_no_ll_0_agnonag_272841_0129_with_cell.dta"
save "`out_path'", replace
