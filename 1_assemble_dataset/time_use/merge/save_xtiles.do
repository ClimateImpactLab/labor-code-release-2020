/*********************************************************************************

This do-file accomplishes the following:

--	generates tercile means, maxes, and mins for LR climate and income, using 
	representative-units as the ranked objects rather than all global IRs. This 
	allows for a different categorization into the cells of the 9-plot graph.

-- output is saved to rep_unit_terciles_grid.dta.

By: Kit Schwarz, csschwarz@uchicago.edu
Date: 28/07/2020

*********************************************************************************/

*****************
*	INITIALIZE
*****************

* get functions and paths
run "/home/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"
run "${DIR_REPO_LABOR}/2_analysis/0_subroutines/functions.do"

local savepath = "${ROOT_INT_DATA}/xtiles"
cap mkdir `savepath'

*****************
*	GET XTILES
*****************

** BY REP-UNIT: GET UNIQUE LR CLIMATE/INCOME VALUES, GET COUNTS

use "${ROOT_INT_DATA}/regression_ready_data/labor_dataset_splines_nochn_tmax_chn_prev_week_no_ll_0.dta", clear

gegen rep_unit_year = tag(rep_unit year)
gcollapse (first) lr_tmax_p1 log_gdp_pc_adm1 (sum) rep_unit_year, by(rep_unit)

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

** QUANTILES OF INC-CLIMATE

xtile clim_quantile = lr_tmax_p1, nq(2)
xtile inc_quantile = log_gdp_pc_adm1, nq(2)

save "`savepath'/rep_unit_terciles_uncollapsed.dta", replace

drop clim_q inc_q

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
