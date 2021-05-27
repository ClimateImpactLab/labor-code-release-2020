/*

Purpose: Figure 3C plotting, to show evolution of total energy damage function over time

*/

**********************************************************************************
* 1 SET UP -- Change paths and input choices to fit desired output
**********************************************************************************

clear all
set more off
set scheme s1color


glob DB "/mnt"

glob DB_data "$DB/Global_ACP/damage_function"

do "/home/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"

glob root "$DIR_REPO_LABOR"
glob output "$DIR_FIG/mc/"


* **********************************************************************************
* 2 Feather plot for pre- and post-2100 damage functions
* **********************************************************************************

* import and reformat the gmst anomaly data, used for defining the range of GMST we plot each damage funciton for 
insheet using "$DB_data/GMST_anomaly/GMTanom_all_temp_2001_2010_smooth.csv", comma names clear
drop if temp == .
tempfile GMST_anom
save `GMST_anom', replace
preserve
  qui bysort year: egen minT=min(temp)
  qui bysort year: egen maxT=max(temp)
  qui replace minT=round(minT,0.1)
  qui replace maxT=round(maxT,0.1)
  qui keep year minT maxT
  qui duplicates drop year, force
  tempfile ref
  qui save `ref', replace
restore

* Load in damage function coefficients
insheet using "$DIR_REPO_LABOR/output/damage_function_no_cons/ce_betas_SSP3.csv", comma names clear 

* Create expanded dataset by valuation and by year
* Just keep data every 5 years
gen roundyr = round(year, 5)
keep if year==roundyr
drop roundyr

* Expand to get obs every quarter degree
expand 40, gen(newobs)
sort year

* Generate anomaly and prediction for every quarter degree
bysort year: gen anomaly = _n/4
gen y = beta1*anomaly + beta2*anomaly^2


* convert to trillion
*replace y = y / 1000


* Merge in range and drop unsupported temperature 
merge m:1 year using `ref'
qui replace y=. if anomaly<minT & year<=2099
qui replace y=. if anomaly>maxT & year<=2099

* initialise graphing local
loc gr 
* Pre-2100 nonparametric lines
foreach yr of numlist 2015(10)2099 {
di "`yr'"
loc gr `gr' line y anomaly if year == `yr', color(edkblue) ||
}

* Post-2100 extrapolation line
foreach yr of numlist 2150 2200 2250 2300 {
loc gr `gr' line y anomaly if year == `yr', color(gs5*.5) ||
}

* 2100 line
loc gr `gr' line y anomaly if year == 2100, color(black) ||
sort anomaly

* Plot and save
graph tw `gr', yline(0, lwidth(vthin)) ///
  ytitle("Trillion 2019 USD" ) xtitle("GMST Anomaly") ///
  title("Total Labor Damage Function No Constant CE, Evolution Over Time", size(small)) ///
  xscale(r(0(1)10)) xlabel(0(1)10) legend(off) scheme(s1mono) ///
  ylabel(, labsize(small)) 

graph export "$output/fig_3C_labor_damage_function_nocons_evolution_SSP3_ce.pdf", replace 
graph drop _all
graph twoway `gr', yline(0, lwidth(vthin)) ytitle(`ytitle') xtitle("GMST Anomaly") legend(order(1 "RCP 8.5" 2 "RCP 4.5" 3 "2098 damage fn.") size(*0.5)) name("wages", replace) xscale(r(0(1)10)) xlabel(0(1)10) yscale(r(0(10)50)) ylabel(0(10)50) scheme(s1mono) title("`title' Damage Function No Constant, End of Century", tstyle(size(medsmall)))  
graph export "$output/damages_with_function_nocons_over_time_ce.pdf", replace 
        
graph drop _all
