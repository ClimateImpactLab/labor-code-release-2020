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
* global dbroot = "/Users/ruixueli/Dropbox"
* global datadir = "$dbroot/Global ACP/ClimateLaborGlobalPaper/Paper/Datasets/Rae_temp/dylan_check"
* global outputdir = "$datadir"
* global plot_outputdir = "$outputdir"

* DYLAN: change this to where you put the damage functions, I guess
global wd ="${DIR_REPO_LABOR}/4_post_projection/mc/2_damage_function/subroutines"
cd $wd

do damage_function
do damage_function_qreg

* Sector
loc sector = "labor"

* Functional form
* loc ff = "poly4_below0bin"

* Are you estimating global or impact region level damage functions?
loc scale = "global" 
* (choices: "global" or "ir")

* SSP
loc ssp = "3"

* How many years to include in the parametric regression?
loc subset = 2085

* Monte carlo = "_MC" or Median = ""
loc mc = ""

* damages or lifeyears or costs or deaths (for mortality only)
loc value = "wages" 
*// "damages" // "lifeyears"

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

di "SSP `ssp'"
*** a few datasets for debugging ***
* output of this piece of code
*insheet using /home/liruixue/repos/labor-code-release-2020/output/damage_function/damage_function_estimation.csv, clear
* the input valuescsv that we used in the fed
*insheet using /shares/gcp/outputs/labor/impacts-fedconference-oct2019/median/valuecsv-1.3.csv, clear
*** a few datasets for debugging ***
* gdp
*import delimited "$ROOT_INT_DATA/projection_outputs/extracted_data/SSP3_damage_function_valuescsv_gdp.csv", varnames(1) clear
* wage
import delimited "$ROOT_INT_DATA/projection_outputs/extracted_data_mc/SSP`ssp'-valuescsv_wage_global.csv", varnames(1)

* pop
*import delimited "$ROOT_INT_DATA/projection_outputs/extracted_data/SSP3_damage_function_valuescsv_popweights.csv", varnames(1) clear

*sort gcm
*list if year == 2099
*count if year == 2099
*count if year == 2099 & value == 0

*list if year == 2100

*count if year == 2100

rename value wages
replace wages = wages / 1000000000000
**********************************************************************************
* STEP 2: Generate damages in Bn 2019 USD
**********************************************************************************
if "`value'" == "damages" | "`value'" == "costs" | "`value'" == "wo_costs" | "`value'" == "wages"  {
		rename wages cil_vv_aa_ss
      replace cil_vv_aa_ss = -cil_vv_aa_ss
		loc vvlist = "vv"
		loc aalist = "aa"
		loc sslist = "ss" 
}


destring year, replace force
drop if missing(year)
*drop if gcm == "MIROC-ESM" 
drop if year < 2010
*drop if gcm == "bcc-csm1-1" 
drop if year == 2100
*drop if year == 2099 
* surrogates and MIROC5 are dropped
*tempfile clean_wages
*save "`clean_wages'", replace
*/mnt/norgay_gcp/Global ACP/ClimateLaborGlobalPaper/Paper/Datasets/Rae_temp
**********************************************************************************
* STEP 3: Regressions & construction of time-varying damage function coefficients 
**********************************************************************************



cap mkdir "$DIR_REPO_LABOR/output/damage_function_mc"
if "`run_regs'" == "true" {
   if "`quantilereg'" == "false" {
      *macro list
      get_df_coefs , output_file("$DIR_REPO_LABOR/output/damage_function_mc/SSP`ssp'_damage_function_estimation") var1_list(`vvlist') var2_list(`aalist') var3_list(`sslist') var1_name(ph1) var2_name(ph2) var3_name(ph3) polyorder(2) subset(`subset') dropbox_path("/mnt/Global_ACP/")
   }

   if "`quantilereg'" == "true" {
      forvalues pp = 5(5)95 {
         di "`pp'"
         loc p = `pp'/100
         loc quantiles_to_eval "`quantiles_to_eval' `p'"
      }
      *macro list
      foreach pp of numlist `quantiles_to_eval' {
         di "`pp'"
         get_df_coefs_qreg , output_file("$DIR_REPO_LABOR/output/damage_function_mc/SSP`ssp'_damage_function_estimation_qreg") var1_list(`vvlist') var2_list(`aalist') var3_list(`sslist') var1_name(ph1) var2_name(ph2) var3_name(ph3) polyorder(2) subset(`subset') dropbox_path("/mnt/Global_ACP/") pp(0.05)
      }
   }
   
}

*get_df_coefs_qreg , output_file("$DIR_REPO_LABOR/output/damage_function_mc/SSP`ssp'_damage_function_estimation_qreg") var1_list(`vvlist') var2_list(`aalist') var3_list(`sslist') var1_name(ph1) var2_name(ph2) var3_name(ph3) polyorder(2) subset(`subset') dropbox_path("/mnt/Global_ACP/") pp(5)


*pp(0.05)
