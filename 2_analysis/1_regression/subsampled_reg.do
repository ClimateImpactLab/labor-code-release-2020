*****************
*	INITIALIZE
*****************

* get functions and paths
run "/home/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"
run "${DIR_REPO_LABOR}/2_analysis/0_subroutines/functions.do"

* log results
cap log close 
log using "${DIR_LOG}/subsampled_splines.smcl", replace

* select dataset and output folder
gl dataset 		"${ROOT_INT_DATA}/regression_ready_data/labor_dataset_splines_nochn_tmax_chn_prev_week_no_ll_0.dta"
loc reg_folder 	"${DIR_STER}/subsampled_splines"
loc xtiles		"${ROOT_INT_DATA}/xtiles/rep_unit_terciles_uncollapsed.dta"

* other selections
gl test_code "no"
gl reg_list inc_t1 inc_t2 inc_t3 inc_q1_clim_q1 inc_q1_clim_q2 inc_q2_clim_q1 inc_q2_clim_q2 // clim_t1 clim_t2 clim_t3
loc fe fe_adm0_wk

********************
*	RUN REGRESSION
********************

* cycle through each of the two regressions
foreach reg in $reg_list {

	use $dataset, clear

	* if test code mode is on, take a random sample
	if "${test_code}"=="yes" {
		sample 0.1
	}

	* only include non-zero observations
	keep if mins_worked > 0

	********************
	*	SUBSET THE DATA
	********************

	* categorize into terciles and quantiles
	merge m:1 rep_unit using `xtiles', keepusing(clim_t inc_t clim_q inc_q) nogen assert(3)

	* this is *truly* ugly, please fix it
	if "`reg'" == "inc_t1" keep if inc_t == 1
	if "`reg'" == "inc_t2" keep if inc_t == 2
	if "`reg'" == "inc_t3" keep if inc_t == 3
	if "`reg'" == "clim_t1" keep if clim_t == 1
	if "`reg'" == "clim_t2" keep if clim_t == 2
	if "`reg'" == "clim_t3" keep if clim_t == 3
	if "`reg'" == "inc_q1_clim_q1" keep if inc_q == 1 & clim_q == 1
	if "`reg'" == "inc_q1_clim_q2" keep if inc_q == 1 & clim_q == 2
	if "`reg'" == "inc_q2_clim_q1" keep if inc_q == 2 & clim_q == 1
	if "`reg'" == "inc_q2_clim_q2" keep if inc_q == 2 & clim_q == 2

	* get rid of some awkward naming
	rename *27_37_39_* **

	* generate regression variables
	gen_controls_and_FEs
	gen_treatment_splines rcspl 3 tmax this_week 1

	* differentiate treatment if reg is by risk
	loc reg_treatment (${vars_T_splines})##i.high_risk

	* both regressions have interacted controls
	local reg_control (${usual_controls})##i.high_risk
	
	* interact each fixed effect with the risk binary
	local reg_fe ""					
	foreach f in $`fe' {
		local reg_fe `reg_fe' `f'#high_risk
	}

	* set the regression weight
	loc weight "risk_adj_sample_wgt"

	* set the ster file name and the notes to be included
	local ster_name "`reg_folder'/subsampled_splines_`reg'.ster"
	local spec_desc "rcspline, 3 knots (27 37 39), tmax, differentiated treatment, fe = $fe, reg_type = `reg', weight = `weight'"

	di "reghdfe mins_worked `reg_treatment' `reg_control' [pweight = `weight'], absorb(`reg_fe') vce(cl cluster_adm1yymm)"
	qui reghdfe mins_worked `reg_treatment' `reg_control' [pweight = `weight'], absorb(`reg_fe') vce(cl cluster_adm1yymm)

	* count regression N by risk
	gen included = e(sample)
	count if included == 1 & high_risk == 1
	estadd scalar high_N = `r(N)'
	count if included == 1 & high_risk == 0
	estadd scalar low_N = `r(N)'

	estimates notes: "`spec_desc'"
	estimates save "`ster_name'", replace

	di "COMPLETED: `reg' regression."

}

cap log close
