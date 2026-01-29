*******************************************************
*  plot_histograms.do  (3 risk groups: low / ag / nonag)
*******************************************************

* Load paths
run "/project/cil/home_dirs/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"

*******************************************************
*  PROGRAM: PLOT HISTOGRAMS & COUNTS
*******************************************************

cap program drop plot_histograms
program define plot_histograms

    * Arguments:
    *   tercile_unit : rep_unit or hierid
    *   weight       : name of weight variable or no_wgt
    *   interaction  : interacted / triple_int / income

    args tercile_unit weight interaction

    * Short tag for this weight, used in global names (avoid 32-char limit)
    local wtag "`weight'"
    if "`weight'" == "rep_unit_year_sample_wgt_sector" local wtag "rusec"

    ***************************************************
    * Decide the collapser list
    ***************************************************

    if "`interaction'" == "interacted" | "`interaction'" == "triple_int" {
        global collapser "clim_t inc_t"
    }
    else if "`interaction'" == "income" {
        global collapser "inc_t"
    }

    di "COLLAPSER = $collapser"

    ***************************************************
    * Load tercile cutoff data
    ***************************************************

    local datapath "/project/cil/norgay/CIL_labor/2_regression/time_use/input"

    if "`tercile_unit'" == "hierid" {
        use "`datapath'/loggdppc_2010_grid.dta", clear
        merge 1:1 group using "`datapath'/lrtmax_tercile_cutoff.dta", nogen
    }
    else if "`tercile_unit'" == "rep_unit" {
        use "${ROOT_INT_DATA}/xtiles/rep_unit_terciles_grid.dta", clear
    }

    di "GETTING TERCILE MAX CUTOFFS..."

    foreach x in loggdppc lrtmax {
        quietly summarize max_`x', detail
        global `x'1 = r(min)
        global `x'2 = r(p50)
        global `x'3 = r(max)
    }

    ***************************************************
    * Load regression dataset
    ***************************************************

    use "/project/cil/battuta_shares/gcp/estimation/labor/code_release_int_data/regression_ready_data/labor_dataset_splines_nochn_tmax_chn_prev_week_no_ll_0_agnonag_272841_0121.dta", clear

    di "ASSIGNING OBSERVATIONS TO TERCILES..."

    * Climate terciles
    gen clim_t = 3
    replace clim_t = 2 if lr_tmax_p1 <= $lrtmax2
    replace clim_t = 1 if lr_tmax_p1 <= $lrtmax1

    * Income terciles
    gen inc_t = 3
    replace inc_t = 2 if log_gdp_pc_adm1 <= $loggdppc2
    replace inc_t = 1 if log_gdp_pc_adm1 <= $loggdppc1

    ***************************************************
    * Risk groups: 0=low, 1=ag, 2=nonag (sector)
    ***************************************************

    * sector assumed in dataset:
    *   sector == 0 : low risk
    *   sector == 1 : high-risk agriculture
    *   sector == 2 : high-risk non-agriculture

    ***************************************************
    * Weight setup
    ***************************************************

    if "`weight'" == "no_wgt" {
        local weighting ""
        local range "0 50000"
    }
    else {
        local weighting "[aweight=`weight']"
        local range "0 1.5"
    }

    ***************************************************
    * Create bins
    ***************************************************

    preserve

    summarize real_temperature `weighting', detail
    local min_realised = floor(r(min))
    local max_realised = ceil(r(max))

    gen double bin = .
    forvalues temp = `min_realised'(0.1)`max_realised' {
        quietly replace bin = round(`temp', 0.1) if real_temperature >= `temp'
    }

    di "COLLAPSING TO BINS..."

    gen no_wgt = 1

    * Split weights into 3 risk groups
    gen double w_low   = `weight' if sector == 0
    gen double w_ag    = `weight' if sector == 1
    gen double w_nonag = `weight' if sector == 2

    gcollapse (sum) `weight' w_low w_ag w_nonag, by(bin $collapser)

    gegen tot_low   = total(w_low),   by($collapser)
    gegen tot_ag    = total(w_ag),    by($collapser)
    gegen tot_nonag = total(w_nonag), by($collapser)
    gegen tot       = total(`weight'), by($collapser)

    gen double w_lowp   = w_low   / tot_low   * 100
    gen double w_agp    = w_ag    / tot_ag    * 100
    gen double w_nonagp = w_nonag / tot_nonag * 100
    gen double w_allp   = `weight' / tot      * 100

    gen double temp = bin + 0.05
    replace temp = round(temp, 0.01)

    ***************************************************
    * Plot histograms for interacted mode
    ***************************************************

    if "`interaction'" == "interacted" | "`interaction'" == "triple_int" {

        local i = 1
        forvalues inc = 1/3 {
            forvalues clim = 1/3 {

                di "PLOTTING HISTOGRAMS FOR CLIM_T=`clim', INC_T=`inc'..."

                local opts "barw(0.1) ylab(#4, labsize(vsmall) angle(vertical)) xtitle(\"\") graphregion(color(white) margin(zero)) xlab(, labsize(small))"

                twoway bar w_low temp if clim_t==`clim' & inc_t==`inc', `opts' ysc(range(`range')) ytitle("Obs", size(small)) xscale(range(-20 50)) xtitle("") ylab(, labsize(vsmall) angle(vertical)) graphregion(margin(tiny) color(white)) plotregion(margin(zero)) xsize(6) ysize(2)  name(hist`i'_low_abs, replace)

		twoway bar w_ag temp if clim_t==`clim' & inc_t==`inc', `opts' ysc(range(`range')) ytitle("Obs", size(small)) xscale(range(-20 50)) xtitle("") ylab(, labsize(vsmall) angle(vertical)) graphregion(margin(tiny) color(white)) plotregion(margin(zero)) xsize(6) ysize(2)  name(hist`i'_ag_abs, replace)

		twoway bar w_nonag temp if clim_t==`clim' & inc_t==`inc', `opts' ysc(range(`range')) ytitle("Obs", size(small)) xscale(range(-20 50)) xtitle("") ylab(, labsize(vsmall) angle(vertical)) graphregion(margin(tiny) color(white)) plotregion(margin(zero)) xsize(6) ysize(2)  name(hist`i'_nonag_abs, replace)

		twoway bar w_all temp if clim_t==`clim' & inc_t==`inc', `opts' ysc(range(`range')) ytitle("Obs", size(small)) xscale(range(-20 50)) xtitle("") ylab(, labsize(vsmall) angle(vertical)) graphregion(margin(tiny) color(white)) plotregion(margin(zero)) xsize(6) ysize(2)  name(hist`i'_all_abs, replace)

		twoway bar w_lowp temp if clim_t==`clim' & inc_t==`inc', `opts' ysc(range(0 5)) ytitle("%", size(small)) xscale(range(-20 50)) xtitle("") ylab(, labsize(vsmall) angle(vertical)) graphregion(margin(tiny) color(white)) plotregion(margin(zero)) xsize(6) ysize(2)  name(hist`i'_low_pct, replace)

		twoway bar w_agp temp if clim_t==`clim' & inc_t==`inc', `opts' ysc(range(0 5)) ytitle("%", size(small)) xscale(range(-20 50)) xtitle("") ylab(, labsize(vsmall) angle(vertical)) graphregion(margin(tiny) color(white)) plotregion(margin(zero)) xsize(6) ysize(2)  name(hist`i'_ag_pct, replace)

		twoway bar w_nonagp temp if clim_t==`clim' & inc_t==`inc', `opts' ysc(range(0 5)) ytitle("%", size(small)) xscale(range(-20 50)) xtitle("") ylab(, labsize(vsmall) angle(vertical)) graphregion(margin(tiny) color(white)) plotregion(margin(zero)) xsize(6) ysize(2)  name(hist`i'_nonag_pct, replace)

		twoway bar w_allp temp if clim_t==`clim' & inc_t==`inc', `opts' ysc(range(0 5)) ytitle("%", size(small)) xscale(range(-20 50)) xtitle("") ylab(, labsize(vsmall) angle(vertical)) graphregion(margin(tiny) color(white)) plotregion(margin(zero)) xsize(6) ysize(2)  name(hist`i'_all_pct, replace)


                foreach g in low ag nonag all {
                    cap mkdir "${DIR_OUTPUT}/interacted_reg_output/plots/histograms/`interaction'"
                    graph save hist`i'_`g'_abs "${DIR_OUTPUT}/interacted_reg_output/plots/histograms/`interaction'/hist`i'_`g'_abs.gph", replace
                    graph save hist`i'_`g'_pct "${DIR_OUTPUT}/interacted_reg_output/plots/histograms/`interaction'/hist`i'_`g'_pct.gph", replace
                }

                local ++i
            }
        }
    }

    ***************************************************
    * Income-only mode
    ***************************************************

    else if "`interaction'" == "income" {

        local i = 1
        forvalues inc = 1/3 {

            di "PLOTTING HISTOGRAMS FOR INC_T=`inc'..."

            local opts "barw(0.1) ylab(#5, labsize(vsmall) angle(vertical)) xtitle(\"\") graphregion(color(white) margin(zero)) xlab(, labsize(small))"

            twoway bar w_low   temp if inc_t==`inc', `opts' ysc(range(`range')) ytitle("Obs", size(small)) name(hist`i'_low_abs, replace)
            twoway bar w_ag    temp if inc_t==`inc', `opts' ysc(range(`range')) ytitle("Obs", size(small)) name(hist`i'_ag_abs, replace)
            twoway bar w_nonag temp if inc_t==`inc', `opts' ysc(range(`range')) ytitle("Obs", size(small)) name(hist`i'_nonag_abs, replace)
            twoway bar `weight' temp if inc_t==`inc', `opts' ysc(range(`range')) ytitle("Obs", size(small)) name(hist`i'_all_abs, replace)

            twoway bar w_lowp   temp if inc_t==`inc', `opts' ysc(range(0 5)) ytitle("%", size(small)) name(hist`i'_low_pct, replace)
            twoway bar w_agp    temp if inc_t==`inc', `opts' ysc(range(0 5)) ytitle("%", size(small)) name(hist`i'_ag_pct, replace)
            twoway bar w_nonagp temp if inc_t==`inc', `opts' ysc(range(0 5)) ytitle("%", size(small)) name(hist`i'_nonag_pct, replace)
            twoway bar w_allp   temp if inc_t==`inc', `opts' ysc(range(0 5)) ytitle("%", size(small)) name(hist`i'_all_pct, replace)

            foreach g in low ag nonag all {
                cap mkdir "${DIR_OUTPUT}/interacted_reg_output/plots/histograms/`interaction'"
                graph save hist`i'_`g'_abs "${DIR_OUTPUT}/interacted_reg_output/plots/histograms/`interaction'/hist`i'_`g'_abs.gph", replace
                graph save hist`i'_`g'_pct "${DIR_OUTPUT}/interacted_reg_output/plots/histograms/`interaction'/hist`i'_`g'_pct.gph", replace
            }

            local ++i
        }
    }

    restore

    ***************************************************
    * Compute percentile cutoffs for later overlay
    ***************************************************

    di "COMPUTING PERCENTILE CUTOFFS..."

    if "`interaction'" == "interacted" | "`interaction'" == "triple_int" {

        local i = 1
        forvalues inc = 1/3 {
            forvalues clim = 1/3 {

                quietly summarize real_temperature `weighting' if clim_t==`clim' & inc_t==`inc' & sector==0, detail
                global p1`i'_low_`wtag'   = r(p1)
                global p5`i'_low_`wtag'   = r(p5)
                global p95`i'_low_`wtag'  = r(p95)
                global p99`i'_low_`wtag'  = r(p99)

                quietly summarize real_temperature `weighting' if clim_t==`clim' & inc_t==`inc' & sector==1, detail
                global p1`i'_ag_`wtag'    = r(p1)
                global p5`i'_ag_`wtag'    = r(p5)
                global p95`i'_ag_`wtag'   = r(p95)
                global p99`i'_ag_`wtag'   = r(p99)

                quietly summarize real_temperature `weighting' if clim_t==`clim' & inc_t==`inc' & sector==2, detail
                global p1`i'_nonag_`wtag' = r(p1)
                global p5`i'_nonag_`wtag' = r(p5)
                global p95`i'_nonag_`wtag'= r(p95)
                global p99`i'_nonag_`wtag'= r(p99)

                quietly summarize real_temperature `weighting' if clim_t==`clim' & inc_t==`inc', detail
                global p1`i'_all_`wtag'   = r(p1)
                global p5`i'_all_`wtag'   = r(p5)
                global p95`i'_all_`wtag'  = r(p95)
                global p99`i'_all_`wtag'  = r(p99)

                local ++i
            }
        }
    }

    else if ("`interaction'" == "income") {

        local i = 1
        forvalues inc = 1/3 {

            quietly summarize real_temperature `weighting' if inc_t==`inc' & sector==0, detail
            global p1`i'_low_`wtag'  = r(p1)
            global p5`i'_low_`wtag'  = r(p5)
            global p95`i'_low_`wtag' = r(p95)
            global p99`i'_low_`wtag' = r(p99)

            quietly summarize real_temperature `weighting' if inc_t==`inc' & sector==1, detail
            global p1`i'_ag_`wtag'  = r(p1)
            global p5`i'_ag_`wtag'  = r(p5)
            global p95`i'_ag_`wtag' = r(p95)
            global p99`i'_ag_`wtag' = r(p99)

            quietly summarize real_temperature `weighting' if inc_t==`inc' & sector==2, detail
            global p1`i'_nonag_`wtag'  = r(p1)
            global p5`i'_nonag_`wtag'  = r(p5)
            global p95`i'_nonag_`wtag' = r(p95)
            global p99`i'_nonag_`wtag' = r(p99)

            quietly summarize real_temperature `weighting' if inc_t==`inc', detail
            global p1`i'_all_`wtag'  = r(p1)
            global p5`i'_all_`wtag'  = r(p5)
            global p95`i'_all_`wtag' = r(p95)
            global p99`i'_all_`wtag' = r(p99)

            local ++i
        }
    }

    ***************************************************
    * Compute counts for tercile summary
    ***************************************************

    di "COMPUTING COUNTS..."

    gen count_low   = (sector == 0)
    gen count_ag    = (sector == 1)
    gen count_nonag = (sector == 2)

    gegen count_rep_unit = tag(rep_unit)
    gegen count_rep_year = tag(rep_unit year)

    gcollapse (sum) count_low count_ag count_nonag count_rep_year count_rep_unit, by($collapser)

    save "${ROOT_INT_DATA}/xtiles/`tercile_unit'_terciles_count.dta", replace
    di "COUNTS COMPLETE."

end
