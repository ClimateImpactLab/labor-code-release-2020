set more off
clear all
cap ssc install rsource

cilpath

global dataset_path /shares/gcp/estimation/Labor/labor_merge_2019
global countries_weekly CHN BRA MEX
global countries_daily IND USA ESP FRA GBR


* generate country dataset

use "$dataset_path/for_regression/labor_dataset_jan_2020_3Cbins_n24C_51C.dta", clear


* a function that split a dataset into country + EU datasets for country-specific regressions
cap program drop generate_country_datasets
program define generate_country_datasets 

	args filename

	foreach country in $countries_weekly {
		preserve
		keep if iso == "`country'"
		drop *_v* 
		save "$dataset_path/for_regression/country_specific_bins/`filename'_`country'.dta", replace
		restore
	}

	foreach country in $countries_daily {
		preserve
		keep if iso == "`country'"
		foreach v of varlist mins_worked b3C* prcp* {
			replace `v' = `v' / sqrt(7)
		}
		foreach v of varlist age* hhsize male {
			replace `v' = `v' * sqrt(7)
		}
		save "$dataset_path/for_regression/country_specific_bins/`filename'_`country'.dta", replace
		restore
	}

	drop _all
	foreach country in ESP GBR FRA {
		append using  "$dataset_path/for_regression/country_specific_bins/`filename'_`country'.dta"
	}

	save "$dataset_path/for_regression/country_specific_bins/`filename'_EU.dta", replace

end


generate_country_datasets labor_dataset_jan_2020_3Cbins_n24C_51C


* generate country dataset for limited range
use "$dataset_path/for_regression/labor_dataset_jan_2020_3Cbins_0C_42C.dta", clear

global countries_weekly CHN BRA MEX
global countries_daily IND USA ESP FRA GBR

* a function that split a dataset into country + EU datasets for country-specific regressions
cap program drop generate_country_datasets
program define generate_country_datasets 

	args filename

	foreach country in $countries_weekly {
		preserve
		keep if iso == "`country'"
		drop *_v* 
		save "$dataset_path/for_regression/country_specific_bins/`filename'_`country'.dta", replace
		restore
	}

	foreach country in $countries_daily {
		preserve
		keep if iso == "`country'"
		foreach v of varlist mins_worked b3C* prcp* below* above* {
			replace `v' = `v' / sqrt(7)
		}
		foreach v of varlist age* hhsize male {
			replace `v' = `v' * sqrt(7)
		}
		save "$dataset_path/for_regression/country_specific_bins/`filename'_`country'.dta", replace
		restore
	}

	drop _all
	foreach country in ESP GBR FRA {
		append using  "$dataset_path/for_regression/country_specific_bins/`filename'_`country'.dta"
	}

	save "$dataset_path/for_regression/country_specific_bins/`filename'_EU.dta"

end


generate_country_datasets labor_dataset_jan_2020_3Cbins_0C_42C


cap program drop define_country_edge_bins 
program define define_country_edge_bins 
	
	args iso lower_edge_bin upper_edge_bin below_degree above_degree lags
	use "$dataset_path/for_regression/country_specific_bins/labor_dataset_jan_2020_3Cbins_n24C_51C_`iso'.dta", clear
	
	gen below`below_degree' = 0
	gen above`above_degree' = 0
	
	forval t = 1/`lower_edge_bin' {
		replace below`below_degree' = below`below_degree' + b3C_`t'
		drop b3C_`t'
	}

	forval t = `upper_edge_bin'/25 {
		replace above`above_degree' = above`above_degree' + b3C_`t'
		drop b3C_`t'
	}

	if "`lags'" == "wlags" {
		forval v = 1/6{
			gen below`below_degree'_v`v' = 0
			gen above`above_degree'_v`v' = 0
			forval t = 1/`lower_edge_bin' {
				replace below`below_degree'_v`v' = below`below_degree'_v`v' + b3C_`t'_v`v'
				drop b3C_`t'_v`v'
			}
			forval t = `upper_edge_bin'/25 {
				replace above`above_degree'_v`v' = above`above_degree'_v`v' + b3C_`t'_v`v'
				drop b3C_`t'_v`v'
			}	
		}	
	}

	save "$dataset_path/for_regression/country_specific_bins/different_edges/labor_dataset_jan_2020_3Cbins_`below_degree'C_`above_degree'C_`iso'.dta", replace

end

use "$dataset_path/for_regression/country_specific_bins/labor_dataset_jan_2020_3Cbins_n24C_51C_USA.dta", clear
	

*define_country_edge_bins CHN 8 20 0 33 nolags 
*define_country_edge_bins MEX 9 25 3 48 nolags
*define_country_edge_bins BRA 12 21 12 36 nolags
*define_country_edge_bins USA 8 23 0 42 wlags
*define_country_edge_bins IND 14 23 18 42 wlags
define_country_edge_bins EU 8 20 0 33 wlags

