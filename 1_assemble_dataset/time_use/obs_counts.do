*****************************
*	COUNTING OBSERVATIONS	*
* 	RA: Kit Schwarz			*
*	csschwarz@uchicago.edu	*
*****************************

/***************************************************************************************************
	This file allows you to generate some statistics by ADM2 unit in the labour data. In particular, 
	you will get a .dta file where each row is a unique ADM2 unit, and the columns will be:

	total_obs:			total number of diary entries for that ADM2 unit
	unique_dates:		number of unique dates (ie. 1 June 1982) of diary entries for that ADM2 unit
	unique_years:		number of unique years (ie. 1982) of diary entries for that ADM2 unit
	total_obs_adj:		identical to total_obs, except that the number is multipled by 7 for BRA, CHN  
						and MEX (since each date represents a week ie. 7 days of unique dates)
	unique_dates_adj: 	same adjustment as total_obs_adj, but for unique_dates

	Note that ADM2 units are used for all countries except China, where ADM3 is used in place of ADM2.

****************************************************************************************************/

// SETTING UP
* ssc install touch
* ssc install gtools
global SAC_SHARES = "/mnt/sacagawea_shares"
global filepath  = "${SAC_SHARES}/gcp/estimation/labor/time_use_data/intermediate"
global data_path = "${SAC_SHARES}/gcp/estimation/labor/time_use_data/final"

// READ IN CROSSWALK
touch "${filepath}/crosswalk", type(dta) replace
local countries "BRA CHN ESP FRA GBR IND MEX USA"
foreach country in `countries' {
	import delimited "${filepath}/shapefile_to_timeuse_crosswalk_`country'.csv", encoding(utf8) clear
	append using "${filepath}/crosswalk", force
	save "${filepath}/crosswalk", replace
	}
replace adm3_id = adm2_id if iso != "CHN" // put all ADM2 ids into ADM3 (since for China we use ADM3)
duplicates drop adm3_id, force
save "${filepath}/crosswalk", replace

// COLLAPSE DATA BY ADMIN REGION
use date year adm3_id adm0_id using "${data_path}/labor_dataset_polynomials_tmax_chn_prev_week_lcl_1.dta" , clear
format adm3_id %8.0f
gen total_obs = 1
gegen unique_dates = tag(adm3_id date)
gegen unique_years = tag(adm3_id year)
gcollapse (sum) total_obs unique_dates unique_years, by(adm3_id)

// MERGE WITH CROSSWALK AND STANDARDIZE
merge 1:1 adm3_id using "${filepath}/crosswalk.dta", keep(3)

gen unique_dates_adj = unique_dates*7 if inlist(iso, "BRA", "MEX", "CHN")
gen total_obs_adj = total_obs*7 if inlist(iso, "BRA", "MEX", "CHN")
replace unique_dates_adj = unique_dates if unique_dates_adj == .
replace total_obs_adj = total_obs if total_obs_adj == .

replace name_1 = name_1_adm1 if iso == "BRA"
replace name_1 = region_name if iso == "GBR"
replace name_2 = district_name if iso == "IND"
replace name_1 = state_name if iso == "MEX"
replace name_2 = municipality_name if iso == "MEX"
replace name_2 = name_3 if iso == "CHN"

// CLEAN UP FILES
keep adm3_id total_obs* unique_dates* unique_years iso name_1 name_2
order adm3_id iso name*, first
lab var adm3_id "ADM3 China, ADM2 other countries"
lab var name_1 "ADM1"
lab var name_2 "ADM3 China, ADM2 other countries"
save "${filepath}/obs_counts_by_adm2.dta", replace
cap erase "${filepath}/crosswalk.dta"
