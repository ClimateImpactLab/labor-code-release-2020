*****************
*	INITIALIZE
*****************

* get functions and paths
run "/home/kschwarz/repos/labor-code-release-2020/0_subroutines/paths.do"
run "${DIR_REPO_LABOR}/2_analysis/0_subroutines/functions.do"

* select dataset and output folder
gl dataset 			"${ROOT_INT_DATA}/regression_ready_data/labor_dataset_splines_nochn_tmax_chn_prev_week_no_ll_0.dta"
loc output_folder 	"${DIR_OUTPUT}/temp_dist"  

* other selections
global bin_step 0.1
global weight_list risk_adj_sample_wgt

*****************************
*	GET DENSITY OF TEMP DIST
***************************** 

use $dataset, clear

* generate absolute density variables
gen no_wgt_comm = 1
gen no_wgt_low = 1 if high_risk == 0
gen no_wgt_high = 1 if high_risk == 1

* gen weighted density variables
foreach weight in $weight_list {
	gen `weight'_comm = `weight'
	gen `weight'_low = `weight' if high_risk == 0
	gen `weight'_high = `weight' if high_risk == 1
}

qui sum real_temp, det

loc max = ceil(r(max))
loc min = floor(r(min))

egen double bin = cut(real_temp), at(`min'($bin_step)`max')

gcollapse (sum) *_comm *_low *_high, by(bin)
rename bin temp

export delim "`output_folder'/no_chn_temp_dist.csv", replace

