clear all
cap log close
cilpath
clear all
set more off
global data_dir "/shares/gcp/estimation/Labor/labor_merge_2019"
global code_dir "$REPO/gcp-labor/1_preparation/time_use"
log using "$code_dir/gen_country_dataset_${S_DATE}_${S_TIME}.log", text replace



use "$data_dir/labor_dataset_with_china_dec2019.dta", clear

global countries_weekly CHN BRA MEX
global countries_daily IND USA ESP FRA GBR


foreach country in $countries_weekly {
	preserve
	keep if iso == "`country'"
	drop *_v* 
	save "$data_dir/labor_dataset_`country'_dec2019.dta", replace
	restore
}



foreach country in $countries_daily {
	preserve
	keep if iso == "`country'"
	foreach v of varlist mins_worked *poly* below0* {
		replace `v' = `v' / sqrt(7)
	}
	foreach v of varlist age* hhsize male {
		replace `v' = `v' * sqrt(7)
	}
	save "$data_dir/labor_dataset_`country'_dec2019.dta", replace
	restore
}

clear all
foreach country in ESP GBR FRA {
	append using  "$data_dir/for_regression/labor_dataset_`country'_dec2019.dta"
}

save "$data_dir/for_regression/labor_dataset_EU_dec2019.dta"

