/*

Purpose: Figure 4 plotting, for energy sector total end of century damages 

*/

clear all
set more off
set scheme s1color

glob DB "/mnt"

glob DB_data "$DB/CIL_energy/code_release_data_pixel_interaction"
glob dir "$DB_data/projection_system_outputs/damage_function_estimation/resampled_data"

glob root "$DIR_REPO_LABOR"
glob output "$DIR_FIG/mc/"


*Load in GMTanom data file, save as a tempfile 
insheet using "$DB_data/projection_system_outputs/damage_function_estimation/GMTanom_all_temp_2001_2010.csv", comma names clear
drop if year < 2015 | year > 2099
tempfile GMST_anom
save `GMST_anom', replace

* **********************************************************************************
* * STEP 1: Pull in Damage CSVs and Merge with GMST Anomaly Data
* **********************************************************************************
loc type = "wages"

import delimited "$ROOT_INT_DATA/projection_outputs/extracted_data_mc/SSP`ssp'-valuescsv_wage_global.csv", varnames(1) clear
drop if year < 2015 | year > 2099
replace value = value / 1000000000000

merge m:1 year gcm rcp using `GMST_anom', nogen assert(3)
tempfile master
save `master', replace

qui bysort year: egen minT=min(temp)
qui bysort year: egen maxT=max(temp)
qui replace minT=round(minT,0.1)
qui replace maxT=round(maxT,0.1)
qui keep year minT maxT
qui duplicates drop year, force

merge 1:m year using `master', nogen assert(3)


* **********************************************************************************
* * STEP 2: Estimate damage functions and plot, pre-2100
* **********************************************************************************

cap rename temp anomaly

* Use this local to determine whether we want consistent scales across other energy
* and electricity plots

loc title = "Labor"
loc ytitle = "Trillion USD"


   * Nonparametric model for use pre-2100 
foreach yr of numlist 2099/2099 {
        qui reg value c.anomaly##c.anomaly if year>=`yr'-2 & year <= `yr'+2 
        cap qui predict yhat_`yr' if year>=`yr'-2 & year <= `yr'+2 
        qreg value  c.anomaly##c.anomaly if year>=`yr'-2 & year <= `yr'+2, quantile(0.05)
      predict y05_`yr' if year>=`yr'-2 & year <= `yr'+2
      qreg `fuel'  c.anomaly##c.anomaly if year>=`yr'-2 & year <= `yr'+2, quantile(0.95)
      predict y95_`yr' if year>=`yr'-2 & year <= `yr'+2
 
}

loc gr
loc gr `gr' sc valie anomaly if rcp=="rcp85" & year>=2095, mlcolor(red%30) msymbol(O) mlw(vthin) mfcolor(red%30) msize(vsmall) ||       
loc gr `gr' sc value anomaly if rcp=="rcp45"& year>=2095, mlcolor(ebblue%30) msymbol(O) mlw(vthin) mfcolor(ebblue%30) msize(vsmall)   ||
loc gr `gr' line yhat_2099 anomaly if year == 2099 , yaxis(1) color(black) lwidth(medthick) ||
loc gr `gr' rarea y95_2099 y05_2099 anomaly if year == 2099 , col(grey%5) lwidth(none) ||

di "Graphing time..."
sort anomaly
graph twoway `gr', yline(0, lwidth(vthin)) ///
      ytitle(`ytitle') xtitle("GMST Anomaly") ///
        legend(order(1 "RCP 8.5" 2 "RCP 4.5" 3 "2099 damage fn.") size(*0.5)) name("`fuel'", replace) ///
        xscale(r(0(1)10)) xlabel(0(1)10) scheme(s1mono) ///
        title("`title' Damage Function, End of Century", tstyle(size(medsmall)))  ///
        yscale(r(`ymin'(`ystep')`ymax')) ylabel(`ymin'(`ystep')`ymax')  
        
capture drop vbl

* Display the slope of this damage function in 2099
loc yr 2099
qui sum anomaly if year>=`yr'-2 & year <= `yr'+2 
loc xmax = r(max)
loc xmin = r(min)
loc Dx = r(max) - r(min)
sum yhat_`yr' if year>=`yr'-2 & year <= `yr'+2 
loc Dy = r(max) - r(min)
loc slope = `Dy'/`Dx'
di "average slope is `slope'"

graph export "$output/damage_function_2099_SSP3.pdf", replace 
restore


**********************************************************************************
* STEP 3: HISTOGRAMS OF GMSTs 
**********************************************************************************

loc bw = 0.4
tw kdensity anomaly if rcp=="rcp45" & year>=2080, color(edkblue) bw(`bw') || ///
   kdensity anomaly if rcp=="rcp85" & year>=2080, color(red*.5) bw(`bw') || , /// 
   legend ( lab(1 "rcp45") lab(2 "rcp85")) scheme(s1mono) ///
   xtitle("Global mean temperature rise") 

graph export "$output/anomaly_densities_GMST_end_of_century.pdf", replace 
graph drop _all




