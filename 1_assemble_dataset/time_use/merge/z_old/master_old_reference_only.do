* liruixue@uchicago.edu
clear all

do "/home/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"

set more off
set trace off

cap ssc install rsource



global temp_path ${shares_path}/gcp/estimation/labor/time_use_data/intermediate
global final_path ${shares_path}/gcp/estimation/labor/time_use_data/final

******* parameters that need to be modified *******
* possible values: tmax, tavg
global t_version_list tmax

* possible values: chn_week_list chn_prev7days chn_prev_week
global chn_week_list  chn_prev_week

* possible values: splines_wchn, splines_nochn, polynomials, bins
global variables_list splines_27_37_39

* set which parts of the code we want to run and how many lead/lag weeks we want
* possible values: YES or NO
global drop_holidays "YES"
global clean_raw_surveys "NO"
global combine_surveys "NO"
global include_chn "NO" 

* set the following global to lcl or no_ll
global leadlag "no_ll"
* number of weeks we want for the lead/lag weeks
global n_ll 0

******* parameters that need to be modified *******

* no need to modify this string
local countries_all CHN USA MEX BRA GBR FRA ESP IND 


if "${clean_raw_surveys}" == "YES"{
	* clean surveys of individual countries
	shell python "$REPO/gcp-labor/replication/1_preparation/time_use/CHNS/chns_data_cleaning.py"
	rsource using "$REPO/gcp-labor/replication/1_preparation/time_use/ATUS/replicate_atus.R", rpath("/usr/bin/R") roptions(`"--vanilla"')
	rsource using "$REPO/gcp-labor/replication/1_preparation/time_use/ENOE/replicate_enoe.R", rpath("/usr/bin/R") roptions(`"--vanilla"')
	rsource using "$REPO/gcp-labor/replication/1_preparation/time_use/MTUS/replicate_mtus.R", rpath("/usr/bin/R") roptions(`"--vanilla"')
	rsource using "$REPO/gcp-labor/replication/1_preparation/time_use/ITUS/replicate_itus.R", rpath("/usr/bin/R") roptions(`"--vanilla"')
	do "$REPO/gcp-labor/replication/1_preparation/time_use/PME/clean_pme.do"
}

if "${combine_surveys}" == "YES" {

	* generate crosswalk and convert the location names in the survey data to admin ids
	shell python "$REPO/gcp-labor/1_preparation/merge/generate_crosswalks.py"
	* combine the surveys into all_time_use.csv
	shell python "$REPO/gcp-labor/1_preparation/merge/combine_surveys.py"
	import delimited using "$temp_path/all_time_use.csv", clear
	count

	* drop UK old data due to quality concerns and data missing issue
	drop if year == 1974 | year == 1975

	* generate some variables
	* date hold interview date for CHN
	* diary date for the daily countries: IND, USA, EU(FRA, ESP, GBR)
	* for BRA: the saturday at the end of the surveyed week 
	* for MEX: the sunday at the end of the surveyed week (sunday before the interview date)
	gen date = mdy(month, day, year)
	gen age2 = age^2
	replace adm3_id = adm2_id if adm3_id == .

	* assign value 8 for weekly data, mon -> 1, sat -> 6, sun -> 0
	gen dow_week = dow(date)
	replace dow_week = 8 if inlist(iso, "CHN","BRA","MEX")

	* scale variables
	replace mins_worked = mins_worked * sqrt(7) if !inlist(iso, "CHN","BRA","MEX")
	foreach v of varlist age age2 hhsize male {
		di "`v'"
		replace `v' = `v' / sqrt(7) if !inlist(iso, "CHN","BRA","MEX")
	}

	drop if missing(hhsize)
	drop if missing(date)

	save "$temp_path/all_time_use_clean.dta", replace

	****** merge in income and population ***********
	do  "$REPO/gcp-labor/replication/1_preparation/income/map_names.do"
	* TO-DO: test the follow line
	rsource using "$REPO/gcp-labor/replication/1_preparation/income/Downscale.R", rpath("/usr/bin/R") roptions(`"--vanilla"')

	
	di "$DB/Global ACP/labor/replication/1_preparation/covariates/income/income_downscaled.csv"
	import delimited using "$DB/Global ACP/labor/replication/1_preparation/covariates/income/income_downscaled.csv", clear
	ds
	keep year iso adm1_id adm0_pop gdppc_adm1_pwt_downscaled gdppc_adm0_pwt

	rename gdppc_adm1_pwt_downscaled log_gdp_pc_adm1
	replace log_gdp_pc_adm1 = log(log_gdp_pc_adm1)
	
	duplicates drop
	drop if iso == "CHN" & year != 2002
	drop if iso == "GBR" & year != 1993
	drop if inlist(iso, "FRA", "IND") & year != 1999
	drop if iso == "BRA" & year != 2006
	drop if iso == "ESP" & year != 2003
	drop if iso == "IND" & year != 1999
	drop if iso == "MEX" & year != 2008
	drop if iso == "USA" & year != 2007

	* keep national-level income for nationally-representative surveys
	replace log_gdp_pc_adm1 = log(gdppc_adm0_pwt) if inlist(iso, "USA", "GBR", "FRA")

	* IMPORTANT!!!!!! when merging, stata keeps the column in the master data if using has columns with the same name
	* so if we don't drop year, the time use data's year will be replaced by year of the population data
	* this was a HUGE BUG
	drop year

	* all merged
	merge 1:n adm1_id using "$temp_path/all_time_use_clean.dta", nogen keep(3)
	*cap drop dow
	*drop adm1_id_old
	save "$temp_path/all_time_use_pop_merged.dta", replace

	*****************************
	****** adjust weight ********
	*****************************
	rsource using "$REPO/gcp-labor/1_preparation/merge/reweight.R", rpath("/usr/bin/R") roptions(`"--vanilla"')
	
	
	use "$temp_path/all_time_use_reweighted.dta", clear

	* generate new weights: population weights separated by high and low risk
	foreach v in risk_prop risk_sum risk_adj_sample_wgt total_risk_share risk_adj_sample_wgt_equal {
		cap drop `v'
	}

	bysort iso high_risk: gen risk_prop = _N 
	by iso: replace risk_prop = risk_prop/_N 
	gen risk_adj_sample_wgt = pop_adj_sample_wgt * risk_prop
	bysort high_risk: egen risk_sum = total(risk_adj_sample_wgt)
	gen total_risk_share = _N 
	bysort high_risk: replace total_risk_share = _N / total_risk_share
	replace risk_adj_sample_wgt = risk_adj_sample_wgt / risk_sum * total_risk_share
	drop total_risk_share risk_prop risk_sum sample_wgt

	// Sample weights by ADM2-by-year
	gegen adm2_year_tot_wgt = total(adm2_adj_sample_wgt), by(adm2_id year)
	gen adm2_year_adj_sample_wgt = adm2_adj_sample_wgt/adm2_year_tot_wgt
	drop adm2_year_tot_wgt

	// Representative unit sample weights - by rep_unit and year
	gen rep_unit = adm1_id
	replace rep_unit = adm0_id if inlist(iso, "USA", "GBR", "FRA")

	gegen rep_unit_tot_wgt = total(risk_adj_sample_wgt), by(rep_unit)
	gen rep_unit_sample_wgt = risk_adj_sample_wgt/rep_unit_tot_wgt
	gegen test_sum = total(rep_unit_sample_wgt), by(rep_unit)

	gegen rep_unit_year_tot_wgt = total(risk_adj_sample_wgt), by(rep_unit year)
	gen rep_unit_year_sample_wgt = risk_adj_sample_wgt/rep_unit_year_tot_wgt
	gegen test_sum_2 = total(rep_unit_year_sample_wgt), by(rep_unit year)

	// test new weights - remove once successfully run!
	count if (round(test_sum) != 1) | (round(test_sum_2) != 1)
	if `r(N)' != 0 {
		di "Whoops, you biffed it! Sample weights don't add to 1."
		}
	else {
		di "Great job, sample weights correctly generated."
		drop rep_unit_tot_wgt rep_unit_year_tot_wgt test_sum test_sum_2
		}

	* redefine clusters so that all the regressions generate standard errors
	egen cluster_adm0yymm = group(iso month year)
	egen cluster_adm1yymm = group(adm1_id month year)

	drop *sum_sample

	save "$temp_path/all_time_use_clustered.dta", replace

	*****************************
	****** filter holidays ********
	*****************************

	* filter out remaining holidays
	rsource using "$REPO/gcp-labor/1_preparation/merge/mark_holidays.R", rpath("/usr/bin/R") roptions(`"--vanilla"')
	* the above file saves to all_time_use_holidays_marked.dta
	
}


* this function merge a whole file of climate variables into the dataset, 
* adding lags to each variable
cap program drop merge_climate_data_file
program define merge_climate_data_file
	args iso filename leadlag n_ll
	di "`iso'"
	
	* set the admin level that the climate data in each country is
	if "`iso'" == "CHN" {
		local adm_level adm3
	}
	if "`iso'" == "FRA" | "`iso'" ==  "GBR" | "`iso'" == "ESP" {
		local adm_level adm1
	}
	if "`iso'" == "USA" | "`iso'" ==  "MEX" | "`iso'" == "IND" | "`iso'" == "BRA" {
		local adm_level adm2
	}

	use "${shares_path}/gcp/estimation/labor/climate_data/final/`iso'/`adm_level'/GMFD_`iso'_`filename'_`adm_level'.dta", clear


	* generate date and dow in climate data for merging
	gen date = mdy(month, day, year)
	gen dow = dow(date)
	* for china, we don't want to include the interview date in the week, so we move the 
	* date of the climate date to one day later

	tsset `adm_level'_id date 
	cap rename *nochn_best* *best*

	quietly{
	* loop through each variable
		foreach v of varlist _all {
			di "`v'"
			if "`v'" == "adm1_id" | "`v'" == "adm2_id" |  "`v'" == "adm3_id" | "`v'" == "date" | "`v'" == "dow" | "`v'" == "year" | "`v'" == "month" | "`v'" == "day" continue
			if "`iso'" == "MEX" | "`iso'" == "BRA" | "`iso'" == "CHN" {
				* for weekly data, sum the climate data in the week before the date
				gen w_`v' = `v'
				forval i = 1/6{
					gen `v'_l`i' = L`i'.`v'
					replace w_`v' = w_`v' + `v'_l`i'
				}
				replace `v' = w_`v' 
				forval i = 1/6{
					gen `v'_v`i' = `v'
				}
				drop w_`v' `v'_l?
			} 
			else {
				* for daily data, scale by sqrt(7) and merge the week including that day
				replace `v' = `v' * sqrt(7)
				forval i = 1/6{
					local j = 7-`i'
					gen `v'_v`i' = F`j'.`v'
					replace `v'_v`i' = L`i'.`v' if dow >=`i'
				}
			}

			* if we want to generate lead/lag weeks
			if "`leadlag'" == "lcl" & `n_ll' > 0{
				forval n_wk = 1/`n_ll' {
					local n_days = `n_wk' * 7
					gen `v'_wkn`n_wk' = L`n_days'.`v'
					gen `v'_wk`n_wk' = F`n_days'.`v'
					* generate the week after and before
					forval i = 1/6{
						gen `v'_wkn`n_wk'_v`i' = L`n_days'.`v'_v`i'
						gen `v'_wk`n_wk'_v`i' = F`n_days'.`v'_v`i'
					}				
				}
			}
		}
	}

	merge 1:n `adm_level'_id date using `iso'_dt, nogen keep(3)
	save `iso'_dt, replace
end


* merge long run climate variables by adm1_id
cap program drop merge_long_run
program define merge_long_run
	args iso 
	di "`iso'"
	if "`iso'" == "USA" | "`iso'" == "GBR" | "`iso'" == "FRA" {
		use "${shares_path}/gcp/estimation/labor/climate_data/final/WORLD/adm0/GMFD_WORLD_long_run_adm0.dta", clear
		rename adm0_id iso
		merge 1:n iso using `iso'_dt, nogen keep(3)
	}
	else {
		use "${shares_path}/gcp/estimation/labor/climate_data/final/`iso'/adm1/GMFD_`iso'_long_run_adm1.dta", clear	
		merge 1:n adm1_id using `iso'_dt, nogen keep(3)
	}
	save `iso'_dt, replace
end


* loop through combinations of macros 
* each combination will result in a data file

foreach t_version in $t_version_list {
	foreach chn_week in $chn_week_list {	
		foreach variables in $variables_list {

			* this is the cleaned and merged time use data file
			* with weights generated, income merged, and holidays labeled
			use "$temp_path/all_time_use_holidays_marked.dta", clear
			cap drop adm1_id_old

			* drop holidays if we want
			if "${drop_holidays}" == "YES" {
				drop if is_holiday == 1		
			}

			cap restore, not

			* drop china observations if include_chn is not set to YES

			if "${include_chn}" == "YES" {
				global countries `countries_all'
			}
			else {
				local chn CHN
				global countries: list countries_all - chn
			}

			di "countries are ${countries}"

			* merge each country with its climate data
			foreach iso in $countries  {
				preserve
				count if iso == "`iso'"
				di "`r(N)' obs for `iso'"
				keep if iso == "`iso'"

				* depending on which week we want to merge the china climate data
				* we do it by shifting the time use data dates to 
				* the last day of the week that we want the climate data
				if "`iso'" == "CHN" {
					gen dow = dow(date)
					replace dow = 7 if dow == 0
					if "`chn_week'" == "chn_prev7days" {
						replace date = date - 1
					}
					if "`chn_week'" == "chn_prev_week" {
						replace date = date - dow
					}
					if "`chn_week'" == "chn_next_week" {
						replace date = date - dow + 7
					}
					drop dow
				}
				cd
				save `iso'_dt, replace

				* merge in the climate data files
				merge_climate_data_file `iso' `t_version'_`variables' ${leadlag} ${n_ll}
				if "`variables'" == "bins" {
					merge_climate_data_file `iso' `t_version'_polynomials ${leadlag} ${n_ll}
					drop `t_version'_p1_v* `t_version'_p2* `t_version'_p3* `t_version'_p4* 
				}
				* merge precip
				merge_climate_data_file `iso' prcp ${leadlag} ${n_ll}
				* merge long run climate
				merge_long_run `iso'

				restore
			}

			* 3 observations in IND not merged (impossible date in time use data, 1999/2/31, 1999/2/29 x 2)
			* lose china and uk observations outside of climate data range (1980 - 2010)

			drop if _n >= 0
			* put together the countries
			foreach iso in $countries {
				di "`iso'"
				append using `iso'_dt.dta
				erase `iso'_dt.dta
			}

			* generate the actual human readable temperature
			if "`variables'" == "splines" {
				gen real_temperature = `t_version'_rcspl_3kn_t0/(7^0.5) if !inlist(iso, "BRA","CHN","MEX")
				replace real_temperature = `t_version'_rcspl_3kn_t0/7 if inlist(iso, "BRA","CHN","MEX")
			}
			if "`variables'" == "splines_27_37_39" {
				gen real_temperature = `t_version'_rcspl_3kn_27_37_39_t0/(7^0.5) if !inlist(iso, "BRA","CHN","MEX")
				replace real_temperature = `t_version'_rcspl_3kn_27_37_39_t0/7 if inlist(iso, "BRA","CHN","MEX")
			}
			else if "`variables'" == "polynomials" | "`variables'" == "bins" {
				gen real_temperature = `t_version'_p1/(7^0.5) if !inlist(iso, "BRA","CHN","MEX")
				replace real_temperature = `t_version'_p1/7 if inlist(iso, "BRA","CHN","MEX")
			}
			
			* generate week of year fixed effect using stata's built in function
			gen week_fe = date
			replace week_fe = week(week_fe)
			
			save "$final_path/labor_dataset_`variables'_`t_version'_`chn_week'_${leadlag}_${n_ll}.dta", replace
		}
	}
}


cap log close
