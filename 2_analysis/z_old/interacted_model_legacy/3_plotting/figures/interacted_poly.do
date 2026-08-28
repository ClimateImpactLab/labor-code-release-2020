
******************************************************
* MAIN RUNNER (your style, minimal changes)
******************************************************

clear all

* Get paths
run "/project/cil/home_dirs/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"
run "${DIR_REPO_LABOR}/2_analysis/0_subroutines/utils_poly.do"
run "/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/2_analysis/all_interacted_reg_code/3_plot/poly-ag-nonag/plot_histograms_poly.do"

* Select input and output folder
global ster_dir "${DIR_OUTPUT}/interacted_reg_output/2_factor_poly/ster"
* global rf_folder "${DIR_OUTPUT}/interacted_reg"

*****************
* MAKE PLOTS
*****************
global reg_list "2_factor"
global data_subset_list "no_chn"
global weights_list "rep_unit_year_sample_wgt"
global fe_list "fe_week_adm0"
global interaction "interacted"
global tercile "rep_unit"
global hist_weight_list "rep_unit_year_sample_wgt"
global hist_style_list "pct"
global max_g 9

// * IMPORTANT: Run plot_histograms FIRST to generate counts/macros
// foreach weight in $hist_weight_list {
//     plot_histograms $tercile `weight' $interaction
// }

* Then run generate_grids which will use the counts from plot_histograms
generate_grids $tercile $interaction

* Generate plots
foreach reg in $reg_list {
    
    cd "${DIR_OUTPUT}/interacted_reg_output/2_factor_poly/plot"

    foreach weight in $weights_list {
        foreach f in ${fe_list} {
            foreach data_subset in ${data_subset_list} {
                foreach hist_weight in ${hist_weight_list} {
                    foreach hist_style in ${hist_style_list} {
		    	forval max_degree = 2(1)4 {
				* <-- put your correct ster_name here
				local ster_name "interacted_polynomials_2_factor_`max_degree'"

				plot_interacted_poly $interaction `f' `max_degree' `data_subset' all_data_no_ci `ster_name' `hist_weight' `hist_style'
			}
                    }
                }
            }
        }
    }
}
