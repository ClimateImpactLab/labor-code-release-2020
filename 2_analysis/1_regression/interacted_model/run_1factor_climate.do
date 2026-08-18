*-------------------------------------------------------------------------------
* run_1factor_climate.do
*-------------------------------------------------------------------------------
* PURPOSE
*   Run the 1-factor interacted climate regression
*   The model separates low-risk and high-risk workers and lets high-risk workers vary with long-run temperature
*
* STEPS
*   1. Load the shared interacted model settings
*   2. Prepare survey rows and spline terms
*   3. Run the regression and save the estimates
*
* INPUTS
*   Regression-ready spline dataset set in config.do
*   Shared programs from 2_analysis/0_subroutines/functions.do
*
* OUTPUTS
*   Stata estimates file for the 1-factor climate model
*-------------------------------------------------------------------------------

clear all
cap log close

*-------------------------------------------------------------------------------
* Setup
*-------------------------------------------------------------------------------

run "/project/cil/home_dirs/`c(username)'/repos/labor-code-release-2020/2_analysis/1_regression/interacted_model/config.do"

log using "${APPG_ROOT}/logs/${APPG_OUTPUT_TAG}.smcl", replace

*-------------------------------------------------------------------------------
* Prepare survey rows
*-------------------------------------------------------------------------------

use "${APPG_DATASET}", clear

drop if iso == "GBR" & year == 1984 & month == 1 & day == 2
keep if mins_worked > 0

rename *${APPG_KNOT1}_${APPG_KNOT2}_${APPG_KNOT3}_* **

gen_controls_and_FEs
gen_treatment_splines rcspl ${APPG_N_KNOTS} tmax this_week 1

cap drop risk_level low_risk
gen risk_level = ${APPG_RISK_VAR}
gen low_risk = 1 - risk_level

*-------------------------------------------------------------------------------
* Build treatment terms
*-------------------------------------------------------------------------------

local suffixes base v1 v2 v3 v4 v5 v6

forvalues term = 0/1 {
	foreach suffix of local suffixes {
		local src_suffix = cond("`suffix'" == "base", "", "_`suffix'")
		local out_suffix = cond("`suffix'" == "base", "", "_`suffix'")
		gen tmax_rcspl_3kn_t`term'_lr`out_suffix' = tmax_rcspl_3kn_t`term'`src_suffix' * low_risk
		gen tmax_rcspl_3kn_t`term'_hr`out_suffix' = tmax_rcspl_3kn_t`term'`src_suffix' * risk_level
		gen tmax_rcspl_3kn_t`term'_hr_l`out_suffix' = tmax_rcspl_3kn_t`term'`src_suffix' * risk_level * lr_tmax_p1
	}
}

local reg_treatment tmax_rcspl_3kn_t0_lr* tmax_rcspl_3kn_t1_lr* ///
	tmax_rcspl_3kn_t0_hr* tmax_rcspl_3kn_t1_hr*

local reg_control (${usual_controls})##i.risk_level

local fe_terms "${fe_adm0_wk}"
local reg_fe ""
foreach f of local fe_terms {
	local reg_fe `reg_fe' `f'#risk_level
}

* Use mixed weights from the final 1-factor setup
replace ${APPG_WEIGHT} = risk_adj_sample_wgt if risk_level == 0

*-------------------------------------------------------------------------------
* Run regression
*-------------------------------------------------------------------------------

di "reghdfe mins_worked `reg_treatment' `reg_control' [pweight = ${APPG_WEIGHT}], absorb(`reg_fe') vce(cl ${APPG_CLUSTER})"

reghdfe mins_worked `reg_treatment' `reg_control' [pweight = ${APPG_WEIGHT}], ///
	absorb(`reg_fe') vce(cl ${APPG_CLUSTER})

gen included = e(sample)
count if included == 1 & risk_level == 0
estadd scalar low_N = `r(N)'
count if included == 1 & risk_level == 1
estadd scalar high_N = `r(N)'

estimates notes: "Appendix G; 1-factor climate; dataset 0814; knots ${APPG_KNOT1} ${APPG_KNOT2} ${APPG_KNOT3}; mixed 1-factor weights"
estimates save "${APPG_REG_FOLDER}/${APPG_OUTPUT_TAG}.ster", replace

cap log close
