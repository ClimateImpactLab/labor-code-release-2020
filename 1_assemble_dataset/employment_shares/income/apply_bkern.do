* apply the bartlett and save final version of downscaled income data
* author: Simon Greenhill, sgreenhill@uchicago.edu
* date: 9/20/2019

* adapted from https://gitlab.com/ClimateImpactLab/Impacts/post-projection-tools/blob/income/income/apply_bkern.do

clear all
cilpath 
glo code_dir $REPO/migration/code

* change this for your sector
glo write_path "$DB/Global ACP/labor/1_preparation/employment_shares/data/income/"

* load program to Calculate triangular moving averages
do "$code_dir/0_programs/1_bkern.do"

import delimited "$write_path/income_downscaled.csv", clear

qui ds *gdp*
loc gdp_vars = r(varlist)

* fill in missings in each geolevel1 timeseries 
xtset geolevel1 year
tsfill

* replace the country name 
bysort geolevel1: replace country = country[1]
assert country != ""
* linearly interpolate the gdp variables 
foreach v of varlist `gdp_vars' {
	destring `v', replace force
	by geolevel1: ipolate `v' year, gen(`v'_fill)
	replace `v' = `v'_fill
	drop `v'_fill
}

* create logged versions of gdp variables
gen log_gdppc_adm0_pwt = log(gdppc_adm0_pwt)
gen log_gdp_adm0_pwt = log(gdp_adm0_pwt)
gen log_gdppc_adm1_pwt_ds = log(gdppc_adm1_pwt_downscaled)

* calculate income in various ways: 
* - 13 yr bartlett
* - 15 yr bartlett
* - 15 yr MA

* kernels
bkern "geolevel1" year y 1 "gdppc_adm0_pwt gdp_adm0_pwt gdppc_adm1_pwt_downscaled log_gdppc_adm0_pwt log_gdp_adm0_pwt log_gdppc_adm1_pwt_ds" 13
bkern "geolevel1" year y 1 "gdppc_adm0_pwt gdp_adm0_pwt gdppc_adm1_pwt_downscaled log_gdppc_adm0_pwt log_gdp_adm0_pwt log_gdppc_adm1_pwt_ds" 15

* MAs
tsset geolevel1 year
foreach var in gdppc_adm0_pwt gdp_adm0_pwt gdppc_adm1_pwt_downscaled log_gdppc_adm0_pwt log_gdp_adm0_pwt log_gdppc_adm1_pwt_ds {
	egen `var'_15ma = filter(`var'), lags(0/14) normalize
}

* save output
export delimited using "$write_path/income_downscaled_bartlett.csv", replace