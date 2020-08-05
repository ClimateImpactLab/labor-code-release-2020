set more off
clear all
cap ssc install rsource

cilpath

global dataset_path /shares/gcp/estimation/Labor/labor_merge_2019


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

global varlist_precip prcp_poly_1 prcp_poly_2
global varlist_spline 
global varlist_poly tmax_poly_1 tmax_poly_2 tmax_poly_3 tmax_poly_4 

global countries MEX BRA USA GBR IND CHN ESP FRA


use "$dataset_path/intermediate_files/labor_time_use_all_countries_weighted.dta", clear

cap restore, not
foreach iso in $countries {
	preserve
	* keep only the country's data
	drop if iso != "`iso'" 
	save `iso'_dt, replace
	merge_climate_data_var_with_lags `iso' varlist_precip
	*merge_long_run `iso'
	merge_long_run_adm1 `iso'
	merge_climate_data_file `iso'  tmax_bins
	restore
}


clear all


foreach iso in $countries {
	di "`iso'"
	append using `iso'_dt.dta
	*erase `iso'_dt.dta
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

*save "/shares/gcp/estimation/Labor/labor_merge_2019/intermediate_files/last_step.dta", replace


*use "/shares/gcp/estimation/Labor/labor_merge_2019/intermediate_files/last_step.dta", clear



global varlist_bin tmax_bins_nInf_n40C tmax_bins_n1C_0C tmax_bins_60C_Inf

forval t = 2/40 {
	local t_minus_1 = `t' - 1
	global varlist_bin $varlist_bin tmax_bins_n`t'C_n`t_minus_1'C
}

forval t = 0/59 {
	local t_plus_1 = `t' + 1
	global varlist_bin $varlist_bin tmax_bins_`t'C_`t_plus_1'C
}

di "$varlist_bin"


cap drop *_f*
cap drop weekly_*

* get rid of bins that have no observations
foreach v in $varlist_bin {
	
		sum `v'
	if r(min) == 0 & r(max) == 0 {
		drop `v'*	
}
}

save "$dataset_path/intermediate_files/labor_dataset_jan_2020_rawbins_n24C_51C_adm1_lrtmax.dta", replace



* rename 1c bins
*use "$dataset_path/intermediate_files/labor_dataset_jan_2020_rawbins_n24C_51C.dta", clear

*

rename tmax_bins_n24C_n23C* b1C_1*
rename tmax_bins_n23C_n22C* b1C_2*
rename tmax_bins_n22C_n21C* b1C_3*
rename tmax_bins_n21C_n20C* b1C_4*
rename tmax_bins_n20C_n19C* b1C_5*
rename tmax_bins_n19C_n18C* b1C_6*
rename tmax_bins_n18C_n17C* b1C_7*
rename tmax_bins_n17C_n16C* b1C_8*
rename tmax_bins_n16C_n15C* b1C_9*
rename tmax_bins_n15C_n14C* b1C_10*
rename tmax_bins_n14C_n13C* b1C_11*
rename tmax_bins_n13C_n12C* b1C_12*
rename tmax_bins_n12C_n11C* b1C_13*
rename tmax_bins_n11C_n10C* b1C_14*
rename tmax_bins_n10C_n9C* b1C_15*
rename tmax_bins_n9C_n8C* b1C_16*
rename tmax_bins_n8C_n7C* b1C_17*
rename tmax_bins_n7C_n6C* b1C_18*
rename tmax_bins_n6C_n5C* b1C_19*
rename tmax_bins_n5C_n4C* b1C_20*
rename tmax_bins_n4C_n3C* b1C_21*
rename tmax_bins_n3C_n2C* b1C_22*
rename tmax_bins_n2C_n1C* b1C_23*
rename tmax_bins_n1C_0C* b1C_24*
rename tmax_bins_0C_1C* b1C_25*
rename tmax_bins_1C_2C* b1C_26*
rename tmax_bins_2C_3C* b1C_27*
rename tmax_bins_3C_4C* b1C_28*
rename tmax_bins_4C_5C* b1C_29*
rename tmax_bins_5C_6C* b1C_30*
rename tmax_bins_6C_7C* b1C_31*
rename tmax_bins_7C_8C* b1C_32*
rename tmax_bins_8C_9C* b1C_33*
rename tmax_bins_9C_10C* b1C_34*
rename tmax_bins_10C_11C* b1C_35*
rename tmax_bins_11C_12C* b1C_36*
rename tmax_bins_12C_13C* b1C_37*
rename tmax_bins_13C_14C* b1C_38*
rename tmax_bins_14C_15C* b1C_39*
rename tmax_bins_15C_16C* b1C_40*
rename tmax_bins_16C_17C* b1C_41*
rename tmax_bins_17C_18C* b1C_42*
rename tmax_bins_18C_19C* b1C_43*
rename tmax_bins_19C_20C* b1C_44*
rename tmax_bins_20C_21C* b1C_45*
rename tmax_bins_21C_22C* b1C_46*
rename tmax_bins_22C_23C* b1C_47*
rename tmax_bins_23C_24C* b1C_48*
rename tmax_bins_24C_25C* b1C_49*
rename tmax_bins_25C_26C* b1C_50*
rename tmax_bins_26C_27C* b1C_51*
rename tmax_bins_27C_28C* b1C_52*
rename tmax_bins_28C_29C* b1C_53*
rename tmax_bins_29C_30C* b1C_54*
rename tmax_bins_30C_31C* b1C_55*
rename tmax_bins_31C_32C* b1C_56*
rename tmax_bins_32C_33C* b1C_57*
rename tmax_bins_33C_34C* b1C_58*
rename tmax_bins_34C_35C* b1C_59*
rename tmax_bins_35C_36C* b1C_60*
rename tmax_bins_36C_37C* b1C_61*
rename tmax_bins_37C_38C* b1C_62*
rename tmax_bins_38C_39C* b1C_63*
rename tmax_bins_39C_40C* b1C_64*
rename tmax_bins_40C_41C* b1C_65*
rename tmax_bins_41C_42C* b1C_66*
rename tmax_bins_42C_43C* b1C_67*
rename tmax_bins_43C_44C* b1C_68*
rename tmax_bins_44C_45C* b1C_69*
rename tmax_bins_45C_46C* b1C_70*
rename tmax_bins_46C_47C* b1C_71*
rename tmax_bins_47C_48C* b1C_72*
rename tmax_bins_48C_49C* b1C_73*
rename tmax_bins_49C_50C* b1C_74*
rename tmax_bins_50C_51C* b1C_75*

drop _merge

save "$dataset_path/intermediate_files/labor_dataset_jan_2020_1Cbins_n24C_51C_adm1_lrtmax.dta", replace


* generate 3C bins
*use  "$dataset_path/for_regression/labor_dataset_jan_2020_1Cbins_n24C_51C.dta", clear

forval n = 1/25 {
	local n1 = 3 * (`n'-1) + 1
	local n2 = 3 * (`n'-1) + 2
	local n3 = 3 * (`n'-1) + 3
	gen b3C_`n' = b1C_`n1' + b1C_`n2' + b1C_`n3'
	local lb =  (`n' - 9 ) * 3 
	local ub =  (`n' - 8 ) * 3
	label variable b3C_`n' "`lb' to `ub'"
	forval v = 1/6 {
		gen b3C_`n'_v`v' = b1C_`n1'_v`v' + b1C_`n2'_v`v' + b1C_`n3'_v`v'
		label variable b3C_`n'_v`v' "`lb' to `ub' v`v'"
		
	}
}

drop b1C*

save "$dataset_path/for_regression/labor_dataset_jan_2020_3Cbins_n24C_51C_adm1_lrtmax.dta", replace
*use "$dataset_path/for_regression/labor_dataset_jan_2020_3Cbins_n24C_51C_adm1_lrtmax.dta", clear


* below 0
gen below0 = 0
forval t = 1/8 {
	replace below0 = below0 + b3C_`t'
	drop b3C_`t'
}

gen above42 = b3C_23 + b3C_24 + b3C_25
drop b3C_23 b3C_24 b3C_25


forval v = 1/6 {
	gen below0_v`v' = 0
	forval t = 1/8 {
		replace below0_v`v' = below0_v`v' + b3C_`t'_v`v'
		drop b3C_`t'_v`v'
	}

	gen above42_v`v' = b3C_23_v`v' + b3C_24_v`v' + b3C_25_v`v'
	drop b3C_23_v`v' b3C_24_v`v' b3C_25_v`v'

}

*drop b1C*

save "$dataset_path/for_regression/labor_dataset_jan_2020_3Cbins_0C_42C_adm1_lrtmax.dta", replace







