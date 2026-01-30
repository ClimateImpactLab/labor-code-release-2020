****************************************************
* Drop duplicate keys entirely, then merge
* (Original files remain untouched)
****************************************************

* File paths
local f0114 "/project/cil/battuta_shares/gcp/estimation/labor/code_release_int_data/regression_ready_data/27_28_41_approx/labor_dataset_splines_nochn_tmax_MASTERMATCH_0114.dta"
local f0116 "/project/cil/battuta_shares/gcp/estimation/labor/code_release_int_data/regression_ready_data/labor_dataset_splines_nochn_tmax_chn_prev_week_no_ll_0_agnonag_272841.dta"

* Merge keys
local keys iso date year month adm0_id adm1_id adm2_id mins_worked high_risk

****************************************************
* 1) Prepare MASTER (0114): drop all duplicate keys
****************************************************
use `keys' tmax_rcspl_3kn_t0 using "`f0114'", clear

* Tag duplicates
duplicates tag `keys', gen(_dup)

* Drop ALL observations with duplicated keys
drop if _dup > 0
drop _dup

tempfile master_clean
save `master_clean', replace

****************************************************
* 2) Prepare USING (0116): drop all duplicate keys
****************************************************
use `keys' tmax_rcspl_3kn_27_28_41_t0 using "`f0116'", clear

duplicates tag `keys', gen(_dup)
drop if _dup > 0
drop _dup

tempfile using_clean
save `using_clean', replace

****************************************************
* 3) Merge on cleaned tempfiles (keep matched only)
****************************************************
use `master_clean', clear
merge 1:1 `keys' using `using_clean'

* Keep only observations present in BOTH datasets
keep if _merge == 3
drop _merge

****************************************************
* 4) (Optional) sanity checks
****************************************************
summ tmax_rcspl_3kn_t0 tmax_rcspl_3kn_27_28_41_t0
corr tmax_rcspl_3kn_t0 tmax_rcspl_3kn_27_28_41_t0

****************************************************
* 5) Save merged result
****************************************************
save "/project/cil/battuta_shares/gcp/estimation/labor/code_release_int_data/regression_ready_data/merge_0114_0116_dropdups_onlymatched.dta", replace
