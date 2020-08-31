cilpath 

do "/home/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"

cap log close 
*log using "/home/`c(username)'/exclude_log.smcl", replace

global REPO = "/home/`c(username)'/repos"
global code_dir "${REPO}/gcp-labor"


do "${code_dir}/2_regression/time_use/common_functions.do"

init
gen_controls_and_FEs

global t_version_list tmax
global chn_week_list chn_prev_week
global filename_stem_list splines_27_37_39
global knots_current "27 37 39"

*splines_25_30_35
*splines_nochn
*splines_16.6_30.3_36.6 splines_-5_20_40 splines_5_25_40 splines_10_20_40 splines_15_25_40

global data_subset_list clim_t1 clim_t2 clim_t3  inc_t1 inc_t2 inc_t3   inc_q1_clim_q1 inc_q1_clim_q2 inc_q2_clim_q1 inc_q2_clim_q2
* 

* no_GBR no_IND no_USA no_FRA
*GBR ESP IND CHN USA BRA MEX EU daily weekly no_chn all_data 
global skip_existing_ster "no"
global test_code "no"
global run_lcl "no"
global differentiated_treatment "yes"
global fe_list fe_week_adm0 

*fe_adm0 fe_adm1 fe_adm3 fe_week_adm1 fe_week_saturated
global is_interacted "no"
global data_ll_version no_ll_0
* the stem of the variable name in the spline data file
global spl_varname "rcspl"
global clustering_var cluster_adm1yymm

global weights_list  rep_unit_year_sample_wgt 
*global weights_var adm1_adj_sample_wgt rep_unit_sample_wgt adj_sample_wgt risk_adj_sample_wgt 

global controls_varname usual_controls
global ref_temp 27 

cap program drop run_rcspline_regressions
program define run_rcspline_regressions

	args data_path differentiated_treatment is_interacted filename_stem t_version chn_week spl_varname data_subset leads_lags N_knots knots_loc controls_var fe clustering weights suffix
	
	if "`is_interacted'" == "yes" local reg_folder interacted_splines
	else local reg_folder uninteracted_splines
	if "`differentiated_treatment'" == "yes" local reg_folder `reg_folder'_by_risk

	local ster_name "$output_dir/estimates/`reg_folder'/`filename_stem'_`t_version'_`chn_week'/`fe'_`N_knots'_knots_`leads_lags'_`data_subset'_`weights'`suffix'"
	capture confirm file "`ster_name'_reghdfe.ster"

	if _rc != 0 | "${skip_existing_ster}" == "no" {
		preserve
		select_data_subset `data_subset'

		* if test code mode is on, take a random sample
		if "${test_code}"=="yes" {
			sample 1
		}
		
		gen_treatment_splines `spl_varname' `N_knots' `t_version' `leads_lags' 1

		
		if "`is_interacted'" == "yes" {
			local reg_treatment ${vars_T_splines} ${vars_T_x_gdp_splines} ${vars_T_x_lr_`t_version'_splines}
		}
		else {
			local reg_treatment ${vars_T_splines}
		}


		local reg_control ${`controls_var'}

		cd "$output_dir/estimates/`reg_folder'"
		cap mkdir `filename_stem'_`t_version'_`chn_week'

		if "${differentiated_treatment}" == "yes" local treat_risk diff_treat
		else local treat_risk comm_treat
		
		local spec_desc "rcspline, `N_knots' knots, `t_version', interacted = `is_interacted', `treat_risk'"
		local spec_desc "`spec_desc'. data: `data_path'"

		run_specification "reghdfe" "`spec_desc'" `filename_stem'_`t_version'_`chn_week'_`data_subset' do_not_include_0_min "`reg_treatment'" "`reg_control'" `treat_risk' diff_cont `fe' `weights' `clustering' "`ster_name'" 
		gen included = e(sample)

		tempfile reg_data
		save `reg_data', replace
		get_RF_uninteracted_splines `leads_lags' `differentiated_treatment' `ster_name'_reghdfe `filename_stem' `t_version' `chn_week' `spl_varname' `fe' `N_knots' `knots_loc' `weights' `data_subset' `reg_folder' ${ref_temp}

		use `reg_data', clear

		* automatically run reg if reghdfe produces standard errors of zero
		
		* creating a matrix of standard errors
		mat A = e(V)
		local coefs =colsof(A)
		matrix std_errors = vecdiag(e(V))
		forvalues i = 1/`coefs' {
			matrix std_errors[1, `i'] = sqrt(std_errors[1, `i'])
		}
		* summing all standard errors
		mata : st_matrix("sum", rowsum(st_matrix("std_errors")))
		* checking if sum of all standard errors are zero; if so, we run a normal reg.
		if sum[1,1] == 0 {
			di "Your standard errors are all zero. Now running a normal reg."
			local fixed_effects = e(extended_absvars)
			run_specification "reg" "`spec_desc'" `filename_stem'_`t_version'_`chn_week'_`data_subset' do_not_include_0_min "`reg_treatment'" "`reg_control'" `treat_risk' diff_cont "`fixed_effects'" `weights' `clustering' "`ster_name'" 
			di "getting RF for rcspline reg"
			get_RF_uninteracted_splines `leads_lags' `differentiated_treatment' `ster_name'_reg `filename_stem' `t_version' `chn_week' `spl_varname' `fe' `N_knots' `knots_loc' `weights' `data_subset' `reg_folder' ${ref_temp}
			}
		else {
			di "Good job! You have some standard errors from reghdfe. No need to run reg."
			}		
		restore
	}
	else {
		di "`ster_name'_reghdfe.ster already exists!"
	}

end 


foreach weight in $weights_list {
	foreach t_version in $t_version_list {
		foreach chn_week in $chn_week_list {	
			foreach filename_stem in $filename_stem_list {				

				local data_path "${data_dir}/labor_dataset_`filename_stem'_`t_version'_`chn_week'_${data_ll_version}.dta" 
				di "data: `data_path'"
				use "`data_path'", clear
			
				foreach f in ${fe_list} {
					foreach data_subset in ${data_subset_list} {
						cap rename *27_37_39_* **
						run_rcspline_regressions `data_path' ${differentiated_treatment} ${is_interacted} `filename_stem' `t_version' `chn_week' ${spl_varname} `data_subset' this_week 3 knots_current usual_controls `f' ${clustering_var} `weight'
						if "${run_lcl}" == "yes" {
							run_rcspline_regressions `data_path' ${differentiated_treatment} ${is_interacted} `filename_stem' `t_version' `chn_week'  ${spl_varname} `data_subset' all_weeks 3 knots_current usual_controls `f' ${clustering_var} `weight'
						}
					}
				}			
			}
		}
	}
}

cap log close 
exit, clear


cap log close
