******************************************************
* POLYNOMIAL HELPERS (MINIMAL-CHANGE VERSION)
* Respect original code; only fix what is necessary:
*   (1) generate_grids: correct lrtmax1..9 mapping by columns
*   (2) gen_response_surface_poly: include lr_tmax_p1 interaction terms
******************************************************


******************************************************
* generate_temperature (UNCHANGED)
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
* generate_grids (ONLY FIX lrtmax1..9 MAPPING)
******************************************************
cap program drop generate_grids
program define generate_grids
	
	args tercile interaction

	/*	
	Takes the mean of each tercile (by IR or by rep-unit) of LR climate (tmax)
	and income (log GDP pc). These are used to define how the 3 x 3 graphs 
	should be plotted. 
	*/

	* grid layout: 
	* -------------
	* | 7 | 8 | 9 |
	* -------------
	* | 4 | 5 | 6 |
	* -------------
	* | 1 | 2 | 3 |
	* -------------

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
	
	if "`interaction'" == "interacted" | "`interaction'" == "triple_int" {

		global max_g = 9

		* <<< CHANGED >>> climate should vary by COLUMN:
		* 1,4,7 cold ; 2,5,8 warm ; 3,6,9 hot
		global lrtmax1 `lrtmax_cold'
		global lrtmax2 `lrtmax_warm'
		global lrtmax3 `lrtmax_hot'
		global lrtmax4 `lrtmax_cold'
		global lrtmax5 `lrtmax_warm'
		global lrtmax6 `lrtmax_hot'
		global lrtmax7 `lrtmax_cold'
		global lrtmax8 `lrtmax_warm'
		global lrtmax9 `lrtmax_hot'
	}

	if "`tercile'" == "hierid" {
		use "/project/cil/norgay/CIL_labor/2_regression/time_use/input/loggdppc_2010_grid.dta", clear
	}
	else if "`tercile'" == "rep_unit" {
		use "/project/cil/battuta_shares/gcp/estimation/labor/code_release_int_data/xtiles/rep_unit_terciles_grid.dta", clear
	}
	else di "Incorrect tercile specification. Permitted: rep_unit, hierid."

	sum mean_loggdppc, detail

	local inc_poor =`r(min)'
	local inc_midl =`r(p50)'
	local inc_rich =`r(max)'

	if "`interaction'" == "interacted" | "`interaction'" == "triple_int" {

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
		global tag9 hot-rich*
	}
	else if "`interaction'" == "income" {

		di "INTERACTION `interaction'"

		global max_g = 3

		global minc1 `inc_poor'
		global minc2 `inc_midl'
		global minc3 `inc_rich'
	}

	* counts block unchanged (you can keep your original below if needed)
end


******************************************************
* poly_temperature_range (UNCHANGED)
******************************************************
cap program drop poly_temperature_range
program define poly_temperature_range
    args max_degree

    cap drop T_poly*
    cap drop T_ref_poly*

    forval d = 1/`max_degree' {
        gen double T_poly`d'     = temp^`d'
        gen double T_ref_poly`d' = ref^`d'
    }
end


******************************************************
* generate_coef_polynomials (KEEP YOUR VERSION)
* Your version already uses:
*  - _b[c.tmax_p*#c.lr_tmax_p1]
*  - _b[1.risk_level#c.tmax_p*#c.lr_tmax_p1]
* So DO NOT change it here.
******************************************************
cap program drop generate_coef_polynomials
program define generate_coef_polynomials
    args max_degree

    cap macro drop b_temp_*
    cap macro drop b_temp_gdp_*
    cap macro drop b_temp_lrtmax_*

    * 1) LOW-RISK (base: risk_level==0)
    forval d = 1/`max_degree' {

        global b_temp_`d'_lr ///
            _b[tmax_p`d']

        global b_temp_gdp_`d'_lr ///
            _b[c.tmax_p`d'#c.log_gdp_pc_adm1]

        global b_temp_lrtmax_`d'_lr ///
            _b[c.tmax_p`d'#c.lr_tmax_p1]

        forval lag = 1/6 {
            global b_temp_`d'_lr ///
                ${b_temp_`d'_lr} ///
                + _b[tmax_p`d'_v`lag']

            global b_temp_gdp_`d'_lr ///
                ${b_temp_gdp_`d'_lr} ///
                + _b[c.tmax_p`d'_v`lag'#c.log_gdp_pc_adm1]

            global b_temp_lrtmax_`d'_lr ///
                ${b_temp_lrtmax_`d'_lr} ///
                + _b[c.tmax_p`d'_v`lag'#c.lr_tmax_p1]
        }
    }

    * 2) HIGH-RISK minus LOW (risk_level interaction)
    forval d = 1/`max_degree' {

        global b_temp_`d'_hr ///
            _b[1.risk_level#c.tmax_p`d']

        global b_temp_gdp_`d'_hr ///
            _b[1.risk_level#c.tmax_p`d'#c.log_gdp_pc_adm1]

        global b_temp_lrtmax_`d'_hr ///
            _b[1.risk_level#c.tmax_p`d'#c.lr_tmax_p1]

        forval lag = 1/6 {
            global b_temp_`d'_hr ///
                ${b_temp_`d'_hr} ///
                + _b[1.risk_level#c.tmax_p`d'_v`lag']

            global b_temp_gdp_`d'_hr ///
                ${b_temp_gdp_`d'_hr} ///
                + _b[1.risk_level#c.tmax_p`d'_v`lag'#c.log_gdp_pc_adm1]

            global b_temp_lrtmax_`d'_hr ///
                ${b_temp_lrtmax_`d'_hr} ///
                + _b[1.risk_level#c.tmax_p`d'_v`lag'#c.lr_tmax_p1]
        }
    }

    * 3) HIGH total = LOW + (HIGH-LOW)
    forval d = 1/`max_degree' {

        global b_temp_`d'_hl ///
            ${b_temp_`d'_lr} + ${b_temp_`d'_hr}

        global b_temp_gdp_`d'_hl ///
            ${b_temp_gdp_`d'_lr} + ${b_temp_gdp_`d'_hr}

        global b_temp_lrtmax_`d'_hl ///
            ${b_temp_lrtmax_`d'_lr} + ${b_temp_lrtmax_`d'_hr}
    }
end


******************************************************
* gen_response_surface_poly (ONLY ADD lrtmax TERM)
******************************************************
cap program drop gen_response_surface_poly
program define gen_response_surface_poly
    args max_degree risk grid

    global response_surface 0

    forval d = 1/`max_degree' {

        global response_surface ///
            ${response_surface} + (${b_temp_`d'`risk'})*(T_poly`d' - T_ref_poly`d')

        global response_surface ///
            ${response_surface} + (${b_temp_gdp_`d'`risk'})*(T_poly`d' - T_ref_poly`d')*${minc`grid'}

        * <<< CHANGED >>> include climate shifter (lr_tmax_p1 grid mean)
        global response_surface ///
            ${response_surface} + (${b_temp_lrtmax_`d'`risk'})*(T_poly`d' - T_ref_poly`d')*${lrtmax`grid'}
    }

    cap drop yhat *_ci
    di "`risk' `grid': $response_surface"
    predictnl yhat = $response_surface, ci(lower_ci upper_ci)
end


******************************************************
* gen_marginal_resp_poly (UNCHANGED; GDP only)
******************************************************
cap program drop gen_marginal_resp_poly
program define gen_marginal_resp_poly
    args max_degree risk

    global response 0
    forval d = 1/`max_degree' {
        global response ///
            ${response} + (${b_temp_gdp_`d'`risk'})*(T_poly`d' - T_ref_poly`d')
    }

    cap drop yhat *_ci
    di "$response"
    predictnl yhat = $response, ci(lower_ci upper_ci)
end


******************************************************
* gen_plot (KEEP YOUR ORIGINAL; pasted as-is)
******************************************************
cap program drop gen_plot
program define gen_plot 
	args plot_title g plot_style risk weight 

	local plot_name = "plot`g'"
	local range_hr = "-50 80"
	local range_lr = "-20 60"
	local range_hl = "-50 100"

	local cutoffs = "xline(${p1`g'`risk'_`weight'}, lcol(gold) lpatt(-)) xline(${p99`g'`risk'_`weight'}, lcol(gold) lpatt(-)) xline(${p5`g'`risk'_`weight'}, lcol(orange) lpatt(_)) xline(${p95`g'`risk'_`weight'}, lcol(orange) lpatt(_))"
	di "`cutoffs'"
	preserve 
	if "`plot_style'" == "all_data_with_ci"{
		tw rarea upper_ci lower_ci temp, col(ltbluishgray) || line yhat temp, lc (dknavy) yline(0) `cutoffs' title("`plot_title'") legend(off) ylab(#8,labs(vsmall) ang(vertical)) ytitle("mins worked", size(small)) xlab("",labs(small)) fysize(65) xtitle("") name(`plot_name', replace) graphregion(margin(zero) color(white)) subtitle("${risk`risk'_`plot_name'} obs, ${ru_`plot_name'} rep-units, ${ry_`plot_name'} rep-unit-years.", size(small)) ysc(r(`range`risk'')) xsc(off)
	}
	if "`plot_style'" == "all_data_no_ci"{
		tw  line yhat temp, lc (dknavy) yline(0) `cutoffs' title("`plot_title'") legend(off) ylab(#8,labs(vsmall) ang(vertical)) ytitle("mins worked", size(small)) xlab("",labs(small)) fysize(65) xtitle("") name(`plot_name', replace) graphregion(margin(zero) color(white)) subtitle("${risk`risk'_`plot_name'} obs, ${ru_`plot_name'} rep-units, ${ry_`plot_name'} rep-unit-years.", size(small)) ysc(r(`range`risk'')) xsc(off)
	}
	restore
end


******************************************************
* plot_interacted_poly (KEEP YOUR ORIGINAL STYLE)
******************************************************
cap program drop plot_interacted_poly
program define plot_interacted_poly
    args interaction f max_degree data_subset plot_style ster_name hist_weight hist_style

    cap mkdir `plot_style'
    cd `plot_style'

    di "Using: ${ster_dir}/`ster_name'.ster"
    estimates use "${ster_dir}/`ster_name'.ster"

    generate_temperature -20 50 27
    poly_temperature_range `max_degree'

    generate_coef_polynomials `max_degree'

    if "`interaction'" == "income" local size = 50
    else local size = 20

    di "INTERACTION : `interaction' `size'"

    foreach risk in _lr _hr _hl {

        forval g = 1/$max_g {
            gen_response_surface_poly `max_degree' `risk' `g'
            gen_plot "${tag`g'}" `g' `plot_style' `risk' `hist_weight'
        }

        if "`risk'" == "_lr" local plot_tag low_risk
        if "`risk'" == "_hl" local plot_tag high_risk
        if "`risk'" == "_hr" local plot_tag marginal_risk

        forval i = 1/$max_g {
            local h`i' = "/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/output/interacted_reg_output/plots/histograms/$interaction/hist`i'`risk'_`hist_style'.gph"
        }

        if "`interaction'" != "income" {
            graph combine ///
                plot7 plot8 plot9 "`h7'" "`h8'" "`h9'" ///
                plot4 plot5 plot6 "`h4'" "`h5'" "`h6'" ///
                plot1 plot2 plot3 "`h1'" "`h2'" "`h3'", ///
                plotregion(color(white)) ///
                graphregion(color(white) margin(t=5 b=5)) ///
                xcomm imargin(0 0 0 0) cols(3) ///
                title("`plot_tag'") ///
                subtitle("`ster_name', hist: `hist_weight' `hist_style'", size(vsmall))
        }
        else {
            graph combine ///
                plot1 plot2 plot3 "`h1'" "`h2'" "`h3'", ///
                plotregion(color(white)) ///
                graphregion(color(white) margin(t=5 b=5)) ///
                xcomm imargin(0 0 0 0) cols(3) ///
                title("`plot_tag'") ///
                subtitle("`ster_name', hist: `hist_weight' `hist_style'", size(vsmall))
        }

        graph export "`ster_name'_`plot_tag'_hist`hist_weight'_`hist_style'.pdf", replace
    }

    foreach risk in _lr _hl {
        gen_marginal_resp_poly `max_degree' `risk'
        export delim using "marginal_resp_poly_`risk'_gdp.csv", replace

        if "`risk'" == "_lr" local plot_tag low_risk
        if "`risk'" == "_hl" local plot_tag high_risk
        gen_marg_plot "`plot_tag'" `plot_tag' `plot_style'
    }

    graph combine low_risk high_risk, ///
        plotregion(color(white)) graphregion(color(white)) ///
        cols(2) ycommon title("gdp") subtitle("`ster_name'")
    graph export "`ster_name'_marginal_gdp.pdf", replace

    cd ..
end


******************************************************
* plot_interacted_poly
* MODIFIED: compute unified y-axis range per figure
******************************************************
cap program drop plot_interacted_poly
program define plot_interacted_poly
    args interaction f max_degree data_subset plot_style ster_name hist_weight hist_style

    cap mkdir `plot_style'
    cd `plot_style'

    di "Using: ${ster_dir}/`ster_name'.ster"
    estimates use "${ster_dir}/`ster_name'.ster"

    * generate temperature grid
    generate_temperature -20 50 27
    poly_temperature_range `max_degree'

    * read coefficients
    generate_coef_polynomials `max_degree'

    * --------------------------------------------------
    * STEP 1: compute unified y-axis range
    * --------------------------------------------------
    tempname ymin ymax
    scalar `ymin' = .
    scalar `ymax' = .

    foreach risk in _lr _hr _hl {
        forval g = 1/$max_g {
            gen_response_surface_poly `max_degree' `risk' `g'
            quietly summarize yhat
            if missing(`ymin') | r(min) < `ymin' {
                scalar `ymin' = r(min)
            }
            if missing(`ymax') | r(max) > `ymax' {
                scalar `ymax' = r(max)
            }
        }
    }

    * small padding for aesthetics
    scalar `ymin' = `ymin' - 5
    scalar `ymax' = `ymax' + 5

    global YMIN = `ymin'
    global YMAX = `ymax'

    di "Unified y-axis range: ${YMIN} ${YMAX}"

    * --------------------------------------------------
    * STEP 2: now generate plots using unified y-axis
    * --------------------------------------------------
    foreach risk in _lr _hr _hl {

        forval g = 1/$max_g {
            gen_response_surface_poly `max_degree' `risk' `g'
            gen_plot "${tag`g'}" `g' `plot_style' `risk' `hist_weight'
        }

        if "`risk'" == "_lr" local plot_tag low_risk
        if "`risk'" == "_hl" local plot_tag high_risk
        if "`risk'" == "_hr" local plot_tag marginal_risk

        forval i = 1/$max_g {
            local h`i' = ///
                "/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/output/interacted_reg_output/plots/histograms/$interaction/hist`i'`risk'_`hist_style'.gph"
        }

        if "`interaction'" != "income" {
            graph combine ///
                plot7 plot8 plot9 "`h7'" "`h8'" "`h9'" ///
                plot4 plot5 plot6 "`h4'" "`h5'" "`h6'" ///
                plot1 plot2 plot3 "`h1'" "`h2'" "`h3'", ///
                plotregion(color(white)) ///
                graphregion(color(white) margin(t=5 b=5)) ///
                xcomm imargin(0 0 0 0) cols(3) ///
                title("`plot_tag'") ///
                subtitle("`ster_name', hist: `hist_weight' `hist_style'", size(vsmall))
        }
        else {
            graph combine ///
                plot1 plot2 plot3 "`h1'" "`h2'" "`h3'", ///
                plotregion(color(white)) ///
                graphregion(color(white) margin(t=5 b=5)) ///
                xcomm imargin(0 0 0 0) cols(3) ///
                title("`plot_tag'") ///
                subtitle("`ster_name', hist: `hist_weight' `hist_style'", size(vsmall))
        }

        graph export "`ster_name'_`plot_tag'_hist`hist_weight'_`hist_style'.pdf", replace
    }

    cd ..
end
******************************************************
* gen_plot
* MODIFIED: NO CI + fix xline lpattern
******************************************************
cap program drop gen_plot
program define gen_plot 
    args plot_title g plot_style risk weight 

    local plot_name = "plot`g'"

    * FIX: use valid lpattern() values (dash / shortdash)
    local cutoffs = ///
        "xline(${p1`g'`risk'_`weight'},   lcol(gold)   lpattern(dash)) " ///
        "xline(${p99`g'`risk'_`weight'},  lcol(gold)   lpattern(dash)) " ///
        "xline(${p5`g'`risk'_`weight'},   lcol(orange) lpattern(shortdash)) " ///
        "xline(${p95`g'`risk'_`weight'},  lcol(orange) lpattern(shortdash))"

    preserve

    * Only line (no CI band)
    tw ///
        line yhat temp, lc(dknavy) yline(0) `cutoffs' ///
        title("`plot_title'") legend(off) ///
        ylab(#8,labs(vsmall) ang(vertical)) ///
        ytitle("mins worked", size(small)) ///
        xlab("",labs(small)) ///
        xtitle("") ///
        name(`plot_name', replace) ///
        graphregion(margin(zero) color(white)) ///
        subtitle("${risk`risk'_`plot_name'} obs, ${ru_`plot_name'} rep-units, ${ry_`plot_name'} rep-unit-years.", size(small)) ///
        ysc(r(${YMIN} ${YMAX})) ///
        xsc(off)

    restore
end
