clear all

* get paths
run "/project/cil/home_dirs/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"
run "/project/cil/home_dirs/`c(username)'/repos/labor-code-release-2020/2_analysis/0_subroutines/utils.do"
run "/project/cil/home_dirs/`c(username)'/repos/labor-code-release-2020/2_analysis/all_interacted_reg_code/3_plot/plot_histograms.do"

* select input and output folder
global ster_dir "${DIR_OUTPUT}/interacted_reg_output/ster"
global rf_folder  "${DIR_OUTPUT}/interacted_reg_output"

*****************
*   MAKE PLOTS
*****************

local N_knots 3

global reg_list 2_factor
global data_subset_list no_chn
global weights_list rep_unit_year_sample_wgt_sector
global fe_list fe_week_adm0
global interaction "interacted"
global tercile rep_unit
global hist_weight_list rep_unit_year_sample_wgt_sector
global hist_style_list abs pct
global risk_group_list low ag nonag
global max_g 9

***********************
*   HISTOGRAMS
***********************

foreach weight in $hist_weight_list {
    plot_histograms $tercile `weight' $interaction
}

***********************
*   GRID DEFINITIONS
***********************

generate_grids_sector $tercile $interaction

******************************************************
*   PROGRAM: plot_interacted_spline  (3 risk groups)
******************************************************

cap program drop plot_interacted_spline
program define plot_interacted_spline
    args interaction f N_knots data_subset plot_style ster_name hist_weight hist_style

    cap mkdir `plot_style'
    cd `plot_style'

    di "Using: ${ster_dir}/`ster_name'.ster"

    estimates clear
    estimates use "${ster_dir}/`ster_name'.ster"

    generate_coef_spline_sector `N_knots' rcspl
    generate_temperature -20 50 27
    spline_temperature_range `N_knots'

    if "`interaction'" == "income" local size = 50
    else local size = 20

    foreach risk in low ag nonag {

        if "`risk'" == "low"   local plot_tag low_risk
        if "`risk'" == "ag"    local plot_tag ag_risk
        if "`risk'" == "nonag" local plot_tag nonag_risk

        forvalues g = 1/$max_g {
            gen_response_surface_spline `N_knots' `risk' `g'
            gen_plot "${tag`g'}" `g' `plot_style' `risk' `hist_weight' `size'
        }

        * histogram files use suffix: low / ag / nonag
        local hist_suffix "`risk'"
        forvalues i = 1/$max_g {
            local h`i' "/project/cil/home_dirs/`c(username)'/repos/labor-code-release-2020/output/interacted_reg_output/plots/histograms/$interaction/hist`i'_`hist_suffix'_`hist_style'.gph"
        }

        graph combine ///
            plot1 plot2 plot3 "`h1'" "`h2'" "`h3'" ///
            plot4 plot5 plot6 "`h4'" "`h5'" "`h6'" ///
            plot7 plot8 plot9 "`h7'" "`h8'" "`h9'", ///
            plotregion(color(white)) ///
            graphregion(color(white) margin(t=5 b=5)) ///
            xcomm imargin(0 0 0 0) cols(3) ///
            xsize(8) ysize(12) ///
            title("`plot_tag' response function in climate-income", size(medium)) ///
            subtitle("`ster_name', hist: `hist_weight' `hist_style'", size(vsmall))

        graph export "`ster_name'_`plot_tag'_hist`hist_weight'_`hist_style'.pdf", replace
    }

    cd ..
end

***********************
*   RESPONSE FUNCTIONS
***********************

foreach reg in $reg_list {

    cap mkdir "${DIR_OUTPUT}/interacted_reg_output/plots/`reg'"
    cd "${rf_folder}/plots/`reg'"

    local ster_name "interacted_reg_`reg'_2025_sector_fc"

    forvalues p = 3/3 {
        foreach weight in $weights_list {
            foreach f in $fe_list {
                foreach data_subset in $data_subset_list {
                    foreach hist_weight in $hist_weight_list {
                        foreach hist_style in $hist_style_list {

                            di "Running reg `reg'  fe `f'  subset `data_subset'"

                            plot_interacted_spline ///
                                $interaction ///
                                `f' ///
                                `N_knots' ///
                                `data_subset' ///
                                all_data_no_ci ///
                                `ster_name' ///
                                `hist_weight' ///
                                `hist_style'
                        }
                    }
                }
            }
        }
    }
}

cd "${DIR_REPO_LABOR}"
