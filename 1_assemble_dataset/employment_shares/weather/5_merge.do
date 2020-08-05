* 5. Merge prepared climate data
* Author: Simon Greenhill, sgreenhill@uchicago.edu (adapted from Tom's migration code)
* Date: 9/12/2019

* This code merges together climate data from all our countries and produces a long dataset

clear all
set more off

cilpath
loc laborDB 	"$DB/Global ACP/labor/"
loc laborStub	$SHARES/estimation/labor/employment_shares_data/climate_data/
loc laborPath 	`laborStub'/1_raw
loc migPath	$SHARES/estimation/migration/data/1_raw

cap log close

******************************************
* 1. merge across years within a country *
******************************************

* set params
loc polynomials 	"1 2 3 4"
loc weights 	"pop"
loc clim 		"GMFD"
loc name 		"gmfd"
loc adm			1
loc parameters  "tavg prcp"
loc test_mode 	1

import delim using "`laborDB'/1_preparation/employment_shares/data/required_clim_data.csv", clear

drop if required_end < 1948

replace country = subinstr(country, " ","_",.)
levelsof country, local(countries)

if `test_mode' == 1 {
	loc countries "`countries'"
        pause on
        set trace off
}
else {
    loc date = subinstr(c(current_date), " ", "_", .)
    log using $REPO/gcp-labor/1_Cleaning/employment_shares/weather/log/5_`date'.log, replace
}

foreach c in `countries' {
	di "----prepping `c'----"
	import delim using "`laborDB'/1_preparation/employment_shares/data/required_clim_data.csv", clear
	replace country = subinstr(country, " ","_",.)

	keep if country == "`c'"
        
        loc already_generated = already_generated[1]
	if `already_generated' == 1 {
		loc path `migPath'/`c'_adm`adm'/climate/weather_data/csv_monthly
                
                import delim using "/mnt/norgay_synology_drive/Wilkes_InternalMigrationGlobal/internal/Data/Raw/supplements/code_keys/internal_required_clim_data.csv", clear
                replace country = subinstr(country, " ", "_", .)
                keep if country == "`c'"
	}
	else {
		loc path `laborPath'/`c'_adm`adm'/climate/weather_data/csv_monthly
	}

	replace required_end = 2010 if required_end > 2010
        replace required_start = 1948 if required_start < 1948

        assert _N == 1
	loc y_start = required_start[1]
	loc y_end = required_end[1]

	* initialize count of parameters 
	local i = 0

	foreach param in `parameters' {
		foreach poly in `polynomials' {
			foreach weight in `weights' {
                        di "START YEAR: `y_start'"
				loc y = `y_end'
				* loop over year chunk files to merge into a single dataset for that country
				while `y' >= `y_start' {
					loc y2 = `y' - 4
					if `y2' > `y_start' {
						di "`path'/`clim'_`param'_poly_`poly'_v2_`y2'_`y'_monthly_`weight'wt.csv"
						import delimited using "`path'/`clim'_`param'_poly_`poly'_v2_`y2'_`y'_monthly_`weight'wt.csv", clear case(pres)
						tempfile `clim'_`param'_`poly'_`y2'_`y'_`weight'
						save ``clim'_`param'_`poly'_`y2'_`y'_`weight'', replace
					}
					else {
						import delimited using "`path'/`clim'_`param'_poly_`poly'_v2_`y_start'_`y'_monthly_`weight'wt.csv", clear case(pres)
						tempfile `clim'_`param'_`poly'_`y_start'_`y'_`weight'
						save ``clim'_`param'_`poly'_`y_start'_`y'_`weight'', replace
					}
					loc y = `y' - 5
				} // end of while loop

				* merge together the datasets
				loc y = `y_end'
				loc y2 = `y_end' - 4

				use ``clim'_`param'_`poly'_`y2'_`y'_`weight'', clear

				loc y = `y_end' - 5

				while `y' >= `y_start' {
					local y2 = `y' - 4
					if `y2' > `y_start' {
						merge 1:1 GEOLEVEL`adm' using ``clim'_`param'_`poly'_`y2'_`y'_`weight'', gen(_z`y')
						assert _z`y' == 3
						drop _z`y'
					}
					else {
						merge 1:1 GEOLEVEL`adm' using ``clim'_`param'_`poly'_`y_start'_`y'_`weight'', gen(_z`y')
						assert _z`y' == 3
						drop _z`y'
					}

					local y = `y'-5
				} // end of while loop

				* reshape to be long by month, and then by year
				***********************************************

				* create variable name stubs for reshape
				local month_stubs ""
				forvalues yr = `y_start'/`y_end'  {
					local month_stubs `month_stubs' y`yr'_m
				}

				* reshape, months first
				reshape long `month_stubs', i(GEOLEVEL1) j(month) string

				* get rid of leading zeros
				destring month, replace 

				* cleanup 
				rename *_m *
				rename y* `clim'_`param'_`poly'_`weight'*

				* reshape years
				reshape long `clim'_`param'_`poly'_`weight', i(GEOLEVEL1 month) j(year)

                                cap confirm numeric var GEOLEVEL`adm'
                                if _rc != 0 {
                                    * pause
                                    encode GEOLEVEL`adm', gen(geo_n)
                                    drop GEOLEVEL`adm'
                                    rename geo_n  GEOLEVEL`adm'
                                }
				tempfile myfile`i'
				save `myfile`i''

				* increment parameter counter
				loc ++i
			} // end of weights loop
		} // end of poly loop	
	} // end of parameter loop

	* merge all parameters together
	* (in other words, combine prcp, tavg, etc.)
	use `myfile0', clear
	local --i
	forval j = 1/`i' {
		merge 1:1 GEOLEVEL`adm' year month using `myfile`j'', nogen assert(3)


                tempfile `c'_adm`adm'
                save ``c'_adm`adm''
	}

	di "----tempfile saved, done with `c'----"
} // end of country loop

************************************************************
* 2. append all the countries together, clean up, and save *
************************************************************

* append
local first_cntry `: word 1 of `countries''
di "`first_cntry'"
use ``first_cntry'_adm1', clear

drop if _n > 0
foreach c in `countries' {
	append using ``c'_adm1'
}

* clean up
rename (`clim'_*) (*)
rename GEOLEVEL1 geolevel1

* save
cap shell mkdir -p `laborStub'/2_intermediate/
export delim "`laborStub'/2_intermediate/`clim'_adm1_internal", replace
