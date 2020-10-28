*****************************************************************************************************
* Programs for: DAMAGE FUNCTION ESTIMATION FOR SCC -- CALCULATION INCLUDING POST-2100 EXTRAPOLATION
*****************************************************************************************************
*TO-DO: change back to 2099 
//Orginal Author: Tamma Carleton
*** NOTE: Updated 10-08-18 to include a constraint that the fitted functions pass
*** 	  through (0,0) where 0 on the x-axis refers to the 2001-2010 GMST value


/* 

Programs and their general purpose:
  * note: helper functions have not been designed to be called by other scripts
	* 1) [helper function] poly2_insample_damage_function: estimates a poly2 damage function for in sample years (2015-2098)
		* Runs a regression in which the damage function is nonparametrically estimated for each year 't'
			using data only from the 5 years around 't'
	* 2) [helper function] poly2_outsample_damage_function: estimates a poly2 damage function for out of sample years (2100-2300) 
		* Runs a regression in which GMST is interacted linearly with time. This regression uses
			only data from a later portion of the century, given irregular early year behavior documented
			in mortality
	* 3) get_df_coefs: output damage function coeffcients for 2015-2300 for all types of values 
		* Predicts damage function coefficients for all years 2015-2300, with post-2100 extrapolation 
			conducted using the linear temporal interaction model and pre-2100 using the nonparametric model
		* Saves a csv of damage function coefficients to be used by the SCC calculation derived from the FAIR 
			simple climate model

Functionality on the to do list:
	* 1) quantiles damage function regressions
	* 2) different poly order damage functions

Program parameter definitions:
  * note: for var*, * can be 1,2,3
	* var*_value [string]: takes on the values of var*_name's value in var*_list 
		this variable is only internally used. 
	* var*_list [string]: list of var* options (explanation by example below)
	* var*_name [string]: name of var* (explanation by example below)
	* subset [integer]: the damage function linearly interacted with time uses years `subset'-2098 of a given value for estimation
	* output_file [string]: df coefficients are saved at output_file... note: this name should not have a file type!! 
		ie don't put output_file = /path/to/file/name.dta or /path/to/file/name.csv instead put output_file = /path/to/file/name
	* polyorder [integer]: damage functino polynomial order
	* dropbox_path [string]: path to dropbox folders

To call get_df_coefs, you must format your damage data frame in a very particular way and load the data into Stata.
	* This formatting could be changed, but it seemed easiest for the current code base to maintain the formatting. 
	At a later point I think it could be changed.

Here are some guidelines for damage data frame formatting that hopefully help:
	* The data frame should have damages at the global or impact region level for a specific SSP. There should be an observation for every
	RCP-GCM-IAM-year combination for every year between 2010 and 2100.
	* The data frame header should look like this (note: model is an iam):
	
	| year | ssp | model | gcm | rcp | batch | cil_*_*_* ...

	There can be many different cil_*_*_* variables representing different types of damages. If you are only running the damage function code on 
	one type of damage you can just put place holders where the *'s are. 
	
	For example:
	
	In energy a set of cil_*_*_* variables might look like: cil_price014_pp_ss, cil_price03_pp_ss, cil_peakprice014_pp_ss
		pp and ss are just placeholders
		var1_list = " price014 price03 peakprice014 "
		var2_list = " pp "
		var3_list = " ss "
		var1_name = "price_scenario" //not positive this is the right name need to check D: 
		var2_name = "placeholder1"
		var3_name = "placeholder2"
	
	In mortality a set of cil_*_*_* variables might look like this: cil_vsl_epa_scaled, cil_vsl_epa_popavg, cil_vly_epa_scaled, cil_vly_epa_popavg
		var1_list = " vsl vly "
		var2_list = " epa "
		var3_list = " scaled popavg "
		var1_name = "age_adjustment"
		var2_name = "heterogeneity"
		var3_name = "placeholder2"
*/

program define poly2_insample_damage_function_qreg

syntax , var1_value(string) var2_value(string) var3_value(string) pp(integer)

	foreach yr of numlist 2015/2098 {
		
		di "Estimating damage function for `yr'..."
		* qui reg cil_`var1_value'_`var2_value'_`var3_value' c.anomaly##c.anomaly if year>=`yr'-2 & year <= `yr'+2 

		// get max and min GMST anomaly for damage function year
		qui summ anomaly if year == `yr', det 
		local amin = `r(min)'
		local amax =  `r(max)'


		cap qreg cil_`var1_value'_`var2_value'_`var3_value' c.anomaly##c.anomaly if year>=`yr'-2 & year <= `yr'+2, quantile(`pp')

		if _rc!=0 {
			di "didn't converge first time, so we are upping the iterations and trying again"
			cap qui areg cil_`var1_value'_`var2_value'_`var3_value' c.anomaly##c.anomaly if year>=`yr'-2 & year <= `yr'+2, quantile(`pp')
			if _rc!=0 {
				di "didn't converge second time, so we are upping the iterations and trying again"
				cap qui areg cil_`var1_value'_`var2_value'_`var3_value' c.anomaly##c.anomaly if year>=`yr'-2 & year <= `yr'+2, quantile(`pp')
				if _rc!=0 {
					di "didn't converge after trying some pretty high numbers for iterations - somethings probably wrong here!"
					break
				}
			}
		}


		di "Storing damage function coefficients for `yr'..."
		post damage_coeffs ("`var1_value'") ("`var2_value'") ("`var3_value'") (`pp') (`yr') (_b[_cons]) (_b[anomaly]) (_b[c.anomaly#c.anomaly]) (`amin') (`amax')
	}

end

program define poly2_outsample_damage_function_qreg

syntax , var1_value(string) var2_value(string) var3_value(string) subset(integer) pp(integer)

	// define time variable to regress 
	local base_year = 2010
	cap gen t = year - `base_year' // only generate if doesnt already exist

	di "Estimating damage function linearly interacted with time on values between `subset' and 2098..."
	*qui reg cil_`var1_value'_`var2_value'_`var3_value' c.anomaly##c.anomaly##c.t  if year >= `subset'
	cap qreg cil_`var1_value'_`var2_value'_`var3_value' c.anomaly##c.anomaly if year >= `subset', quantile(`pp')


	foreach yr of numlist 2099/2300 {

		di "Calculating damage function for `yr'..."

		loc cons = _b[_cons] + _b[t]*(`yr'-`base_year')
		loc beta1 = _b[anomaly] + _b[c.anomaly#c.t]*(`yr'-`base_year')
		loc beta2 = _b[c.anomaly#c.anomaly] + _b[c.anomaly#c.anomaly#c.t]*(`yr'-`base_year')
		
		di "Storing damage function coefficients for `yr'..."

		* NOTE: we don't have future min and max, so assume they go through all GMST values 	
		post damage_coeffs ("`var1_value'") ("`var2_value'") ("`var3_value'") (`pp') (`yr') (`cons') (`beta1') (`beta2') (0) (11)

	}
end


program define get_df_coefs_qreg
syntax , output_file(string) var1_list(string) var2_list(string) var3_list(string) var1_name(string) var2_name(string) var3_name(string) polyorder(integer) subset(integer) dropbox_path(string) pp(integer)
	

	di "Ensuring functionality exists for poly`polyorder' damage functions."
	assert `polyorder' == 2 // other functionality not developed yet

	di "Merging in GMST anomalies..."

	preserve 
		insheet using "`dropbox_path'/Global ACP/damage_function/GMST_anomaly/GMTanom_all_temp_2001_2010.csv", comma clear
		rename temp anomaly
		tempfile GMST_anoms
		save `GMST_anoms', replace
	restore
	
	merge m:1 year rcp gcm using `GMST_anoms'
	drop if year < 2010
	drop if _merge != 3
	assert _merge == 3
	drop _merge


	di "Setting up postfile..."

	postfile damage_coeffs str10(`var1_name') str10(`var2_name') str10(`var3_name') year cons beta1 beta2 anomalymin anomalymax using "`output_file'", replace

	di "Storing damage function coefficients for all value types..."
	foreach var1 in `var1_list' {
		foreach var2 in `var2_list' {
			foreach var3 in `var3_list' {
				
				di "Storing damage function coefficients for `var1' `var2' `var3'..."

				di "Storing insample poly`polyorder' damage function coefficients..."
				poly`polyorder'_insample_damage_function_qreg , var1_value("`var1'") var2_value("`var2'") var3_value("`var3'") pp(`pp')
				
				di "Storing outsample poly`polyorder' damage function coefficients..."
				poly`polyorder'_outsample_damage_function_qreg , var1_value("`var1'") var2_value("`var2'") var3_value("`var3'") subset(`subset') pp(`pp')
			}
		}
	}

	postclose damage_coeffs

	di "Saving postfile as a csv..."
	use "`output_file'", clear
	outsheet using "`output_file'.csv", comma replace
	
	di "Erasing postfile"
	erase "`output_file'.dta"
end
