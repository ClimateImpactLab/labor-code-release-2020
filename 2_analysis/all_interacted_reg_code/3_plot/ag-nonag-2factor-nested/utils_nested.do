******************************************************
* gen_response_surface_spline
******************************************************
cap program drop gen_response_surface_spline
program define gen_response_surface_spline

	args N_knots risk grid

	local N_new_vars=`N_knots'-2 
	global response_surface 0
	
	forval i=0/`N_new_vars'{
		gl response_surface ${response_surface}+(${b_T_spline_`i'`risk'})*(T_spline`i'-T_ref_spline`i')
		gl response_surface ${response_surface}+(${b_T_x_gdp_spline_`i'`risk'})*(T_spline`i'-T_ref_spline`i')*${minc`grid'}
		gl response_surface ${response_surface}+(${b_T_x_lrtmax_spline_`i'`risk'})*(T_spline`i'-T_ref_spline`i')*${lrtmax`grid'}
	}
	
	cap drop yhat *_ci
	di "`risk' `grid': $response_surface"
	predictnl yhat = $response_surface, ci(lower_ci upper_ci)
end


******************************************************
* gen_plot
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

	foreach risk in _lr _hr _hl {
		tempname ymin_`risk' ymax_`risk'
		scalar `ymin_`risk'' = .
		scalar `ymax_`risk'' = .

		forval g = 1/$max_g {
			gen_response_surface_spline `N_knots' `risk' `g'
			quietly summarize yhat
			
			if missing(`ymin_`risk'') | r(min) < `ymin_`risk'' {
				scalar `ymin_`risk'' = r(min)
			}
			if missing(`ymax_`risk'') | r(max) > `ymax_`risk'' {
				scalar `ymax_`risk'' = r(max)
			}
			
			cap drop yhat lower_ci upper_ci
		}

		scalar `ymin_`risk'' = `ymin_`risk'' - 5
		scalar `ymax_`risk'' = `ymax_`risk'' + 5

		global YMIN`risk' = `ymin_`risk''
		global YMAX`risk' = `ymax_`risk''

		di "Unified y-axis range for `risk': ${YMIN`risk'} to ${YMAX`risk'}"
	}

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

	foreach marginal_var in gdp lrtmax {
		foreach risk in _lr _hl {
			gen_marginal_resp_spline `N_knots' `marginal_var' `risk'
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
	cd ..
end

******************************************************
* generate_grids (NESTED VERSION: clim first, income within clim)
******************************************************
cap program drop generate_grids
program define generate_grids
	
	args tercile interaction

	****************************************************
	* 1) Read GRID (nested) and set lrtmax1..9, minc1..9, tag1..9
	****************************************************
	if "`interaction'" == "interacted" | "`interaction'" == "triple_int" {

		global max_g = 9

		* ---- read the nested 9-row grid ----
		if "`tercile'" == "hierid" {
			* 如果你未来也要 hierid 做 nested，需要你另存一份 hierid_nested grid
			di as error "!! hierid nested grid not implemented in this script."
			exit 198
		}
		else if "`tercile'" == "rep_unit" {
			use "${ROOT_INT_DATA}/xtiles/rep_unit_terciles_grid_nested.dta", clear
		}
		else {
			di as error "!! Incorrect tercile specification. Permitted: rep_unit, hierid."
			exit 198
		}

		* ---- sanity: should be 9 rows with clim_t inc_t cell ----
		confirm variable clim_t
		confirm variable inc_t
		confirm variable mean_lrtmax
		confirm variable mean_loggdppc

		* IMPORTANT:
		* g index must match your plotting order:
		* i = 1..9 loops income first (inc=1..3), climate within (clim=1..3)
		* so plots 1-3 are inc=1, plots 4-6 inc=2, plots 7-9 inc=3.
		local i = 1
		forvalues inc = 1/3 {
			forvalues clim = 1/3 {

				quietly summarize mean_lrtmax if clim_t==`clim' & inc_t==`inc', meanonly
				global lrtmax`i' = r(mean)

				quietly summarize mean_loggdppc if clim_t==`clim' & inc_t==`inc', meanonly
				global minc`i' = r(mean)

				* Tag for panel titles (nested income is within clim, so keep explicit)
				global tag`i' "clim`clim'-inc`inc'"

				di "Grid `i' (clim=`clim', inc=`inc'): lrtmax=${lrtmax`i'}  minc=${minc`i'}  tag=${tag`i'}"

				local ++i
			}
		}
	}

	****************************************************
	* 2) Income-only case (keep your old logic)
	****************************************************
	else if "`interaction'" == "income" {

		di "INTERACTION `interaction'"
		global max_g = 3

		* Here we still use the non-nested income grid (global income terciles)
		if "`tercile'" == "hierid" {
			use "/project/cil/norgay/CIL_labor/2_regression/time_use/input/loggdppc_2010_grid.dta", clear
		}
		else if "`tercile'" == "rep_unit" {
			use "/project/cil/battuta_shares/gcp/estimation/labor/code_release_int_data/xtiles/rep_unit_terciles_grid.dta", clear
		}
		else {
			di as error "!! Incorrect tercile specification. Permitted: rep_unit, hierid."
			exit 198
		}

		sum mean_loggdppc, detail
		local inc_poor = r(min)
		local inc_midl = r(p50)
		local inc_rich = r(max)

		global minc1 `inc_poor'
		global minc2 `inc_midl'
		global minc3 `inc_rich'

		global tag1 poor
		global tag2 midincome
		global tag3 rich
	}

	else {
		di as error "!! Unsupported interaction: `interaction'"
		exit 198
	}

	****************************************************
	* 3) Read counts file and load subtitle macros
	*    (must match the SAME g-index ordering)
	****************************************************
	di "READING COUNTS FROM FILE..."

	* Your plot_histograms saves counts here:
	*   "${ROOT_INT_DATA}/xtiles/`tercile'_terciles_count.dta"
	* For nested interacted, that file has clim_t inc_t (no need cell).
	use "${ROOT_INT_DATA}/xtiles/`tercile'_terciles_count.dta", clear

	if "`interaction'" == "interacted" | "`interaction'" == "triple_int" {

		local i = 1
		forvalues inc = 1/3 {
			forvalues clim = 1/3 {

				sum count_lr if clim_t==`clim' & inc_t==`inc', meanonly
				global risk_lr_plot`i' = r(sum)

				sum count_hr if clim_t==`clim' & inc_t==`inc', meanonly
				global risk_hr_plot`i' = r(sum)
				global risk_hl_plot`i' = r(sum)

				sum count_rep_unit if clim_t==`clim' & inc_t==`inc', meanonly
				global ru_plot`i' = r(sum)

				sum count_rep_year if clim_t==`clim' & inc_t==`inc', meanonly
				global ry_plot`i' = r(sum)

				di "Counts grid `i' (clim=`clim', inc=`inc'): LR=${risk_lr_plot`i'} HR=${risk_hr_plot`i'} RU=${ru_plot`i'} RY=${ry_plot`i'}"

				local ++i
			}
		}
	}

	else if "`interaction'" == "income" {

		local i = 1
		forvalues inc = 1/3 {

			sum count_lr if inc_t==`inc', meanonly
			global risk_lr_plot`i' = r(sum)

			sum count_hr if inc_t==`inc', meanonly
			global risk_hr_plot`i' = r(sum)
			global risk_hl_plot`i' = r(sum)

			sum count_rep_unit if inc_t==`inc', meanonly
			global ru_plot`i' = r(sum)

			sum count_rep_year if inc_t==`inc', meanonly
			global ry_plot`i' = r(sum)

			di "Counts grid `i' (inc=`inc'): LR=${risk_lr_plot`i'} HR=${risk_hr_plot`i'} RU=${ru_plot`i'} RY=${ry_plot`i'}"

			local ++i
		}
	}

	di "COUNTS LOADED INTO GLOBAL MACROS."
end

******************************************************
* generate_coef_spline
******************************************************
cap program drop generate_coef_spline
program define generate_coef_spline
	args N_knots spl_varname

	local N_new_vars=`N_knots'-2 

	forval k=0/`N_new_vars'{

		global b_T_spline_`k'_lr 0
		global b_T_x_gdp_spline_`k'_lr 0
		global b_T_x_lrtmax_spline_`k'_lr 0

		global b_T_spline_`k'_hr 0
		global b_T_x_gdp_spline_`k'_hr 0
		global b_T_x_lrtmax_spline_`k'_hr 0 

		global b_T_spline_`k'_lr _b[tmax_`spl_varname'_`N_knots'kn_t`k']
		global b_T_x_gdp_spline_`k'_lr _b[c.tmax_`spl_varname'_`N_knots'kn_t`k'#c.log_gdp_pc_adm1]
		global b_T_x_lrtmax_spline_`k'_lr _b[c.tmax_`spl_varname'_`N_knots'kn_t`k'#c.lr_tmax_p1]

		global b_T_spline_`k'_hr _b[1.risk_level#c.tmax_`spl_varname'_`N_knots'kn_t`k']
		global b_T_x_gdp_spline_`k'_hr _b[1.risk_level#c.tmax_`spl_varname'_`N_knots'kn_t`k'#c.log_gdp_pc_adm1]
		global b_T_x_lrtmax_spline_`k'_hr _b[1.risk_level#c.tmax_`spl_varname'_`N_knots'kn_t`k'#c.lr_tmax_p1]			
		
		forval lag=1/6{

			global b_T_spline_`k'_lr ${b_T_spline_`k'_lr}+_b[tmax_`spl_varname'_`N_knots'kn_t`k'_v`lag']
			global b_T_x_gdp_spline_`k'_lr ${b_T_x_gdp_spline_`k'_lr}+_b[c.tmax_`spl_varname'_`N_knots'kn_t`k'_v`lag'#c.log_gdp_pc_adm1]
			global b_T_x_lrtmax_spline_`k'_lr ${b_T_x_lrtmax_spline_`k'_lr}+_b[c.tmax_`spl_varname'_`N_knots'kn_t`k'_v`lag'#c.lr_tmax_p1]

			global b_T_spline_`k'_hr ${b_T_spline_`k'_hr}+_b[1.risk_level#c.tmax_`spl_varname'_`N_knots'kn_t`k'_v`lag']
			global b_T_x_gdp_spline_`k'_hr ${b_T_x_gdp_spline_`k'_hr}+_b[1.risk_level#c.tmax_`spl_varname'_`N_knots'kn_t`k'_v`lag'#c.log_gdp_pc_adm1]
			global b_T_x_lrtmax_spline_`k'_hr ${b_T_x_lrtmax_spline_`k'_hr}+_b[1.risk_level#c.tmax_`spl_varname'_`N_knots'kn_t`k'_v`lag'#c.lr_tmax_p1]

		}

		global b_T_spline_`k'_hl ${b_T_spline_`k'_lr} + ${b_T_spline_`k'_hr}
		global b_T_x_gdp_spline_`k'_hl  ${b_T_x_gdp_spline_`k'_lr} + ${b_T_x_gdp_spline_`k'_hr}
		global b_T_x_lrtmax_spline_`k'_hl ${b_T_x_lrtmax_spline_`k'_lr} + ${b_T_x_lrtmax_spline_`k'_hr}	
	}
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
