*****************
*	INITIALIZE
*****************

* log results
log using "/home/nsharma/repos/logs/f_tests.smcl", replace

* get paths
run "/home/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"

* select input and output folder
gl ster_dir "${DIR_OUTPUT}/interacted_reg_output/ster"
gl rf_folder "${DIR_OUTPUT}/interacted_reg_output"

********************************
*	DEFINE PROGRAM TO RUN F TEST
********************************
* generate coefficients for plotting
cap program drop generate_coef_spline
program define generate_coef_spline
	args N_knots spl_varname

	local N_new_vars=`N_knots'-2 
	di "new var"
	di "`N_new_vars'"

	forval k=0/`N_new_vars'{


		global b_T_spline_`k'_lr 0
		global b_T_x_gdp_spline_`k'_lr 0
		global b_T_x_lrtmax_spline_`k'_lr 0

		global b_T_spline_`k'_hr 0
		global b_T_x_gdp_spline_`k'_hr 0
		global b_T_x_lrtmax_spline_`k'_hr 0 


		global b_T_spline_`k'_lr _b[tmax_`spl_varname'_`N_knots'kn_t`k']
		global b_T_x_gdp_spline_`k'_lr _b[c.tmax_`spl_varname'_`N_knots'kn_t`k'#c.log_gdp_pc_adm1]
		global b_T_x_lrtmax_spline_`k'_lr _b[c.tmax_`spl_varname'_`N_knots'kn_t`k'#c.lr_tmax_p1]

		global b_T_spline_`k'_hr _b[1.high_risk#c.tmax_`spl_varname'_`N_knots'kn_t`k']
		global b_T_x_gdp_spline_`k'_hr _b[1.high_risk#c.tmax_`spl_varname'_`N_knots'kn_t`k'#c.log_gdp_pc_adm1]
		global b_T_x_lrtmax_spline_`k'_hr _b[1.high_risk#c.tmax_`spl_varname'_`N_knots'kn_t`k'#c.lr_tmax_p1]			
		
		forval lag=1/6{

			global b_T_spline_`k'_lr ${b_T_spline_`k'_lr}+_b[tmax_`spl_varname'_`N_knots'kn_t`k'_v`lag']
			global b_T_x_gdp_spline_`k'_lr ${b_T_x_gdp_spline_`k'_lr}+_b[c.tmax_`spl_varname'_`N_knots'kn_t`k'_v`lag'#c.log_gdp_pc_adm1]
			global b_T_x_lrtmax_spline_`k'_lr ${b_T_x_lrtmax_spline_`k'_lr}+_b[c.tmax_`spl_varname'_`N_knots'kn_t`k'_v`lag'#c.lr_tmax_p1]

			global b_T_spline_`k'_hr ${b_T_spline_`k'_hr}+_b[1.high_risk#c.tmax_`spl_varname'_`N_knots'kn_t`k'_v`lag']
			global b_T_x_gdp_spline_`k'_hr ${b_T_x_gdp_spline_`k'_hr}+_b[1.high_risk#c.tmax_`spl_varname'_`N_knots'kn_t`k'_v`lag'#c.log_gdp_pc_adm1]
			global b_T_x_lrtmax_spline_`k'_hr ${b_T_x_lrtmax_spline_`k'_hr}+_b[1.high_risk#c.tmax_`spl_varname'_`N_knots'kn_t`k'_v`lag'#c.lr_tmax_p1]

		}

		global b_T_spline_`k'_hl ${b_T_spline_`k'_lr} + ${b_T_spline_`k'_hr}
		global b_T_x_gdp_spline_`k'_hl  ${b_T_x_gdp_spline_`k'_lr} + ${b_T_x_gdp_spline_`k'_hr}
		global b_T_x_lrtmax_spline_`k'_hl ${b_T_x_lrtmax_spline_`k'_lr} + ${b_T_x_lrtmax_spline_`k'_hr}	
	}
end   


cap program drop test_interaction_spline
program define test_interaction_spline
	args f N_knots data_subset ster_name wgt
	
	estimates use "${ster_dir}/`ster_name'.ster"

	local N_new_vars=`N_knots'-2 

	* matrix for F test results
	putexcel set "${rf_folder}/test_spline_results.xlsx", sheet("`wgt'") modify
	mat results = J(2,6,.)
	local j = 1

	foreach risk in lr hl {
		global test_exp_gdp 0
		global test_exp_lrtmax 0
		global test_exp_gdp_and_lrtmax 0

		forval i=0/`N_new_vars'{
			global test_exp_gdp $test_exp_gdp = (${b_T_x_gdp_spline_`i'_`risk'}) 
			global test_exp_lrtmax $test_exp_lrtmax = (${b_T_x_lrtmax_spline_`i'_`risk'}) 
			global test_exp_gdp_and_lrtmax $test_exp_gdp_and_lrtmax = (${b_T_x_gdp_spline_`i'_`risk'}) = (${b_T_x_lrtmax_spline_`i'_`risk'}) 

		}

		local colnames = "`colnames' `risk'_GDP_interaction"
		test ${test_exp_gdp} 
		mat results[1, `j'] = `r(F)'
		mat results[2, `j'] = `r(p)'
		local ++j
		local colnames = "`colnames' `risk'_lrtmax_interaction"
		test ${test_exp_lrtmax}
		mat results[1, `j'] = `r(F)'
		mat results[2, `j'] = `r(p)'
		local ++j
		local colnames = "`colnames' `risk'_joint_interaction"
		test ${test_exp_gdp_and_lrtmax}
		mat results[1, `j'] = `r(F)'
		mat results[2, `j'] = `r(p)'
		local ++j
	}
	
	mat colnames results  = `colnames'
	mat rownames results  = F pval
	putexcel A1 = matrix(results), names

end


*****************
*	RUN F TEST
*****************

* other selections
generate_coef_spline 3 rcspl

gl reg_list 2_factor
loc f fe_adm0_wk
loc N_knots 3 
loc data_subset no_chn

foreach reg in $reg_list{

	di "`reg_list'"
	loc ster_name "interacted_reg_`reg'"
	test_interaction_spline `f' `N_knots' `data_subset' `ster_name' `reg'

}

cap log close
