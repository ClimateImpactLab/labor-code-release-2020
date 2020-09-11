/////////////////////////////////////////////////////////////////////////
	// Example code for using programs from damage_function.do
/////////////////////////////////////////////////////////////////////////

*****************************************
* DAMAGE FUNCTION ESTIMATION FOR SCC 
* CALCULATION INCLUDING POST-2100 EXTRAPOLATION
*****************************************

/* 

   This script does the following:
   * 1) Pulls in a .csv containing damages at global or impact region level. The .csv 
   should be SSP-specific, and contain damages in current year USD for every
   RCP-GCM-IAM-year combination. 
   * 2) Runs a regression in which the damage function is nonparametrically estimated for each year 't'
   using data only from the 5 years around 't'
   * 3) Runs a second regression in which GMST is interacted linearly with time. This regression uses
   only data from the second half of the century, given irregular early year behavior documented
   in mortality
   * 4) Predicts damage function coefficients for all years 2015-2300, with post-2100 extrapolation 
   conducted using the linear temporal interaction model and pre-2100 using the nonparametric model
   * 5) Saves a csv of damage function coefficients to be used by the SCC calculation derived from the FAIR 
   simple climate model

   Note on input file names: This script expects a .csv with a filename formatted as follows:

   'sector'_'scale'_damages_with_gmt_anom_'ff'_SSP'num'.csv 

   Where 'sector' is the sector of impacts -- e.g. "mortality" or "energy"
   Where 'scale' is either "global" or "local"
   Where 'ff' is "poly4" or "bins" or ... (other functional forms)
   Where 'num' is the number of the SSP -- e.g. 3 

   * T. Carleton 2018-06-17

   *** NOTE: Updated 10-08-18 to include a constraint that the fitted functions pass
   *** 	  through (0,0) where 0 on the x-axis refers to the 2001-2010 GMST value

*/

**********************************************************************************
* SET UP -- Change paths and input choices to fit desired output
**********************************************************************************

clear all
set more off, perm
pause on 
set scheme s1mono

do "/home/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"

* Directories
global dbroot = "/Users/ruixueli/Dropbox"
global datadir = "$dbroot/Global ACP/ClimateLaborGlobalPaper/Paper/Datasets/Rae_temp/dylan_check"
global outputdir = "$datadir"
global plot_outputdir = "$outputdir"

* DYLAN: change this to where you put the damage functions, I guess
global wd ="/Users/ruixueli/Desktop/repos/damage-function/programs"
cd $wd

do damage_function


* Sector
loc sector = "labor"

* Functional form
loc ff = "poly4_below0bin"

* Are you estimating global or impact region level damage functions?
loc scale = "global" // (choices: "global" or "ir")

* SSP
loc ssp = "3"

* How many years to include in the parametric regression?
loc subset = 2085

* Monte carlo = "_MC" or Median = ""
loc mc = ""

* damages or lifeyears or costs or deaths (for mortality only)
loc value = "wages" // "damages" // "lifeyears"

* controls
loc run_regs = "true"
loc quantilereg = "false"
loc paper_plots = "true"
loc diag_plots = "true"
loc time_plots = "true"

loc yearlist 2020 2050 2070 2097
**********************************************************************************
* STEP 1: Pull in and format .csv
**********************************************************************************

clear
/*
   if "`scale'" == "global" {
   if "`value'" == "damages" {
   import delimited "$datadir/damages/global/`sector'_`scale'_damages`mc'_`ff'_SSP`ssp'", varnames(1) 
   gen mod = "high" 
   replace mod= "low" if model == "IIASA GDP" //????????
   ren *mt* *mt_epa*
   }
   }
*/

import delimited "$datadir/valuecsv-1.3.csv", varnames(1)

**********************************************************************************
* STEP 2: Generate damages in Bn 2019 USD
**********************************************************************************
if "`value'" == "damages" | "`value'" == "costs" | "`value'" == "wo_costs" | "`value'" == "wages"  {
	if "`sector'" == "mortality" {
		merge m:1 mod using "$datadir/adjustments/vsl_adjustments.dta",nogen
		loc vvlist = "vsl vly mt"
		loc aalist = "epa"
		loc sslist = "scaled popavg" 
		foreach vv in `vvlist' {
			foreach aa in `aalist' {
				foreach ss in `sslist' {

					* Total impacts (full adapt plus costs), full adapt, costs, share of gdp FA+C
					gen cil_`vv'_`aa'_`ss' = (monetized_deaths_`vv'_`aa'_`ss' + monetized_costs_`vv'_`aa'_`ss')*(1/1000000000)*inf_adj*income_adj*vsl_adj
					gen cil_`vv'_`aa'_`ss'_wo = (monetized_deaths_`vv'_`aa'_`ss')*(1/1000000000)*inf_adj*income_adj*vsl_adj
					gen cil_`vv'_`aa'_`ss'_costs = (monetized_costs_`vv'_`aa'_`ss')*(1/1000000000)*inf_adj*income_adj*vsl_adj

				}
			}
		}
	}
	else if "`sector'" == "labor" {
		rename cil_damages_total cil_vv_aa_ss
		loc vvlist = "vv"
		loc aalist = "aa"
		loc sslist = "ss" 
	}
}

destring year, replace force
drop if missing(year)
drop if gcm == "MIROC-ESM" 
drop if gcm == "bcc-csm1-1" 
drop if year == 2100
*tempfile clean_wages
*save "`clean_wages'", replace

**********************************************************************************
* STEP 3: Regressions & construction of time-varying damage function coefficients 
**********************************************************************************
if "`run_regs'" == "true" {

	if "`quantilereg'" == "false" {
		*macro list
		get_df_coefs , output_file("$outputdir/labor_df_nov6") ///
			var1_list(`vvlist') var2_list(`aalist') var3_list(`sslist') ///
			var1_name(ph1) var2_name(ph2) var3_name(ph3) ///
			polyorder(2) subset(`subset') dropbox_path("$dbroot")

	}

}

