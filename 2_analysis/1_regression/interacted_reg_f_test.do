*****************
*	INITIALIZE
*****************

* get paths
run "/home/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"
run "/home/`c(username)'/repos/labor-code-release-2020/0_subroutines/utils.do"

* select input and output folder
gl ster_dir "${DIR_OUTPUT}/interacted_reg_output/ster"
gl rf_folder "${DIR_OUTPUT}/interacted_reg_output"

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
	test_interaction_spline `f' `N_knots' `data_subset' `ster_name' rep_unit_year_sample_wgt

}
