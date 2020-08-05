
/*********************************************************************************

This do-file accomplishes the following:

--	generates tercile means, maxes, and mins for LR climate and income, using 
	representative-units as the ranked objects rather than all global IRs. This 
	allows for a different categorization into the cells of the 9-plot graph.

-- output is saved to rep_unit_terciles_grid.dta.

By: Kit Schwarz, csschwarz@uchicago.edu
Date: 28/07/2020

*********************************************************************************/

** SET UP

* ssc install gtools
* ssc install egenmore

local filepath = "/shares/gcp/estimation/labor/time_use_data/final"
local savepath = "/mnt/CIL_labor/2_regression/time_use/input"

** BY REP-UNIT: GET UNIQUE LR CLIMATE/INCOME VALUES, GET COUNTS

use "`filepath'/labor_dataset_splines_27_37_39_tmax_chn_prev_week_no_ll_0.dta", clear

gcollapse (first) lr_tmax_p1 log_gdp_pc_adm1 , by(rep_unit)

** TERCILES OF LONG RUN CLIMATE

xtile clim_tercile = lr_tmax_p1, nq(3)
egen mean_lrtmax = mean(lr_tmax_p1), by(clim_tercile)
egen min_lrtmax = min(lr_tmax_p1), by(clim_tercile)
egen max_lrtmax = max(lr_tmax_p1), by(clim_tercile)

** TERCILES OF INCOME

xtile inc_tercile = log_gdp_pc_adm1, nq(3)
egen mean_loggdppc = mean(log_gdp_pc_adm1), by(inc_tercile)
egen min_loggdppc = min(log_gdp_pc_adm1), by(inc_tercile)
egen max_loggdppc = max(log_gdp_pc_adm1), by(inc_tercile)


** SAVE LR CLIMATE TERCILES

preserve

gcollapse (first) mean_lrtmax min_lrtmax max_lrtmax, by(clim_tercile)
rename clim_tercile tercile
tempfile clim
save `clim', replace

** SAVE INCOME TERCILES

restore

gcollapse (first) mean_loggdppc min_loggdppc max_loggdppc, by(inc_tercile)
rename inc_tercile tercile

** MERGE FILES TOGETHER FOR NEATNESS 
merge 1:1 tercile using `clim', nogen

save "`savepath'/rep_unit_terciles_grid.dta", replace
