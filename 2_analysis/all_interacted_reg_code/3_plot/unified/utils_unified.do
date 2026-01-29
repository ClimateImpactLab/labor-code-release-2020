******************************************************
* UNIFIED UTILITY FUNCTIONS
* Supports: income (1-factor), climate (1-factor), and interacted (2-factor)
* Styles: pretty and normal (for income/climate)
******************************************************

******************************************************
* generate_coef_spline - Extract spline coefficients
* Handles 1-factor (income/climate) and 2-factor (interacted)
******************************************************
cap program drop generate_coef_spline
program define generate_coef_spline
    args N_knots spl_varname

    local N_new_vars=`N_knots'-2 

    forval k=0/`N_new_vars'{

        * Initialize all coefficient globals
        global b_T_spline_`k'_lr 0
        global b_T_x_gdp_spline_`k'_lr 0
        global b_T_x_lrtmax_spline_`k'_lr 0

        global b_T_spline_`k'_hr 0
        global b_T_x_gdp_spline_`k'_hr 0
        global b_T_x_lrtmax_spline_`k'_hr 0 

        * Check if this is a 2-factor model (interacted)
        cap confirm parameter _b[c.tmax_`spl_varname'_`N_knots'kn_t`k'#c.log_gdp_pc_adm1]
        
        if !_rc {
            * 2-FACTOR MODEL (interacted): full interaction syntax
            di "Detected 2-factor model (interacted)"
            
            global b_T_spline_`k'_lr _b[tmax_`spl_varname'_`N_knots'kn_t`k']
            global b_T_x_gdp_spline_`k'_lr _b[c.tmax_`spl_varname'_`N_knots'kn_t`k'#c.log_gdp_pc_adm1]
            global b_T_x_lrtmax_spline_`k'_lr _b[c.tmax_`spl_varname'_`N_knots'kn_t`k'#c.lr_tmax_p1]

            global b_T_spline_`k'_hr _b[1.risk_level#c.tmax_`spl_varname'_`N_knots'kn_t`k']
            global b_T_x_gdp_spline_`k'_hr _b[1.risk_level#c.tmax_`spl_varname'_`N_knots'kn_t`k'#c.log_gdp_pc_adm1]
            global b_T_x_lrtmax_spline_`k'_hr _b[1.risk_level#c.tmax_`spl_varname'_`N_knots'kn_t`k'#c.lr_tmax_p1]
            
            * Add lag terms for 2-factor model
            forval lag=1/6{
                global b_T_spline_`k'_lr ${b_T_spline_`k'_lr}+_b[tmax_`spl_varname'_`N_knots'kn_t`k'_v`lag']
                global b_T_x_gdp_spline_`k'_lr ${b_T_x_gdp_spline_`k'_lr}+_b[c.tmax_`spl_varname'_`N_knots'kn_t`k'_v`lag'#c.log_gdp_pc_adm1]
                global b_T_x_lrtmax_spline_`k'_lr ${b_T_x_lrtmax_spline_`k'_lr}+_b[c.tmax_`spl_varname'_`N_knots'kn_t`k'_v`lag'#c.lr_tmax_p1]

                global b_T_spline_`k'_hr ${b_T_spline_`k'_hr}+_b[1.risk_level#c.tmax_`spl_varname'_`N_knots'kn_t`k'_v`lag']
                global b_T_x_gdp_spline_`k'_hr ${b_T_x_gdp_spline_`k'_hr}+_b[1.risk_level#c.tmax_`spl_varname'_`N_knots'kn_t`k'_v`lag'#c.log_gdp_pc_adm1]
                global b_T_x_lrtmax_spline_`k'_hr ${b_T_x_lrtmax_spline_`k'_hr}+_b[1.risk_level#c.tmax_`spl_varname'_`N_knots'kn_t`k'_v`lag'#c.lr_tmax_p1]
            }
        }
        else {
            * 1-FACTOR MODEL (income or climate): using _g suffix
            di "Detected 1-factor model"
            
            * Low risk: base temperature effect
            global b_T_spline_`k'_lr _b[tmax_`spl_varname'_`N_knots'kn_t`k'_lr]
            
            * High risk: base effect
            global b_T_spline_`k'_hr _b[tmax_`spl_varname'_`N_knots'kn_t`k'_hr]
            
            * High risk: interaction term (using _g suffix)
            global b_T_x_gdp_spline_`k'_hr _b[tmax_`spl_varname'_`N_knots'kn_t`k'_hr_g]
            global b_T_x_lrtmax_spline_`k'_hr _b[tmax_`spl_varname'_`N_knots'kn_t`k'_hr_g]
            
            * Add lag terms for 1-factor model
            forval lag=1/6{
                * Low risk lags
                cap confirm parameter _b[tmax_`spl_varname'_`N_knots'kn_t`k'_lr_v`lag']
                if !_rc {
                    global b_T_spline_`k'_lr ${b_T_spline_`k'_lr}+_b[tmax_`spl_varname'_`N_knots'kn_t`k'_lr_v`lag']
                }
                
                * High risk base lags
                cap confirm parameter _b[tmax_`spl_varname'_`N_knots'kn_t`k'_hr_v`lag']
                if !_rc {
                    global b_T_spline_`k'_hr ${b_T_spline_`k'_hr}+_b[tmax_`spl_varname'_`N_knots'kn_t`k'_hr_v`lag']
                }
                
                * High risk interaction lags
                cap confirm parameter _b[tmax_`spl_varname'_`N_knots'kn_t`k'_hr_g_v`lag']
                if !_rc {
                    global b_T_x_gdp_spline_`k'_hr ${b_T_x_gdp_spline_`k'_hr}+_b[tmax_`spl_varname'_`N_knots'kn_t`k'_hr_g_v`lag']
                    global b_T_x_lrtmax_spline_`k'_hr ${b_T_x_lrtmax_spline_`k'_hr}+_b[tmax_`spl_varname'_`N_knots'kn_t`k'_hr_g_v`lag']
                }
            }
        }

        * High risk total = base + interaction
        global b_T_spline_`k'_hl ${b_T_spline_`k'_hr}
        global b_T_x_gdp_spline_`k'_hl ${b_T_x_gdp_spline_`k'_hr}
        global b_T_x_lrtmax_spline_`k'_hl ${b_T_x_lrtmax_spline_`k'_hr}
    }
end

******************************************************
* gen_response_surface_spline - Generate predictions
* Automatically handles income, climate, and interacted
******************************************************
cap program drop gen_response_surface_spline
program define gen_response_surface_spline

    args N_knots risk grid

    local N_new_vars=`N_knots'-2 
    global response_surface 0
    
    forval i=0/`N_new_vars'{
        * Base temperature effect (always present)
        gl response_surface ${response_surface}+(${b_T_spline_`i'`risk'})*(T_spline`i'-T_ref_spline`i')
        
        * Income interaction effect (if exists)
        cap confirm scalar ${minc`grid'}
        if !_rc {
            gl response_surface ${response_surface}+(${b_T_x_gdp_spline_`i'`risk'})*(T_spline`i'-T_ref_spline`i')*${minc`grid'}
        }
        
        * Climate interaction effect (if exists)
        cap confirm scalar ${lrtmax`grid'}
        if !_rc {
            gl response_surface ${response_surface}+(${b_T_x_lrtmax_spline_`i'`risk'})*(T_spline`i'-T_ref_spline`i')*${lrtmax`grid'}
        }
    }
    
    cap drop yhat *_ci
    di "`risk' `grid': $response_surface"
    predictnl yhat = $response_surface, ci(lower_ci upper_ci)
end

******************************************************
* gen_marginal_resp_spline - Marginal effects
* For income (gdp) or climate (lrtmax)
******************************************************
cap program drop gen_marginal_resp_spline
program define gen_marginal_resp_spline

    args N_knots risk

    local N_new_vars=`N_knots'-2 
    global response 0

    * Determine which interaction to use based on what exists
    local use_gdp = 0
    local use_lrtmax = 0
    
    * Check if we have income grids
    cap confirm scalar ${minc1}
    if !_rc {
        local use_gdp = 1
    }
    
    * Check if we have climate grids
    cap confirm scalar ${lrtmax1}
    if !_rc {
        local use_lrtmax = 1
    }

    forval i=0/`N_new_vars'{
        if `use_gdp' == 1 {
            global response $response + (${b_T_x_gdp_spline_`i'`risk'})*(T_spline`i' - T_ref_spline`i')
        }
        if `use_lrtmax' == 1 {
            global response $response + (${b_T_x_lrtmax_spline_`i'`risk'})*(T_spline`i' - T_ref_spline`i')
        }
    }
    cap drop yhat *_ci
    di "$response"
    predictnl yhat = $response, ci(lower_ci upper_ci)
end

******************************************************
* gen_plot - Create individual response plots
* Supports pretty and normal styles
******************************************************
cap program drop gen_plot
program define gen_plot 
    args plot_title g plot_style risk weight 
    
    local plot_name = "plot`g'"
    
    local cutoffs = "xline(${p1`g'`risk'_`weight'}, lcol(gold) lpatt(-) lw(medium)) xline(${p99`g'`risk'_`weight'}, lcol(gold) lpatt(-) lw(medium)) xline(${p5`g'`risk'_`weight'}, lcol(orange) lpatt(_) lw(medium)) xline(${p95`g'`risk'_`weight'}, lcol(orange) lpatt(_) lw(medium))"
    
    preserve 
    
    * Extrema detection (for normal style)
    local peak_lines = ""
    local extrema_note = ""
    
    if "$plot_format" == "normal" {
        quietly {
            summarize temp
            local temp_min_range = r(min)
            local temp_max_range = r(max)
            
            sort temp
            
            gen double deriv = (yhat[_n+1] - yhat[_n-1]) / (temp[_n+1] - temp[_n-1])
            
            gen byte sign_deriv = sign(deriv)
            gen byte sign_change = (sign_deriv[_n] != sign_deriv[_n-1]) & !missing(sign_deriv[_n]) & !missing(sign_deriv[_n-1])
            
            gen byte is_local_min = sign_change & (sign_deriv[_n] > sign_deriv[_n-1])
            gen byte is_local_max = sign_change & (sign_deriv[_n] < sign_deriv[_n-1])
            
            replace is_local_min = 0 if abs(temp - `temp_min_range') <= 1 | abs(temp - `temp_max_range') <= 1
            replace is_local_max = 0 if abs(temp - `temp_min_range') <= 1 | abs(temp - `temp_max_range') <= 1
            
            count if is_local_min == 1
            local n_mins = r(N)
            
            count if is_local_max == 1
            local n_maxs = r(N)
        }
        
        * Build extrema annotations for normal style
        if `n_mins' > 0 {
            quietly {
                local min_counter = 0
                forvalues i = 1/`=_N' {
                    if is_local_min[`i'] == 1 {
                        local temp_val = round(temp[`i'], 0.1)
                        local ++min_counter
                        
                        local peak_lines = "`peak_lines' xline(`temp_val', lcol(blue) lpatt(dash))"
                        
                        if `n_mins' == 1 {
                            local extrema_note = "`extrema_note'Min at T=`temp_val'°C"
                        }
                        else {
                            if `min_counter' == 1 {
                                local extrema_note = "`extrema_note'Min`min_counter' at T=`temp_val'°C"
                            }
                            else {
                                local extrema_note = "`extrema_note', Min`min_counter' at T=`temp_val'°C"
                            }
                        }
                    }
                }
            }
        }
        
        if `n_maxs' > 0 {
            quietly {
                local max_counter = 0
                forvalues i = 1/`=_N' {
                    if is_local_max[`i'] == 1 {
                        local temp_val = round(temp[`i'], 0.1)
                        local ++max_counter
                        
                        local peak_lines = "`peak_lines' xline(`temp_val', lcol(green) lpatt(dash))"
                        
                        if "`extrema_note'" != "" {
                            local extrema_note = "`extrema_note', "
                        }
                        
                        if `n_maxs' == 1 {
                            local extrema_note = "`extrema_note'Max at T=`temp_val'°C"
                        }
                        else {
                            local extrema_note = "`extrema_note'Max`max_counter' at T=`temp_val'°C"
                        }
                    }
                }
            }
        }
    }
    
    * Set y-axis styling based on format
    if "$plot_format" == "pretty" {
        * Pretty style: conditional y-axis
        if `g' == 1 {
            local yaxis_opts "ylab(#8, labs(medium) ang(vertical) tlcolor(black) nogrid tlw(medium)) ytitle("{bf:Minutes worked}", size(medium) color(white))"
        }
        else {
            local yaxis_opts "ylab(#8, labs(medium) ang(vertical) labcolor(white) tlcolor(white) nogrid tlw(medium)) ytitle("{bf:Minutes worked}", size(medium) color(white))"
        }
        local fysize_opt "fysize(80)"
        local subtitle_opt ""
        local note_opt ""
    }
    else {
        * Normal style: standard formatting with subtitle
        local yaxis_opts "ylab(#8,labs(vsmall) ang(vertical)) ytitle("mins worked", size(small))"
        local fysize_opt "fysize(50)"
        local subtitle_opt `"subtitle("${risk`risk'_`plot_name'} obs, ${ru_`plot_name'} rep-units, ${ry_`plot_name'} rep-unit-years.", size(small))"'
        if "`extrema_note'" != "" {
            local note_opt `"note("`extrema_note'", size(vsmall) position(6))"'
        }
    }
    
    * Generate plots with or without confidence intervals
    if "`plot_style'" == "all_data_with_ci"{
        tw rarea upper_ci lower_ci temp, col(ltbluishgray) || ///
           line yhat temp, lc(dknavy) lw(medium) yline(0, lw(medium)) `cutoffs' `peak_lines' ///
           title("`plot_title'") legend(off) ///
           `yaxis_opts' ///
           xlab("",labs(small)) `fysize_opt' xtitle("") ///
           name(`plot_name', replace) ///
           graphregion(margin(zero) color(white)) ///
           `subtitle_opt' ///
           `note_opt' ///
           ysc(r(${YMIN`risk'} ${YMAX`risk'}) lw(medium)) ///
           xsc(off lw(medium))
    }
    
    if "`plot_style'" == "all_data_no_ci"{
        tw line yhat temp, lc(dknavy) lw(medium) yline(0, lw(medium)) `cutoffs' `peak_lines' ///
           title("`plot_title'") legend(off) ///
           `yaxis_opts' ///
           xlab("",labs(small)) `fysize_opt' xtitle("") ///
           name(`plot_name', replace) ///
           graphregion(margin(zero) color(white)) ///
           `subtitle_opt' ///
           `note_opt' ///
           ysc(r(${YMIN`risk'} ${YMAX`risk'}) lw(medium)) ///
           xsc(off lw(medium))
    }
    restore
end

******************************************************
* gen_marg_plot - Create marginal effect plots
******************************************************
cap program drop gen_marg_plot
program define gen_marg_plot 
    args plot_title plot_name plot_style
    preserve 
    if "`plot_style'" == "all_data_with_ci"{
        tw rarea upper_ci lower_ci temp, col(ltbluishgray) || line yhat temp, lc (dknavy) yline(0) title("`plot_title'") legend(off) graphregion(color(white)) ylabel(,angle(horizontal)) ytitle("mins worked") xtitle("Temperature C", height(6)) name(`plot_name', replace)
    }
    if "`plot_style'" == "all_data_no_ci"{
        tw  line yhat temp, lc (dknavy) yline(0) title("`plot_title'") legend(off) graphregion(color(white)) ylabel(,angle(horizontal)) ytitle("mins worked") xtitle("Temperature C", height(6)) name(`plot_name', replace)
    }
    restore
end

******************************************************
* plot_interacted_spline - Main plotting routine
* Handles all interaction types with unified y-axis
******************************************************
cap program drop plot_interacted_spline
program define plot_interacted_spline
    args interaction f N_knots data_subset plot_style ster_name hist_weight hist_style

    cap mkdir `plot_style'
    cd `plot_style'

    di "Using: ${ster_dir}/`ster_name'.ster"
    estimates use "${ster_dir}/`ster_name'.ster"

    generate_temperature -20 50 27
    spline_temperature_range `N_knots'

    ******************************************************
    * STEP 1: Calculate global y-axis range
    ******************************************************
    di "========================================="
    di "STEP 1: CALCULATING GLOBAL Y-AXIS RANGE"
    di "========================================="
    
    tempfile temp_predictions
    
    * Initialize global min/max for each risk level
    foreach risk in _lr _hr _hl {
        scalar ymin`risk' = .
        scalar ymax`risk' = .
    }
    
    * Generate predictions for all grids to find range
    foreach risk in _lr _hr _hl {
        forval g = 1/$max_g {
            gen_response_surface_spline `N_knots' `risk' `g'
            
            * Get min/max including confidence intervals
            quietly {
                sum yhat, detail
                local temp_min = r(min)
                local temp_max = r(max)
                
                * Also check CI bounds
                cap confirm variable lower_ci
                if !_rc {
                    sum lower_ci, detail
                    local temp_min = min(`temp_min', r(min))
                }
                
                cap confirm variable upper_ci
                if !_rc {
                    sum upper_ci, detail
                    local temp_max = max(`temp_max', r(max))
                }
            }
            
            * Update global min/max
            if missing(ymin`risk') | `temp_min' < ymin`risk' {
                scalar ymin`risk' = `temp_min'
            }
            if missing(ymax`risk') | `temp_max' > ymax`risk' {
                scalar ymax`risk' = `temp_max'
            }
            
            di "Risk `risk', Grid `g': yhat range [`temp_min', `temp_max']"
        }
    }
    
    * Set unified y-axis ranges with padding
    foreach risk in _lr _hr _hl {
        local range = ymax`risk' - ymin`risk'
        local padding = `range' * 0.05
        
        global YMIN`risk' = floor((ymin`risk' - `padding') / 50) * 50
        global YMAX`risk' = ceil((ymax`risk' + `padding') / 50) * 50
        
        di "Final unified y-axis for `risk': [${YMIN`risk'}, ${YMAX`risk'}]"
    }

    ******************************************************
    * STEP 2: Generate plots with unified y-axis
    ******************************************************
    di "========================================="
    di "STEP 2: GENERATING PLOTS"
    di "========================================="
    
    foreach risk in _lr _hr _hl {
        forval g = 1/$max_g {
            gen_response_surface_spline `N_knots' `risk' `g'
            gen_plot "${tag`g'}" `g' `plot_style' `risk' `hist_weight'
        }
        
        * Set plot tag
        if "`risk'" == "_lr" local plot_tag low_risk
        if "`risk'" == "_hl" local plot_tag high_risk
        if "`risk'" == "_hr" local plot_tag marginal_risk

        * Set histogram paths
        forval i=1/$max_g {
            local h`i' = "${DIR_OUTPUT}/interacted_reg_output/plots/histograms/$interaction/hist`i'`risk'_`hist_style'.gph"
        }
        
        * Combine plots based on interaction type
        if "`interaction'" == "interacted" | "`interaction'" == "triple_int" {
            * 9-panel plot (3x3 grid)
            graph combine ///
                plot7 plot8 plot9 "`h7'" "`h8'" "`h9'" ///
                plot4 plot5 plot6 "`h4'" "`h5'" "`h6'" ///
                plot1 plot2 plot3 "`h1'" "`h2'" "`h3'", ///
                plotregion(color(white)) ///
                graphregion(color(white) margin(t=5 b=5)) ///
                imargin(0 0 0 0) ///
                rows(2) cols(6) ///
                xsize(12) ysize(8) ///
                l1title("{bf:Minutes worked}", size(medium)) ///
                b1title("{bf:Temperature (°C)}", size(medium))
        }
        else if "`interaction'" == "income" | "`interaction'" == "climate" {
            * 3-panel plot (1x3 grid)
            graph combine ///
                plot1 plot2 plot3 "`h1'" "`h2'" "`h3'", ///
                plotregion(color(white)) ///
                graphregion(color(white) margin(t=5 b=5)) ///
                imargin(0 0 0 0) ///
                rows(2) cols(3) ///
                holes(4 5 6) ///
                xsize(12) ysize(5) ///
                l1title("{bf:Minutes worked}", size(medium)) ///
                b1title("{bf:Temperature (°C)}", size(medium))
        }
        
        graph export "`ster_name'_`plot_tag'_hist`hist_weight'_`hist_style'.pdf", replace
    }

    ******************************************************
    * STEP 3: Generate marginal response plots
    ******************************************************
    di "========================================="
    di "STEP 3: GENERATING MARGINAL PLOTS"
    di "========================================="
    
    * Determine which marginal plots to create
    local has_gdp = 0
    local has_lrtmax = 0
    
    cap confirm scalar ${minc1}
    if !_rc {
        local has_gdp = 1
    }
    
    cap confirm scalar ${lrtmax1}
    if !_rc {
        local has_lrtmax = 1
    }
    
    * Create marginal plots
    if `has_gdp' == 1 {
        foreach risk in _lr _hl {
            gen_marginal_resp_spline `N_knots' `risk'
            export delim using "marginal_resp_spline_`risk'_gdp.csv", replace
            if "`risk'" == "_lr" local plot_tag low_risk
            if "`risk'" == "_hl" local plot_tag high_risk
            
            gen_marg_plot "`plot_tag'" `plot_tag' `plot_style' 
        }
        graph combine low_risk high_risk, ///
            plotregion(color(white)) graphregion(color(white)) ///
            cols(2) ycommon title("GDP Interaction") subtitle("`ster_name'")
        graph export "`ster_name'_marginal_gdp.pdf", replace
    }
    
    if `has_lrtmax' == 1 {
        foreach risk in _lr _hl {
            gen_marginal_resp_spline `N_knots' `risk'
            export delim using "marginal_resp_spline_`risk'_lrtmax.csv", replace
            if "`risk'" == "_lr" local plot_tag low_risk
            if "`risk'" == "_hl" local plot_tag high_risk
            
            gen_marg_plot "`plot_tag'" `plot_tag' `plot_style' 
        }
        graph combine low_risk high_risk, ///
            plotregion(color(white)) graphregion(color(white)) ///
            cols(2) ycommon title("Climate Interaction") subtitle("`ster_name'")
        graph export "`ster_name'_marginal_lrtmax.pdf", replace
    }
    
    cd ..
end

******************************************************
* generate_grids - Set up tercile grids
* Handles income, climate, and interacted
******************************************************
cap program drop generate_grids
program define generate_grids
    
    args tercile interaction

    ******************************************************
    * Load appropriate grid data
    ******************************************************
    if "`interaction'" == "climate" {
        * Load climate grid only
        if "`tercile'" == "hierid" {
            use "/project/cil/norgay/CIL_labor/2_regression/time_use/input/lrtmax_grid.dta", clear
        }
        else if "`tercile'" == "rep_unit" {
            use "/project/cil/battuta_shares/gcp/estimation/labor/code_release_int_data/xtiles/rep_unit_terciles_grid.dta", clear
        }
        else di "!! Incorrect tercile specification. Permitted: rep_unit, hierid."

        sum mean_lrtmax, detail

        local lrtmax_cold=`r(min)'
        local lrtmax_warm=`r(p50)'
        local lrtmax_hot=`r(max)'
        
        global max_g = 3
        
        global lrtmax1 `lrtmax_cold'
        global lrtmax2 `lrtmax_warm'
        global lrtmax3 `lrtmax_hot'
        
        global tag1 cold
        global tag2 warm
        global tag3 hot
    }
    else if "`interaction'" == "income" {
        * Load income grid only
        if "`tercile'" == "hierid" {
            use "/project/cil/norgay/CIL_labor/2_regression/time_use/input/loggdppc_2010_grid.dta", clear
        }
        else if "`tercile'" == "rep_unit" {
            use "/project/cil/battuta_shares/gcp/estimation/labor/code_release_int_data/xtiles/rep_unit_terciles_grid.dta", clear
        }
        else di "!! Incorrect tercile specification. Permitted: rep_unit, hierid."

        sum mean_loggdppc, detail

        local inc_poor =`r(min)'
        local inc_midl =`r(p50)'
        local inc_rich =`r(max)'
        
        global max_g = 3
        
        global minc1 `inc_poor'
        global minc2 `inc_midl'
        global minc3 `inc_rich'
        
        global tag1 poor
        global tag2 midincome
        global tag3 rich
    }
    else if "`interaction'" == "interacted" | "`interaction'" == "triple_int" {
        * Load both climate and income grids
        if "`tercile'" == "rep_unit" {
            use "/project/cil/battuta_shares/gcp/estimation/labor/code_release_int_data/xtiles/rep_unit_terciles_grid.dta", clear
        }
        else {
            di as error "!! Interacted model requires rep_unit terciles"
            exit 198
        }

        sum mean_lrtmax, detail
        local lrtmax_cold=`r(min)'
        local lrtmax_warm=`r(p50)'
        local lrtmax_hot=`r(max)'
        
        sum mean_loggdppc, detail
        local inc_poor =`r(min)'
        local inc_midl =`r(p50)'
        local inc_rich =`r(max)'
        
        global max_g = 9

        * Set climate values for all 9 grids
        global lrtmax1 `lrtmax_cold'
        global lrtmax2 `lrtmax_warm'
        global lrtmax3 `lrtmax_hot'
        global lrtmax4 `lrtmax_cold'
        global lrtmax5 `lrtmax_warm'
        global lrtmax6 `lrtmax_hot'
        global lrtmax7 `lrtmax_cold'
        global lrtmax8 `lrtmax_warm'
        global lrtmax9 `lrtmax_hot'

        * Set income values for all 9 grids
        global minc1 `inc_poor'
        global minc2 `inc_poor'
        global minc3 `inc_poor'
        global minc4 `inc_midl'
        global minc5 `inc_midl'
        global minc6 `inc_midl'
        global minc7 `inc_rich'
        global minc8 `inc_rich'
        global minc9 `inc_rich'

        global tag1 cold-poor
        global tag2 warm-poor
        global tag3 hot-poor
        global tag4 cold-midincome
        global tag5 warm-midincome
        global tag6 hot-midincome
        global tag7 cold-rich
        global tag8 warm-rich
        global tag9 hot-rich
    }

    ******************************************************
    * Read counts and set global macros
    ******************************************************
    di "READING COUNTS FROM FILE..."
    
    use "${ROOT_INT_DATA}/xtiles/`tercile'_terciles_count.dta", clear
    
    if "`interaction'" == "climate" {
        local i = 1
        forvalues clim = 1(1)3 {
            sum count_lr if clim_t == `clim', meanonly
            global risk_lr_plot`i' = r(sum)
            
            sum count_hr if clim_t == `clim', meanonly
            global risk_hr_plot`i' = r(sum)
            global risk_hl_plot`i' = r(sum)
            
            sum count_rep_unit if clim_t == `clim', meanonly
            global ru_plot`i' = r(sum)
            
            sum count_rep_year if clim_t == `clim', meanonly
            global ry_plot`i' = r(sum)
            
            di "Grid `i': LR=${risk_lr_plot`i'}, HR=${risk_hr_plot`i'}, RU=${ru_plot`i'}, RY=${ry_plot`i'}"
            
            local ++i
        }
    }
    else if "`interaction'" == "income" {
        local i = 1
        forvalues inc = 1(1)3 {
            sum count_lr if inc_t == `inc', meanonly
            global risk_lr_plot`i' = r(sum)
            
            sum count_hr if inc_t == `inc', meanonly
            global risk_hr_plot`i' = r(sum)
            global risk_hl_plot`i' = r(sum)
            
            sum count_rep_unit if inc_t == `inc', meanonly
            global ru_plot`i' = r(sum)
            
            sum count_rep_year if inc_t == `inc', meanonly
            global ry_plot`i' = r(sum)
            
            di "Grid `i': LR=${risk_lr_plot`i'}, HR=${risk_hr_plot`i'}, RU=${ru_plot`i'}, RY=${ry_plot`i'}"
            
            local ++i
        }
    }
    else if "`interaction'" == "interacted" | "`interaction'" == "triple_int" {
        local i = 1
        forvalues inc = 1(1)3 {
            forvalues clim = 1(1)3 {
                sum count_lr if clim_t == `clim' & inc_t == `inc', meanonly
                global risk_lr_plot`i' = r(sum)
                
                sum count_hr if clim_t == `clim' & inc_t == `inc', meanonly
                global risk_hr_plot`i' = r(sum)
                global risk_hl_plot`i' = r(sum)
                
                sum count_rep_unit if clim_t == `clim' & inc_t == `inc', meanonly
                global ru_plot`i' = r(sum)
                
                sum count_rep_year if clim_t == `clim' & inc_t == `inc', meanonly
                global ry_plot`i' = r(sum)
                
                di "Grid `i': LR=${risk_lr_plot`i'}, HR=${risk_hr_plot`i'}, RU=${ru_plot`i'}, RY=${ry_plot`i'}"
                
                local ++i
            }
        }
    }
    
    di "COUNTS LOADED INTO GLOBAL MACROS."
end

******************************************************
* generate_temperature - Create temperature grid
******************************************************
cap program drop generate_temperature
program define generate_temperature

    args min max ref

    cap drop if _n > 0
    cap drop _all
    cap drop temp
    gen temp=.
    local obs = `max' - `min' + 1
    set obs `obs'
    replace temp = _n - 1 + `min'
    gen ref = `ref'
    gen mins_worked = 0
end

******************************************************
* spline_temperature_range - Create spline basis
******************************************************
cap program drop spline_temperature_range
program define spline_temperature_range
    args N_knots

    * Set knot locations based on N_knots
    if `N_knots' == 3 {
        local knots 27 37 39
    }
    
    local N_vars_sp=`N_knots'-1

    * Identify first and last knots
    loc count=1
    foreach k in `knots'{
        if `count'==1{
            loc first_knot=`k'
        }
        if `count'==`N_knots'{
            loc last_knot=`k'
        }
        loc count=`count' + 1
    }

    * Calculate scaling factor
    local scaling_factor=(`last_knot'-`first_knot')^2

    * Create cubic splines
    mkspline T_spline=temp, cubic knots(`knots')
    mkspline T_ref_spline=ref, cubic knots(`knots')

    * Apply scaling to higher order terms
    forval k=2/`N_vars_sp'{
        replace T_spline`k'=T_spline`k'*`scaling_factor'
        replace T_ref_spline`k'=T_ref_spline`k'*`scaling_factor'
    }

    * Rename to match expected naming convention
    rename T_spline1 T_spline0
    rename T_spline2 T_spline1
    rename T_ref_spline1 T_ref_spline0
    rename T_ref_spline2 T_ref_spline1
end
