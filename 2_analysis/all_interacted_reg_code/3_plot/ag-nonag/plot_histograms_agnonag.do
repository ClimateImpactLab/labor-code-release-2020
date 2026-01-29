cap program drop plot_histograms
program define plot_histograms

    args tercile_unit weight interaction

    ****************************************
    * 0) SET COLLAPSER
    ****************************************
    if "`interaction'" == "interacted" | "`interaction'" == "triple_int" {
        global collapser = "clim_t inc_t"
    }
    else if "`interaction'" == "income" {
        global collapser = "inc_t"
    }
    else {
        di as error "interaction must be interacted / triple_int / income"
        exit 198
    }

    di "COLLAPSER $collapser"

    ****************************************
    * 1) PATHS & LOAD TERCILE CUTOFFS
    ****************************************
    local datapath = "/mnt/CIL_labor/2_regression/time_use/input"

    if "`tercile_unit'" == "hierid" {
        use "`datapath'/loggdppc_2010_grid.dta", clear
        merge 1:1 group using "`datapath'/lrtmax_tercile_cutoff.dta", nogen
    }
    else if "`tercile_unit'" == "rep_unit" {
        use "${ROOT_INT_DATA}/xtiles/rep_unit_terciles_grid.dta", clear
    }
    else {
        di as error "tercile_unit must be hierid or rep_unit"
        exit 198
    }

    di "GETTING TERCILE MAX CUTOFFS..."

    foreach x in loggdppc lrtmax {
        sum max_`x' if tercile == 1, meanonly
        global `x'1 = r(max)

        sum max_`x' if tercile == 2, meanonly
        global `x'2 = r(max)

        sum max_`x' if tercile == 3, meanonly
        global `x'3 = r(max)
    }

    di "Climate tercile cutoffs: $lrtmax1, $lrtmax2, $lrtmax3"
    di "Income tercile cutoffs:  $loggdppc1, $loggdppc2, $loggdppc3"

    ****************************************
    * 2) LOAD MAIN DATASET & ASSIGN TERCILES
    ****************************************
    use "/project/cil/battuta_shares/gcp/estimation/labor/code_release_int_data/regression_ready_data/labor_dataset_splines_nochn_tmax_chn_prev_week_no_ll_0_noMEXBRA.dta", clear

    di "ASSIGNING TO TERCILES..."

    cap drop clim_t inc_t
    gen clim_t = .
    replace clim_t = 1 if lr_tmax_p1 <= $lrtmax1 & !missing(lr_tmax_p1)
    replace clim_t = 2 if lr_tmax_p1 >  $lrtmax1 & lr_tmax_p1 <= $lrtmax2
    replace clim_t = 3 if lr_tmax_p1 >  $lrtmax2 & !missing(lr_tmax_p1)

    gen inc_t = .
    replace inc_t = 1 if log_gdp_pc_adm1 <= $loggdppc1 & !missing(log_gdp_pc_adm1)
    replace inc_t = 2 if log_gdp_pc_adm1 >  $loggdppc1 & log_gdp_pc_adm1 <= $loggdppc2
    replace inc_t = 3 if log_gdp_pc_adm1 >  $loggdppc2 & !missing(log_gdp_pc_adm1)

    * quick sanity check
    tab clim_t inc_t, missing

    count if missing(clim_t)
    if r(N) > 0 di as error "WARNING: " r(N) " observations have missing clim_t"

    count if missing(inc_t)
    if r(N) > 0 di as error "WARNING: " r(N) " observations have missing inc_t"

    ****************************************
    * 3) WEIGHTING SETUP
    ****************************************
    local weighting ""
    if "`weight'" != "no_wgt" {
        local weighting = "[aweight=`weight']"
    }

    ****************************************
    * 3.5) SAVE RAW DATA (FOR COUNTS LATER)
    ****************************************
    tempfile raw_data
    save `raw_data', replace

    ****************************************
    * 4) HISTOGRAM DATA: BIN + COLLAPSE
    ****************************************

    * global temperature range for plots
    global temp_min = -20
    global temp_max = 50

    * diagnostics you added (keep them)
    di "BEFORE BIN:"
    tab clim_t inc_t, missing
    count if clim_t==1 & inc_t==1
    di "N(1x1) before bin = " r(N)

    count if clim_t==1 & inc_t==1 & !missing(real_temperature)
    di "N(1x1) with nonmissing temp = " r(N)

    * create bin ONCE
    cap drop bin
    gen double bin = floor(real_temperature/0.1)*0.1

    count if clim_t==1 & inc_t==1 & !missing(bin)
    di "N(1x1) with nonmissing bin = " r(N)

    * create weight vars
    cap drop no_wgt
    gen double no_wgt = 1

    * choose base weight variable for histogram
    local wbase "`weight'"
    if "`weight'" == "no_wgt" local wbase "no_wgt"

    cap drop `wbase'_high `wbase'_low
    gen double `wbase'_high = `wbase' if high_risk == 1
    gen double `wbase'_low  = `wbase' if high_risk == 0

    * ensure output dir exists
    cap mkdir "${DIR_OUTPUT}/interacted_reg_output/plots"
    cap mkdir "${DIR_OUTPUT}/interacted_reg_output/plots/histograms"
    cap mkdir "${DIR_OUTPUT}/interacted_reg_output/plots/histograms/`interaction'"

    * collapse
    di "Collapsing to bins..."
    gcollapse (sum) `wbase' `wbase'_high `wbase'_low, by(bin $collapser)

    * totals within each cell
    gegen tot_high = total(`wbase'_high), by($collapser)
    gegen tot_low  = total(`wbase'_low),  by($collapser)
    gegen tot      = total(`wbase'),      by($collapser)

    * percentages
    cap drop `wbase'_hp `wbase'_lp `wbase'_p
    gen double `wbase'_hp = cond(tot_high>0, (`wbase'_high/tot_high)*100, 0)
    gen double `wbase'_lp = cond(tot_low>0,  (`wbase'_low/tot_low)*100,   0)
    gen double `wbase'_p  = cond(tot>0,      (`wbase'/tot)*100,           0)

    * y-axis scaling
    su `wbase'_hp, meanonly
    local max_hp = r(max)
    su `wbase'_lp, meanonly
    local max_lp = r(max)
    su `wbase'_p,  meanonly
    local max_p  = r(max)

    local ymax_pct = max(`max_hp', `max_lp', `max_p')
    local ymax_pct = ceil(`ymax_pct'*2)/2
    if `ymax_pct' < 2 local ymax_pct = 2
    di "Unified Y-axis max for percentages: `ymax_pct'"

    su `wbase', meanonly
    local ymax_abs = r(max)
    if "`weight'" == "no_wgt" {
        local ymax_abs = ceil(`ymax_abs'*1.1)
    }
    else {
        local ymax_abs = ceil(`ymax_abs'*20)/20
        if `ymax_abs' < 0.1 local ymax_abs = 0.1
    }
    local range_abs = "0 `ymax_abs'"

    * plotting variable
    cap drop temp
    gen double temp = bin

    * save collapsed snapshot for reuse
    tempfile collapsed_data
    save `collapsed_data', replace

    * build placeholder dataset (all zeros) with same vars for plotting
    tempfile placeholder
    preserve
        clear
        set obs 2
        gen double temp = ${temp_min} in 1
        replace temp = ${temp_max} in 2

        gen double `wbase'      = 0
        gen double `wbase'_high = 0
        gen double `wbase'_low  = 0
        gen double `wbase'_hp   = 0
        gen double `wbase'_lp   = 0
        gen double `wbase'_p    = 0

        if "`interaction'" == "interacted" | "`interaction'" == "triple_int" {
            gen clim_t = .
            gen inc_t  = .
        }
        else if "`interaction'" == "income" {
            gen inc_t  = .
        }

        save `placeholder', replace
    restore

    ****************************************
    * 5) PLOT HISTOGRAMS (REAL OR PLACEHOLDER)
    ****************************************
    local opts_x  `"xlab(${temp_min}(10)${temp_max}, labs(small)) xsc(range(${temp_min} ${temp_max})) xtitle("")"'
    local opts_abs `"barwidth(0.09) ylab(#4, labs(vsmall) angle(vertical)) graphregion(color(white) margin(zero)) plotregion(margin(zero)) fysize(10) `opts_x'"'
    local opts_pct `"barwidth(0.09) ylab(#4, labs(vsmall) angle(vertical)) graphregion(color(white) margin(zero)) plotregion(margin(zero)) fysize(10) `opts_x'"'

    if "`interaction'" == "interacted" | "`interaction'" == "triple_int" {

        local i = 1
        forvalues inc=1/3 {
            forvalues clim=1/3 {

                di "=== PLOTTING HIST FOR TERCILE `clim' X `inc' ==="

                use `collapsed_data', clear
                count if clim_t==`clim' & inc_t==`inc'
                local has = r(N)

                if `has' == 0 {
                    use `placeholder', clear
                    replace clim_t = `clim'
                    replace inc_t  = `inc'
                }
                else {
                    keep if clim_t==`clim' & inc_t==`inc'
                }

                tw bar `wbase'_high temp, ///
                    `opts_abs' ysc(range(`range_abs')) ytitle("Obs", size(small)) ///
                    name(hist`i'_hl_abs, replace)

                tw bar `wbase'_low temp, ///
                    `opts_abs' ysc(range(`range_abs')) ytitle("Obs", size(small)) ///
                    name(hist`i'_lr_abs, replace)

                tw bar `wbase' temp, ///
                    `opts_abs' ysc(range(`range_abs')) ytitle("Obs", size(small)) ///
                    name(hist`i'_hr_abs, replace)

                tw bar `wbase'_hp temp, ///
                    `opts_pct' ysc(range(0 `ymax_pct')) ytitle("%", size(small)) ///
                    name(hist`i'_hl_pct, replace)

                tw bar `wbase'_lp temp, ///
                    `opts_pct' ysc(range(0 `ymax_pct')) ytitle("%", size(small)) ///
                    name(hist`i'_lr_pct, replace)

                tw bar `wbase'_p temp, ///
                    `opts_pct' ysc(range(0 `ymax_pct')) ytitle("%", size(small)) ///
                    name(hist`i'_hr_pct, replace)

                foreach h in hr lr hl {
                    graph save hist`i'_`h'_abs "${DIR_OUTPUT}/interacted_reg_output/plots/histograms/`interaction'/hist`i'_`h'_abs.gph", replace
                    graph save hist`i'_`h'_pct "${DIR_OUTPUT}/interacted_reg_output/plots/histograms/`interaction'/hist`i'_`h'_pct.gph", replace
                }

                local ++i
            }
        }
    }
    else if "`interaction'" == "income" {

        local i = 1
        forvalues inc=1/3 {

            di "=== PLOTTING HIST FOR INCOME TERCILE `inc' ==="

            use `collapsed_data', clear
            count if inc_t==`inc'
            local has = r(N)

            if `has' == 0 {
                use `placeholder', clear
                replace inc_t = `inc'
            }
            else {
                keep if inc_t==`inc'
            }

            tw bar `wbase'_high temp, ///
                `opts_abs' ysc(range(`range_abs')) ytitle("Obs", size(small)) ///
                name(hist`i'_hl_abs, replace)

            tw bar `wbase'_low temp, ///
                `opts_abs' ysc(range(`range_abs')) ytitle("Obs", size(small)) ///
                name(hist`i'_lr_abs, replace)

            tw bar `wbase' temp, ///
                `opts_abs' ysc(range(`range_abs')) ytitle("Obs", size(small)) ///
                name(hist`i'_hr_abs, replace)

            tw bar `wbase'_hp temp, ///
                `opts_pct' ysc(range(0 `ymax_pct')) ytitle("%", size(small)) ///
                name(hist`i'_hl_pct, replace)

            tw bar `wbase'_lp temp, ///
                `opts_pct' ysc(range(0 `ymax_pct')) ytitle("%", size(small)) ///
                name(hist`i'_lr_pct, replace)

            tw bar `wbase'_p temp, ///
                `opts_pct' ysc(range(0 `ymax_pct')) ytitle("%", size(small)) ///
                name(hist`i'_hr_pct, replace)

            foreach h in hr lr hl {
                graph save hist`i'_`h'_abs "${DIR_OUTPUT}/interacted_reg_output/plots/histograms/`interaction'/hist`i'_`h'_abs.gph", replace
                graph save hist`i'_`h'_pct "${DIR_OUTPUT}/interacted_reg_output/plots/histograms/`interaction'/hist`i'_`h'_pct.gph", replace
            }

            local ++i
        }
    }

    ****************************************
    * 7) COUNTS FOR SUBTITLES (SAVE FILE)
    ****************************************
    di "STARTING COUNTS..."

    * IMPORTANT: go back to raw data with high_risk
    use `raw_data', clear

    cap drop count_lr count_hr count_rep_unit count_rep_year
    gen byte count_lr = (high_risk == 0) if !missing(high_risk)
    gen byte count_hr = (high_risk == 1) if !missing(high_risk)

    gegen count_rep_unit = tag(rep_unit)
    gegen count_rep_year = tag(rep_unit year)

    gcollapse (sum) count_lr count_hr count_rep_year count_rep_unit, by($collapser)

    save "${ROOT_INT_DATA}/xtiles/`tercile_unit'_terciles_count.dta", replace
    di "COUNTS COMPLETE."

end
