/*

Purpose: Figure 4 plotting, for energy sector total end of century damages 

*/

clear all
set more off
set scheme s1color


do "/home/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"

glob DB_data "/mnt/CIL_energy/code_release_data_pixel_interaction"

glob root "$DIR_REPO_LABOR"
glob output "$DIR_FIG/mc/"


*Load in GMTanom data file, save as a tempfile 
insheet using "$DB_data/projection_system_outputs/damage_function_estimation/GMTanom_all_temp_2001_2010.csv", comma names clear
drop if year < 2010 | year >= 2099
tempfile GMST_anom
save `GMST_anom', replace

* **********************************************************************************
* * STEP 1: Pull in Damage CSVs and Merge with GMST Anomaly Data
* **********************************************************************************

import delimited "$ROOT_INT_DATA/projection_outputs/extracted_data_mc/SSP3-valuescsv_wage_global.csv", varnames(1) clear
drop if year < 2010 | year >= 2099
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
ren *alue wages
replace wages = -wages / 1000000000000
save `master', replace


* **********************************************************************************
* * STEP 2: Estimate damage functions and plot, pre-2100
* **********************************************************************************

cap rename temp anomaly

* Use this local to determine whether we want consistent scales across other energy
* and electricity plots
loc title = "Total Dollar Value"
loc ytitle = "Trillion USD"

* Nonparametric model for use pre-2100 
foreach yr of numlist 2015/2098 {
        qui reg wages c.anomaly##c.anomaly if year>=`yr'-2 & year <= `yr'+2 
        cap qui predict yhat_wages_`yr' if year>=`yr'-2 & year <= `yr'+2 
}

di "Graphing time..."
sort anomaly

loc gr
*loc gr `gr' sc wages anomaly if rcp=="rcp85" & year>=2095, mlcolor(red%30) msymbol(O) mlw(vthin) mfcolor(red%30) msize(vsmall) ||       
*loc gr `gr' sc wages anomaly if rcp=="rcp45"& year>=2095, mlcolor(ebblue%30) msymbol(O) mlw(vthin) mfcolor(ebblue%30) msize(vsmall)   ||
foreach yr of numlist 2150 2200 2250 2300 {
	loc gr `gr' line yhat_wages_`yr' anomaly if year == `yr' , yaxis(1) color(black) lwidth(medthick) ||
*	loc gr `gr' line y anomaly if year == `yr', color(gs5*.5) ||
}

*graph twoway `gr', yline(0, lwidth(vthin)) ytitle(`ytitle') xtitle("GMST Anomaly") legend(order(1 "RCP 8.5" 2 "RCP 4.5" 3 "2098 damage fn.") size(*0.5)) name("wages", replace) xscale(r(0(1)10)) xlabel(0(1)10) yscale(r(0(10)50)) ylabel(0(10)50) scheme(s1mono) title("`title' Damages, End of Century", tstyle(size(medsmall)))  
*graph export "$output/damages_without_function.pdf", replace 

*loc gr `gr' line yhat_wages_2098 anomaly if year == 2098 , yaxis(1) color(black) lwidth(medthick) ||

graph twoway `gr', yline(0, lwidth(vthin)) ytitle(`ytitle') xtitle("GMST Anomaly") legend(order(1 "RCP 8.5" 2 "RCP 4.5" 3 "2098 damage fn.") size(*0.5)) name("wages", replace) xscale(r(0(1)10)) xlabel(0(1)10) yscale(r(0(10)50)) ylabel(0(10)50) scheme(s1mono) title("`title' Damage Function, End of Century", tstyle(size(medsmall)))  
graph export "$output/damages_with_function_over_time.pdf", replace 
        
graph drop _all
