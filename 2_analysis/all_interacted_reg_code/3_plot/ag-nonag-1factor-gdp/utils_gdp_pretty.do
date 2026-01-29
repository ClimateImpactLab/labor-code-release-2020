******************************************************
* COMPLETE CODE FOR CLIMATE INTERACTION
******************************************************

******************************************************
* generate_coef_spline (modified for income)
******************************************************
cap program drop generate_coef_spline
program define generate_coef_spline
	args N_knots spl_varname

	local N_new_vars=`N_knots'-2 

	forval k=0/`N_new_vars'{

		global b_T_spline_`k'_lr 0
		global b_T_x_gdp_spline_`k'_lr 0

		global b_T_spline_`k'_hr 0
		global b_T_x_gdp_spline_`k'_hr 0 

		* Low risk: uninteracted
		global b_T_spline_`k'_lr _b[tmax_`spl_varname'_`N_knots'kn_t`k'_lr]
		
		* High risk: base effect
		global b_T_spline_`k'_hr _b[tmax_`spl_varname'_`N_knots'kn_t`k'_hr]
		
		* High risk: income interaction (using _g suffix)
		global b_T_x_gdp_spline_`k'_hr _b[tmax_`spl_varname'_`N_knots'kn_t`k'_hr_g]
		
		forval lag=1/6{
			* Low risk lags
			global b_T_spline_`k'_lr ${b_T_spline_`k'_lr}+_b[tmax_`spl_varname'_`N_knots'kn_t`k'_lr_v`lag']
			
			* High risk base lags
			global b_T_spline_`k'_hr ${b_T_spline_`k'_hr}+_b[tmax_`spl_varname'_`N_knots'kn_t`k'_hr_v`lag']
			
			* High risk income interaction lags
			global b_T_x_gdp_spline_`k'_hr ${b_T_x_gdp_spline_`k'_hr}+_b[tmax_`spl_varname'_`N_knots'kn_t`k'_hr_g_v`lag']
		}

		* High risk total = base + interaction
		global b_T_spline_`k'_hl ${b_T_spline_`k'_hr}
		global b_T_x_gdp_spline_`k'_hl ${b_T_x_gdp_spline_`k'_hr}
	}
end


******************************************************
* gen_response_surface_spline (modified for income)
******************************************************
cap program drop gen_response_surface_spline
program define gen_response_surface_spline

	args N_knots risk grid

	local N_new_vars=`N_knots'-2 
	global response_surface 0
	
	forval i=0/`N_new_vars'{
		* Base temperature effect
		gl response_surface ${response_surface}+(${b_T_spline_`i'`risk'})*(T_spline`i'-T_ref_spline`i')
		
		* Income interaction effect (using minc instead of lrtmax)
		gl response_surface ${response_surface}+(${b_T_x_gdp_spline_`i'`risk'})*(T_spline`i'-T_ref_spline`i')*${minc`grid'}
	}
	
	cap drop yhat *_ci
	di "`risk' `grid': $response_surface"
	predictnl yhat = $response_surface, ci(lower_ci upper_ci)
end


******************************************************
* gen_marginal_resp_spline (for income)
******************************************************
cap program drop gen_marginal_resp_spline
program define gen_marginal_resp_spline

	args N_knots risk

	local N_new_vars=`N_knots'-2 

	global response 0

	forval i=0/`N_new_vars'{
		global response $response + (${b_T_x_gdp_spline_`i'`risk'})*(T_spline`i' - T_ref_spline`i')
	}
	cap drop yhat *_ci
	di "$response"
	predictnl yhat = $response, ci(lower_ci upper_ci)
end
******************************************************
* gen_plot (with conditional y-axis styling and medium width axes)
******************************************************
cap program drop gen_plot
program define gen_plot 
	args plot_title g plot_style risk weight 
	
	local plot_name = "plot`g'"
	
	local cutoffs = "xline(${p1`g'`risk'_`weight'}, lcol(gold) lpatt(-) lw(medium)) xline(${p99`g'`risk'_`weight'}, lcol(gold) lpatt(-) lw(medium)) xline(${p5`g'`risk'_`weight'}, lcol(orange) lpatt(_) lw(medium)) xline(${p95`g'`risk'_`weight'}, lcol(orange) lpatt(_) lw(medium))"
	
	preserve 
	
	local peak_lines = ""
	local extrema_note = ""
	
	* Set y-axis styling based on plot number
	if `g' == 1 {
		* First plot: keep black title, labels, and ticks
		local yaxis_opts "ylab(#8, labs(medium) ang(vertical) tlcolor(black) nogrid tlw(medium)) ytitle("{bf:Minutes worked}", size(medium) color(white))"
	}
	else {
		* Second and third plots: white labels and title, white ticks, no grid
		local yaxis_opts "ylab(#8, labs(medium) ang(vertical) labcolor(white) tlcolor(white) nogrid tlw(medium)) ytitle("{bf:Minutes worked}", size(medium) color(white))"
	}
	
	if "`plot_style'" == "all_data_with_ci"{
		tw rarea upper_ci lower_ci temp, col(ltbluishgray) || ///
		   line yhat temp, lc(dknavy) lw(medium) yline(0, lw(medium)) `cutoffs' ///
		   title("`plot_title'") legend(off) ///
		   `yaxis_opts' ///
		   xlab("",labs(small)) fysize(80) xtitle("") ///
		   name(`plot_name', replace) ///
		   graphregion(margin(zero) color(white)) ///
		   ysc(r(${YMIN`risk'} ${YMAX`risk'}) lw(medium)) ///
		   xsc(off lw(medium))
	}
	
	if "`plot_style'" == "all_data_no_ci"{
		tw line yhat temp, lc(dknavy) lw(medium) yline(0, lw(medium)) `cutoffs' ///
		   title("`plot_title'") legend(off) ///
		   `yaxis_opts' ///
		   xlab("",labs(small)) fysize(80) xtitle("") ///
		   name(`plot_name', replace) ///
		   graphregion(margin(zero) color(white)) ///
		   ysc(r(${YMIN`risk'} ${YMAX`risk'}) lw(medium)) ///
		   xsc(off lw(medium))
	}
	restore
end
******************************************************
* gen_marg_plot
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
* plot_interacted_spline (modified for income with unified y-axis)
******************************************************
cap program drop plot_interacted_spline
program define plot_interacted_spline
	args interaction f N_knots data_subset plot_style ster_name hist_weight hist_style

	cap mkdir `plot_style'
	cd `plot_style'

	di "Using: ${ster_dir}/`ster_name'.ster"
	estimates use "${ster_dir}/`ster_name'.ster"

	generate_temperature -20 50 27
	spline_temperature_range 3

	******** STEP 1: Generate all predictions to find global y-axis range ********
	di "========================================="
	di "STEP 1: CALCULATING GLOBAL Y-AXIS RANGE"
	di "========================================="
	
	tempfile temp_predictions
	
	* Initialize global min/max for each risk level
	foreach risk in _lr _hr _hl {
		scalar ymin`risk' = .
		scalar ymax`risk' = .
	}
	
	* Generate predictions for all grids and risk levels to find range
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
	
	* Set unified y-axis ranges with some padding
	foreach risk in _lr _hr _hl {
		local range = ymax`risk' - ymin`risk'
		local padding = `range' * 0.05
		
		global YMIN`risk' = floor((ymin`risk' - `padding') / 50) * 50
		global YMAX`risk' = ceil((ymax`risk' + `padding') / 50) * 50
		
		di "Final unified y-axis for `risk': [${YMIN`risk'}, ${YMAX`risk'}]"
	}

	******** STEP 2: Generate plots with unified y-axis ********
	di "========================================="
	di "STEP 2: GENERATING PLOTS"
	di "========================================="
	
	foreach risk in _lr _hr _hl {
		forval g = 1/$max_g {
			gen_response_surface_spline `N_knots' `risk' `g'
			gen_plot "${tag`g'}" `g' `plot_style' `risk' `hist_weight'
		}
		
		if "`risk'" == "_lr" local plot_tag low_risk
		if "`risk'" == "_hl" local plot_tag high_risk
		if "`risk'" == "_hr" local plot_tag marginal_risk

		forval i=1/$max_g {
			local h`i' = "/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/output/interacted_reg_output/plots/histograms/$interaction/hist`i'`risk'_`hist_style'.gph"
		}
		
		* For income: only 3 panels
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
		
		graph export "`ster_name'_`plot_tag'_hist`hist_weight'_`hist_style'.pdf", replace
	}

	******** STEP 3: Marginal response plots ********
	di "========================================="
	di "STEP 3: GENERATING MARGINAL PLOTS"
	di "========================================="
	
	foreach risk in _lr _hl {
		gen_marginal_resp_spline `N_knots' `risk'
		export delim using "marginal_resp_spline_`risk'_gdp.csv", replace
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
* generate_grids (for income only)
******************************************************
cap program drop generate_grids
program define generate_grids
	
	args tercile interaction

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

	* For income interaction: only 3 grids
	global max_g = 3
	
	global minc1 `inc_poor'
	global minc2 `inc_midl'
	global minc3 `inc_rich'
	
	global tag1 poor
	global tag2 midincome
	global tag3 rich

	* Read counts and set global macros
	di "READING COUNTS FROM FILE..."
	
	use "${ROOT_INT_DATA}/xtiles/`tercile'_terciles_count.dta", clear
	
	* For income interaction
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
	
	di "COUNTS LOADED INTO GLOBAL MACROS."
end

******************************************************
* generate_temperature
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
* spline_temperature_range
******************************************************
cap program drop spline_temperature_range
program define spline_temperature_range
	args N_knots

	if `N_knots' == 3 {
		local knots 27 28 41
	}
	
	local N_vars_sp=`N_knots'-1

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

	local scaling_factor=(`last_knot'-`first_knot')^2

	mkspline T_spline=temp, cubic knots(`knots')
	mkspline T_ref_spline=ref, cubic knots(`knots')

	forval k=2/`N_vars_sp'{
		replace T_spline`k'=T_spline`k'*`scaling_factor'
		replace T_ref_spline`k'=T_ref_spline`k'*`scaling_factor'
	}

	rename T_spline1 T_spline0
	rename T_spline2 T_spline1
	rename T_ref_spline1 T_ref_spline0
	rename T_ref_spline2 T_ref_spline1
end

