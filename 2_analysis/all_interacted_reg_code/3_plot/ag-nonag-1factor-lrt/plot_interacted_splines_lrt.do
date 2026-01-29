
******************************************************
* RUNNER CODE
******************************************************
clear all 
run "/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/0_subroutines/paths.do"

* Source the helper programs above (save them in a .do file and run it here)
run "/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/2_analysis/all_interacted_reg_code/3_plot/ag-nonag-1factor-lrt/utils_lrt.do"

run "/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/2_analysis/all_interacted_reg_code/3_plot/ag-nonag-1factor-lrt/plot_histograms_lrt.do"

global ster_dir "${DIR_OUTPUT}/interacted_reg_output/ster"
global rf_folder "${DIR_OUTPUT}/interacted_reg_output"

local N_knots 3 
global reg_list "1_factor"
global data_subset_list "no_chn"
global weights_list "rep_unit_year_sample_wgt"
global fe_list "fe_week_adm0" 
global interaction "climate"
global tercile "rep_unit"
global hist_weight_list "rep_unit_year_sample_wgt"
global hist_style_list "pct"
global max_g 3

* Run plot_histograms FIRST
foreach weight in $hist_weight_list {
	plot_histograms $tercile `weight' $interaction
}

* Run generate_grids
generate_grids $tercile $interaction

* Generate spline coefficients
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
							local ster_name "interacted_reg_1_factor_2026_climate"
							plot_interacted_spline $interaction `f' `p' `data_subset' all_data_with_ci `ster_name' `hist_weight' `hist_style'
						}
					}
				}
			}
		}
	}	
}
