*****************
*	INITIALIZE
*****************

* get functions and paths
run "/home/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"
run "${DIR_REPO_LABOR}/2_analysis/0_subroutines/functions.do"

* log results
cap log close 
log using "/home/rfrost/repos/labor-code-release-2020/logs/interacted_splines_lr_interaction_and_mixed_weight.smcl", replace

* select dataset and output folder
gl dataset 		"${ROOT_INT_DATA}/regression_ready_data/labor_dataset_splines_nochn_tmax_chn_prev_week_no_ll_0.dta"
loc reg_folder 	"${DIR_OUTPUT}/interacted_reg_output/ster"

* other selections
gl test_code "no"
gl reg_list 1_factor 
*2_factor
loc fe fe_adm0_wk

********************
*	RUN REGRESSION
********************

* cycle through each of the two regressions
foreach reg in $reg_list {

	di "`reg_list'"

	use $dataset, clear
	drop if iso == "GBR" & year == 1984 & month == 1 & day == 2

	* if test code mode is on, take a random sample
	if "${test_code}"=="yes" {
		sample 0.1
	}

	* only include non-zero observations
	keep if mins_worked > 0

	* get rid of some awkward naming
	rename *27_37_39_* **

	* generate regression variables
	gen_controls_and_FEs
	gen_treatment_splines rcspl 3 tmax this_week 1

	* differentiate treatment if reg is by risk
	
	*generate variables for the pooled regression to get the correct coeffs for LR group
	gen low_risk = 1-high_risk

	gen tmax_rcspl_3kn_t0_lr = tmax_rcspl_3kn_t0*low_risk
	gen tmax_rcspl_3kn_t0_lr_v1 = tmax_rcspl_3kn_t0_v1*low_risk
	gen tmax_rcspl_3kn_t0_lr_v2 = tmax_rcspl_3kn_t0_v2*low_risk
	gen tmax_rcspl_3kn_t0_lr_v3 = tmax_rcspl_3kn_t0_v3*low_risk
	gen tmax_rcspl_3kn_t0_lr_v4 = tmax_rcspl_3kn_t0_v4*low_risk
	gen tmax_rcspl_3kn_t0_lr_v5 = tmax_rcspl_3kn_t0_v5*low_risk
	gen tmax_rcspl_3kn_t0_lr_v6 = tmax_rcspl_3kn_t0_v6*low_risk

        gen tmax_rcspl_3kn_t1_lr = tmax_rcspl_3kn_t1*low_risk
        gen tmax_rcspl_3kn_t1_lr_v1 = tmax_rcspl_3kn_t1_v1*low_risk
        gen tmax_rcspl_3kn_t1_lr_v2 = tmax_rcspl_3kn_t1_v2*low_risk
        gen tmax_rcspl_3kn_t1_lr_v3 = tmax_rcspl_3kn_t1_v3*low_risk
        gen tmax_rcspl_3kn_t1_lr_v4 = tmax_rcspl_3kn_t1_v4*low_risk
        gen tmax_rcspl_3kn_t1_lr_v5 = tmax_rcspl_3kn_t1_v5*low_risk
        gen tmax_rcspl_3kn_t1_lr_v6 = tmax_rcspl_3kn_t1_v6*low_risk

	gen tmax_rcspl_3kn_t0_hr = tmax_rcspl_3kn_t0*high_risk
        gen tmax_rcspl_3kn_t0_hr_v1 = tmax_rcspl_3kn_t0_v1*high_risk
        gen tmax_rcspl_3kn_t0_hr_v2 = tmax_rcspl_3kn_t0_v2*high_risk
        gen tmax_rcspl_3kn_t0_hr_v3 = tmax_rcspl_3kn_t0_v3*high_risk
        gen tmax_rcspl_3kn_t0_hr_v4 = tmax_rcspl_3kn_t0_v4*high_risk
        gen tmax_rcspl_3kn_t0_hr_v5 = tmax_rcspl_3kn_t0_v5*high_risk
        gen tmax_rcspl_3kn_t0_hr_v6 = tmax_rcspl_3kn_t0_v6*high_risk

        gen tmax_rcspl_3kn_t1_hr = tmax_rcspl_3kn_t1*high_risk
        gen tmax_rcspl_3kn_t1_hr_v1 = tmax_rcspl_3kn_t1_v1*high_risk
        gen tmax_rcspl_3kn_t1_hr_v2 = tmax_rcspl_3kn_t1_v2*high_risk
        gen tmax_rcspl_3kn_t1_hr_v3 = tmax_rcspl_3kn_t1_v3*high_risk
        gen tmax_rcspl_3kn_t1_hr_v4 = tmax_rcspl_3kn_t1_v4*high_risk
        gen tmax_rcspl_3kn_t1_hr_v5 = tmax_rcspl_3kn_t1_v5*high_risk
        gen tmax_rcspl_3kn_t1_hr_v6 = tmax_rcspl_3kn_t1_v6*high_risk

	gen tmax_rcspl_3kn_t0_hr_g = tmax_rcspl_3kn_t0*high_risk*log_gdp_pc_adm1
        gen tmax_rcspl_3kn_t0_hr_g_v1 = tmax_rcspl_3kn_t0_v1*high_risk*log_gdp_pc_adm1
        gen tmax_rcspl_3kn_t0_hr_g_v2 = tmax_rcspl_3kn_t0_v2*high_risk*log_gdp_pc_adm1
        gen tmax_rcspl_3kn_t0_hr_g_v3 = tmax_rcspl_3kn_t0_v3*high_risk*log_gdp_pc_adm1
        gen tmax_rcspl_3kn_t0_hr_g_v4 = tmax_rcspl_3kn_t0_v4*high_risk*log_gdp_pc_adm1
        gen tmax_rcspl_3kn_t0_hr_g_v5 = tmax_rcspl_3kn_t0_v5*high_risk*log_gdp_pc_adm1
        gen tmax_rcspl_3kn_t0_hr_g_v6 = tmax_rcspl_3kn_t0_v6*high_risk*log_gdp_pc_adm1

        gen tmax_rcspl_3kn_t1_hr_g = tmax_rcspl_3kn_t1*high_risk*log_gdp_pc_adm1
        gen tmax_rcspl_3kn_t1_hr_g_v1 = tmax_rcspl_3kn_t1_v1*high_risk*log_gdp_pc_adm1
        gen tmax_rcspl_3kn_t1_hr_g_v2 = tmax_rcspl_3kn_t1_v2*high_risk*log_gdp_pc_adm1
        gen tmax_rcspl_3kn_t1_hr_g_v3 = tmax_rcspl_3kn_t1_v3*high_risk*log_gdp_pc_adm1
        gen tmax_rcspl_3kn_t1_hr_g_v4 = tmax_rcspl_3kn_t1_v4*high_risk*log_gdp_pc_adm1
        gen tmax_rcspl_3kn_t1_hr_g_v5 = tmax_rcspl_3kn_t1_v5*high_risk*log_gdp_pc_adm1
        gen tmax_rcspl_3kn_t1_hr_g_v6 = tmax_rcspl_3kn_t1_v6*high_risk*log_gdp_pc_adm1

	if "`reg'" == "1_factor" loc reg_treatment tmax_rcspl_3kn_t0_lr* tmax_rcspl_3kn_t1_lr*  tmax_rcspl_3kn_t0_hr* tmax_rcspl_3kn_t1_hr*
	
	*** This will give you un-useable estimate for LR
	*if "`reg'" == "1_factor" loc reg_treatment (${vars_T_splines} ${vars_T_x_gdp_splines})##i.high_risk
  
	
	else if "`reg'" == "2_factor" loc reg_treatment (${vars_T_splines} ${vars_T_x_gdp_splines} ${vars_T_x_lr_tmax_splines})##i.high_risk
	else di in red "bad reg specification -> pick '1 factor' or '2 factor'"
	di "`reg_treatment'"

	* both regressions have interacted controls
	local reg_control (${usual_controls})##i.high_risk
	di "`reg_control'"
	
	* interact each fixed effect with the risk binary
	local reg_fe ""					
	foreach f in $`fe' {
		local reg_fe `reg_fe' `f'#high_risk
	}

	* set the ster file name and the notes to be included
	local ster_name "`reg_folder'/interacted_reg_`reg'_lr_interaction_mixed_weight.ster"
	local spec_desc "rcspline, 3 knots (27 37 39), tmax, differentiated treatment withlr interaction, fe = $fe, reg_type = `reg'"

	* set the regression weight
	replace risk_adj_sample_wgt = rep_unit_year_sample_wgt if high_risk ==1
	loc weight "risk_adj_sample_wgt"

	di "reghdfe mins_worked `reg_treatment' `reg_control' [pweight = `weight'], absorb(`reg_fe') vce(cl cluster_adm1yymm)"
	reghdfe mins_worked `reg_treatment' `reg_control' [pweight = `weight'], absorb(`reg_fe') vce(cl cluster_adm1yymm)

	* count regression N by risk
	gen included = e(sample)
	count if included == 1 & high_risk == 1
	estadd scalar high_N = `r(N)'
	count if included == 1 & high_risk == 0
	estadd scalar low_N = `r(N)'

	estimates notes: "`spec_desc' change weight to mixed version, and specify interactions such that we correctly recover LR and HR curves"
	estimates save "`ster_name'", replace

	di "COMPLETED: `reg' regression."

}

cap log close
