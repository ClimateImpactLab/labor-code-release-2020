/* 
Latest empshare regressions: full IPUMS sample, last census year.
The following code runs regresses highrisk share on income and temperature polynomial.
There are two temperature polynomial specifications- case 1: temperature^k = LR(T^k) 
and case 2: temperature^k = LRT^k

input file: "/mnt/CIL_labor/1_preparation/employment_shares/data/emp_inc_clim_merged.csv"

outputs:
1. ster files for each regression
2. csv files of yhat values calculated using coefficients from each regression

Author: Nishka Sharma, nishkasharma@uchicago.edu
Date: 5/25/2021
*/


clear all
set more off
pause off

loc lab "/mnt/CIL_labor"
loc out "/home/`c(username)'/repos/labor-code-release-2020/output/employment_shares"
loc ster "`out'/ster"

* specify income variable you want to use here
loc inc_depvar log_gdppc_adm1_pwt_ds_15ma
loc inc_test 1

* import dataset and do some cleaning
import delimited "`lab'/1_preparation/employment_shares/data/emp_inc_clim_merged.csv", clear

* drop places that don't actually exist (missings, etc.)
drop if geolev1 == 1
drop if country == "NA"
drop if gdppc_adm1_pwt_downscaled_13br == "NA"
drop if (inlist(mod(geolev1, 100), 99, 98) & geolev1 != 192099) | geolev1 == 231017

qui ds
loc vars = r(varlist)
loc not country continent
loc vars: list vars - not

qui destring `vars', replace force

encode continent, gen(continent_code)

* subset to census years only
keep if !mi(total_pop)
* drop years we don't have climate data for (GMFD goes to 2010 only)
drop if year > 2010
bysort geolev1: egen max_year = max(year)

rename `inc_depvar' log_inc

gen log_share = log(ind_highrisk_share)
gen log_popop = log(popop)

* create terciles of vars
xtile inc_tercile = gdppc_adm1_pwt_downscaled_13br, nquantiles(3)	
* I know this is redundant, but makes things easier further down
xtile log_inc_tercile = log_inc, nquantiles(3) 
forval i=1(1)4 {
		xtile temp`i'_tercile = tavg_`i'_pop_ma_30yr, nquantiles(3)
}
xtile popop_tercile = popop, nquantiles(3)
* again, redundant, but makes life easier
xtile log_popop_tercile = log_popop, nquantiles(3) 

keep if year == max_year 

gen temp_poly1 = tavg_1_pop_ma_30yr 
gen temp_poly2 = tavg_1_pop_ma_30yr^2
gen temp_poly3 = tavg_1_pop_ma_30yr^3
gen temp_poly4 = tavg_1_pop_ma_30yr^4
			
save "`out'/riskshare_reg_data.dta", replace

foreach spec in 1 2 3 4{

if `spec' == 1 {
			reghdfe ind_highrisk_share log_inc tavg_1_pop_ma_30yr tavg_2_pop_ma_30yr tavg_3_pop_ma_30yr tavg_4_pop_ma_30yr, noabsorb residuals(resid_`spec')
			loc saveas "log_inc_poly4"
		}

* continent dummies, uninteracted. base level of continent FE changed to asia
if `spec' == 2 {
			reghdfe ind_highrisk_share log_inc tavg_1_pop_ma_30yr tavg_2_pop_ma_30yr tavg_3_pop_ma_30yr tavg_4_pop_ma_30yr ib3.continent_code, noabsorb residuals(resid`spec')
			loc saveas "log_inc_poly4_continent_fes"
		}

if `spec' == 3 { 
			reghdfe ind_highrisk_share log_inc temp_poly1 temp_poly2 temp_poly3 temp_poly4, noabsorb residuals(resid_`spec')
			loc saveas "log_inc_lrtk"
		}

* continent dummies, uninteracted. base level of continent FE changed to asia
if `spec' == 4 { 
			reghdfe ind_highrisk_share log_inc temp_poly1 temp_poly2 temp_poly3 temp_poly4 ib3.continent_code, noabsorb residuals(resid_`spec')
			loc saveas "log_inc_lrtk_continent_fes"
		}

		if inlist(`spec', 1, 2, 3, 4) {
			di "`out'/ster/"
			estimates save "`out'/ster/`saveas'.ster", replace
		}

* plot residuals as function of income tercile
			loc temp_graphs
					
				qui sum gdppc_adm1_pwt_downscaled_13br
				loc inc=`r(mean)'

				qui sum log_inc 
				loc log_inc=`r(mean)'

				* set min and max for graphs to be 5-95. change min temperature to `r(p5)' and max temperature to `r(p95)' for data limits
				qui sum temp_poly1, d
				loc min=floor(-26.22) // global min
				loc max=ceil(42.87) // global max
				
				loc ref=round((`max' + `min')/2)

					preserve
						* create temp vector
						drop if _n > 0
						gen temp = .

						local obs = `max' - `min' + 1

						* expand dataset by length of vector
						set obs `obs'
						replace temp = _n + (`min' - 1)

						if `spec' == 1 {
							loc temp_cmd "_b[_cons] + _b[log_inc]*`log_inc' + _b[tavg_1_pop_ma_30yr]*temp + _b[tavg_2_pop_ma_30yr]*temp^2 + _b[tavg_3_pop_ma_30yr]*temp^3 + _b[tavg_4_pop_ma_30yr]*temp^4"
						}
						
						if `spec' == 2 {
							loc temp_cmd "_b[_cons] + _b[log_inc]*`log_inc' + _b[tavg_1_pop_ma_30yr]*temp + _b[tavg_2_pop_ma_30yr]*temp^2 + _b[tavg_3_pop_ma_30yr]*temp^3 + _b[tavg_4_pop_ma_30yr]*temp^4"
						}

						if `spec' == 3 {
							loc temp_cmd "_b[_cons] + _b[log_inc]*`log_inc' + _b[temp_poly1]*temp + _b[temp_poly2]*temp^2 + _b[temp_poly3]*temp^3 + _b[temp_poly4]*temp^4"
						}
						
						if `spec' == 4 {
							loc temp_cmd "_b[_cons] + _b[log_inc]*`log_inc' + _b[temp_poly1]*temp + _b[temp_poly2]*temp^2 + _b[temp_poly3]*temp^3 + _b[temp_poly4]*temp^4"
						}

						predictnl yhat = `temp_cmd', se(se_hi) ci(lowerci_hi upperci_hi)
						keep temp yhat se_hi lowerci_hi upperci_hi

						export delimited "`out'/yhat_values/`saveas'_TempPredMinMax.csv", replace 
						*change filename here after modifying the max temperature

					restore
					
					
			loc inc_graphs

				forval k=1(1)4 {
					qui sum tavg_`k'_pop_ma_30yr
					loc tavg`k'=`r(mean)'
					qui sum temp_poly`k'
					loc temp`k'=`r(mean)'
					}

					preserve
						* create inc vector
						drop if _n > 0
						gen inc = .
						loc min = 650
						loc max = 77050
						local obs = (`max' + abs(`min')) / 100

						* expand dataset by length of temperature vector
						set obs `obs'
						replace inc = _n*100 + `min'

						gen inc_log = log(inc)
						
						if `spec' == 1 {
							loc inc_cmd "_b[_cons] + _b[log_inc]*inc_log + _b[tavg_1_pop_ma_30yr]*`tavg1' + _b[tavg_2_pop_ma_30yr]*`tavg2' + _b[tavg_3_pop_ma_30yr]*`tavg3' + _b[tavg_4_pop_ma_30yr]*`tavg4'"
							loc inc_var inc_log
						}
						
						if `spec' == 2 {
							loc inc_cmd "_b[_cons] + _b[log_inc]*inc_log + _b[tavg_1_pop_ma_30yr]*`tavg1' + _b[tavg_2_pop_ma_30yr]*`tavg2' + _b[tavg_3_pop_ma_30yr]*`tavg3' + _b[tavg_4_pop_ma_30yr]*`tavg4'"
							loc inc_var inc_log
						}
						
						if `spec' == 3 {
							loc inc_cmd "_b[_cons] + _b[log_inc]*inc_log + _b[temp_poly1]*`temp1' + _b[temp_poly2]*`temp2' + _b[temp_poly3]*`temp3' + _b[temp_poly4]*`temp4'"
							loc inc_var inc_log
						}

						if `spec' == 4 {
							loc inc_cmd "_b[_cons] + _b[log_inc]*inc_log + _b[temp_poly1]*`temp1' + _b[temp_poly2]*`temp2' + _b[temp_poly3]*`temp3' + _b[temp_poly4]*`temp4'"
							loc inc_var inc_log
						}
					
						predictnl yhat = `inc_cmd', se(se_hi) ci(lowerci_hi upperci_hi)
						keep inc_log yhat se_hi lowerci_hi upperci_hi
						
						export delimited "`out'/yhat_values/`saveas'_IncPred.csv", replace 
						*change filename here after modifying the max temperature

					restore
}



