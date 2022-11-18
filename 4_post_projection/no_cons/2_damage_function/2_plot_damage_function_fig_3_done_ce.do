/*

Purpose: plot labor end-of-century damage function (no constant) 
with points, curve, and confidence interval


*/

clear all
set more off
set scheme s1color


glob DB "/mnt"

glob DB_data "$DB/Global_ACP/damage_function"

do "/home/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"

glob output "$DIR_FIG/mc/"


*Load in GMTanom data file, save as a tempfile 
insheet using "$DB_data/GMST_anomaly/GMTanom_all_temp_2001_2010_smooth.csv", comma names clear
drop if year < 2010 | year > 2099
drop if temp == .
tempfile GMST_anom
save `GMST_anom', replace

* **********************************************************************************
* * STEP 1: Pull in Damage CSVs and Merge with GMST Anomaly Data
* **********************************************************************************
loc type = "wages"

*import delimited "$ROOT_INT_DATA/projection_outputs/extracted_data_mc/SSP3-valuescsv_wage_global.csv", varnames(1) clear
import delimited "/mnt/CIL_labor/6_ce/risk_aversion_constant/risk_aversion_constant_damage_function_points.csv", varnames(1) clear
drop if year < 2010 | year > 2099
rename global_damages_constant value
drop if ssp != "SSP3"
replace value = value / 1000000000000

merge m:1 year gcm rcp using `GMST_anom', nogen keep(3)
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


loc title = "Labor"
loc ytitle = "Trillion USD"
loc ystep = 10
loc ymax = 40 
loc ymin = -10

   * Nonparametric model for use pre-2100 
foreach yr of numlist 2099/2099 {
      qui reg value c.anomaly##c.anomaly if year>=`yr'-2 & year <= `yr'+2, nocons
      cap qui predict yhat_`yr' if year>=`yr'-2 & year <= `yr'+2 
    
      * use weights to trick qreg into running noconstant
      gen anomaly2 = anomaly * anomaly
      gen qanomaly = anomaly / anomaly2
      gen qvalue = value / anomaly2
      qreg qvalue  c.qanomaly if year>=`yr'-2 & year <= `yr'+2 [pweight = anomaly2], quantile(0.05)
      gen y05_`yr' = _b[qanomaly] * anomaly + _b[_cons] * anomaly2  if year>=`yr'-2 & year <= `yr'+2
      qreg qvalue  c.qanomaly if year>=`yr'-2 & year <= `yr'+2 [pweight = anomaly2], quantile(0.95)
      gen y95_`yr' = _b[qanomaly] * anomaly + _b[_cons] * anomaly2  if year>=`yr'-2 & year <= `yr'+2
      
 
}

loc gr
loc gr `gr' sc value anomaly if rcp=="rcp85" & year>=2095, mlcolor(red%30) msymbol(O) mlw(vthin) mfcolor(red%30) msize(vsmall) ||       
loc gr `gr' sc value anomaly if rcp=="rcp45"& year>=2095, mlcolor(ebblue%30) msymbol(O) mlw(vthin) mfcolor(ebblue%30) msize(vsmall)   ||
loc gr `gr' line yhat_2099 anomaly if year == 2099 , yaxis(1) color(black) lwidth(medthick) ||
loc gr `gr' rarea y95_2099 y05_2099 anomaly if year == 2099 , col(grey%5) lwidth(none) ||

di "Graphing time..."
sort anomaly
graph twoway `gr', yline(0, lwidth(vthin)) ///
      ytitle(`ytitle') xtitle("GMST Anomaly") ///
        legend(order(1 "RCP 8.5" 2 "RCP 4.5" 3 "2099 damage fn.") size(*0.5)) name("wages", replace) ///
        xscale(r(0(1)10)) xlabel(0(1)10) scheme(s1mono) ///
        title("`title' CE Damage Function, End of Century", tstyle(size(medsmall)))  ///
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

graph export "$output/damage_function_nocons_2099_SSP3_ce.pdf", replace 

