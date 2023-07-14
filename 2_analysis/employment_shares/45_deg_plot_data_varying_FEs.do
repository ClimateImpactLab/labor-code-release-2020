/*
The following code generates data to make a 45 deg plot of predicted values of yhat
LR(T^K) vs yhat LRT^K specifications

Author: Jonah Gilbert, jonahmgilbert@uchicago.edu
Date: 7/12/2023

*/


clear all
set more off
macro drop _all
set scheme s1color

loc lab "/mnt/CIL_labor"
loc out "/home/`c(username)'/repos/labor-code-release-2020/output/employment_shares"
loc ster "`out'/ster"

use "`out'/riskshare_reg_data.dta", clear

* continent fe model predictions, save for merge later
		estimates use "`ster'/log_inc_poly4_continent_fes"

		loc temp_cmd "_b[_cons] + _b[log_inc]*log_inc + _b[tavg_1_pop_ma_30yr]*tavg_1_pop_ma_30yr + _b[tavg_2_pop_ma_30yr]*tavg_2_pop_ma_30yr + _b[tavg_3_pop_ma_30yr]*tavg_3_pop_ma_30yr + _b[tavg_4_pop_ma_30yr]*tavg_4_pop_ma_30yr"

		predictnl yhat_continent_fes = predict(), se(se_continent_fes) ci(lowerci_continent_fes upperci_continent_fes)

		preserve

		keep geolev1 year log_inc tavg_1_pop_ma_30yr yhat_continent_fes se_continent_fes lowerci_continent_fes upperci_continent_fes

		tempfile continent_fes_file
		save `continent_fes_file', replace
		* export delimited "`out'/highriskshare_check/yhat_temp_lrtk.csv", replace 

		restore
					
					
* continent, year model predictions, save for merge later
		estimates use "`ster'/log_inc_poly4_continent_year_fes"

		loc temp_cmd "_b[_cons] + _b[log_inc]*log_inc + _b[tavg_1_pop_i.ma_30yr]*tavg_1_pop_ma_30yr + _b[tavg_2_pop_ma_30yr]*tavg_2_pop_ma_30yr + _b[tavg_3_pop_ma_30yr]*tavg_3_pop_ma_30yr + _b[tavg_4_pop_ma_30yr]*tavg_4_pop_ma_30yr"

		predictnl yhat_continent_year_fes = predict(), se(se_continent_year_fes) ci(lowerci_continent_year_fes upperci_continent_year_fes)

		preserve

		keep geolev1 year log_inc tavg_1_pop_ma_30yr yhat_continent_year_fes se_continent_year_fes lowerci_continent_year_fes upperci_continent_year_fes

		tempfile continent_year_fes_file
		save `continent_year_fes_file', replace
		* export delimited "`out'/highriskshare_check/yhat_temp_lrtk.csv", replace 

		restore

* year model predictions, save for merge later
		estimates use "`ster'/log_inc_poly4_year_fes"

		loc temp_cmd "_b[_cons] +_b[year]*i.year + _b[log_inc]*log_inc + _b[tavg_1_pop_ma_30yr]*tavg_1_pop_ma_30yr + _b[tavg_2_pop_ma_30yr]*tavg_2_pop_ma_30yr + _b[tavg_3_pop_ma_30yr]*tavg_3_pop_ma_30yr + _b[tavg_4_pop_ma_30yr]*tavg_4_pop_ma_30yr"

		predictnl yhat_year_fes = predict(), se(se_year_fes) ci(lowerci_year_fes upperci_year_fes)

		preserve

		keep geolev1 year log_inc tavg_1_pop_ma_30yr yhat_year_fes se_year_fes lowerci_year_fes upperci_year_fes

		tempfile year_fes_file
		save `year_fes_file', replace
		* export delimited "`out'/highriskshare_check/yhat_temp_lrtk.csv", replace 

		restore
		
* main model predictions, change the _b coefficients and temp poly varnames

		estimates use "`ster'/log_inc_poly4"

		loc temp_cmd "_b[_cons] + _b[log_inc]*log_inc + _b[tavg_1_pop_ma_30yr]*tavg_1_pop_ma_30yr + _b[tavg_2_pop_ma_30yr]*tavg_2_pop_ma_30yr + _b[tavg_3_pop_ma_30yr]*tavg_3_pop_ma_30yr + _b[tavg_4_pop_ma_30yr]*tavg_4_pop_ma_30yr"

		predictnl yhat_main = predict(), se(se_main) ci(lowerci_main upperci_main)

* merge the two together to generate data for 45 deg plots
		preserve
		
		keep geolev1 year log_inc tavg_1_pop_ma_30yr yhat_main se_main lowerci_main upperci_main
		
		merge 1:1 geolev1 year using `continent_fes_file', nogen	
		merge 1:1 geolev1 year using `continent_year_fes_file', nogen	
		merge 1:1 geolev1 year using `year_fes_file'
		drop _m

		export delimited "`out'/yhat_values/45_deg_plot_continent_fes.csv", replace 

		restore