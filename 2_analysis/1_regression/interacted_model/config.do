*-------------------------------------------------------------------------------
* config.do
*-------------------------------------------------------------------------------
* PURPOSE
*   Set the shared choices for the interacted model scripts
*   This keeps file names, knots, weights, and output folders in one place
*
* STEPS
*   1. Load repo paths and shared Stata programs
*   2. Define the dataset, knots, weights, fixed effects, and output folders
*   3. Create output folders if they are missing
*
* INPUTS
*   Repository paths and shared functions
*
* OUTPUTS
*   Stata globals used by the interacted regression, response, table, and figure scripts
*-------------------------------------------------------------------------------

*-------------------------------------------------------------------------------
* Load shared code
*-------------------------------------------------------------------------------

run "/project/cil/home_dirs/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"
run "${DIR_REPO_LABOR}/2_analysis/0_subroutines/functions.do"

*-------------------------------------------------------------------------------
* Shared choices
*-------------------------------------------------------------------------------

global APPG_ROOT "${DIR_REPO_LABOR}/2_analysis/1_regression/interacted_model"

global APPG_DATASET "${ROOT_INT_DATA}/regression_ready_data/labor_dataset_splines_nochn_tmax_chn_prev_week_no_ll_0_agnonag_272841_0814.dta"
global APPG_TERCILE_GRID "${ROOT_INT_DATA}/xtiles/new/rep_unit_terciles_grid_0722.dta"

global APPG_OUTPUT_TAG "interacted_reg_1_factor_climate_2026"
global APPG_2FACTOR_NAME "interacted_reg_2_factor_2026"

global APPG_REG_FOLDER "${DIR_STER}/interacted_model"
global APPG_RF_FOLDER "${DIR_RF}/interacted_model"
global APPG_PLOT_FOLDER "${DIR_FIG}/interacted_appendix_g_2026/data"
global APPG_FIG_FOLDER "${DIR_FIG}/interacted_appendix_g_2026"
global APPG_TABLE_FOLDER "${DIR_TABLE}/interacted_model"

global APPG_REF_TEMP 27
global APPG_KNOT1 27
global APPG_KNOT2 28
global APPG_KNOT3 41
global APPG_N_KNOTS 3

global APPG_REG_LIST "1_factor"
global APPG_FACTOR "climate"
global APPG_RISK_VAR "high_risk"
global APPG_FE "fe_adm0_wk"
global APPG_WEIGHT "rep_unit_year_sample_wgt"
global APPG_CLUSTER "cluster_adm1yymm"

*-------------------------------------------------------------------------------
* Output folders
*-------------------------------------------------------------------------------

cap mkdir "${APPG_REG_FOLDER}"
cap mkdir "${APPG_RF_FOLDER}"
cap mkdir "${APPG_PLOT_FOLDER}"
cap mkdir "${APPG_TABLE_FOLDER}"
cap mkdir "${APPG_FIG_FOLDER}"
cap mkdir "${APPG_ROOT}/logs"
