use "/shares/gcp/estimation/Labor/Stata_Data/Yuqi_Files/NewMergeGMFD/GMFD_Labor_merged_0819_smallwt_clean_allcov_newclim.dta", clear

keep if iso == "BRA"
list in 1/1

use "/shares/gcp/estimation/Labor/Climate_data/time_use_newvars/outputs/merged/BRA/by_var/GMFD_BRA_tmax_poly_1.dta", clear
gen date = mdy(month,day,year)
keep if date >= 15794 & date <= 15800 &  location_id2 == 516
collapse (sum) tmax_poly_1
list


use "/shares/gcp/estimation/Labor/Stata_Data/Yuqi_Files/NewMergeGMFD/GMFD_Labor_merged_0819_smallwt_clean_allcov_newclim.dta", clear
keep if iso == "MEX"
list in 1/1

use "/shares/gcp/estimation/Labor/Climate_data/time_use_newvars/outputs/merged/MEX/by_var/GMFD_MEX_tmax_poly_1.dta", clear
gen date = mdy(month,day,year)
keep if date >= 18524 & date <= 18530 &  location_id2 == 905
collapse (sum) tmax_poly_1
list






***************************************	
* MEXICO (MEX) LABOR MERGE
***************************************	

//Local country
local loc="MEX"

//Make Directory
cap mkdir "`OUTPATH'/`loc'"

//Change to code path
cd "`CODEPATH'/`loc'"

//Clean Climate Data
*Step 1: Reshape [Note this one run slowly for a couple of hours]
do "Reform_MEX.do"
*Step 2: Clean up ADM Names
do "Reform2_MEX.do"

//Merge in Labor Data
do "main_copy.do" /* Matt's MEXm weekly data*/
*do Mex_merge.do /* Tim's MEX daily data, deprecated May 2019 */

**The final file produced shall have N=8,424,923 for weekly data** 
**Year Range 2005-2012**






local DATAPATH "/shares/gcp/estimation/Labor/Labor_merge"
use "`DATAPATH'/MEX/outcomeCombined_weekly.dta", clear
gen date = mdy(month, day, year)
sum date


cilpath
import delimited using "$DB/Global ACP/labor/replication/1_preparation/time_use/enoe_replicated.csv", clear
gen date = mdy(month, day, year)
sum date



use "/shares/gcp/estimation/Labor/Stata_Data/Yuqi_Files/NewMergeGMFD/GMFD_Labor_merged_0819_allcov_newclim.dta", clear
