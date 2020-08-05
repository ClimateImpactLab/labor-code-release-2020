
* 2 Jan 2020

set more off
clear all
cap ssc install rsource

cilpath

* run the following when need to generate crosswalks
*shell python "$REPO/gcp-labor/1_preparation/merge/generate_crosswalks.py"

global dataset_path /shares/gcp/estimation/Labor/labor_merge_2019

* get labor data for china
insheet using "$DB/Global ACP/labor/1_preparation/time_use/china/chn_time_use.csv", clear
keep commid mins_worked high_risk age age2 hhsize interview_date male idind
tostring interview_date, replace

* drop those missing interview date
drop if interview_date == ""
gen date = date(interview_date, "YMD") 
gen interview_dow = dow(date)

replace date = date - interview_dow 
replace date = date - 7 if interview_dow == 0


drop interview_date

* generate some variables to be consistent with other countries
gen iso = "CHN"
gen country = 8
gen dow_week = 8
gen sample_weight = 1
gen year = year(date)
gen month = month(date)
gen day = day(date)
tempfile CHN_survey
save `CHN_survey'

insheet using "$DB/Global ACP/labor/1_preparation/crosswalks/timeuse_climate_crosswalk_CHN.csv", clear
merge 1:n commid using `CHN_survey'
/*
   *    Result                           # of obs.
   *    -----------------------------------------
   *    not matched                             2
   *        from master                         1  (_merge==1) * no matching survey entry
   *        from using                          1  (_merge==2) * no commid, no time worked*
   *
   *    matched                            73,084  (_merge==3)
   *    -----------------------------------------
*/
drop if _merge != 3
drop _merge name_1 name_2 commid
tempfile CHN_append
rename idind id
save `CHN_append'

* append china to the full dataset
* get the labor data for countries except for china
use "/shares/gcp/estimation/Labor/Stata_Data/Yuqi_Files/NewMergeGMFD/GMFD_Labor_merged_0819_smallwt_clean_allcov_newclim.dta", clear
* in this dataset, year = year(date), month = month(date), day = day(date), dow_week = dow(date) with weekly data set to 8
keep location_id1 location_id2 mins_worked high_risk age age2 hhsize date iso male sample_weight year month day dow_week country id
append using `CHN_append'

save  "$dataset_path/intermediate_files/labor_time_use_all_countries.dta", replace

use  "$dataset_path/intermediate_files/labor_time_use_all_countries.dta", clear

* clean downscaled income and population data
* use income and population in the year (beginning year + end year) / 2 round up
import delimited using "$DB/Global ACP/labor/1_preparation/covariates/income/income_downscaled.csv", clear
keep year iso getal_admin_name adm0_pop gdppc_adm1_pwt_downscaled location_id1 

* manually correct one entry for matching
preserve
keep if iso == "CHN"
replace getal_admin_name = "Chongqing" if location_id1 == 55
drop location_id1  
* we want to use 2002 gdp for china
keep if year == 2002
*drop if year != 2005
tempfile income_pop_CHN
save `income_pop_CHN'
restore 

* keep only the years we want for the other countries
drop if iso == "CHN"
drop if iso == "GBR" & year != 1993
drop if inlist(iso, "FRA", "IND") & year != 1999
drop if iso == "BRA" & year != 2006
drop if iso == "ESP" & year != 2003
drop if iso == "IND" & year != 1999
drop if iso == "MEX" & year != 2008
drop if iso == "USA" & year != 2007

tempfile income_pop_non_CHN
save `income_pop_non_CHN'

* merge crosswalk with china income to add location_id1 to china income and population
insheet using "$DB/Global ACP/labor/1_preparation/crosswalks/timeuse_climate_crosswalk_CHN.csv", clear
rename name_1 getal_admin_name
drop name_2 location_id2
duplicates drop location_id1, force
merge 1:n getal_admin_name using `income_pop_CHN'
* result: all matched
keep year iso location_id1 getal_admin_name gdppc_adm1_pwt_downscaled adm0_pop


* combine with the income of other countries
append using `income_pop_non_CHN'
drop year getal_admin_name
*drop getal_admin_name
tempfile income_pop
save `income_pop'


* merge in income and population data to time use data
use "$dataset_path/intermediate_files/labor_time_use_all_countries.dta", clear

merge n:1 location_id1 using `income_pop'
drop if _merge != 3
drop _merge
rename adm0_pop pop
gen lgdppc = log(gdppc_adm1_pwt_downscaled)

* add weights
save "$dataset_path/intermediate_files/labor_time_use_all_countries.dta", replace

rsource using "$REPO/gcp-labor/1_preparation/merge/reweight.R", rpath("/usr/bin/R") roptions(`"--vanilla"')



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
		merge 1:n location_id1 location_id2 date using `iso'_dt
		drop if _merge != 3
		drop _merge
		save `iso'_dt, replace
	}
end

* merge specified climate variables into the dataset, NOT adding lags to each variable
cap program drop merge_climate_data_var_no_lags
program define merge_climate_data_var_no_lags
	args iso varlist_name
	di "`iso'"
	* loop through each variable
	foreach v in ${`varlist_name'} {
		di "`v'"
		use "/shares/gcp/estimation/Labor/Climate_data/time_use_newvars/outputs/merged/`iso'/by_var/GMFD_`iso'_`v'.dta", clear
		gen date = mdy(month, day, year)
		merge 1:n location_id1 location_id2 date using `iso'_dt
		drop if _merge != 3
		drop _merge
		save `iso'_dt, replace
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
	merge 1:n location_id1 location_id2 date using `iso'_dt
	drop if _merge != 3
	drop _merge
	save `iso'_dt, replace
end



* merge long run climate variables by location_id1 and location_id2
cap program drop merge_long_run
program define merge_long_run
	args iso 
	di "`iso'"
	use "/shares/gcp/estimation/Labor/Climate_data/time_use_newvars/outputs/merged/`iso'/by_var/GMFD_`iso'_long_run.dta", clear	
	merge 1:n location_id1 location_id2 using `iso'_dt
	drop if _merge != 3
	drop _merge
	save `iso'_dt, replace
end



* merge long run climate variables by location_id1 and location_id2
cap program drop merge_long_run_adm1
program define merge_long_run_adm1
	args iso 
	di "`iso'"
	use "/shares/gcp/estimation/Labor/Climate_data/time_use_newvars/outputs/merged/`iso'/by_var/GMFD_`iso'_long_run.dta", clear	
	merge 1:n location_id1 using `iso'_dt
	drop if _merge != 3
	drop _merge
	save `iso'_dt, replace
end


* define variable lists

global varlist_precip prcp_poly_1 prcp_poly_2
global varlist_spline 
global varlist_poly tmax_poly_1 tmax_poly_2 tmax_poly_3 tmax_poly_4 
global varlist_polyAbove0 tmax_polyAbove0_1 tmax_polyAbove0_2 tmax_polyAbove0_3 tmax_polyAbove0_4 
global varlist_polyAbove27 tmax_polyAbove27_1 tmax_polyAbove27_2 tmax_polyAbove27_3 tmax_polyAbove27_4 
global varlist_polyBelow27 tmax_polyBelow27_1 tmax_polyBelow27_2 tmax_polyBelow27_3 tmax_polyBelow27_4 

************************************************************
* generate dataset for polynomial regression (uninteracted)
use "$dataset_path/intermediate_files/labor_time_use_all_countries_weighted.dta", clear


global countries MEX BRA USA GBR IND CHN ESP FRA

foreach iso in $countries {
	preserve
	* keep only the country's data
	drop if iso != "`iso'" 
	save `iso'_dt, replace
	merge_climate_data_var_with_lags `iso' varlist_precip
	merge_climate_data_var_with_lags `iso' varlist_poly
	merge_long_run_adm1 `iso'
	restore
}

clear all

foreach iso in $countries {
	di "`iso'"
	append using `iso'_dt.dta
	erase `iso'_dt.dta
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


*save "$dataset_path/labor_dataset_jan_2012_poly_uninteracted.dta", replace


save "$dataset_path/labor_dataset_feb_2012_polynomials_adm1_lrtmax.dta", replace





