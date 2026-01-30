*****************
*  INITIALIZE
*****************

* get functions and paths
run "/project/cil/home_dirs/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"
run "${DIR_REPO_LABOR}/2_analysis/0_subroutines/functions.do"

* log results
cap log close 
log using "/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/logs/interacted_polynomials_lr_interaction_and_mixed_weight_new.smcl", replace

* select dataset and output folder
gl dataset      "/project/cil/battuta_shares/gcp/estimation/labor/code_release_int_data/regression_ready_data/labor_dataset_polynomials_nochn_tmax_chn_prev_week_no_ll_0.dta"
loc reg_folder  "${DIR_OUTPUT}/interacted_reg_output/ster"

* other selections
gl test_code "no"
gl reg_list 1_factor
loc fe fe_adm0_wk
local t_version "tmax"

* Note on weights: 
*   run regression 1_factor with mixed weights (see line 131, 144,)
*   run regression 2_factor with rep_unit_year_sample_wgt

* ---------- CHOOSE WHICH RISK DEFINITION TO USE ---------- 
global risk_def "high_risk"
* --------------------------------------------------------

********************
*  RUN REGRESSION
********************

* cycle through each of the two regressions
foreach reg in $reg_list {
    forval N_order=2(1)4 {
        di "`reg_list'"
        gl dataset "/project/cil/battuta_shares/gcp/estimation/labor/code_release_int_data/regression_ready_data/labor_dataset_polynomials_nochn_tmax_chn_prev_week_no_ll_0.dta"
        cap mkdir "${DIR_STER}/interacted_polynomials"
        loc reg_folder "${DIR_STER}/interacted_polynomials"

        use $dataset, clear
        drop if iso == "GBR" & year == 1984 & month == 1 & day == 2

        * if test code mode is on, take a random sample
        if "${test_code}"=="yes" {
            sample 0.1
        }

        * only include non-zero observations
        keep if mins_worked > 0

        * generate regression variables
        gen_controls_and_FEs
        gen_treatment_polynomials `N_order' tmax this_week 1

        * ---------- DEFINE risk_level FROM CHOSEN SOURCE ----------
        cap drop risk_level
        gen risk_level = .
        replace risk_level = high_risk_old if "${risk_def}"=="high_risk_old"
        replace risk_level = high_risk        if "${risk_def}"=="high_risk"
        replace risk_level = sector if "${risk_def}"=="sector"
        replace risk_level = occup_code if "${risk_def}"=="occup_code"
        * ----------------------------------------------------------

        * generate variables for the pooled regression to get the correct coeffs for LR group
        gen low_risk = 1 - risk_level

        * -------------------------------------------------------------------
        * LOW RISK: Polynomial terms WITHOUT lr_tmax interaction
        * -------------------------------------------------------------------
        forval degree = 1/`N_order' {
            gen tmax_p`degree'_lr = tmax_p`degree' * low_risk
            
            * Add lagged versions
            forval lag = 1/6 {
                gen tmax_p`degree'_lr_v`lag' = tmax_p`degree'_v`lag' * low_risk
            }
        }

        * -------------------------------------------------------------------
        * HIGH RISK: Polynomial terms WITHOUT lr_tmax (base effect)
        * -------------------------------------------------------------------
        forval degree = 1/`N_order' {
            gen tmax_p`degree'_hr = tmax_p`degree' * risk_level
            
            * Add lagged versions
            forval lag = 1/6 {
                gen tmax_p`degree'_hr_v`lag' = tmax_p`degree'_v`lag' * risk_level
            }
        }

        * -------------------------------------------------------------------
        * HIGH RISK: Polynomial terms WITH lr_tmax interaction
        * Variable naming: _l suffix means "× lr_tmax"
        * -------------------------------------------------------------------
        forval degree = 1/`N_order' {
            gen tmax_p`degree'_hr_l = tmax_p`degree' * risk_level * lr_tmax_p1
            
            * Add lagged versions
            forval lag = 1/6 {
                gen tmax_p`degree'_hr_l_v`lag' = tmax_p`degree'_v`lag' * risk_level * lr_tmax_p1
            }
        }

        * -------------------------------------------------------------------
        * SPECIFY REGRESSION TREATMENT VARIABLES
        * -------------------------------------------------------------------
        if "`reg'" == "1_factor" {
            local reg_treatment tmax_p*_lr tmax_p*_lr_v* ///
                               tmax_p*_hr tmax_p*_hr_v* ///
                               tmax_p*_hr_l tmax_p*_hr_l_v*
        }
        else if "`reg'" == "2_factor" {
            local reg_treatment (${vars_T_polynomials} ${vars_T_x_gdp_polynomials} ${vars_T_x_lr_`t_version'_polynomials})##i.risk_level
        }
        else {
            di in red "bad reg specification -> pick '1_factor' or '2_factor'"
        }
        
        di _n "{hline 60}"
        di "TREATMENT SPECIFICATION:"
        di "`reg_treatment'"
        di "{hline 60}" _n

        * both regressions have interacted controls
        local reg_control (${usual_controls})##i.risk_level
        di "CONTROL SPECIFICATION:"
        di "`reg_control'" _n
        
        * interact each fixed effect with the risk binary
        local reg_fe ""                    
        foreach f in $`fe' {
            local reg_fe `reg_fe' `f'#risk_level
        }
        
        * -------------------------------------------------------------------
        * SET OUTPUT NAMES AND WEIGHTS
        * -------------------------------------------------------------------
        local ster_name "`reg_folder'/interacted_polynomials_`reg'_`N_order'_2025.ster"
        local spec_desc "polynomials order `N_order', tmax, LR uninteracted, HR with lr_tmax interaction, fe = $fe, reg_type = `reg'"

        * set the regression weight
        loc weight "rep_unit_year_sample_wgt"

        * -------------------------------------------------------------------
        * RUN REGRESSION
        * -------------------------------------------------------------------
        di _n "{hline 70}"
        di "RUNNING REGRESSION: `reg', polynomial order = `N_order'"
        di "{hline 70}"
        di "Command: reghdfe mins_worked `reg_treatment' `reg_control' [pweight = `weight'], absorb(`reg_fe') vce(cl cluster_adm1yymm)"
        di "{hline 70}" _n
        
        reghdfe mins_worked `reg_treatment' `reg_control' [pweight = `weight'], absorb(`reg_fe') vce(cl cluster_adm1yymm)

        * -------------------------------------------------------------------
        * VERIFY THAT _l VARIABLES ARE INCLUDED
        * -------------------------------------------------------------------
        di _n "{hline 70}"
        di "CHECKING IF lr_tmax INTERACTION TERMS (_l variables) ARE INCLUDED:"
        di "{hline 70}"
        
        local coef_names : colnames e(b)
        local found_l = 0
        
        foreach name in `coef_names' {
            if regexm("`name'", "_hr_l") {
                di "  ✓ Found: `name'"
                local found_l = 1
            }
        }
        
        if `found_l' == 0 {
            di as error "  ✗ WARNING: No _hr_l variables found in regression!"
            di as error "  The lr_tmax interaction may not be included."
        }
        else {
            di as text _n "  ✓ SUCCESS: lr_tmax interaction terms (_l) are included in the regression."
        }
        di "{hline 70}" _n

        * count regression N by risk
        gen included = e(sample)
        count if included == 1 & risk_level == 0
        estadd scalar low_N = `r(N)'
        count if included == 1 & risk_level == 1
        estadd scalar high_N = `r(N)'

        * Display regression statistics
        di _n "{hline 70}"
        di "REGRESSION STATISTICS:"
        di "{hline 70}"
        di "Polynomial order:     " `N_order'
        di "N observations:       " %12.0fc e(N)
        di "  Low risk N:         " %12.0fc e(low_N)
        di "  High risk N:        " %12.0fc e(high_N)
        di "N clusters:           " %12.0fc e(N_clust)
        di "R-squared:            " %12.4f e(r2)
        di "Adjusted R-squared:   " %12.4f e(r2_a)
        di "Root MSE:             " %12.4f e(rmse)
        di "{hline 70}" _n

        estimates notes: "`spec_desc' representative unit-year weights"
        estimates save "`ster_name'", replace

        di "COMPLETED: `reg' regression, polynomial order `N_order'."
        di "Saved to: `ster_name'" _n
    }
}

cap log close
