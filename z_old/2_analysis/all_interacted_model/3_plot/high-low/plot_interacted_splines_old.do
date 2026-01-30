clear all 

* Get paths
run "/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/0_subroutines/paths.do"
run "/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/2_analysis/all_interacted_reg_code/3_plot/high-low/utils_old.do"
run "/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/2_analysis/all_interacted_reg_code/3_plot/high-low/plot_histograms_old.do"

* Select input and output folder
global ster_dir "${DIR_OUTPUT}/interacted_reg_output/ster"
global rf_folder "${DIR_OUTPUT}/interacted_reg_output"

*****************
* CREATE SHORT WEIGHT VARIABLE
*****************
use "${ROOT_INT_DATA}/regression_ready_data/labor_dataset_splines_nochn_tmax_chn_prev_week_no_ll_0.dta", clear
gen wgt = rep_unit_year_sample_wgt_old
save "${ROOT_INT_DATA}/regression_ready_data/labor_dataset_splines_nochn_tmax_chn_prev_week_no_ll_0.dta", replace

*****************
* MAKE PLOTS
*****************
* Other selections
local N_knots 3 
global reg_list "2_factor"
global data_subset_list "no_chn"

* Now use short weight name
global weights_list "wgt"
global hist_weight_list "wgt"

global fe_list "fe_week_adm0" 
global interaction "interacted"
global tercile "rep_unit"
global hist_style_list "abs pct"
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
							local ster_name "interacted_reg_`reg'_2025_high_old"
							plot_interacted_spline $interaction `f' `p' `data_subset' all_data_no_ci `ster_name' `hist_weight' `hist_style'
						}
					}
				}
			}
		}
	}	
}
