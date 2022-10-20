* most programs are similar in function and structure to plot_interacted_polynomials.do
* the only difference is that instead of looping from poly 1 to poly N,
* we loop from term 0 to term (N_knots - 2)
* and we generate special temperature variables using mkspline function

clear all 

* get paths
run "/home/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"
run "/home/`c(username)'/repos/labor-code-release-2020/2_analysis/0_subroutines/utils.do"
run "/home/`c(username)'/repos/labor-code-release-2020/2_analysis/all_interacted_reg_code/plot_histograms.do"

* select input and output folder
gl ster_dir "${DIR_OUTPUT}/interacted_reg_output/ster"
gl rf_folder "${DIR_OUTPUT}/interacted_reg_output"


*****************
*	MAKE PLOTS
*****************

* other selections

local N_knots 3 

global reg_list 1_factor
* takes: 1_factor 2_factor

global data_subset_list no_chn
*global data_subset_list FRA GBR ESP IND CHN USA BRA MEX EU daily weekly no_chn all_data 

global weights_list rep_unit_year_sample_wgt

global fe_list fe_week_adm0 

global interaction "income"
* takes: interacted, income, triple_int

global tercile rep_unit
* takes: rep_unit, hierid

global hist_weight_list rep_unit_year_sample_wgt
* takes: no_wgt rep_unit_year_sample_wgt

global hist_style_list abs pct

global max_g 3

foreach weight in $hist_weight_list {
	plot_histograms rep_unit `weight' $interaction
}

generate_grids $tercile $interaction
generate_coef_spline 3 rcspl

foreach reg in $reg_list{
	cap mkdir "${DIR_OUTPUT}/interacted_reg_output/plots/`reg'"
	cd "${rf_folder}/plots/`reg'"
	forval p = 3/3 {
		foreach weight in $weights_list {
			foreach f in ${fe_list} {
				foreach data_subset in ${data_subset_list} {
					foreach hist_weight in ${hist_weight_list} {
						foreach hist_style in ${hist_style_list} {
							di "`reg_list'"
							loc ster_name "interacted_reg_`reg'"
							plot_interacted_spline $interaction `f' `p' `data_subset' all_data_with_ci `ster_name' `hist_weight' `hist_style'
						}
					}
				}
			}
		}
	}	
}
