* find knots
* liruixue@uchicago.edu
* adapted from emile's code

set more off
set trace off

clear all
cap ssc install rsource

cilpath


if "`c(hostname)'" == "battuta" {
	global shares_path "/mnt/sacagawea_shares"
}
else global shares_path "/shares"


global temp_path ${shares_path}/gcp/estimation/labor/time_use_data/intermediate
global final_path ${shares_path}/gcp/estimation/labor/time_use_data/final

global t_version_list tmax tavg 
global chn_week_list chn_prev7days 
global variables_list polynomials

cap program drop find_knots 
program define find_knots 
	args N_knots
	*this code finds the knots to be used to get the rcspline transformation of temperatures.
	*the method is based on Harrell(2001) who gives recommended percentiles of the variable to transform, as knots, for a given number of knots.
	*below are these percentiles for a number of knots from 3 to 7.
	*We use population weighted percentiles to compute these knots. 
	global percentiles_3kn 10 50 90
	global percentiles_4kn 5 35 65 95
	global percentiles_5kn 27.5 50 72.5 95
	global percentiles_6kn 5 23 41 59 77 95 
	global percentiles_7kn 2.5 18.33 34.17 50 65.83 81.67 97.5
	*di "we use the following percentiles of the daily max temperatures : ${percentiles_`N_knots'kn}"
	_pctile real_temperature [pw=pop_adj_sample_wgt], percentiles(${percentiles_`N_knots'kn})
	loc count=0
	global knots_`N_knots'kn
	foreach p in ${percentiles_`N_knots'kn}{
		loc count=`count'+1
		loc `count'_rounded = round(`r(r`count')', 0.1) 
		*di "the percentile `p' of real temperature is `r(r`count')'"
		global knots_`N_knots'kn ${knots_`N_knots'kn}, ``count'_rounded' 
	}
	di "the rounded percentiles, that should be be used as knots for the rcspline transformation, are ${knots_`N_knots'kn}"
end 

foreach t_version in $t_version_list {
	foreach chn_week in $chn_week_list {	
		foreach variables in $variables_list {
			di "`t_version'"
			di "`chn_week'"
			di "`variables'"
			use "$final_path/labor_dataset_`variables'_`t_version'_`chn_week'_lcl_1.dta", clear
			drop if iso == "CHN"
			find_knots 3
			find_knots 4
			di ""
			di ""
		}
	}
}

