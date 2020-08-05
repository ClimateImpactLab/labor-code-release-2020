
* 2 Jan 2020

set more off
clear all
cap ssc install rsource

cilpath

* run the following when need to generate crosswalks
*shell python "$REPO/gcp-labor/1_preparation/merge/generate_crosswalks.py"

global dataset_path /shares/gcp/estimation/Labor/labor_merge_2019

global varlist_precip prcp_poly_1 prcp_poly_2


************************************************************
* generate dataset for polynomial regression (uninteracted)
use "$dataset_path/intermediate_files/labor_time_use_all_countries_weighted.dta", clear



* merge specified climate variables into the dataset, adding lags to each variable
cap program drop merge_climate_data_var_with_lags
program define merge_climate_data_var_with_lags
	args iso varlist_name
	di "`iso'"

	* loop through each variable
	foreach v in ${`varlist_name'} {
		di "`v'"
		use "/shares/gcp/estimation/Labor/Climate_data/time_use_newvars/outputs/merged/`iso'/by_var/GMFD_`iso'_`v'.dta", clear
		gen date = mdy(month, day, year)
		gen dow = dow(date)		
		tsset location_id2 date 

		if "`iso'" == "BRA" | "`iso'" == "MEX" {
			* weekly 
			gen weekly_`v' = `v'
			forval i = 1/6{
				gen `v'_f`i' = F`i'.`v'
				replace weekly_`v' = weekly_`v' + `v'_f`i'
			}
			replace `v' = weekly_`v' 
			forval i = 1/6{
				gen `v'_v`i' = `v'
			}
			drop weekly_* *_f?
			keep if dow == 0 | (date == 17166 & "`iso'"=="BRA")
			replace date = 17531 if date == 17166 & "`iso'"=="BRA"
		} 
		else if "`iso'" == "CHN" {
			gen weekly_`v' = `v'
			forval i = 1/6{
				gen `v'_l`i' = L`i'.`v'
				replace weekly_`v' = weekly_`v' + `v'_l`i'
			}
			replace `v' = weekly_`v' 
			forval i = 1/6{
				gen `v'_v`i' = `v'
			}
			drop weekly_* *_l?
		} 
		else {
			* daily 
			replace `v' = `v' * sqrt(7)
			forval i = 1/6{
				local j = 7-`i'
				gen `v'_v`i' = F`j'.`v'
				replace `v'_v`i' = L`i'.`v' if dow >=`i'
			}
		}
		merge 1:n location_id1 location_id2 date using `iso'_spl_dt
		drop if _merge != 3
		drop _merge
		save `iso'_spl_dt, replace
	}
end

* merge a whole file of climate variables into the dataset, adding lags to each variable
cap program drop merge_climate_data_file
program define merge_climate_data_file
	args iso filename
	di "`iso'"
	use "/shares/gcp/estimation/Labor/Climate_data/time_use_newvars/outputs/merged/`iso'/by_var/GMFD_`iso'_`filename'.dta", clear
	gen date = mdy(month, day, year)
	gen dow = dow(date)		
	tsset location_id2 date 
	drop month day year

	* loop through each variable
	foreach v of varlist _all {
		di "`v'"
		if "`v'" == "location_id2" | "`v'" == "location_id1" | "`v'" == "date" | "`v'" == "dow" continue
		if "`iso'" == "BRA" | "`iso'" == "MEX" {
			* weekly 
			gen weekly_`v' = `v'
			forval i = 1/6{
				gen `v'_f`i' = F`i'.`v'
				replace weekly_`v' = weekly_`v' + `v'_f`i'
			}
			replace `v' = weekly_`v' 
			forval i = 1/6{
				gen `v'_v`i' = `v'
			}
			drop weekly_* *_f?
		
		} 
		else if "`iso'" == "CHN" {
			gen weekly_`v' = `v'
			forval i = 1/6{
				gen `v'_l`i' = L`i'.`v'
				replace weekly_`v' = weekly_`v' + `v'_l`i'
			}
			replace `v' = weekly_`v' 
			forval i = 1/6{
				gen `v'_v`i' = `v'
			}
			drop weekly_* *_l?
		} 
		else {
			* daily 
			replace `v' = `v' * sqrt(7)
			forval i = 1/6{
				local j = 7-`i'
				gen `v'_v`i' = F`j'.`v'
				replace `v'_v`i' = L`i'.`v' if dow >=`i'
			}
		}
	}
	*replace date = 17531 if date == 17166 & "`iso'"=="BRA"
	merge 1:n location_id1 location_id2 date using `iso'_spl_dt
	drop if _merge != 3
	drop _merge
	save `iso'_spl_dt, replace
end



* merge long run climate variables by location_id1 and location_id2
cap program drop merge_long_run
program define merge_long_run
	args iso 
	di "`iso'"
	use "/shares/gcp/estimation/Labor/Climate_data/time_use_newvars/outputs/merged/`iso'/by_var/GMFD_`iso'_long_run.dta", clear	
	merge 1:n location_id1 location_id2 using `iso'_spl_dt
	drop if _merge != 3
	drop _merge
	save `iso'_spl_dt, replace
end

cap program drop merge_long_run_adm1
program define merge_long_run_adm1
	args iso 
	di "`iso'"
	use "/shares/gcp/estimation/Labor/Climate_data/time_use_newvars/outputs/merged/`iso'/by_var/GMFD_`iso'_long_run.dta", clear	
	merge 1:n location_id1 using `iso'_spl_dt
	drop if _merge != 3
	drop _merge
	save `iso'_spl_dt, replace
end


global countries CHN MEX BRA USA GBR IND ESP FRA
global varlist_tmax_poly_1 tmax_poly_1
* define variable lists

foreach iso in $countries {
	preserve
	* keep only the country's data
	drop if iso != "`iso'" 
	save `iso'_spl_dt, replace
	merge_climate_data_var_with_lags `iso' varlist_tmax_poly_1
	merge_climate_data_var_with_lags `iso' varlist_precip
	merge_climate_data_file `iso' tmax_splines
	merge_long_run_adm1 `iso'
	*merge_long_run `iso'
	
	restore
}

clear all

foreach iso in $countries {
	di "`iso'"
	append using `iso'_spl_dt.dta
	erase `iso'_spl_dt.dta
}



* separate the dataset into 4 quadrants by climate and income, and add all kinds of weights
cap program drop generate_grids_and_weights
program define generate_grids_and_weights  
	preserve
	collapse (first)lr_cdd_30C lgdppc, by(location_id1)
	xtile htile = lr_cdd_30C, nq(2)
	xtile ytile = lgdppc, nq(2)
	tempfile tiles
	save `tiles'
	restore

	merge n:1 location_id1 using `tiles'

	* generate some variables for plotting histograms
	gen adj_sample_weight_adm2_int = adj_sample_weight_adm2 * 10^14
	*gen real_temperature = tmax_poly_1/(7^0.5) if dow_week!=8
	*replace real_temperature = tmax_poly_1/7 if dow_week==8

	* generate new weights: population weights separated by high and low risk
	foreach v in risk_prop risk_sum adj_sample_weight_risk total_risk_share adj_sample_weight_risk_equal {
		cap drop `v'
	}
	bysort iso high_risk: gen risk_prop = _N 
	by iso: replace risk_prop = risk_prop/_N 
	gen adj_sample_weight_risk = pop_adj_sample_weight * risk_prop
	bysort high_risk: egen risk_sum = total(adj_sample_weight_risk)
	gen total_risk_share = _N
	bysort high_risk: replace total_risk_share = _N / total_risk_share
	replace adj_sample_weight_risk = adj_sample_weight_risk / risk_sum * total_risk_share

	cap drop adj_sample_weight_risk_equal
	gen adj_sample_weight_risk_equal = adj_sample_weight_risk /  total_risk_share
	drop total_risk_share risk_prop risk_sum 

	* redefine clusters so that all the regressions generate standard errors
	egen cluster_isommyy = group(iso month year)
	egen cluster_adm1mmyy = group(location_id1 month year)

end

generate_grids_and_weights

gen real_temperature = tmax_poly_1/(7^0.5) if dow_week!=8
replace real_temperature = tmax_poly_1/7 if dow_week==8


save "$dataset_path/for_regression/labor_dataset_jan_2012_splines_adm1_lrtmax.dta", replace

*use "$dataset_path/for_regression/labor_dataset_jan_2012_splines.dta", clear

