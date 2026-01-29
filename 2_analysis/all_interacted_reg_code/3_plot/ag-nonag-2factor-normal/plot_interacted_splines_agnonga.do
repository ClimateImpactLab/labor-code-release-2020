clear all 

* Get paths
run "/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/0_subroutines/paths.do"
run "/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/2_analysis/all_interacted_reg_code/3_plot/ag-nonag-2factor-normal/utils_agnonag.do"
run "/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/2_analysis/all_interacted_reg_code/3_plot/ag-nonag-2factor-normal/plot_histograms_agnonag.do"

* Select input and output folder
global ster_dir "${DIR_OUTPUT}/interacted_reg_output/ster"
global rf_folder "${DIR_OUTPUT}/interacted_reg_output"

*****************
* MAKE PLOTS
*****************
* Other selections
local N_knots 3 
global reg_list "2_factor"
global data_subset_list "no_chn"
global weights_list "rep_unit_year_sample_wgt"
global fe_list "fe_week_adm0" 
global interaction "interacted"
global tercile "rep_unit"
global hist_weight_list "rep_unit_year_sample_wgt"
global hist_style_list "pct"
global max_g 9

* IMPORTANT: Run plot_histograms FIRST to generate counts
foreach weight in $hist_weight_list {
	plot_histograms $tercile `weight' $interaction
}

* Then run generate_grids which will use the counts from plot_histograms
generate_grids $tercile $interaction

* Generate spline coefficients for plotting
generate_coef_spline 3 rcspl

* Generate plots
foreach reg in $reg_list {
	cap mkdir "${DIR_OUTPUT}/interacted_reg_output/plots/`reg'"
	cd "${rf_folder}/plots/`reg'"
	forval p = 3/3 {
		foreach weight in $weights_list {
			foreach f in ${fe_list} {
				foreach data_subset in ${data_subset_list} {
					foreach hist_weight in ${hist_weight_list} {
						foreach hist_style in ${hist_style_list} {
							local ster_name "interacted_reg_2_factor_2026_272841"
							plot_interacted_spline $interaction `f' `p' `data_subset' all_data_no_ci `ster_name' `hist_weight' `hist_style'
						}
					}
				}
			}
		}
	}	
}
