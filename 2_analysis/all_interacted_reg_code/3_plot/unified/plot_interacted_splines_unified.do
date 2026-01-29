******************************************************
* UNIFIED RUNNER CODE FOR ALL INTERACTION TYPES
* Supports: income, climate, and interacted (climate x income)
******************************************************
clear all 

* Load paths
run "/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/0_subroutines/paths.do"

* Source helper programs
run "/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/2_analysis/all_interacted_reg_code/3_plot/unified/utils_unified.do"
run "/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/2_analysis/all_interacted_reg_code/3_plot/unified/plot_histograms_unified.do"

* Set global directories
global ster_dir "${DIR_OUTPUT}/interacted_reg_output/ster"
global rf_folder "${DIR_OUTPUT}/interacted_reg_output"

******************************************************
* USER CONFIGURATION SECTION
******************************************************

* Choose interaction type: "income", "climate", or "interacted"
global interaction "interacted"  // Change this to switch interaction types
global plot_format "pretty"
* Spline parameters
local N_knots 3 

* Regression specifications
global reg_list "2_factor"  // Use "2_factor" for interacted
global data_subset_list "no_chn"
global weights_list "rep_unit_year_sample_wgt"
global fe_list "fe_week_adm0" 

* Tercile unit: "rep_unit" or "hierid"
global tercile "rep_unit"

* Histogram settings
global hist_weight_list "rep_unit_year_sample_wgt"
global hist_style_list "pct"

* Set number of grids based on interaction type
if "$interaction" == "income" | "$interaction" == "climate" {
    global max_g 3
}
else if "$interaction" == "interacted" | "$interaction" == "triple_int" {
    global max_g 9
}

* Set .ster file name based on interaction type
if "$interaction" == "income" {
    global ster_name "interacted_reg_1_factor_2026_272841_income"
}
else if "$interaction" == "climate" {
    global ster_name "interacted_reg_1_factor_2026_272841_climate"
}
else if "$interaction" == "interacted" | "$interaction" == "triple_int" {
    global ster_name "interacted_reg_2_factor_2026_272841"
}

* Set plot style: "all_data_with_ci" or "all_data_no_ci"
global plot_style "all_data_with_ci"

******************************************************
* EXECUTION PIPELINE
******************************************************

* Step 1: Generate histograms (must run first to create counts)
di "========================================="
di "STEP 1: GENERATING HISTOGRAMS"
di "Interaction type: $interaction"
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
generate_coef_spline `N_knots' rcspl

* Step 4: Generate plots
di "========================================="
di "STEP 4: GENERATING PLOTS"
di "========================================="
foreach reg in $reg_list {
    cap mkdir "${DIR_OUTPUT}/interacted_reg_output/plots/`reg'"
    cd "${rf_folder}/plots/`reg'"
    
    forval p = `N_knots'/`N_knots' {
        foreach weight in $weights_list {
            foreach f in ${fe_list} {
                foreach data_subset in ${data_subset_list} {
                    foreach hist_weight in ${hist_weight_list} {
                        foreach hist_style in ${hist_style_list} {
                            di "Plotting: $ster_name with $interaction interaction"
                            plot_interacted_spline $interaction `f' `p' `data_subset' $plot_style $ster_name `hist_weight' `hist_style'
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
