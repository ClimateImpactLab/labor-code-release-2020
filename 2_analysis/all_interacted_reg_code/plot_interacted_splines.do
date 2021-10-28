* most programs are similar in function and structure to plot_interacted_polynomials.do
* the only difference is that instead of looping from poly 1 to poly N,
* we loop from term 0 to term (N_knots - 2)
* and we generate special temperature variables using mkspline function

clear all 

* get paths
run "/home/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"
run "/home/`c(username)'/repos/labor-code-release-2020/2_analysis/0_subroutines/utils.do"
run "/home/`c(username)'/repos/labor-code-release-2020/2_analysis/0_subroutines/histograms.do"

* select input and output folder
gl ster_dir "${DIR_OUTPUT}/interacted_reg_output/ster"
gl rf_folder "${DIR_OUTPUT}/interacted_reg_output"


*****************
*	MAKE PLOTS
*****************

* other selections
gl reg_list 2_factor
loc f fe_adm0_wk
loc N_knots 3 
loc data_subset no_chn
loc tercile rep_unit

generate_coef_spline 3 rcspl
generate_grids `tercile'
plot_histograms `tercile' rep_unit_year_sample_wgt

cd "${rf_folder}"
cap mkdir plots
cd plots
		
foreach reg in $reg_list{

	di "`reg_list'"
	loc ster_name "interacted_reg_`reg'"
	plot_interacted_spline `f' `N_knots' `data_subset' all_data_no_ci `ster_name' rep_unit_year_sample_wgt

}