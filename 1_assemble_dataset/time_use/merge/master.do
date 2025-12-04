* liruixue@uchicago.edu
clear all

do "/project/cil/home_dirs/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"

set more off
set trace off

cap ssc install rsource

global temp_path ${ROOT_INT_DATA}/temp
global final_path ${ROOT_INT_DATA}/regression_ready_data

******* parameters that need to be modified *******
* possible values: tmax, tavg
global t_version_list tmax

* possible values: chn_week_list chn_prev7days chn_prev_week
global chn_week_list chn_prev_week

* possible values: splines_wchn, splines_nochn, polynomials_wchn, polynomials_nochn, bins_nochn, bins_wchn
global variables_list splines_nochn

* set which parts of the code we want to run and how many lead/lag weeks we want
* possible values: YES or NO
global drop_holidays "YES"
global clean_raw_surveys "NO"
global combine_surveys "YES"
global include_chn "NO" 

* set the following global to lcl or no_ll
global leadlag "no_ll"
* number of weeks we want for the lead/lag weeks
* global n_ll 1 * for 1 week of lead and lag
global n_ll 0

******* parameters that need to be modified *******

* no need to modify this string, we drop china in later part of the code
local countries_all CHN USA MEX BRA GBR FRA ESP IND 

if "${clean_raw_surveys}" == "YES"{
	* clean surveys of individual countries 
	shell python "$DIR_REPO_LABOR/time_use/surveys/clean_CHN_chns.py"
	rsource using "$DIR_REPO_LABOR/time_use/surveys/clean_WEU_mtus.R", rpath("/usr/bin/R") roptions(`"--vanilla"')
	rsource using "$DIR_REPO_LABOR/time_use/surveys/clean_IND_itus.R", rpath("/usr/bin/R") roptions(`"--vanilla"')
	rsource using "$DIR_REPO_LABOR/time_use/surveys/clean_MEX_enoe.py", rpath("/usr/bin/R") roptions(`"--vanilla"')
	rsource using "$DIR_REPO_LABOR/time_use/surveys/clean_USA_atus.py", rpath("/usr/bin/R") roptions(`"--vanilla"')
	do "$DIR_REPO_LABOR/time_use/surveys/clean_BRA_pme.do"
}

if "${combine_surveys}" == "YES" {

	* generate crosswalk and convert the location names in the survey data to admin ids
	* shell python "$DIR_REPO_LABOR/time_use/surveys/generate_crosswalks.py"
	* combine the surveys into all_time_use.csv
	*shell python "$DIR_REPO_LABOR/time_use/merge/combine_surveys.py"
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
	* do  "$/1_preparation/income/map_names.do"
	* TO-DO: test the follow line
	* rsource using "$REPO/gcp-labor/replication/1_preparation/income/Downscale.R", rpath("/usr/bin/R") roptions(`"--vanilla"')

	
	*di "$DB/Global ACP/labor/replication/1_preparation/covariates/income/income_downscaled.csv"
	import delimited using "${DIR_EXT_DATA}/misc/income_downscaled.csv", clear
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
	
	* Important here that you use R/4.2.1 (`module load R/4.2.1`)
	
	rsource using "$DIR_REPO_LABOR/1_assemble_dataset/time_use/merge/reweight.R", rpath("/software/R-4.2.1-el8-x86_64/bin/R") roptions(`"--vanilla"')
	
	use "$temp_path/all_time_use_pop_merged_reweighted.dta", clear

	* generate new weights: population weights separated by high and low risk
	foreach v in risk_prop risk_sum risk_adj_sample_wgt total_risk_share risk_adj_sample_wgt_equal {
		cap drop `v'
	}
	
	capture program drop create_risk_weights
	program define create_risk_weights
	
		syntax varname, base_weight(varname) [suffix(string)]
    
		* Store the grouping variable name
		local group_var `varlist'
    
		* Set default suffix to empty if not provided
		if "`suffix'" == "" {
			local suffix ""
		}
    
		* Calculate proportions within iso
		bysort iso `group_var': gen `group_var'_prop = _N 
		by iso: replace `group_var'_prop = `group_var'_prop/_N 
    
		* Adjust weights by proportion
		gen risk_adj_sample_wgt`suffix' = `base_weight' * `group_var'_prop
		bysort `group_var': egen `group_var'_sum = total(risk_adj_sample_wgt`suffix')
		gen total_`group_var'_share = _N 
		bysort `group_var': replace total_`group_var'_share = _N / total_`group_var'_share
		replace risk_adj_sample_wgt`suffix' = risk_adj_sample_wgt`suffix' / `group_var'_sum * total_`group_var'_share
    
		* clean up
		drop total_`group_var'_share `group_var'_prop `group_var'_sum
    
		* Representative unit sample weights - by rep_unit
		gegen rep_unit_tot_wgt`suffix' = total(risk_adj_sample_wgt`suffix'), by(rep_unit)
		gen rep_unit_sample_wgt`suffix' = risk_adj_sample_wgt`suffix'/rep_unit_tot_wgt`suffix'
		gegen test_sum`suffix' = total(rep_unit_sample_wgt`suffix'), by(rep_unit)
    
		* Representative unit sample weights - by rep_unit and year
		gegen rep_unit_year_tot_wgt`suffix' = total(risk_adj_sample_wgt`suffix'), by(rep_unit year)
		gen rep_unit_year_sample_wgt`suffix' = risk_adj_sample_wgt`suffix'/rep_unit_year_tot_wgt`suffix'
		gegen test_sum_2`suffix' = total(rep_unit_year_sample_wgt`suffix'), by(rep_unit year)
    
		* Test weights
		count if (round(test_sum`suffix') != 1) | (round(test_sum_2`suffix') != 1)
		if `r(N)' != 0 {
			di as error "Whoops, you biffed it! Sample weights for `group_var' don't add to 1."
		}
		else {
			di as result "Great job, sample weights for `group_var' correctly generated."
			drop rep_unit_tot_wgt`suffix' rep_unit_year_tot_wgt`suffix' test_sum`suffix' test_sum_2`suffix'
		}
    
	end

	* Create rep_unit variable (only needs to be done once)
	gen rep_unit = adm1_id
	replace rep_unit = adm0_id if inlist(iso, "USA", "GBR", "FRA")

	* run function to create weights for each of the three variables. Occupations code weights to
	* be made in regression script for flexibility
	create_risk_weights high_risk, base_weight(pop_adj_sample_wgt)
	create_risk_weights high_risk_old, base_weight(pop_adj_sample_wgt) suffix(_old)
	create_risk_weights sector, base_weight(pop_adj_sample_wgt) suffix(_sector)

	* redefine clusters so that all the regressions generate standard errors
	egen cluster_adm0yymm = group(iso month year)
	egen cluster_adm1yymm = group(adm1_id month year)

	drop *sum_sample

	save "$temp_path/all_time_use_pop_merged_reweighted_clustered.dta", replace


	*****************************
	****** filter holidays ********
	*****************************

	* filter out remaining holidays
	rsource using "$DIR_REPO_LABOR/1_assemble_dataset/time_use/merge/mark_holidays.R", rpath("/software/R-4.2.1-el8-x86_64/bin/R") roptions(`"--vanilla"')
	use "$temp_path/all_time_use_pop_merged_reweighted_clustered_holidays_marked.dta", clear
	
	* drop holidays if we want
	if "${drop_holidays}" == "YES" {
		drop if is_holiday == 1		
	}
	save "$temp_path/all_time_use_pop_merged_reweighted_clustered_holidays_dropped.dta", replace
	
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

	use "${ROOT_INT_DATA}/climate/final/`iso'/`adm_level'/GMFD_`iso'_`filename'_`adm_level'.dta", clear

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
		use "${ROOT_INT_DATA}/climate/final/WORLD/adm0/GMFD_WORLD_long_run_adm0.dta", clear
		rename ISO iso
		merge 1:n iso using `iso'_dt, nogen keep(3)
	}
	else {
		use "${ROOT_INT_DATA}/climate/final/`iso'/adm1/GMFD_`iso'_long_run_adm1.dta", clear	
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
			use "$temp_path/all_time_use_pop_merged_reweighted_clustered_holidays_dropped.dta", clear
			cap drop adm1_id_old

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
				if strpos("`variables'","polynomials") > 0 {
					merge_climate_data_file `iso' `t_version'_polynomials ${leadlag} ${n_ll}
				}
				else if strpos("`variables'","bins") > 0 {
					merge_climate_data_file `iso' `t_version'_bins ${leadlag} ${n_ll}
				}
				else {
					merge_climate_data_file `iso' `t_version'_`variables' ${leadlag} ${n_ll}
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
			cap rename *27_37_39*3kn* *3kn*27_37_39*
			cap rename *21_37_41*3kn* *3kn*21_37_41*
			* generate the actual human readable temperature
			if "`variables'" == "splines" {
				gen real_temperature = `t_version'_rcspl_3kn_t0/(7^0.5) if !inlist(iso, "BRA","CHN","MEX")
				replace real_temperature = `t_version'_rcspl_3kn_t0/7 if inlist(iso, "BRA","CHN","MEX")
			}
			if "`variables'" == "splines_nochn" {
				gen real_temperature = `t_version'_rcspl_3kn_27_37_39_t0/(7^0.5) if !inlist(iso, "BRA","CHN","MEX")
				replace real_temperature = `t_version'_rcspl_3kn_27_37_39_t0/7 if inlist(iso, "BRA","CHN","MEX")
			}
			if "`variables'" == "splines_wchn" {
				gen real_temperature = `t_version'_rcspl_3kn_21_37_41_t0/(7^0.5) if !inlist(iso, "BRA","CHN","MEX")
				replace real_temperature = `t_version'_rcspl_3kn_21_37_41_t0/7 if inlist(iso, "BRA","CHN","MEX")
			}
			else if (strpos("`variables'", "polynomials") > 0) {
				gen real_temperature = `t_version'_p1/(7^0.5) if !inlist(iso, "BRA","CHN","MEX")
				replace real_temperature = `t_version'_p1/7 if inlist(iso, "BRA","CHN","MEX")
			}
			
			* generate week of year fixed effect using stata's built in function
			gen week_fe = date
			replace week_fe = week(week_fe)
			
			* drop straggler duplicates 
			drop if (iso == "MEX" & ind_id == 361587 & year == 2007 & month == 7 & day == 1)
			drop if (iso == "GBR" & ind_id == 22798  & year == 2001 & month == 2 & day == 14)
			
			save "$final_path/labor_dataset_`variables'_`t_version'_`chn_week'_${leadlag}_${n_ll}.dta", replace
		}
	}
}


cap log close
