*****************************************
* Quantile regression for SCC uncertainty 
* CALCULATION INCLUDING POST-2100 EXTRAPOLATION
*****************************************
/* 
This script does the following:
  * 1) Pulls in a .csv containing damages at global or impact region level. The .csv 
      should be SSP-specific, and contain damages in current year USD for every
      RCP-GCM-IAM-year combination. 
  * 2) Runs a quantile regression in which the quantiles of the damage function are 
      nonparametrically estimated for each year 't'
      using data only from the 5 years around 't'
  * 3) Runs a second regression in which GMST is interacted linearly with time. 
  * 4) Predicts quantile regression coefficients for all years 2015-2300, with post-2100 extrapolation 
      conducted using the linear temporal interaction model and pre-2100 using the nonparametric model
  * 5) Saves a csv of quantile regression coefficients to be used by the SCC uncertainty calculation derived from the FAIR 
      simple climate model
*/
**********************************************************************************
* SET UP -- Change paths and input choices to fit desired output
**********************************************************************************

clear all
set more off
set scheme s1color


glob DB "/mnt"

glob DB_data "$DB/Global_ACP/damage_function"

do "/home/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"
do "$DIR_REPO_LABOR/0_subroutines/paths.do"

glob output "$DIR_FIG/mc/"

* SSP toggle - options are "SSP2", "SSP3", or "SSP4"
loc ssp = "SSP3" 

* Model toggle  - options are "main", "lininter", or "lininter_double"
loc model = "main"

* What year do we use data from for determining DF estimates used for the out of sample extrapolation
loc subset = 2085


loc model_tag = ""


**********************************************************************************

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

import delimited "$ROOT_INT_DATA/projection_outputs/extracted_data_mc/SSP3-valuescsv_wage_global.csv", varnames(1) clear
drop if year < 2010 | year > 2099
replace value = -value / 1000000000000
loc conversion_value_2005_to_2020 = 113.625 / 87.421
replace value = value * `conversion_value_2005_to_2020'


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

* What year do we use data from for determining DF estimates used for the out of sample extrapolation
loc subset = 2085

**  INITIALIZE FILE WE WILL POST RESULTS TO
capture postutil clear
tempfile coeffs
postfile damage_coeffs str20(var_type) year pctile beta1 beta2 anomalymin anomalymax using "`coeffs'", replace   


** Regress, and output coeffs 
gen t = year-2010

timer clear
timer on 1



* use weights to trick qreg into running noconstant
gen anomaly2 = anomaly * anomaly
gen qanomaly = anomaly / anomaly2
gen qvalue = value / anomaly2



forvalues pp = 5(5)95 {
  di "`pp'"
  loc p = `pp'/100
  loc quantiles_to_eval "`quantiles_to_eval' `p'"
}
di "`quantiles_to_eval'"


foreach vv in value {
  foreach pp of numlist `quantiles_to_eval' {
    di "`pp'"
    * Nonparametric model for use pre-2100 
    foreach yr of numlist 2015/2099 { 
      di "`vv' `yr' `pp'"   
      * Need to save the min and max temperature for each year for plotting
      qui summ anomaly if year == `yr', det 
      loc amin = `r(min)'
      loc amax =  `r(max)'
      

      cap qui qreg qvalue  c.qanomaly if year>=`yr'-2 & year <= `yr'+2 [pweight = anomaly2], quantile(`pp')
      

      if _rc!=0 {
        di "didn't converge first time, so we are upping the iterations and trying again"
        cap qui qreg qvalue  c.qanomaly if year>=`yr'-2 & year <= `yr'+2 [pweight = anomaly2], quantile(`pp') wlsiter(20)
        if _rc!=0 {
          di "didn't converge second time, so we are upping the iterations and trying again"
          cap qui qreg qvalue  c.qanomaly if year>=`yr'-2 & year <= `yr'+2 [pweight = anomaly2], quantile(`pp')) wlsiter(40)
          if _rc!=0 {
            di "didn't converge after trying some pretty high numbers for iterations - somethings probably wrong here!"
            break
          }
        }
      }
    
      * Save coefficients for all years prior to 2100
      post damage_coeffs ("`vv'") (`yr') (`pp') (_b[qanomaly]) (_b[_cons]) (`amin') (`amax')
    }
    
    * Linear extrapolation for years post-2100 
    cap qui qreg qvalue c.qanomaly#c.t if year>=`yr'-2 & year <= `yr'+2 [pweight = anomaly2], quantile(`pp')) wlsiter(40)
    * reg `vv' anomaly c.anomaly#c.t c.anomaly#c.anomaly c.anomaly#c.anomaly#c.t if year >= `subset' , nocons quantile(`pp')

    foreach yr of numlist 2100/2300 {
    
      di "`vv' `yr' `pp'"
      loc beta1 = _b[anomaly] + _b[c.anomaly#c.t]*(`yr'-2010)
      loc beta2 = _b[c.anomaly#c.anomaly] + _b[c.anomaly#c.anomaly#c.t]*(`yr'-2010)
      
      * NOTE: we don't have future min and max, so assume they go through all GMST values   
      post damage_coeffs ("`vv'") (`yr') (`pp') (`beta1') (`beta2') (0) (11)   
*    }
  }
}

postclose damage_coeffs
timer off 1
timer list
di "Time to completion = `r(t1)'"

**********************************************************************************
* STEP 3: WRITE AND SAVE OUTPUT 
**********************************************************************************
 
use "`coeffs'", clear
outsheet using "$DIR_REPO_LABOR/output/damage_function_no_cons/unmodified_betas/nocons_qreg_betas_`ssp'`model_tag'.csv", comma replace 



* **********************************************************************************
* * STEP 4: Pull in global consumption csv and save as tempfile
* **********************************************************************************

import delimited "$DIR_REPO_LABOR/output/damage_function_no_cons/unmodified_betas/global_consumption_new.csv", encoding(Big5) clear

rename global_cons_constant_model_colla global_consumption

keep ssp year global_consumption 

sum global_consumption if year == 2099
loc gc_2099 = `r(mean)'

gen ratio = global_consumption/`gc_2099' if year >= 2100
  
tempfile consumption
save `consumption', replace

*****************************************************************************************

import delimited "$DIR_REPO_LABOR/output/damage_function_no_cons/unmodified_betas/nocons_qreg_betas_`ssp'`model_tag'.csv", clear 

keep year pctile cons beta1 beta2  

merge 1:m year using `consumption'
keep if _m == 3
drop _m

foreach var in "beta1" "beta2"{
  sum `var' if year == 2099
  loc b_`var' = `r(mean)'
  replace `var' = `b_`var''*ratio if year > 2099
}

sum beta1 beta2, d

export delimited using "$DIR_REPO_LABOR/output/damage_function_no_cons/nocons_betas_SSP3.csv", replace 



