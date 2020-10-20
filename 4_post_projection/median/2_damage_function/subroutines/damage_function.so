*****************************************************************************************************
* Programs for: DAMAGE FUNCTION ESTIMATION FOR SCC -- CALCULATION INCLUDING POST-2100 EXTRAPOLATION
*****************************************************************************************************

//Orginal Author: Tamma Carleton

/* 

Programs and their general purpose:
  * note: helper functions have not been designed to be called by other scripts
	* [helper function] poly2_insample_damage_function: estimates a poly2 damage function for in sample years (2015-2099)
		* Runs a regression in which the damage function is nonparametrically estimated for each year 't'
			using data only from the 5 years around 't'
	* [helper function] poly2_outsample_damage_function: estimates a poly2 damage function for out of sample years (2100-2300) 
		* Runs a regression in which GMST is interacted linearly with time. This regression uses
			only data from a later portion of the century, given irregular early year behavior documented
			in mortality
	* load_gmst_anom: loads GMST anomalies (consistent across all sectors)
	* get_df_coefs: output damage function coeffcients for 2015-2300 for all types of values 
		* Predicts damage function coefficients for all years 2015-2300, with post-2100 extrapolation 
			conducted using the linear temporal interaction model and pre-2100 using the nonparametric model
		* Saves a csv of damage function coefficients to be used by the SCC calculation derived from the FAIR 
			simple climate model

Functionality on the to do list:
	* 1) quantiles damage function regressions
	* 2) different poly order damage functions

Program parameter definitions:
  * note: for var*, * can be 1,2,3 (2 and 3 are optional)
	* identifier_list [string]: list of suffixes attached to cil
	* subset [integer]: the damage function linearly interacted with time uses years `subset'-2099 of a given value for estimation
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
	
	| year | ssp | model | gcm | rcp | batch | cil_* ...

	There can be many different cil_* where * is replaced by a suffix in the identifier_list
	
	For example:
	
	In energy a set of cil_* variables might look like: cil_price014, cil_price03, cil_peakprice014. Thus, energy will provide get_df_coefs 
	an identifier_list that looks like this: " price03 price014 peakprice014 "

	
	In mortality a set of cil_* variables might look like this: cil_vsl_epa_scaled, cil_vsl_epa_popavg, cil_vly_epa_scaled, cil_vly_epa_popavg. Thus,
		mortality will provide get_df_coefs with an identifier_list that looks like this: 
		" vsl_epa_scaled vsl_epa_popavg vly_epa_scaled cil_vly_epa_popavg "

*/

program define poly2_insample_damage_function

syntax , identifier(string)

	foreach yr of numlist 2015/2099 {
		
		di "Estimating damage function for `identifier' in `yr'..."
		qui reg cil_`identifier' c.anomaly##c.anomaly if year>=`yr'-2 & year <= `yr'+2 

		// get max and min GMST anomaly for damage function year
		qui summ anomaly if year == `yr', det 
		local amin = `r(min)'
		local amax =  `r(max)'

		di "Storing damage function coefficients for `yr'..."
		post damage_coeffs ("`identifier'") (`yr') (_b[_cons]) (_b[anomaly]) (_b[c.anomaly#c.anomaly]) (`amin') (`amax')
	}

end

program define poly2_outsample_damage_function

syntax , identifier(string) subset(integer)

	// define time variable to regress 
	local base_year = 2010
	cap gen t = year - `base_year' // only generate if doesnt already exist

	di "Estimating damage function linearly interacted with time on values between `subset' and 2099..."
	qui reg cil_`identifier' c.anomaly##c.anomaly##c.t  if year >= `subset'


	foreach yr of numlist 2100/2300 {

		di "Calculating damage function for `yr'..."

		loc cons = _b[_cons] + _b[t]*(`yr'-`base_year')
		loc beta1 = _b[anomaly] + _b[c.anomaly#c.t]*(`yr'-`base_year')
		loc beta2 = _b[c.anomaly#c.anomaly] + _b[c.anomaly#c.anomaly#c.t]*(`yr'-`base_year')
		
		di "Storing damage function coefficients for `yr'..."

		* NOTE: we don't have future min and max, so assume they go through all GMST values 	
		post damage_coeffs ("`identifier'") (`yr') (`cons') (`beta1') (`beta2') (0) (11)

	}
end

program define load_gmst_anom 
syntax , dropbox_path(string)
	
	di "Loading GMST anomaly data..."
	insheet using "`dropbox_path'/Global ACP/damage_function/GMST_anomaly/GMTanom_all_temp_2001_2010.csv", comma clear
	rename temp anomaly

end


program define get_df_coefs
syntax , output_file(string) identifier_list(string)  polyorder(integer) subset(integer) dropbox_path(string)
	
	di "Ensuring functionality exists for poly`polyorder' damage functions."
	assert `polyorder' == 2 // other functionality not developed yet

	// save current data for merge later
	tempfile damages
	save `damages', replace

	// loading gmst anom
	load_gmst_anom , dropbox_path("`dropbox_path'")
	
	di "Merging results and GMST anomalies..."
	merge 1:m year rcp gcm using `damages'
	drop if year < 2010
	assert _merge == 3
	drop _merge

	di "Setting up postfile..."

	postfile damage_coeffs str20(identifier) year cons beta1 beta2 anomalymin anomalymax using "`output_file'", replace

	foreach identifier in `identifier_list' {
		di "Storing damage function coefficients for `identifier'..."

		di "Storing insample poly`polyorder' damage function coefficients..."
		poly`polyorder'_insample_damage_function , identifier("`identifier'")
		
		di "Storing outsample poly`polyorder' damage function coefficients..."
		poly`polyorder'_outsample_damage_function , identifier("`identifier'") subset(`subset')
	}

	postclose damage_coeffs

	di "Saving postfile as a csv..."
	use "`output_file'", clear
	outsheet using "`output_file'.csv", comma replace
	
	di "Erasing postfile"
	erase "`output_file'.dta"
end
