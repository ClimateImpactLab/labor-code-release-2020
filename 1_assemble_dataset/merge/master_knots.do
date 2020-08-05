* liruixue@uchicago.edu


set more off
set trace off

clear all
cap ssc install rsource


if "`c(hostname)'" == "battuta" {
	global shares_path "/mnt/sacagawea_shares"
}
else global shares_path "/shares"


global temp_path ${shares_path}/gcp/estimation/labor/time_use_data/intermediate
global final_path ${shares_path}/gcp/estimation/labor/time_use_data/final


*the following globals need to be modified according to data generation needs
global t_version_list tmax

*global chn_week_list chn_prev7days chn_prev_week
global chn_week_list chn_prev_week 
*chn_prev_week chn_prev7days

global variables_list splines
* if we want to generate fake spline terms, set to yes, and set variable to polynomials
global gen_spline_terms "yes"

* set which parts of the code we want to run and how many lead/lag weeks we want
global drop_holidays "YES"
global clean_raw_surveys "NO"
global combine_surveys "NO"
global include_chn "YES" 
global leadlag "lcl"
global n_ll 1

local countries_all CHN USA MEX BRA GBR FRA ESP IND 

* define different versions of knots that we want to generate using polynomial terms
global knots0 = "21 37 41"
global knots1 = "-5 20 40"
global knots2 = "5 25 40"
global knots3 = "16.6 30.3 36.6"
global knots4 = "10 20 40"
global knots5 = "15 25 40"
global knots6 = "25 30 35"

global knots7 =  "20 30 40"
global knots8 =  "21 30 39"
global knots9 =  "22 30 38"
global knots10 =  "23 30 37"
global knots11 =  "24 30 36"
global knots12 =  "26 30 34"
global knots13 =  "27 30 33"
global knots14 =  "28 30 32"
global knots15 =  "29 30 31"
global knots16 =  "25 35 40"

loc low_min = 15
loc low_max = 27
loc low_step = 2
loc mid_min = 25
loc mid_max = 37
loc mid_step = 1
loc high_min = 35
loc high_max = 42
loc high_step = 2

loc count = 16

forval i = `low_min'(`low_step')`low_max'{
	di "`i'"
	forval j = `mid_min'(`mid_step')`mid_max' {
		if(`j' <= `i'){
			di "skipping"
		}
		else{
			forval k = `high_min'(`high_step')`high_max'{
				if(`k' <= `j'){
					di "skipping"
				}
				else{
					loc count = `count' + 1
					global knots`count' "`i' `j' `k'"
				}
			}
		}
	}
}


* count goes up to 336
loc knots_ver_start = 1
loc knots_ver_end  = 336



if "${clean_raw_surveys}" == "YES"{
	* clean surveys of individual countries
	shell python "$REPO/gcp-labor/replication/1_preparation/time_use/CHNS/chns_data_cleaning.py"
	rsource using "$REPO/gcp-labor/replication/1_preparation/time_use/ATUS/replicate_atus.R", rpath("/usr/bin/R") roptions(`"--vanilla"')
	rsource using "$REPO/gcp-labor/replication/1_preparation/time_use/ENOE/replicate_enoe.R", rpath("/usr/bin/R") roptions(`"--vanilla"')
	rsource using "$REPO/gcp-labor/replication/1_preparation/time_use/MTUS/replicate_mtus.R", rpath("/usr/bin/R") roptions(`"--vanilla"')
	rsource using "$REPO/gcp-labor/replication/1_preparation/time_use/ITUS/replicate_itus.R", rpath("/usr/bin/R") roptions(`"--vanilla"')
	do "$REPO/gcp-labor/replication/1_preparation/time_use/PME/clean_pme.do"
}

if "${combine_surveys}" == "YES"{
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

	import delimited using "$DB/Global ACP/labor/replication/1_preparation/covariates/income/income_downscaled.csv", clear
	keep year iso adm1_id adm0_pop gdppc_adm1_pwt_downscaled
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
	drop total_risk_share risk_prop risk_sum sample_wgt adj_sample_wgt


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
	* the above file saves to all_time_use_holidays_removed.dta
}

*
* merge a whole file of climate variables into the dataset, adding lags to each variable
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

	* generate spline terms with the polynomial file
	if "${gen_spline_terms}" == "yes" & "`filename'" == "tmax_polynomials" {

		local knots ${current_knots}
		di "generating spline terms for knots `knots'"

		local knot1 : word 1 of `knots'
		local knot2 : word 2 of `knots'
		local knot3 : word 3 of `knots'

		gen tmax_rcspl_3kn_t0 = tmax_p1

		gen tmax_rcspl_3kn_t1 = .
		replace tmax_rcspl_3kn_t1 = 0 if tmax_p1 < (`knot1')
		replace tmax_rcspl_3kn_t1 = (tmax_p3 - 3*(`knot1')*tmax_p2 + 3*(`knot1')^2*tmax_p1 - (`knot1')^3) if tmax_p1 >= (`knot1')  
		replace tmax_rcspl_3kn_t1 = (tmax_p3 - 3*(`knot1')*tmax_p2 + 3*(`knot1')^2*tmax_p1 - (`knot1')^3) - (tmax_p3 - 3*(`knot2')*tmax_p2 + 3*(`knot2')^2*tmax_p1 - (`knot2')^3)* (((`knot3')-(`knot1')) / ((`knot3')-(`knot2'))) if tmax_p1 >= (`knot2')
		replace tmax_rcspl_3kn_t1 = (tmax_p3 - 3*(`knot1')*tmax_p2 + 3*(`knot1')^2*tmax_p1 - (`knot1')^3) - (tmax_p3 - 3*(`knot2')*tmax_p2 + 3*(`knot2')^2*tmax_p1 - (`knot2')^3) * (((`knot3')-(`knot1')) / ((`knot3')-(`knot2'))) + (tmax_p3 - 3*(`knot3')*tmax_p2 + 3*(`knot3')^2*tmax_p1 - (`knot3')^3) * (((`knot2')-(`knot1')) / ((`knot3')-(`knot2')))  if tmax_p1 >= (`knot3') 
		global spline_filename splines_`knot1'_`knot2'_`knot3'
	}

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

	merge 1:n `adm_level'_id date using `iso'_dt${knots_suffix}, nogen keep(3)
	save `iso'_dt${knots_suffix}, replace
end


* merge long run climate variables by adm1_id
cap program drop merge_long_run
program define merge_long_run
	args iso 
	di "`iso'"
	use "${shares_path}/gcp/estimation/labor/climate_data/final/`iso'/adm1/GMFD_`iso'_long_run_adm1.dta", clear	
	merge 1:n adm1_id using `iso'_dt${knots_suffix}, nogen keep(3)
	save `iso'_dt${knots_suffix}, replace
end


* loop through combinations of macros 
* each combination will result in a data file

forval knots_ver = `knots_ver_start'/`knots_ver_end' {
	global knots_suffix = `knots_ver'
	global current_knots ${knots`knots_ver'}

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

				* drop china observations if needed

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

					save `iso'_dt${knots_suffix}, replace

					* merge in the climate data files
					merge_climate_data_file `iso' `t_version'_`variables' ${leadlag} ${n_ll}
					if "`variables'" == "bins" {
						merge_climate_data_file `iso' `t_version'_polynomials ${leadlag} ${n_ll}
						drop `t_version'_p1_v* `t_version'_p2* `t_version'_p3* `t_version'_p4* 
					}
					* merge precip
					merge_climate_data_file `iso' prcp ${leadlag} ${n_ll}
					* merge long run climate
					if "${gen_spline_terms}" != "yes" {
						merge_long_run `iso'
					}

					restore
				}

				* 3 observations in IND not merged (impossible date in time use data, 1999/2/31, 1999/2/29 x 2)
				* lose china and uk observations outside of climate data range (1980 - 2010)

				drop if _n >= 0
				* put together the countries
				foreach iso in $countries {
					di "`iso'"
					append using `iso'_dt${knots_suffix}.dta
					erase `iso'_dt${knots_suffix}.dta
				}

				* generate the actual human readable temperature
				if "`variables'" == "splines" {
					gen real_temperature = `t_version'_rcspl_3kn_t0/(7^0.5) if !inlist(iso, "BRA","CHN","MEX")
					replace real_temperature = `t_version'_rcspl_3kn_t0/7 if inlist(iso, "BRA","CHN","MEX")
				}
				else if "`variables'" == "polynomials" | "`variables'" == "bins" {
					gen real_temperature = `t_version'_p1/(7^0.5) if !inlist(iso, "BRA","CHN","MEX")
					replace real_temperature = `t_version'_p1/7 if inlist(iso, "BRA","CHN","MEX")
					
				}
				
				* generate week of year fixed effect using stata's built in function
				gen week_fe = date
				replace week_fe = week(week_fe)

				* name separately if we're constructing spline terms
				if "${gen_spline_terms}" == "yes" {
					drop tmax_p*
					save "$final_path/labor_dataset_${spline_filename}_`t_version'_`chn_week'_${leadlag}_${n_ll}.dta", replace
				}
				else save "$final_path/labor_dataset_`variables'_`t_version'_`chn_week'_${leadlag}_${n_ll}.dta", replace
			}
		}
	}
}

