******************************************************
* COMPLETE CODE FOR CLIMATE INTERACTION
******************************************************

******************************************************
* generate_coef_spline (modified for climate)
******************************************************
cap program drop generate_coef_spline
program define generate_coef_spline
	args N_knots spl_varname

	local N_new_vars=`N_knots'-2 

	forval k=0/`N_new_vars'{

		global b_T_spline_`k'_lr 0
		global b_T_x_lrtmax_spline_`k'_lr 0

		global b_T_spline_`k'_hr 0
		global b_T_x_lrtmax_spline_`k'_hr 0 

		* Low risk: uninteracted
		global b_T_spline_`k'_lr _b[tmax_`spl_varname'_`N_knots'kn_t`k'_lr]
		
		* High risk: base effect
		global b_T_spline_`k'_hr _b[tmax_`spl_varname'_`N_knots'kn_t`k'_hr]
		
		* High risk: climate interaction (note the _l suffix)
		global b_T_x_lrtmax_spline_`k'_hr _b[tmax_`spl_varname'_`N_knots'kn_t`k'_hr_l]
		
		forval lag=1/6{
			* Low risk lags
			global b_T_spline_`k'_lr ${b_T_spline_`k'_lr}+_b[tmax_`spl_varname'_`N_knots'kn_t`k'_lr_v`lag']
			
			* High risk base lags
			global b_T_spline_`k'_hr ${b_T_spline_`k'_hr}+_b[tmax_`spl_varname'_`N_knots'kn_t`k'_hr_v`lag']
			
			* High risk climate interaction lags
			global b_T_x_lrtmax_spline_`k'_hr ${b_T_x_lrtmax_spline_`k'_hr}+_b[tmax_`spl_varname'_`N_knots'kn_t`k'_hr_l_v`lag']
		}

		* High risk total = base + interaction
		global b_T_spline_`k'_hl ${b_T_spline_`k'_hr}
		global b_T_x_lrtmax_spline_`k'_hl ${b_T_x_lrtmax_spline_`k'_hr}
	}
end


******************************************************
* gen_response_surface_spline (modified for climate only)
******************************************************
cap program drop gen_response_surface_spline
program define gen_response_surface_spline

	args N_knots risk grid

	local N_new_vars=`N_knots'-2 
	global response_surface 0
	
	forval i=0/`N_new_vars'{
		* Base temperature effect
		gl response_surface ${response_surface}+(${b_T_spline_`i'`risk'})*(T_spline`i'-T_ref_spline`i')
		
		* Climate interaction effect
		gl response_surface ${response_surface}+(${b_T_x_lrtmax_spline_`i'`risk'})*(T_spline`i'-T_ref_spline`i')*${lrtmax`grid'}
	}
	
	cap drop yhat *_ci
	di "`risk' `grid': $response_surface"
	predictnl yhat = $response_surface, ci(lower_ci upper_ci)
end


******************************************************
* gen_marginal_resp_spline (for climate only)
******************************************************
cap program drop gen_marginal_resp_spline
program define gen_marginal_resp_spline

	args N_knots risk

	local N_new_vars=`N_knots'-2 

	global response 0

	forval i=0/`N_new_vars'{
		global response $response + (${b_T_x_lrtmax_spline_`i'`risk'})*(T_spline`i' - T_ref_spline`i')
	}
	cap drop yhat *_ci
	di "$response"
	predictnl yhat = $response, ci(lower_ci upper_ci)
end


******************************************************
* gen_plot (with extrema detection)
******************************************************
cap program drop gen_plot
program define gen_plot 
	args plot_title g plot_style risk weight 

	local plot_name = "plot`g'"

	local cutoffs = "xline(${p1`g'`risk'_`weight'}, lcol(gold) lpatt(-)) xline(${p99`g'`risk'_`weight'}, lcol(gold) lpatt(-)) xline(${p5`g'`risk'_`weight'}, lcol(orange) lpatt(_)) xline(${p95`g'`risk'_`weight'}, lcol(orange) lpatt(_))"

	preserve 
	
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
	
	local peak_lines = ""
	local extrema_note = ""
	
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
	
	if "`plot_style'" == "all_data_with_ci"{
		if "`extrema_note'" != "" {
			tw rarea upper_ci lower_ci temp, col(ltbluishgray) || ///
			   line yhat temp, lc(dknavy) yline(0) `cutoffs' `peak_lines' ///
			   title("`plot_title'") legend(off) ///
			   ylab(#8,labs(vsmall) ang(vertical)) ///
			   ytitle("mins worked", size(small)) ///
			   xlab("",labs(small)) fysize(65) xtitle("") ///
			   name(`plot_name', replace) ///
			   graphregion(margin(zero) color(white)) ///
			   subtitle("${risk`risk'_`plot_name'} obs, ${ru_`plot_name'} rep-units, ${ry_`plot_name'} rep-unit-years.", size(small)) ///
			   note("`extrema_note'", size(vsmall) position(6)) ///
			   ysc(r(${YMIN`risk'} ${YMAX`risk'})) ///
			   xsc(off)
		}
		else {
			tw rarea upper_ci lower_ci temp, col(ltbluishgray) || ///
			   line yhat temp, lc(dknavy) yline(0) `cutoffs' ///
			   title("`plot_title'") legend(off) ///
			   ylab(#8,labs(vsmall) ang(vertical)) ///
			   ytitle("mins worked", size(small)) ///
			   xlab("",labs(small)) fysize(65) xtitle("") ///
			   name(`plot_name', replace) ///
			   graphregion(margin(zero) color(white)) ///
			   subtitle("${risk`risk'_`plot_name'} obs, ${ru_`plot_name'} rep-units, ${ry_`plot_name'} rep-unit-years.", size(small)) ///
			   ysc(r(${YMIN`risk'} ${YMAX`risk'})) ///
			   xsc(off)
		}
	}
	
	if "`plot_style'" == "all_data_no_ci"{
		if "`extrema_note'" != "" {
			tw line yhat temp, lc(dknavy) yline(0) `cutoffs' `peak_lines' ///
			   title("`plot_title'") legend(off) ///
			   ylab(#8,labs(vsmall) ang(vertical)) ///
			   ytitle("mins worked", size(small)) ///
			   xlab("",labs(small)) fysize(65) xtitle("") ///
			   name(`plot_name', replace) ///
			   graphregion(margin(zero) color(white)) ///
			   subtitle("${risk`risk'_`plot_name'} obs, ${ru_`plot_name'} rep-units, ${ry_`plot_name'} rep-unit-years.", size(small)) ///
			   note("`extrema_note'", size(vsmall) position(6)) ///
			   ysc(r(${YMIN`risk'} ${YMAX`risk'})) ///
			   xsc(off)
		}
		else {
			tw line yhat temp, lc(dknavy) yline(0) `cutoffs' ///
			   title("`plot_title'") legend(off) ///
			   ylab(#8,labs(vsmall) ang(vertical)) ///
			   ytitle("mins worked", size(small)) ///
			   xlab("",labs(small)) fysize(65) xtitle("") ///
			   name(`plot_name', replace) ///
			   graphregion(margin(zero) color(white)) ///
			   subtitle("${risk`risk'_`plot_name'} obs, ${ru_`plot_name'} rep-units, ${ry_`plot_name'} rep-unit-years.", size(small)) ///
			   ysc(r(${YMIN`risk'} ${YMAX`risk'})) ///
			   xsc(off)
		}
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
* plot_interacted_spline
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

	global YMIN_lr = -150
	global YMAX_lr = 50
	global YMIN_hl = -150
	global YMAX_hl = 50
	global YMIN_hr = -150
	global YMAX_hr = 50

	di "Unified y-axis range: -150 to 50 for all risk levels"

	* Generate plots using unified y-axis
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
		
		if "`interaction'" == "interacted" | "`interaction'" == "triple_int" {
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
		else if "`interaction'" == "climate" | "`interaction'" == "income" {
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

	* Marginal response plots
	if "`interaction'" == "climate" {
		foreach risk in _lr _hl {
			gen_marginal_resp_spline `N_knots' `risk'
			export delim using "marginal_resp_spline_`risk'_lrtmax.csv", replace
			if "`risk'" == "_lr" local plot_tag low_risk
			if "`risk'" == "_hl" local plot_tag high_risk
			
			gen_marg_plot "`plot_tag'" `plot_tag' `plot_style' 
		}
		graph combine low_risk high_risk, ///
			plotregion(color(white)) graphregion(color(white)) ///
			cols(2) ycommon title("lrtmax") subtitle("`ster_name'")
		graph export "`ster_name'_marginal_lrtmax.pdf", replace
	}
	else if "`interaction'" == "income" {
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
	}
	else if "`interaction'" == "interacted" | "`interaction'" == "triple_int" {
		foreach marginal_var in gdp lrtmax {
			foreach risk in _lr _hl {
				gen_marginal_resp_spline `N_knots' `risk'
				export delim using "marginal_resp_spline_`risk'_`marginal_var'.csv", replace
				if "`risk'" == "_lr" local plot_tag low_risk
				if "`risk'" == "_hl" local plot_tag high_risk
				
				gen_marg_plot "`plot_tag'" `plot_tag' `plot_style' 
			}
			graph combine low_risk high_risk, ///
				plotregion(color(white)) graphregion(color(white)) ///
				cols(2) ycommon title("`marginal_var'") subtitle("`ster_name'")
			graph export "`ster_name'_marginal_`marginal_var'.pdf", replace
		}
	}
	
	cd ..
end
******************************************************
* generate_grids (modified for climate)
******************************************************
cap program drop generate_grids
program define generate_grids
	
	args tercile interaction

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
	
	if "`interaction'" == "climate" {
		global max_g = 3

		global lrtmax1 `lrtmax_cold'
		global lrtmax2 `lrtmax_warm'
		global lrtmax3 `lrtmax_hot'
		
		global tag1 cold
		global tag2 warm
		global tag3 hot
	}
	else if "`interaction'" == "interacted" | "`interaction'" == "triple_int" {
		global max_g = 9

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
	else if "`interaction'" == "income" {
		global max_g = 3
	}

	if "`interaction'" != "climate" {
		if "`tercile'" == "hierid" {
			use "/project/cil/norgay/CIL_labor/2_regression/time_use/input/loggdppc_2010_grid.dta", clear
		}
		else if "`tercile'" == "rep_unit" {
			use "/project/cil/battuta_shares/gcp/estimation/labor/code_release_int_data/xtiles/rep_unit_terciles_grid.dta", clear
		}

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
			global minc1 `inc_poor'
			global minc2 `inc_midl'
			global minc3 `inc_rich'
			
			global tag1 poor
			global tag2 midincome
			global tag3 rich
		}
	}

	* Read counts and set global macros
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
		local knots 27 37 39
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

