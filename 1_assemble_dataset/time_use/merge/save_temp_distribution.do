*****************
*	INITIALIZE
*****************

* get functions and paths
run "/home/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"
run "${DIR_REPO_LABOR}/2_analysis/0_subroutines/functions.do"

* select dataset and output folder
gl dataset_list 	wchn nochn inc_t1 inc_t2 inc_t3 inc_q2_clim_q1 inc_q2_clim_q2 inc_q1_clim_q1 inc_q1_clim_q2
loc output_folder 	"${DIR_OUTPUT}/temp_dist"  

* other selections
global bin_step 0.1
global weight_list risk_adj_sample_wgt pop_adj_sample_wgt

*****************************
*	GET DENSITY OF TEMP DIST
***************************** 
foreach dataset in $dataset_list {

	if "$dataset" !="nochn" & "$dataset" != "wchn" {

		use "${ROOT_INT_DATA}/regression_ready_data/labor_dataset_splines_nochn_tmax_chn_prev_week_no_ll_0.dta", clear

		merge m:1 rep_unit using "${ROOT_INT_DATA}/xtiles/rep_unit_terciles_uncollapsed.dta"
		subsample_data `dataset'

	}

	else {

		use "${ROOT_INT_DATA}/regression_ready_data/labor_dataset_splines_`dataset'_tmax_chn_prev_week_no_ll_0.dta", clear

	}

		* test: number of observations
		count
		di "`dataset' : `r(N)' observations"

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

		export delim "`output_folder'/`dataset'_temp_dist.csv", replace

}

