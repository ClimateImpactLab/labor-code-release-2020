
* 2 Jan 2020

set more off
clear all
cap ssc install rsource

cilpath

global temp_path /shares/gcp/estimation/labor/time_use_data/intermediate


* merge a whole file of climate variables into the dataset, adding lags to each variable
cap program drop merge_climate_data_file_ll
program define merge_climate_data_file_ll
	args iso filename 
	di "`iso'"
	use "/shares/gcp/estimation/labor/climate_data/final/`iso'/GMFD_`iso'_`filename'.dta", clear

	*gen date = mdy(month, day, year)
	gen interview_date = mdy(month, day, year)
	gen dow = dow(interview_date)		
	tsset adm2_id interview_date 

	* loop through each variable
	foreach v of varlist _all {
		di "`v'"
		if "`v'" == "adm1_id" | "`v'" == "adm2_id" | "`v'" == "date" | "`v'" == "dow" | "`v'" == "year" | "`v'" == "month" | "`v'" == "day" | "`v'" == "interview_date"  continue
		* generate 21 leads and lags, with interview date as day 1 of the lead week
		forval i = 1/14{
			local n_day = 15 - `i'  
			gen `v'_d`n_day' = L`i'.`v'
		}
		gen `v'_d15 = `v'

		forval i = 1/7{
			local n_day = 15 + `i'  
			gen `v'_d`n_day' = F`i'.`v'
		}
		drop `v'
	}
	merge 1:n adm2_id interview_date using `iso'_dt, nogen keep(3)
	*merge 1:n adm2_id date using `iso'_dt, nogen keep(3)
	save `iso'_dt, replace
end


* merge a whole file of climate variables into the dataset, adding lags to each variable
cap program drop merge_climate_data_variable
program define merge_climate_data_variable
	args iso filename v
	di "`iso'"
	use "/shares/gcp/estimation/labor/climate_data/final/`iso'/GMFD_`iso'_`filename'.dta", clear

	gen interview_date = mdy(month, day, year)
	tsset adm2_id interview_date 

	di "`v'"
	keep interview_date adm2_id `v'
	merge 1:n adm2_id interview_date using `iso'_dt, nogen keep(3)
	save `iso'_dt, replace
end


use "$temp_path/all_time_use_holidays_removed", clear
keep if iso == "CHN"
save CHN_dt, replace
import delimited using "$temp_path/CHN_CHNS_time_use_interview_dates.csv", clear
rename idind ind_id
merge 1:1 year month day ind_id using CHN_dt, nogen keep(3)
drop v1 commid 
gen interview_date = mdy(interview_month, interview_day, interview_year)
gen interview_dow = dow(interview_date)
save CHN_dt, replace

use CHN_dt, clear
*	merge_climate_data_intv_dt_bin CHN bins

merge_climate_data_file_ll CHN splines 
merge_climate_data_file_ll CHN precip
merge_climate_data_variable CHN polynomials tmax_p1
*merge_long_run CHN

cap drop *_v?
gen real_temperature = tmax_p1
save "$temp_path/daily_controls/chn_splines_daily_d1_d21.dta", replace

