* Step 1: Clean the using dataset and save a separate file

use "/project/cil/battuta_shares/gcp/estimation/labor/code_release_int_data/regression_ready_data/labor_dataset_splines_nochn_tmax_chn_prev_week_no_ll_0_3sector_occup_codes_dummies.dta", clear

* Define the key variables
local keys iso adm1_id gdppc_adm0_pwt log_gdp_pc_adm1 adm0_pop ind_id year month day mins_worked age hhsize

* Keep only keys and variables that will be merged in
keep `keys' high_risk high_risk3 manuf

* For each key, keep only the first occurrence in the using data
duplicates drop `keys', force

* Rename incoming variables to avoid name conflicts in the master dataset
rename high_risk  high_risk_before
rename high_risk3 high_risk3_before
rename manuf      manuf_before

* Save the cleaned using dataset
save "/project/cil/battuta_shares/gcp/estimation/labor/code_release_int_data/regression_ready_data/labor_dataset_occ_clean_for_merge.dta", replace


* Step 2: Open the master dataset (1126) and merge m:1

use "/project/cil/battuta_shares/gcp/estimation/labor/code_release_int_data/regression_ready_data/labor_dataset_splines_nochn_tmax_chn_prev_week_no_ll_0_1126.dta", clear

* Record the number of observations in the master dataset
count
local N_master = r(N)

* Define the same key variables
local keys iso adm1_id gdppc_adm0_pwt log_gdp_pc_adm1 adm0_pop ind_id year month day mins_worked age hhsize

* Sort by keys
sort `keys'

* Many-to-one merge: master may have duplicates, using is now unique
merge m:1 `keys' using "/project/cil/battuta_shares/gcp/estimation/labor/code_release_int_data/regression_ready_data/labor_dataset_occ_clean_for_merge.dta"

* Check merge result
tab _merge

* Keep only observations that were present in the master dataset
* This keeps matched observations (3) and, if they exist, master only (1)
keep if _merge == 3 | _merge == 1

* Drop the merge indicator
drop _merge

* Verify that the final number of observations equals the original master
count
display "N in master (1126): " `N_master'
display "N after merge     : " r(N)

* Save the final merged dataset
save "/project/cil/battuta_shares/gcp/estimation/labor/code_release_int_data/regression_ready_data/labor_dataset_splines_nochn_tmax_chn_prev_week_no_ll_0_1201.dta", replace
