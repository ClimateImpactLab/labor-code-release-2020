******************************************************
* RUNNER CODE (for income interaction)
******************************************************
clear all 
run "/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/0_subroutines/paths.do"

* Source the helper programs
run "/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/2_analysis/all_interacted_reg_code/3_plot/ag-nonag-1factor-gdp/utils_gdp.do"
run "/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/2_analysis/all_interacted_reg_code/3_plot/ag-nonag-1factor-gdp/plot_histograms_gdp.do"

* Set global directories and parameters
global ster_dir "${DIR_OUTPUT}/interacted_reg_output/ster"
global rf_folder "${DIR_OUTPUT}/interacted_reg_output"

* Spline parameters
local N_knots 3 

* Regression specifications
global reg_list "1_factor"
global data_subset_list "no_chn"
global weights_list "rep_unit_year_sample_wgt"
global fe_list "fe_week_adm0" 

* Interaction type: income
global interaction "income"
global tercile "rep_unit"

* Histogram settings
global hist_weight_list "rep_unit_year_sample_wgt"
global hist_style_list "pct"

* Number of grids for income (3 terciles: poor, middle, rich)
global max_g 3

* Step 1: Generate histograms
di "========================================="
di "STEP 1: GENERATING HISTOGRAMS"
di "========================================="
foreach weight in $hist_weight_list {
	plot_histograms $tercile `weight' $interaction
}

* Step 2: Generate grids and load counts
di "========================================="
di "STEP 2: GENERATING GRIDS AND LOADING COUNTS"
di "========================================="
generate_grids $tercile $interaction

* Step 3: Generate spline coefficients
di "========================================="
di "STEP 3: GENERATING SPLINE COEFFICIENTS"
di "========================================="
generate_coef_spline 3 rcspl

* Step 4: Generate plots
di "========================================="
di "STEP 4: GENERATING PLOTS"
di "========================================="
foreach reg in $reg_list {
	cap mkdir "${DIR_OUTPUT}/interacted_reg_output/plots/`reg'"
	cd "${rf_folder}/plots/`reg'"
	
	forval p = 3/3 {
		foreach weight in $weights_list {
			foreach f in ${fe_list} {
				foreach data_subset in ${data_subset_list} {
					foreach hist_weight in ${hist_weight_list} {
						foreach hist_style in ${hist_style_list} {
							* Specify the .ster file name for income interaction
							local ster_name "interacted_reg_1_factor_2026_272841_income"
							
							di "Plotting: `ster_name'"
							plot_interacted_spline $interaction `f' `p' `data_subset' all_data_with_ci `ster_name' `hist_weight' `hist_style'
						}
					}
				}
			}
		}
	}	
}

di "========================================="
di "PLOTTING COMPLETE"
di "========================================="




