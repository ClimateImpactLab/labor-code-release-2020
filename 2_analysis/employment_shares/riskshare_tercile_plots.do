/* 
Latest empshare regressions: full IPUMS sample, last census year.
The following code runs regresses highrisk share on income and temperature polynomial 

input file: "/mnt/CIL_labor/1_preparation/employment_shares/data/emp_inc_clim_merged.csv"

outputs:
1. residual plots
2. scatter plots yhat vs actual value
3. tercile plots of temperature vs high risk share evaluated at mean income for each income tercile
4. tercile plots of income vs high risk share evaluated at mean temperarture for each 
temperature poly tercile

Author: Nishka Sharma, nishkasharma@uchicago.edu
Date: 5/25/2021
*/

clear all
set more off
pause off

cilpath
loc lab "/mnt/CIL_labor"
loc out "/home/`c(username)'/repos/labor-code-release-2020/output/employment_shares"

* specify income variable you want to use here
loc inc_depvar log_gdppc_adm1_pwt_ds_15ma

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
xtile log_inc_tercile = log_inc, nquantiles(3) // I know this is redundant, but makes things easier further down
forval i=1(1)4 {
		xtile temp`i'_tercile = tavg_`i'_pop_ma_30yr, nquantiles(3)
}
xtile popop_tercile = popop, nquantiles(3)
xtile log_popop_tercile = log_popop, nquantiles(3) // again, redundant, but makes life easier

tempfile data
save `data'

***************
* REGRESSIONS *
***************

* main regressions: 
* 1. high risk share on LR tavg, up to poly 2, and income
* 2. high risk share on LR tavg poly 2, log income
* 3. log high risk share on LR tavg poly 2, log income
* 4. high risk share on log income only

* run this for full dataset and for last census only
foreach spec in 6 12 {
	foreach r in "last" { // if you want to run for all cenfsus as well
		di "`r'"

		use `data', clear
		* for now, sub in 15 yr MA where we can't calculate 30 yr MA due to lack of data
		forval i=1(1)4 {
			* replace tavg_`i'_pop_ma_30yr = tavg_`i'_pop_ma_15yr if mi(tavg_`i'_pop_ma_30yr) 
		}

		if "`r'" == "last" {
			keep if year == max_year
		}

		loc plot_3x3 0
		loc vars temp log_inc popop // vars for 3x3. note that order matters here: I have temp first, which minimizes the amount of code that's specific to the temperature variables
		loc plot_continent 0
		loc plot_inc 1
		loc plot_temp_one_graph 0 // plot the 3x1 of temp as a single graph (in addition to 3 graphs combined together)?
		loc plot_inc_one_graph 0 // same as above, but for income

		if `spec' == 6 {
			reghdfe ind_highrisk_share log_inc tavg_1_pop_ma_30yr tavg_2_pop_ma_30yr tavg_3_pop_ma_30yr tavg_4_pop_ma_30yr, noabsorb residuals(resid)
			loc depvar ind_highrisk_share
			loc saveas "log_inc_poly4"
			loc note "Regression of high risk share on 30 year moving average of daily temperature (poly 4) and log income."
			loc plot_temp_one_graph 1
			loc plot_inc_one_graph 1
		}
		if `spec' == 12 { // continent dummies, uninteracted
			reghdfe ind_highrisk_share log_inc tavg_1_pop_ma_30yr tavg_2_pop_ma_30yr tavg_3_pop_ma_30yr tavg_4_pop_ma_30yr i.continent_code, noabsorb residuals(resid)
			loc depvar in_highrisk_share
			loc saveas "log_inc_poly4_continent_fes"
			loc note "Regression of high risk share on 30 yr moving avg of daily T (poly 4) and log income with continent FEs."
			loc plot_temp_one_graph 1
			loc plot_inc_one_graph 1
		}
		
		pause

		* add r-squared to graph notes
		loc r2=string(`e(r2)', "%9.4f")
		loc note "`note'" "R-squared: `r2'"

		* plots
		*******
		predict predicted

		* transform from logs to levels if necessary
		if "`depvar'" == "log_share" {
			replace predicted = exp(predicted)
			replace resid = ind_highrisk_share - predicted
		}

		* residuals
		twoway hist resid, fraction color(bluishgray) ///
			graphregion(color(white)) plotregion(color(white)) ///
			note("`note'" "Estimated on `r' censuses for each country.")

		graph export "`out'/plot/residuals/`saveas'_residuals.pdf", replace

		* scatter yhat vs actual (dropping observations where predicted > 1, to have consistent y axis scale)
		tw scatter predicted ind_highrisk_share if predicted <= 1 & predicted >= 0, msize(tiny) || ///
			function y=x, ///
			xtitle("High risk share") ytitle("Predicted value") note("`note'" "Estimated on `r' censuses for each country.") ///
			legend(off) graphregion(color(white)) plotregion(color(white))

		graph export "`out'/plot/scatters/`saveas'_predicted_actual_scatter.pdf", replace
			if `plot_3x3' != 1 {
				* Temp, evaluated at terciles of income distribution
				loc temp_graphs
				loc inc_resid 		
				forval i=1(1)3 {
					* plot residuals as function of income tercile
					twoway hist resid if inc_tercile == `i', fraction color(bluishgray) ///
						graphregion(color(white)) plotregion(color(white)) ///
						title("Income Tercile `i'") name(resid_`i', replace)

					loc inc_resid `inc_resid' resid_`i'

					qui sum gdppc_adm1_pwt_downscaled_13br if inc_tercile == `i'
					loc inc=`r(mean)'

					qui sum log_inc if inc_tercile == `i'
					loc log_inc=`r(mean)'

					qui sum popop if popop_tercile == `i'
					loc popop=`r(mean)'

					* set min and max for graphs to be 5-95
					qui sum tavg_1_pop_ma_30yr, d
					loc min=floor(`r(p5)')
					loc max=ceil(`r(p95)')
					loc ref=round((`max' + `min')/2)

					preserve
						* create temp vector
						drop if _n > 0
						gen temp = .

						local obs = `max' - `min' + 1

						* expand dataset by length of vector
						set obs `obs'
						replace temp = _n + (`min' - 1)

						if `spec' == 6 {
							loc temp_cmd "_b[_cons] + _b[tavg_1_pop_ma_30yr]*temp + _b[tavg_2_pop_ma_30yr]*temp^2 + _b[tavg_3_pop_ma_30yr]*temp^3 + _b[tavg_4_pop_ma_30yr]*temp^4 + _b[log_inc]*`log_inc'"
						}
						if `spec' == 12 {
							loc temp_cmd "_b[_cons] + _b[log_inc]*`log_inc' + _b[tavg_1_pop_ma_30yr]*temp + _b[tavg_2_pop_ma_30yr]*temp^2 + _b[tavg_3_pop_ma_30yr]*temp^3 + _b[tavg_4_pop_ma_30yr]*temp^4"
						}

						predictnl yhat = `temp_cmd', se(se_hi) ci(lowerci_hi upperci_hi)

						* convert from logs to levels if necessary
						if "`depvar'" == "log_share" {
							replace yhat = exp(yhat)
							replace upperci_hi = exp(upperci_hi)
							replace lowerci_hi = exp(lowerci_hi)
						}

						tw rarea upperci_hi lowerci_hi temp, col(ltblue%30) || line yhat temp, lc (purple) ///
							graphregion(color(white)) plotregion(color(white)) yscale(r(0, 1)) ///
							legend(off) title("Income Tercile `i'") xtitle("Long-run avg. temperature") ///
							name(temp_response_`i', replace)

						loc temp_graphs `temp_graphs' temp_response_`i'

					restore
				}

				* combine residuals by Income into a 3x1
				graph combine `inc_resid', ycomm xcomm rows(1) ///
					graphregion(color(white)) plotregion(color(white)) ///
					title("Residuals by income group") ///
					note("`note'" "Estimated on `r' censuses for each country.")

				graph export "`out'/plot/residuals/`saveas'_inc_residuals.pdf", replace

				* combine predictions by Income into a 3x1
				graph combine `temp_graphs', ycomm xcomm rows(1) ///
					graphregion(color(white)) plotregion(color(white)) ///
					title("High risk share predictions") ///
					note("`note'" "Estimated on `r' censuses for each country."  "`extranote'")

				graph export "`out'/plot/predictions/`saveas'_TempPrediction.pdf", replace

				* plot temp response for all three income terciles on one graph if desired
				if `plot_temp_one_graph' == 1 {
					forval i=1(1)3 {
						qui sum log_inc if inc_tercile == `i'
						loc log_inc_`i'=`r(mean)'
					}

					qui sum tavg_1_pop_ma_30yr, d
					loc min=floor(`r(p5)')
					loc max=ceil(`r(p95)')
					loc ref=round((`max' + `min')/2)

					preserve
						drop if _n > 0
						gen temp = .

						loc obs = `max' - `min' + 1
						set obs `obs'
						replace temp = _n + (`min' - 1)

						if `spec' == 6 {
							forval i=1(1)3 {
								loc temp_cmd_`i' "_b[_cons] + _b[log_inc]*`log_inc_`i'' + _b[tavg_1_pop_ma_30yr]*temp + _b[tavg_2_pop_ma_30yr]*temp^2 + _b[tavg_3_pop_ma_30yr]*temp^3 + _b[tavg_4_pop_ma_30yr]*temp^4"
							}
						}
						if `spec' == 12 {
							forval i=1(1)3 {
								loc temp_cmd_`i' "_b[_cons] + _b[log_inc]*`log_inc_`i'' + _b[tavg_1_pop_ma_30yr]*temp + _b[tavg_2_pop_ma_30yr]*temp^2 + _b[tavg_3_pop_ma_30yr]*temp^3 + _b[tavg_4_pop_ma_30yr]*temp^4"
							}
						}

						forval i=1(1)3 {
							predictnl yhat_`i' = `temp_cmd_`i'', se(se_hi_`i') ci(lowerci_hi_`i' upperci_hi_`i')
						}

						pause 
						tw rarea upperci_hi_1 lowerci_hi_1 temp, col(ltblue%30) || line yhat_1 temp, lc("48 74 0") || ///
							rarea upperci_hi_2 lowerci_hi_2 temp, col(ltblue%30) || line yhat_2 temp, lc("105 137 0") || ///
							rarea upperci_hi_3 lowerci_hi_3 temp, col(ltblue%30) || line yhat_3 temp, lc("174 211 0") ///
							legend(order(2 "First" 4 "Second" 6 "Third") title("Income tercile") rows(1)) ///
							graphregion(color(white)) plotregion(color(white)) yscale(r(0, 1)) /// 
							title("High-risk share prediction by income tercile") xtitle("Long-run avg. temperature (C)") ///
							note("`note'" "`extranote'")
							

						graph export "`out'/plot/predictions/`saveas'_TempPrediction_sameaxes.pdf", replace


					restore
				} // end of plot_temp_one_graph condition

				* Income, evaluated at terciles of temp distribution			
				if `plot_inc' == 1 {
					loc inc_graphs
					forval i=1(1)3 {
						forval k=1(1)4 {
							qui sum tavg_`k'_pop_ma_30yr if temp`i'_tercile == `i'
							loc temp`k'=`r(mean)'	
						}

						preserve
							* create inc vector
							drop if _n > 0
							gen inc = .
							loc min = 500
							loc max = 50500
							local obs = (`max' + abs(`min')) / 100

							* expand dataset by length of temperature vector
							set obs `obs'
							replace inc = _n*100 + `min'

							gen inc_log = log(inc)

							if `spec' == 6 {
								loc inc_cmd "_b[_cons] + _b[tavg_1_pop_ma_30yr]*`temp1' + _b[tavg_2_pop_ma_30yr]*`temp2' + _b[tavg_3_pop_ma_30yr]*`temp3' + _b[tavg_4_pop_ma_30yr]*`temp4'+ _b[log_inc]*inc_log"
								loc inc_var inc_log 
							}
							if `spec' == 12 {
								loc inc_cmd "_b[_cons] + _b[log_inc]*inc_log + _b[tavg_1_pop_ma_30yr]*`temp1' + _b[tavg_2_pop_ma_30yr]*`temp2' + _b[tavg_3_pop_ma_30yr]*`temp3' + _b[tavg_4_pop_ma_30yr]*`temp4'"
								loc inc_var inc_log
							}
							
							predictnl yhat = `inc_cmd', se(se_hi) ci(lowerci_hi upperci_hi)

							* convert from logs to levels if necessary
							if "`depvar'" == "log_share" {
								replace yhat = exp(yhat)
								replace upperci_hi = exp(upperci_hi)
								replace lowerci_hi = exp(lowerci_hi)
							}

							tw rarea upperci_hi lowerci_hi `inc_var', col(ltblue%30) || line yhat `inc_var', lc (purple) ///
								graphregion(color(white)) plotregion(color(white)) ///
								legend(off) title("LR Tavg Tercile `i'") xtitle("`inc_var'") xlabel(,angle(vertical)) ///
								name(inc_response_`i', replace)

							loc inc_graphs `inc_graphs' inc_response_`i'
						restore
					}

					graph combine `inc_graphs', ///
						ycomm xcomm rows(1) ///
						graphregion(color(white)) plotregion(color(white)) ///
						title("High risk share predictions") ///
						note("`note'" "Estimated on `r' censuses for each country.")
					graph export "`out'/plot/predictions/`saveas'_IncPrediction.pdf", replace

					* plot temp response for all three temp terciles on one graph if desired
					if `plot_inc_one_graph' == 1 {
						forval i=1(1)3 {
							forval k=1(1)4 {
								qui sum tavg_`k'_pop_ma_30yr if temp`i'_tercile == `i'
								loc temp`k'_`i'=`r(mean)'	
							}
						}

						preserve
							drop if _n > 0
							gen inc = .
							loc min = 500
							loc max = 50500
							local obs = (`max' + abs(`min')) / 100

							* expand dataset by length of temperature vector
							set obs `obs'
							replace inc = _n*100 + `min'

							gen inc_log = log(inc)

							if `spec' == 6 {
								forval i=1(1)3 {
									loc inc_cmd_`i' "_b[_cons] + _b[log_inc]*inc_log + _b[tavg_1_pop_ma_30yr]*`temp1_`i'' + _b[tavg_2_pop_ma_30yr]*`temp2_`i'' + _b[tavg_3_pop_ma_30yr]*`temp3_`i'' + _b[tavg_4_pop_ma_30yr]*`temp4_`i''"
								}
							}
							if `spec' == 12 {
								forval i=1(1)3 {
									loc inc_cmd_`i' "_b[_cons] + _b[log_inc]*inc_log + _b[tavg_1_pop_ma_30yr]*`temp1_`i'' + _b[tavg_2_pop_ma_30yr]*`temp2_`i'' + _b[tavg_3_pop_ma_30yr]*`temp3_`i'' + _b[tavg_4_pop_ma_30yr]*`temp4_`i''"
								}
							}

							forval i=1(1)3 {
								predictnl yhat_`i' = `inc_cmd_`i'', se(se_hi_`i') ci(lowerci_hi_`i' upperci_hi_`i')
							}

							tw rarea upperci_hi_1 lowerci_hi_1 `inc_var', col(ltblue%30) || line yhat_1 `inc_var', lc("255 220 78") || ///
								rarea upperci_hi_2 lowerci_hi_2 `inc_var', col(ltblue%30) || line yhat_2 `inc_var', lc("255 119 29") || ///
								rarea upperci_hi_3 lowerci_hi_3 `inc_var', col(ltblue%30) || line yhat_3 `inc_var', lc("255 0 0") ///
								legend(order(2 "First" 4 "Second" 6 "Third") subtitle("Long-run average temperature tercile") rows(1)) ///
								graphregion(color(white)) plotregion(color(white)) /// 
								title("High-risk share prediction by long-run temperature tercile") xtitle("Log income") ///
								note("`note'" "`extranote'")
								

							graph export "`out'/plot/predictions/`saveas'_IncPrediction_sameaxes.pdf", replace

						restore
					} // end of plot_temp_one_graph condition
				} // end of plot_inc cond
			} // end of plot 3by3 condition != 1
	} // end of full/last loop
} // end of spec loop

