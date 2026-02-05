****************************************************
* This file runs the subsampled uninteracted regression.
*
* How to use:
*   1. Log in to a computing node.
*   2. Update the following settings in this file:
*        - logs
*        - dataset
*        - risk_def
*        - ster_name
*        - weight
*   3. Weight naming convention:
*        - For low-risk and sector-specific regressions, 
*          add the suffix "_old" or "_sector" to the weight variable.
*        - For high-risk regressions, use the weight variable
*          without any suffix.
*   4. For "sector", change:
*	*count regression N by risk
*	gen included = e(sample)
*	count if included == 1 & risk_level == 1       
*	estadd scalar ag_N = `r(N)'
*	count if included == 1 & risk_level == 0      
*	estadd scalar low_N = `r(N)'
*	count if included == 1 & risk_level == 2
*	estadd scalar nonag_N = `r(N)'
*
* Runtime:
*   - Approximately 2 hours.
****************************************************

clear all
*****************
* CHANGE HERE
*****************
* Get functions and paths
run "/project/cil/home_dirs/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"
run "${DIR_REPO_LABOR}/2_analysis/0_subroutines/functions.do"

* Log results
cap log close 
log using "${DIR_LOG}/subsampled_splines_260129.smcl", replace


* Select dataset and output folder
gl dataset "${ROOT_INT_DATA}/regression_ready_data/labor_dataset_splines_nochn_tmax_chn_prev_week_no_ll_0_agnonag_272841_0129.dta"
loc xtiles "${ROOT_INT_DATA}/xtiles/rep_unit_quantiles_uncollapsed.dta"

loc reg_folder "${DIR_OUTPUT}/subsampled_reg/ster"

* Other selections
gl test_code "no"
gl reg_list by_risk // options: by risk, common
gl sample_list inc_q1_clim_q1 inc_q1_clim_q2 inc_q2_clim_q1 inc_q2_clim_q2 clim_t1 clim_t2 clim_t3 //inc_t1 inc_t2 inc_t3
loc fe fe_adm0_wk

* ---------- CHOOSE WHICH RISK DEFINITION TO USE ----------
global risk_def "high_risk"
* --------------------------------------------------------

********************
*	RUN REGRESSION
********************

* cycle through each of the regression and sample pairs
foreach reg in $reg_list {
	
	foreach sample in $sample_list{
	
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

		subsample_data `sample'
		
		* get rid of some awkward naming
		rename *27_28_41_* **
		
		* ---------- DEFINE risk_level FROM CHOSEN SOURCE ----------
		cap drop risk_level 
		gen risk_level = .   
		replace risk_level = high_risk     if "${risk_def}"=="high_risk"
		replace risk_level = high_risk_old if "${risk_def}"=="high_risk_old"
		replace risk_level = sector if "${risk_def}"=="sector"
		replace risk_level = occup_code if "${risk_def}"=="occup_code"
		
		* generate regression variables
		gen_controls_and_FEs
		gen_treatment_splines rcspl 3 tmax this_week 1

		* differentiate treatment if reg is by risk
		if "`reg'" == "by_risk" loc reg_treatment (${vars_T_splines})##i.risk_level 
		else if "`reg'" == "common" loc reg_treatment (${vars_T_splines})
		else di in red "bad reg specification -> pick 'common' or 'by_risk'"
		di "`reg_treatment'"

		* both regressions have interacted controls
		local reg_control (${usual_controls})##i.risk_level    
		di "`reg_control'"
		    
		* interact each fixed effect with the risk binary
		local reg_fe ""                    
		foreach f in $`fe' {
			local reg_fe `reg_fe' `f'#risk_level
			}

		* set the regression weight (pop_adj for common, risk_adj for by-risk)
		if "`reg'" == "common" loc weight "pop_adj_sample_wgt"
		else loc weight "risk_adj_sample_wgt"

		* set the ster file name and the notes to be included
		local ster_name "`reg_folder'/subsampled_splines_`reg'_`sample'_260129.ster"
		local spec_desc "rcspline, 3 knots (27 28 41), tmax, differentiated treatment, fe = $fe, reg_type = `reg', weight = `weight'"

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

		di "COMPLETED: `reg' `sample' regression."
	}

}

cap log close
