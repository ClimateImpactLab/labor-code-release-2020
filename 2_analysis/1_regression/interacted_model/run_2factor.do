*-------------------------------------------------------------------------------
* run_2factor.do
*-------------------------------------------------------------------------------
* PURPOSE
*   Run the 2-factor interacted regression
*   The model lets temperature effects vary by risk group, income, and long-run temperature
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
*   Stata estimates file for the 2-factor model
*-------------------------------------------------------------------------------

clear all
cap log close

*-------------------------------------------------------------------------------
* Setup
*-------------------------------------------------------------------------------

run "/project/cil/home_dirs/`c(username)'/repos/labor-code-release-2020/2_analysis/1_regression/interacted_model/config.do"

log using "${APPG_ROOT}/logs/${APPG_2FACTOR_NAME}.smcl", replace

*-------------------------------------------------------------------------------
* Prepare survey rows
*-------------------------------------------------------------------------------

use "${APPG_DATASET}", clear

drop if iso == "GBR" & year == 1984 & month == 1 & day == 2
keep if mins_worked > 0

rename *${APPG_KNOT1}_${APPG_KNOT2}_${APPG_KNOT3}_* **

gen_controls_and_FEs
gen_treatment_splines rcspl ${APPG_N_KNOTS} tmax this_week 1

cap drop risk_level
gen risk_level = ${APPG_RISK_VAR}

*-------------------------------------------------------------------------------
* Build regression terms
*-------------------------------------------------------------------------------

local reg_treatment (${vars_T_splines} ${vars_T_x_gdp_splines} ///
	${vars_T_x_lr_tmax_splines})##i.risk_level

local reg_control (${usual_controls})##i.risk_level

local fe_terms "${fe_adm0_wk}"
local reg_fe ""
foreach f of local fe_terms {
	local reg_fe `reg_fe' `f'#risk_level
}

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

estimates notes: "Appendix G; 2-factor income and climate; dataset 0814; knots ${APPG_KNOT1} ${APPG_KNOT2} ${APPG_KNOT3}; rep-unit-year weights"
estimates save "${APPG_REG_FOLDER}/${APPG_2FACTOR_NAME}.ster", replace

cap log close
