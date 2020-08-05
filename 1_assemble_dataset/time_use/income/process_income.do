/*=======================================================================
Creator: Greg Dobbels, gdobbels@uchicago.edu
Date last modified: 08/19/2019
Last modified by: Simon Greenhill -- modify to keep LaPorta adm0 gdppc 
Purpose: 
	Downscale Penn World Tables national level income panel to subnational 
	units. 
		- EU: Use avg ratio of national income to NUTS2 level income to 
			define a scaling factor
		- everywhere else: 
			1) interpolate the incomplete subnational income panel compiled 
				by La Porta
			2) Use time-varying ratio of national income to subnational 
				income in LaPorta data to define scaling factors

Notes:
	Downscaling of Penn World Tables chosen over raw LaPorta data due to 
	inconsistencies in LaPorta data, global coverage, temporal coverage,
	and unit consistency 

==========================================================================*/

* TO DO: FIGURE OUT HOW TO HANDLE DUPLICATES ACROSS LA PORTA AND EU DATA. 
* AFTER THAT, THIS SHOULD BE READY TO BE PASSED ON TO DOWNSCALING.

*************************************************************************
* 							PART A. Initializing						*			
*************************************************************************

clear all
set more off
set varabbrev off
cap set processors 12
set maxvar 32767
pause off
cap ssc install unique

cilpath 
local lab       "$DB/Global ACP/labor/"
global Inc_DATA "$DB/Global ACP/MORTALITY/Replication_2018/2_Data"

*************************************************************************
* 				PART B. Import Pen World Tables Data					*			
*************************************************************************

* import Penn World Tables Country-level data 
use "$Inc_DATA/Raw/Income/PennWorldTables/pwt90.dta", clear

* get the inflation factor
preserve
	keep if countrycode == "USA" & year == 2005
	local price_level = pl_gdpo
restore

* cleanup
gen gdppc_adm0_PWT = `price_level' * rgdpna/pop 
keep countrycode country year gdppc_adm0_PWT 
drop if gdppc_adm0_PWT  == .

tempfile pwt 
save `pwt'


*********************************************************************************
* 			PART C. Import La Porta Data, EU Data & interpolate					*			
*********************************************************************************

* Note that in this section we deal with missing data in several different ways: 
* 	step (to mimic what was previously done)
* 	linear 
* 	linear interpolation, log extrapolation
* Ultimately, we move forward with linear interpolation, log extrapolation. 
* Other methods are kept for diagnostic purposes. 

* LA PORTA
**********

import delimited "$Inc_DATA/Raw/Income/LaPorta/Gennaioli2014_full.csv", clear

* housekeeping
rename code countrycode 
keep countrycode country region year gdppc*

* set max year as 2014
local new = _N + 1
set obs `new'
replace year = 2014 if year == .
replace countrycode = "ALB" if year == 2014
replace region = "Berat" if year == 2014
replace country = "Albania" if year == 2014

* merge "Germany" WDI data to "Germany, east" & "Germany, west"
replace countrycode = "DEU" if countrycode == "BRD" | countrycode == "DDR"

rename gdppccountry gdppc_adm0
rename gdppcstate gdppc_adm1

gen source = "La Porta"

tempfile laporta 
save `laporta'

* EU
****
* import iso-2 to iso-3 crosswalk
import delimited "$Inc_DATA/Raw/Income/EU/countries_codes_and_coordinates.csv", clear varnames(1)
foreach var in alpha2code alpha3code {
	replace `var' = subinstr(`var',`"""',"",.)
	replace `var' = subinstr(`var'," ","",.)
}
rename alpha2code iso2 
rename alpha3code iso3 
keep country iso2 iso3

*update codes to match EU data 
replace iso2 = "UK" if iso2 == "GB"
replace iso2 = "EL" if iso2 == "GR"

* duplicates indicate multiple spellings of a country 
duplicates drop iso2 iso3, force 

tempfile iso_xwalk 
save `iso_xwalk'

* import NUTS_2 gdppd and create downscaling factor to 
* 	apply to Penn world tables national figures
import delimited "$Inc_DATA/Raw/Income/EU/nama_10r_2gdp.tsv", delimit(tab) clear

* rename year columns
forvalues ii = 2/18 {
	local yr = 2018 - `ii'
	rename v`ii' gdppc`yr'
}

* drop column names imported in the first rownumb
drop if v1 == "unit,geo\time"

* split identifier string variable & clean up var names
split v1, parse(",")
rename v11 unit 
rename v12 NUTS_ID

* keep purchasing power parity units (to enable comparison w/in year)
* "PPS_HAB" = Purchasing power standard (PPS) per inhabitant
keep if unit == "PPS_HAB" 
drop unit v1 

* reshape into a standard format
reshape long gdppc, i(NUTS_ID) j(year)

* convert gdppc to numeric 
replace gdppc = subinstr(gdppc," ","",.)
replace gdppc = subinstr(gdppc,":","",.)
* ie. use estimate figures
replace gdppc = subinstr(gdppc,"e","",.)


* merge national figures with subnational
preserve 
	keep if strlen(NUTS_ID) == 2
	rename NUTS_ID iso2
	rename gdppc national_gdppc 
	tempfile NUTS0
	save `NUTS0'
restore 

keep if strlen(NUTS_ID) == 3
gen iso2 = substr(NUTS_ID,1,2)
merge m:1 iso2 year using `NUTS0', assert(3) nogen 

* merge in alpha-3 iso codes 
merge m:1 iso2 using "`iso_xwalk'", assert(2 3) keep(3) nogen

rename gdppc gdppc_adm1
rename national_gdppc gdppc_adm0
rename NUTS_ID region
gen source = "EU Data"

keep iso3 region country year gdppc_adm0 gdppc_adm1 source
duplicates drop 
rename iso3 countrycode

destring gdp*, replace force

append using `laporta'

* INTERPOLATION
****************

* get a region id 
egen pid = group(countrycode country region)

* fill in the time series
xtset pid year
tsfill, full
sort pid year

* loop over ids to fill in countrycode, country, region
qui sum pid
forval i=1(1)`r(max)' {
	qui levelsof countrycode if pid == `i', loc(cc)
	qui replace countrycode = `cc' if pid == `i' & countrycode == ""

	qui levelsof country if pid == `i', loc(c)
	qui replace country = `c' if pid == `i' & country == ""

	qui levelsof region if pid == `i', loc(r)
	qui replace region = `r' if pid == `i' & region == ""
} 

* linear interpolation in sample
sort pid year
by pid: ipolate gdppc_adm0 year, gen(gdppc_adm0_infill)
by pid: ipolate gdppc_adm1 year, gen(gdppc_adm1_infill)

* logarithmic extrapolation of adm0 growth rates out of sample 
gen log_gdppc_adm0 = log(gdppc_adm0)
gen log_gdppc_adm1 = log(gdppc_adm1)

by pid: ipolate log_gdppc_adm0 year, gen(log_gdppc_adm0_infill) epolate
by pid: ipolate log_gdppc_adm1 year, gen(log_gdppc_adm1_infill) epolate
by pid: replace gdppc_adm0_infill = exp(log_gdppc_adm0_infill) if gdppc_adm0_infill == .

* use extrapolated adm0 growth rate to extrapolate adm1 growth rates
* Note this assumes the distribution of income within a country remains the same in the extrapolation
by pid: gen gdppc_adm0_growthrate = (gdppc_adm0_infill - gdppc_adm0_infill[_n - 1]) / gdppc_adm0_infill[_n - 1]
by pid: replace gdppc_adm0_growthrate = gdppc_adm0_growthrate[_n - 1] if mi(gdppc_adm0_growthrate)

by pid: replace gdppc_adm1_infill = gdppc_adm1_infill[_n-1] * (1 + gdppc_adm0_growthrate) if mi(gdppc_adm1_infill)

by pid: gen gdppc_adm0_backgrowthrate = (gdppc_adm0_infill[_n - 1] - gdppc_adm0_infill[_n]) / gdppc_adm0_infill[_n]

qui unique pid
local N = r(unique)

loc i 10^10
* loop until we have only one missing per region (the first obs)
while `i' > `N' {
	by pid: replace gdppc_adm1_infill = gdppc_adm1_infill[_n+1] * (1 + gdppc_adm0_backgrowthrate) if mi(gdppc_adm1_infill)

	qui count if mi(gdppc_adm1_infill)
	loc i = r(N)
}

pause

*************************************************************************
* 						PART E. Merge & rescale							*			
*************************************************************************

* merge in PWT data 
merge m:1 countrycode year using `pwt', nogen 

* clean up 
label var gdppc_adm0 "raw ADM0 level income data (source: La Porta/EU)"
label var gdppc_adm1 "raw ADM1 level income data (source: La Porta/EU)"
label var gdppc_adm0_infill "interpolated ADM0 level income data (source: La Porta/EU)"
label var gdppc_adm1_infill "interpolated ADM1 level income data (source: La Porta/EU)"
label var gdppc_adm0_PWT "ADM0 level income data from PWT"
label var region "Region name"
label var countrycode "alpha-3 iso code"

* save output -- note: other users may want to change this path

save "`lab'/replication/1_preparation/covariates/income/pwt_income_adm1.dta", replace

