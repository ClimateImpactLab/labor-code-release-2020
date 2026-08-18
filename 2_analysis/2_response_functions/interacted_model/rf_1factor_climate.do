*-------------------------------------------------------------------------------
* rf_1factor_climate.do
*-------------------------------------------------------------------------------
* PURPOSE
*   Build response CSVs for the 1-factor climate model
*   The script writes one full temperature grid and one set of table temperatures
*
* STEPS
*   1. Load the shared interacted model settings
*   2. Load the 1-factor estimates
*   3. Predict low-risk and high-risk responses
*   4. Export response values as CSV files
*
* INPUTS
*   Stata estimates file from run_1factor_climate.do
*
* OUTPUTS
*   Full response CSV and table-values CSV
*-------------------------------------------------------------------------------

clear all

*-------------------------------------------------------------------------------
* Setup
*-------------------------------------------------------------------------------

run "/project/cil/home_dirs/`c(username)'/repos/labor-code-release-2020/2_analysis/1_regression/interacted_model/config.do"

numlist "-20(0.1)47"
global APPG_FULL_RESPONSE `r(numlist)'

numlist "45 40 35 30 27 10 5 0 -5 -10"
global APPG_TABLE_VALUES `r(numlist)'

*-------------------------------------------------------------------------------
* Predict responses
*-------------------------------------------------------------------------------

cap program drop _appg_predict_climate_rf
program define _appg_predict_climate_rf
	args temp_list outfile

	qui make_temp_dist, list(`temp_list') ref(${APPG_REF_TEMP})
	estimates use "${APPG_REG_FOLDER}/${APPG_OUTPUT_TAG}.ster"
	make_spline_terms ${APPG_KNOT1} ${APPG_KNOT2} ${APPG_KNOT3}

	gen mins_worked = .

	#delimit ;
	predictnl yhat_low =
		(T_spline0 - ref_spline0) *
			(_b[tmax_rcspl_3kn_t0_lr] + _b[tmax_rcspl_3kn_t0_lr_v1] + _b[tmax_rcspl_3kn_t0_lr_v2] +
			 _b[tmax_rcspl_3kn_t0_lr_v3] + _b[tmax_rcspl_3kn_t0_lr_v4] + _b[tmax_rcspl_3kn_t0_lr_v5] +
			 _b[tmax_rcspl_3kn_t0_lr_v6]) +
		(T_spline1 - ref_spline1) *
			(_b[tmax_rcspl_3kn_t1_lr] + _b[tmax_rcspl_3kn_t1_lr_v1] + _b[tmax_rcspl_3kn_t1_lr_v2] +
			 _b[tmax_rcspl_3kn_t1_lr_v3] + _b[tmax_rcspl_3kn_t1_lr_v4] + _b[tmax_rcspl_3kn_t1_lr_v5] +
			 _b[tmax_rcspl_3kn_t1_lr_v6]),
		ci(lowerci_low upperci_low) se(se_low);

	predictnl yhat_high =
		(T_spline0 - ref_spline0) *
			(_b[tmax_rcspl_3kn_t0_hr_l] + _b[tmax_rcspl_3kn_t0_hr_l_v1] + _b[tmax_rcspl_3kn_t0_hr_l_v2] +
			 _b[tmax_rcspl_3kn_t0_hr_l_v3] + _b[tmax_rcspl_3kn_t0_hr_l_v4] + _b[tmax_rcspl_3kn_t0_hr_l_v5] +
			 _b[tmax_rcspl_3kn_t0_hr_l_v6]) +
		(T_spline1 - ref_spline1) *
			(_b[tmax_rcspl_3kn_t1_hr_l] + _b[tmax_rcspl_3kn_t1_hr_l_v1] + _b[tmax_rcspl_3kn_t1_hr_l_v2] +
			 _b[tmax_rcspl_3kn_t1_hr_l_v3] + _b[tmax_rcspl_3kn_t1_hr_l_v4] + _b[tmax_rcspl_3kn_t1_hr_l_v5] +
			 _b[tmax_rcspl_3kn_t1_hr_l_v6]),
		ci(lowerci_high upperci_high) se(se_high);
	#delimit cr

	drop T* ref_* min* mins_worked
	export delimited using "`outfile'", replace
	clear
end

*-------------------------------------------------------------------------------
* Export CSV files
*-------------------------------------------------------------------------------

_appg_predict_climate_rf "$APPG_FULL_RESPONSE" "${APPG_RF_FOLDER}/${APPG_OUTPUT_TAG}_full_response.csv"
_appg_predict_climate_rf "$APPG_TABLE_VALUES" "${APPG_RF_FOLDER}/${APPG_OUTPUT_TAG}_table_values.csv"
