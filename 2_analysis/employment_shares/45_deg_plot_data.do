/*
The following code generates data to make a 45 deg plot of predicted values of yhat
LR(T^K) vs yhat LRT^K specifications

Author: Nishka Sharma, nishkasharma@uchicago.edu
Date: 5/25/2021

*/


clear all
set more off
macro drop _all
set scheme s1color

loc lab "/mnt/CIL_labor"
loc out "/home/`c(username)'/repos/labor-code-release-2020/output/employment_shares"
loc ster "`out'/ster"

use "`out'/riskshare_reg_data.dta", clear

* lrt^k model predictions, save for merge later
		estimates use "`ster'/log_inc_lrtk"

		loc temp_cmd "_b[_cons] + _b[log_inc]*log_inc + _b[temp_poly1]*temp_poly1 + _b[temp_poly2]*temp_poly2 + _b[temp_poly3]*temp_poly3 + _b[temp_poly4]*temp_poly4"

		predictnl yhat_lrtk = `temp_cmd', se(se_lrtk) ci(lowerci_lrtk upperci_lrtk)

		preserve

		keep geolev1 year log_inc tavg_1_pop_ma_30yr yhat_lrtk se_lrtk lowerci_lrtk upperci_lrtk

		tempfile lrtk_file
		save `lrtk_file', replace
		* export delimited "`out'/highriskshare_check/yhat_temp_lrtk.csv", replace 

		restore
						

* main model predictions, change the _b coefficients and temp poly varnames

		estimates use "`ster'/log_inc_poly4"

		loc temp_cmd "_b[_cons] + _b[log_inc]*log_inc + _b[tavg_1_pop_ma_30yr]*tavg_1_pop_ma_30yr + _b[tavg_2_pop_ma_30yr]*tavg_2_pop_ma_30yr + _b[tavg_3_pop_ma_30yr]*tavg_3_pop_ma_30yr + _b[tavg_4_pop_ma_30yr]*tavg_4_pop_ma_30yr"

		predictnl yhat_main = `temp_cmd', se(se_main) ci(lowerci_main upperci_main)

* merge the two together to generate data for 45 deg plots
		preserve
		
		keep geolev1 year log_inc tavg_1_pop_ma_30yr yhat_main se_main lowerci_main upperci_main
		
		merge 1:1 geolev1 year using `lrtk_file'
		drop _m

		export delimited "`out'/yhat_values/45_deg_plot.csv", replace 

		restore