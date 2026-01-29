*****************
*    INITIALIZE
*****************

run "/project/cil/home_dirs/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"
run "${DIR_REPO_LABOR}/2_analysis/0_subroutines/functions.do"
run "${DIR_REPO_LABOR}/2_analysis/0_subroutines/utils.do"

gl ster_dir "${DIR_OUTPUT}/interacted_reg_output/ster"
gl rf_folder "${DIR_OUTPUT}/interacted_reg_output"

*****************
*    RUN F TEST
*****************

generate_coef_spline 3 rcspl

gl reg_list 2_factor
loc f fe_adm0_wk
loc N_knots 3
loc data_subset no_chn

foreach reg in $reg_list {
 
    di "`reg'"

    if "`reg'" == "1_factor" {
        loc ster_name "interacted_reg_1_factor_2025_climatehigh_only"
    }
    if "`reg'" == "2_factor" {
        loc ster_name "interacted_reg_2_factor_2026_272841"
    }

    test_interaction_spline `f' `N_knots' `data_subset' "`reg'" "`ster_name'" rep_unit_year_sample_wgt
}
