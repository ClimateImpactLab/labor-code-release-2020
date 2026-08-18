*-------------------------------------------------------------------------------
* master.do
*-------------------------------------------------------------------------------
* PURPOSE
*   Build the main regression-ready labor dataset from the cleaned time-use surveys
*
* STEPS
*   1. Optionally clean the raw country survey files
*   2. Optionally combine surveys, merge income and population, rebuild weights,
*      and mark/drop holidays
*   3. Merge temperature, precipitation, and long-run climate variables by country
*   4. Append country files and save the final regression dataset
*
* MAIN OUTPUT
*   Regression-ready labor dataset saved in regression_ready_data
*
* Original author: liruixue@uchicago.edu
*-------------------------------------------------------------------------------

clear all

do "/project/cil/home_dirs/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"

set more off
set trace off

cap ssc install rsource

global temp_path ${ROOT_INT_DATA}/temp
global final_path ${ROOT_INT_DATA}/regression_ready_data

*-------------------------------------------------------------------------------
* Run switches
*-------------------------------------------------------------------------------

* Climate temperature variable: tmax or tavg
global t_version_list tmax

* Old timing option: can be ignored since China no longer in sample
global chn_week_list chn_prev_week

* Climate variable family merged into the final dataset
global variables_list splines_nochn

* Survey build steps
global drop_holidays "YES"
global clean_raw_surveys "NO"
global combine_surveys "NO"
global include_chn "NO" 

* Lead/lag setup: no_ll for no lead/lag weeks, lcl to add them
global leadlag "no_ll"
global n_ll 0

local countries_all CHN USA MEX BRA GBR FRA ESP IND 

*-----------------------------------
* Optional raw survey cleaning
*-----------------------------------

if "${clean_raw_surveys}" == "YES"{
	* Clean each country survey before combining
	shell python "$DIR_REPO_LABOR/time_use/surveys/clean_CHN_chns.py"
	rsource using "$DIR_REPO_LABOR/time_use/surveys/clean_WEU_mtus.R", rpath("/usr/bin/R") roptions(`"--vanilla"')
	rsource using "$DIR_REPO_LABOR/time_use/surveys/clean_IND_itus.R", rpath("/usr/bin/R") roptions(`"--vanilla"')
	rsource using "$DIR_REPO_LABOR/time_use/surveys/clean_MEX_enoe.py", rpath("/usr/bin/R") roptions(`"--vanilla"')
	rsource using "$DIR_REPO_LABOR/time_use/surveys/clean_USA_atus.py", rpath("/usr/bin/R") roptions(`"--vanilla"')
	do "$DIR_REPO_LABOR/time_use/surveys/clean_BRA_pme.do"
}

*-------------------------------------------------
* Optional survey combine, weights, and holidays
*-------------------------------------------------

if "${combine_surveys}" == "YES" {

	* Running crosswalk and survey-combine python scripts if needed
	* shell python "$DIR_REPO_LABOR/time_use/surveys/generate_crosswalks.py"
	* shell python "$DIR_REPO_LABOR/time_use/merge/combine_surveys.py"
	import delimited using "$temp_path/all_time_use.csv", clear

	count

	* Drop early UK years with data quality issues
	drop if year == 1974 | year == 1975

	* Build date variables from the survey date fields
	* For weekly surveys, date is the end of the surveyed week
	gen date = mdy(month, day, year)
	gen age2 = age^2

	* Use 8 for weekly surveys, daily surveys keep day of week
	gen dow_week = dow(date)
	replace dow_week = 8 if inlist(iso, "CHN","BRA","MEX")

	* Scale daily survey variables to weekly units
	replace mins_worked = mins_worked * sqrt(7) if !inlist(iso, "CHN","BRA","MEX")
	foreach v of varlist age age2 hhsize male {
		di "`v'"
		replace `v' = `v' / sqrt(7) if !inlist(iso, "CHN","BRA","MEX")
	}

	drop if missing(hhsize)
	drop if missing(date)

	save "$temp_path/all_time_use_clean.dta", replace

	*---------------------------------
	* Merge income and population
	*---------------------------------
	
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

	* Drop year before merging so Stata does not keep the income-file year
	* in place of the survey year
	drop year

	* Merge income/population to survey rows
	merge 1:n adm1_id using "$temp_path/all_time_use_clean.dta", nogen keep(3)
	*cap drop dow
	*drop adm1_id_old
	save "$temp_path/all_time_use_pop_merged.dta", replace

	*---------------------
	* Rebuild weights
	*---------------------
	
	* Use R/4.2.1 for reweight.R
	rsource using "$DIR_REPO_LABOR/1_assemble_dataset/time_use/merge/reweight.R", rpath("/software/R-4.2.1-el8-x86_64/bin/R") roptions(`"--vanilla"')
	
	use "$temp_path/all_time_use_pop_merged_reweighted.dta", clear

	* Drop old generated weights before rebuilding them
	foreach v in risk_prop risk_sum risk_adj_sample_wgt total_risk_share risk_adj_sample_wgt_equal ///
		risk_adj_sample_wgt_sector2 rep_unit_sample_wgt_sector2 rep_unit_year_sample_wgt_sector2 {
		cap drop `v'
	}
	
	capture program drop create_risk_weights
	program define create_risk_weights
	
		syntax varname, base_weight(varname) [suffix(string)]
    
		* Grouping variable used for the reweighting
		local group_var `varlist'
    
		* Default suffix is empty
		if "`suffix'" == "" {
			local suffix ""
		}
    
		* Group shares within country
		bysort iso `group_var': gen `group_var'_prop = _N if !missing(`group_var')
		by iso: replace `group_var'_prop = `group_var'_prop/_N if !missing(`group_var')
    
		* Reweight so group totals match their sample shares
		gen risk_adj_sample_wgt`suffix' = `base_weight' * `group_var'_prop if !missing(`group_var')
		bysort `group_var': egen `group_var'_sum = total(risk_adj_sample_wgt`suffix') if !missing(`group_var')
		gen total_`group_var'_share = _N if !missing(`group_var')
		bysort `group_var': replace total_`group_var'_share = _N / total_`group_var'_share if !missing(`group_var')
		replace risk_adj_sample_wgt`suffix' = risk_adj_sample_wgt`suffix' / `group_var'_sum * total_`group_var'_share if !missing(`group_var')
    
		* Clean up temporary variables
		drop total_`group_var'_share `group_var'_prop `group_var'_sum
    
		* Representative-unit weights
		gegen rep_unit_tot_wgt`suffix' = total(risk_adj_sample_wgt`suffix') if !missing(`group_var'), by(rep_unit)
		gen rep_unit_sample_wgt`suffix' = risk_adj_sample_wgt`suffix'/rep_unit_tot_wgt`suffix' if !missing(`group_var')
		gegen test_sum`suffix' = total(rep_unit_sample_wgt`suffix') if !missing(`group_var'), by(rep_unit)
    
		* Representative-unit-year weights
		gegen rep_unit_year_tot_wgt`suffix' = total(risk_adj_sample_wgt`suffix') if !missing(`group_var'), by(rep_unit year)
		gen rep_unit_year_sample_wgt`suffix' = risk_adj_sample_wgt`suffix'/rep_unit_year_tot_wgt`suffix' if !missing(`group_var')
		gegen test_sum_2`suffix' = total(rep_unit_year_sample_wgt`suffix') if !missing(`group_var'), by(rep_unit year)
    
		* Check that representative-unit weights add up
		count if !missing(`group_var') & ((round(test_sum`suffix') != 1) | (round(test_sum_2`suffix') != 1))
		if `r(N)' != 0 {
			di as error "Whoops, you biffed it! Sample weights for `group_var' don't add to 1."
		}
		else {
			di as result "Great job, sample weights for `group_var' correctly generated."
			drop rep_unit_tot_wgt`suffix' rep_unit_year_tot_wgt`suffix' test_sum`suffix' test_sum_2`suffix'
		}
    
	end

	* Representative unit used for weights
	gen rep_unit = adm1_id
	replace rep_unit = adm0_id if inlist(iso, "USA", "GBR", "FRA")

	* Build weights for the main risk and sector variables
	* Occupation-code weights are built later in the regression scripts
	create_risk_weights high_risk, base_weight(pop_adj_sample_wgt)
	create_risk_weights high_risk_old, base_weight(pop_adj_sample_wgt) suffix(_old)
	create_risk_weights sector, base_weight(pop_adj_sample_wgt) suffix(_sector)
	create_risk_weights sector2, base_weight(pop_adj_sample_wgt) suffix(_sector2)

	* Monthly country and adm1 clusters
	egen cluster_adm0yymm = group(iso month year)
	egen cluster_adm1yymm = group(adm1_id month year)

	drop *sum_sample

	save "$temp_path/all_time_use_pop_merged_reweighted_clustered.dta", replace

	*--------------------------
	* Mark and drop holidays
	*--------------------------

	* Mark holidays in R, then drop them if requested
	rsource using "$DIR_REPO_LABOR/1_assemble_dataset/time_use/merge/mark_holidays.R", rpath("/software/R-4.2.1-el8-x86_64/bin/R") roptions(`"--vanilla"')
	use "$temp_path/all_time_use_pop_merged_reweighted_clustered_holidays_marked.dta", clear
	
	* Drop marked holidays if requested
	if "${drop_holidays}" == "YES" {
		drop if is_holiday == 1		
	}
	save "$temp_path/all_time_use_pop_merged_reweighted_clustered_holidays_dropped.dta", replace
	
}


*-------------------------------------------------------------------------
* Helper: merge daily climate variables and create weekly exposure terms
*-------------------------------------------------------------------------

cap program drop merge_climate_data_file
program define merge_climate_data_file
	args iso filename leadlag n_ll
	di "`iso'"
	
	* Climate admin level by country
	if "`iso'" == "CHN" {
		local adm_level adm3
	}
	if "`iso'" == "FRA" | "`iso'" ==  "GBR" | "`iso'" == "ESP" {
		local adm_level adm1
	}
	if "`iso'" == "USA" | "`iso'" ==  "MEX" | "`iso'" == "IND" | "`iso'" == "BRA" {
		local adm_level adm2
	}

	use "${ROOT_INT_DATA}/climate/final_27_28_41/`iso'/`adm_level'/GMFD_`iso'_`filename'_`adm_level'.dta", clear
	* Rename term0 to t0 when needed
	cap ds *term0*
	if !_rc {
	    foreach x of varlist `r(varlist)' {
		local new = subinstr("`x'", "term0", "t0", .)
		cap rename `x' `new'
	    }
	}

	* Rename term1 to t1 when needed
	cap ds *term1*
	if !_rc {
	    foreach x of varlist `r(varlist)' {
		local new = subinstr("`x'", "term1", "t1", .)
		cap rename `x' `new'
	    }
	}

	* Rename rcspline to rcspl when needed
	cap ds *rcspline*
	if !_rc {
	    foreach x of varlist `r(varlist)' {
		local new = subinstr("`x'", "rcspline", "rcspl", .)
		cap rename `x' `new'
	    }
	}

	* Date variables used for merging and weekly exposure timing
	gen date = mdy(month, day, year)
	gen dow = dow(date)

	tsset `adm_level'_id date 
	cap rename *nochn_best* *best*

	quietly{
	* Build current-week and lag terms for each climate variable
		foreach v of varlist _all {
			di "`v'"
			if "`v'" == "adm1_id" | "`v'" == "adm2_id" |  "`v'" == "adm3_id" | "`v'" == "date" | "`v'" == "dow" | "`v'" == "year" | "`v'" == "month" | "`v'" == "day" continue
			if "`iso'" == "MEX" | "`iso'" == "BRA" | "`iso'" == "CHN" {
				* Weekly surveys use the current day plus six lags
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
				* Daily surveys use weekday-specific leads/lags and sqrt(7) scaling
				replace `v' = `v' * sqrt(7)
				forval i = 1/6{
					local j = 7-`i'
					gen `v'_v`i' = F`j'.`v'
					replace `v'_v`i' = L`i'.`v' if dow >=`i'
				}
			}

			* Optional lead/lag weeks
			if "`leadlag'" == "lcl" & `n_ll' > 0{
				forval n_wk = 1/`n_ll' {
					local n_days = `n_wk' * 7
					gen `v'_wkn`n_wk' = L`n_days'.`v'
					gen `v'_wk`n_wk' = F`n_days'.`v'
					* Shift the six lag terms by whole weeks
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


*-------------------------------------------------------------------------------
* Helper: merge long-run temperature
*-------------------------------------------------------------------------------

cap program drop merge_long_run
program define merge_long_run
	args iso 
	di "`iso'"

	if "`iso'" == "USA" | "`iso'" == "GBR" | "`iso'" == "FRA" {
		use "${ROOT_INT_DATA}/climate/final_27_28_41/WORLD/adm0/GMFD_WORLD_long_run_adm0.dta", clear
		rename ISO iso
		merge 1:n iso using `iso'_dt, nogen keep(3)
	}
	else {
		use "${ROOT_INT_DATA}/climate/final_27_28_41/`iso'/adm1/GMFD_`iso'_long_run_adm1.dta", clear	
		merge 1:n adm1_id using `iso'_dt, nogen keep(3)
	}
	save `iso'_dt, replace
end


*-------------------------------------------------------------------------------
* Main climate merge and final save
*-------------------------------------------------------------------------------

foreach t_version in $t_version_list {
	foreach chn_week in $chn_week_list {	
		foreach variables in $variables_list {

			* Start from the time-use sample with weights, income, clusters, and holidays handled
			use "$temp_path/all_time_use_pop_merged_reweighted_clustered_holidays_dropped.dta", clear
			cap drop adm1_id_old

			cap restore, not

			if "${include_chn}" == "YES" {
				global countries `countries_all'
			}
			else {
				local chn CHN
				global countries: list countries_all - chn
			}

			di "countries are ${countries}"

			* Build one country file at a time
			foreach iso in $countries  {
				preserve
				count if iso == "`iso'"
				di "`r(N)' obs for `iso'"
				keep if iso == "`iso'"

				* Date shift used only if China is included
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

				* Merge the selected temperature variables
				if strpos("`variables'","polynomials") > 0 {
					merge_climate_data_file `iso' `t_version'_polynomials ${leadlag} ${n_ll}
				}
				else if strpos("`variables'","bins") > 0 {
					merge_climate_data_file `iso' `t_version'_bins ${leadlag} ${n_ll}
				}
				else {
					merge_climate_data_file `iso' `t_version'_`variables' ${leadlag} ${n_ll}
				}
				* Merge precipitation
				merge_climate_data_file `iso' prcp ${leadlag} ${n_ll}
				* Merge long-run temperature
				merge_long_run `iso'

				restore
			}

			* Empty the master frame, then append the country files
			drop if _n >= 0
			foreach iso in $countries {
				di "`iso'"
				append using `iso'_dt.dta
				erase `iso'_dt.dta
			}
			cap rename *27_28_41*3kn* *3kn*27_28_41*
			* Keep the original daily temperature in an easier-to-read variable
			if "`variables'" == "splines_nochn" {
				gen real_temperature = `t_version'_rcspl_3kn_27_28_41_t0/(7^0.5) if !inlist(iso, "BRA","CHN","MEX")
				replace real_temperature = `t_version'_rcspl_3kn_27_28_41_t0/7 if inlist(iso, "BRA","CHN","MEX")
			}
			else if (strpos("`variables'", "polynomials") > 0) {
				gen real_temperature = `t_version'_p1/(7^0.5) if !inlist(iso, "BRA","CHN","MEX")
				replace real_temperature = `t_version'_p1/7 if inlist(iso, "BRA","CHN","MEX")
			}
			
			* Week-of-year fixed effect
			gen week_fe = date
			replace week_fe = week(week_fe)
			* Drop two duplicate survey rows that survive earlier cleaning
			drop if (iso == "MEX" & ind_id == 361587 & year == 2007 & month == 7 & day == 1)
			drop if (iso == "GBR" & ind_id == 22798  & year == 2001 & month == 2 & day == 14)

			save "$final_path/labor_dataset_`variables'_`t_version'_`chn_week'_${leadlag}_${n_ll}_agnonag_272841_0814.dta", replace
		}
	}
}


cap log close
