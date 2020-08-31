
cap program drop init
program define init 
	* macro drop _all
	* clear all

	set matsize 5000


	cap log close
	set more off
	*cap ssc install parallel

	if "`c(hostname)'" == "battuta" {
		global shares_path "/mnt/sacagawea_shares"
	}
	else global shares_path "/shares"
	*local path `c(pwd)'
	*global code_dir `path'

	global data_dir "${shares_path}/gcp/estimation/labor/time_use_data/final"
	global output_dir "${shares_path}/gcp/estimation/labor/regression_results" 

	global clustering_var cluster_adm1yymm
	global weights_var risk_adj_sample_wgt

	global bin_step 0.1
	
end 
*log using "${code_dir}/parallel", replace text

cap program drop run_specification
program define run_specification

	args reg_method spec_desc data include_0_min treatment control diff_treat diff_cont fe_ver weights clustering_var ster_name suffix

	local FE_dummies `fe_ver'


	if "`clustering'" == "no_clustering" {
		local clustering 
	}
	else {
		local clustering cl `clustering_var'
	}

	if "`diff_treat'" == "diff_treat"{
		local treatment (`treatment')##i.high_risk
	}

	if "`diff_cont'" == "diff_cont"{
		local control (`control')##i.high_risk
		local fe 
		foreach f in ${`fe_ver'} {
			local fe `fe' `f'#high_risk
		}
	}



	if "`include_0_min'" != "include_0_min" keep if mins_worked > 0


	if "`reg_method'" == "reg"{
		timer on 1 
		* if we want run using reg, we need to turn the FEs into dummies
		* we create the FE group variables after loading the data
		* and pass a list of dummies e.g. i.g1 i.g2 i.g3
		* to the same argument as FE in the reghdfe case

		di "reg mins_worked `treatment' `control' `FE_dummies' [pweight = `weights'] if included == 1, cluster(`clustering_var')"
		qui reg mins_worked `treatment' `control' `FE_dummies' [pweight = `weights'] if included == 1, cluster(`clustering_var')
		estimates notes: "`spec_desc'"
		estimates save "`ster_name'_reg", replace	
		*di _b[tmax_p1] 
		*di _se[tmax_p1]

		timer off 1 

		timer list 1

		local time = `r(t1)'
		local div = 3600
		local time_hours = `time'/`div'

		di "the specification took `time_hours' hours to run"
	}

	if "`reg_method'" == "reghdfe"{
		timer on 2

		di "reghdfe mins_worked `treatment' `control' [pweight = `weights'], absorb(`fe') vce(`clustering')"
		qui reghdfe mins_worked `treatment' `control' [pweight = `weights'], absorb(`fe') vce(`clustering')
		estimates notes: "`spec_desc'"
		estimates save "`ster_name'_reghdfe", replace	
		*di _b[tmax_p1]
		*di _se[tmax_p1]
		timer off 2 

		timer list 2

		local time = `r(t2)'
		local div = 3600
		local time_hours = `time'/`div'

		di "the specification took `time_hours' hours to run"
	}




end

cap program drop gen_treatment_splines 
program define gen_treatment_splines

	args spl_varname N_knots t_version leads_lags n_ll

	local N_new_vars=`N_knots'-2 

	global vars_T_splines 
	global vars_T_x_gdp_splines 
	global vars_T_x_lr_`t_version'_splines


	forval splines_term=0/`N_new_vars'{
	

		if "`leads_lags'"=="this_week"{
			*stacking contemporaneous week's weather 
			global vars_T_splines ${vars_T_splines} c.`t_version'_`spl_varname'_`N_knots'kn_t`splines_term'
			global vars_T_x_gdp_splines ${vars_T_x_gdp_splines} c.`t_version'_`spl_varname'_`N_knots'kn_t`splines_term'#c.log_gdp_pc_adm1
			global vars_T_x_lr_`t_version'_splines ${vars_T_x_lr_`t_version'_splines} c.`t_version'_`spl_varname'_`N_knots'kn_t`splines_term'#c.lr_`t_version'_p1
			
			forval lag=1/6 {
				global vars_T_splines ${vars_T_splines} c.`t_version'_`spl_varname'_`N_knots'kn_t`splines_term'_v`lag'
				global vars_T_x_gdp_splines ${vars_T_x_gdp_splines} c.`t_version'_`spl_varname'_`N_knots'kn_t`splines_term'_v`lag'#c.log_gdp_pc_adm1
				global vars_T_x_lr_`t_version'_splines ${vars_T_x_lr_`t_version'_splines} c.`t_version'_`spl_varname'_`N_knots'kn_t`splines_term'_v`lag'#c.lr_`t_version'_p1

			}
		}
		if "`leads_lags'"=="all_weeks"{
			*stacking contemporaneous week's weather...
			*that day
			global vars_T_splines ${vars_T_splines} c.`t_version'_`spl_varname'_`N_knots'kn_t`splines_term'
			global vars_T_x_gdp_splines ${vars_T_x_gdp_splines} c.`t_version'_`spl_varname'_`N_knots'kn_t`splines_term'#c.log_gdp_pc_adm1
			global vars_T_x_lr_`t_version'_splines ${vars_T_x_lr_`t_version'_splines} c.`t_version'_`spl_varname'_`N_knots'kn_t`splines_term'#c.lr_`t_version'_p1
			*other days
			forval lag=1/6 {

				global vars_T_splines ${vars_T_splines} c.`t_version'_`spl_varname'_`N_knots'kn_t`splines_term'_v`lag'
				global vars_T_x_gdp_splines ${vars_T_x_gdp_splines} c.`t_version'_`spl_varname'_`N_knots'kn_t`splines_term'_v`lag'#c.log_gdp_pc_adm1
				global vars_T_x_lr_`t_version'_splines ${vars_T_x_lr_`t_version'_splines} c.`t_version'_`spl_varname'_`N_knots'kn_t`splines_term'_v`lag'#c.lr_`t_version'_p1

			}


			*... and adding the n-order week lead ang lag

			local weeks 
			forval order=1/`n_ll' {
				local weeks `weeks' wk`order' wkn`order'
			}

			foreach week in `weeks' {

				*that day (n week before/after)
				global vars_T_splines ${vars_T_splines} c.`t_version'_`spl_varname'_`N_knots'kn_t`splines_term'_`week'
				global vars_T_x_gdp_splines ${vars_T_x_gdp_splines} c.`t_version'_`spl_varname'_`N_knots'kn_t`splines_term'_`week'#c.log_gdp_pc_adm1
				global vars_T_x_lr_`t_version'_splines ${vars_T_x_lr_`t_version'_splines} c.`t_version'_`spl_varname'_`N_knots'kn_t`splines_term'_`week'#c.lr_`t_version'_p1

				*other days (n week before or after)
				forval lag=1/6 {

					global vars_T_splines ${vars_T_splines} c.`t_version'_`spl_varname'_`N_knots'kn_t`splines_term'_`week'_v`lag'
					global vars_T_x_gdp_splines ${vars_T_x_gdp_splines} c.`t_version'_`spl_varname'_`N_knots'kn_t`splines_term'_`week'_v`lag'#c.log_gdp_pc_adm1
					global vars_T_x_lr_`t_version'_splines ${vars_T_x_lr_`t_version'_splines} c.`t_version'_`spl_varname'_`N_knots'kn_t`splines_term'_`week'_v`lag'#c.lr_`t_version'_p1
				}
			}
		}
	}


end 


cap program drop gen_controls_and_FEs
program define gen_controls_and_FEs
	global usual_controls c.age c.age2 c.male c.hhsize
		
	forval poly = 1/2 {
		global usual_controls ${usual_controls} c.precip_p`poly'
		forval lead_lag = 1/6 {
			global usual_controls ${usual_controls} c.precip_p`poly'_v`lead_lag'
		}
	}

	* define fixed effects and controls
	global fe_adm0 "adm3_id dow_week adm0_id#month#year" 
	global fe_adm1 "adm3_id dow_week adm1_id#month#year"
	global fe_adm3 "adm3_id dow_week adm3_id#month#year"
	global fe_week_adm0 "adm3_id dow_week adm0_id#week_fe adm0_id#year"
	global fe_week_adm1 "adm3_id dow_week adm1_id#week_fe adm1_id#year"
	global fe_week_saturated "adm3_id dow_week adm1_id#month#year adm1_id#week_fe"
	global fe_ind_adm0 "ind_id dow_week adm0_id#month#year"
end


cap program drop gen_treatment_polynomials
program define gen_treatment_polynomials

	args N_order t_version leads_lags n_ll


	global vars_T_polynomials 
	global vars_T_x_gdp_polynomials 
	global vars_T_x_lr_`t_version'_polynomials


	forval poly_order=1/`N_order'{
	

		if "`leads_lags'"=="this_week"{


			*stacking contemporaneous week's weather 

			global vars_T_polynomials ${vars_T_polynomials} c.`t_version'_p`poly_order'
			global vars_T_x_gdp_polynomials ${vars_T_x_gdp_polynomials} c.`t_version'_p`poly_order'#c.log_gdp_pc_adm1
			global vars_T_x_lr_`t_version'_polynomials ${vars_T_x_lr_`t_version'_polynomials} c.`t_version'_p`poly_order'#c.lr_`t_version'_p1


			forval lag=1/6 {

				global vars_T_polynomials ${vars_T_polynomials} c.`t_version'_p`poly_order'_v`lag'
				global vars_T_x_gdp_polynomials ${vars_T_x_gdp_polynomials} c.`t_version'_p`poly_order'_v`lag'#c.log_gdp_pc_adm1
				global vars_T_x_lr_`t_version'_polynomials ${vars_T_x_lr_`t_version'_polynomials} c.`t_version'_p`poly_order'_v`lag'#c.lr_`t_version'_p1

			}


		}

		if "`leads_lags'"=="all_weeks"{

			*stacking contemporaneous week's weather...

			*that day
			global vars_T_polynomials ${vars_T_polynomials} c.`t_version'_p`poly_order'
			global vars_T_x_gdp_polynomials ${vars_T_x_gdp_polynomials} c.`t_version'_p`poly_order'#c.log_gdp_pc_adm1
			global vars_T_x_lr_`t_version'_polynomials ${vars_T_x_lr_`t_version'_polynomials} c.`t_version'_p`poly_order'#c.lr_`t_version'_p1


			*other days
			forval lag=1/6 {

				global vars_T_polynomials ${vars_T_polynomials} c.`t_version'_p`poly_order'_v`lag'
				global vars_T_x_gdp_polynomials ${vars_T_x_gdp_polynomials} c.`t_version'_p`poly_order'_v`lag'#c.log_gdp_pc_adm1
				global vars_T_x_lr_`t_version'_polynomials ${vars_T_x_lr_`t_version'_polynomials} c.`t_version'_p`poly_order'_v`lag'#c.lr_`t_version'_p1

			}


			*... and adding the n-order week lead ang lag

			local weeks 
			forval order=1/`n_ll' {
				local weeks `weeks' wk`order' wkn`order'
			}

			foreach week in `weeks' {

				*that day (n week before/after)
				global vars_T_polynomials ${vars_T_polynomials} c.`t_version'_p`poly_order'_`week'
				global vars_T_x_gdp_polynomials ${vars_T_x_gdp_polynomials} c.`t_version'_p`poly_order'_`week'#c.log_gdp_pc_adm1
				global vars_T_x_lr_`t_version'_polynomials ${vars_T_x_lr_`t_version'_polynomials} c.`t_version'_p`poly_order'_`week'#c.lr_`t_version'_p1

				*other days (n week before or after)
				forval lag=1/6 {

					global vars_T_polynomials ${vars_T_polynomials} c.`t_version'_p`poly_order'_`week'_v`lag'
					global vars_T_x_gdp_polynomials ${vars_T_x_gdp_polynomials} c.`t_version'_p`poly_order'_`week'_v`lag'#c.log_gdp_pc_adm1
					global vars_T_x_lr_`t_version'_polynomials ${vars_T_x_lr_`t_version'_polynomials} c.`t_version'_p`poly_order'_`week'_v`lag'#c.lr_`t_version'_p1
				}
			}
		}
	}

end 




cap program drop generate_grids
program define generate_grids
	
	args tercile

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
		use "/mnt/CIL_labor/2_regression/time_use/input/lrtmax_grid.dta", clear
		* generated by emile from the projection system
		* long run tmax from CCSM4 rcp8.5, averaged from 1950 to 2005 
	}
	else if "`tercile'" == "rep_unit" {
		use "/mnt/CIL_labor/2_regression/time_use/input/rep_unit_terciles_grid.dta", clear
		* generated by Kit using gcp-labor/1_preparation/time_use/tercile_by_rep_units.do
	}
	else di "!! Incorrect tercile specification. Permitted: rep_unit, hierid."

	sum mean_lrtmax, detail

	local lrtmax_cold=`r(min)'
	local lrtmax_warm=`r(p50)'
	local lrtmax_hot=`r(max)'
	
	* min, median, and max from data
	*local lrtmax_cold=6.499815
	*local lrtmax_warm=27.84472
	*local lrtmax_hot=33.34956

	global lrtmax1 `lrtmax_cold'
	global lrtmax2 `lrtmax_warm'
	global lrtmax3 `lrtmax_hot'
	global lrtmax4 `lrtmax_cold'
	global lrtmax5 `lrtmax_warm'
	global lrtmax6 `lrtmax_hot'
	global lrtmax7 `lrtmax_cold'
	global lrtmax8 `lrtmax_warm'
	global lrtmax9 `lrtmax_hot'

	if "`tercile'" == "hierid" {
		use "/mnt/CIL_labor/2_regression/time_use/input/loggdppc_2010_grid.dta", clear
		* income generated by tom, also from projection system
		* mean of each of the tercile (by impact region) 
	}
	else if "`tercile'" == "rep_unit" {
		use "/mnt/CIL_labor/2_regression/time_use/input/rep_unit_terciles_grid.dta", clear
		* generated by Kit using gcp-labor/1_preparation/time_use/tercile_by_rep_units
	}
	else di "Incorrect tercile specification. Permitted: rep_unit, hierid."

	sum mean_loggdppc, detail

	local inc_poor =`r(min)'
	local inc_midl =`r(p50)'
	local inc_rich =`r(max)'

	*local inc_poor =7.302803
	*local inc_midl =9.466311
	*local inc_rich =11.2296

	global minc1 `inc_poor'
	global minc2 `inc_poor'
	global minc3 `inc_poor'
	global minc4 `inc_midl'
	global minc5 `inc_midl'
	global minc6 `inc_midl'
	global minc7 `inc_rich'
	global minc8 `inc_rich'
	global minc9 `inc_rich'

	* define tags that are used to label each plot
	global tag1 cold-poor
	global tag2 warm-poor
	global tag3 hot-poor
	global tag4 cold-midincome
	global tag5 warm-midincome
	global tag6 hot-midincome
	global tag7 cold-rich
	global tag8 warm-rich
	global tag9 hot-rich*

	* add counts of observations, rep-units, and rep-unit-years.
	use "/mnt/CIL_labor/2_regression/time_use/input/`tercile'_terciles_count.dta", clear

	local i = 1
	forvalues inc=1(1)3 {
		forvalues clim=1(1)3 {
			
			* general counts (consistent across risk subsets)
			sum count_rep_unit if clim == `clim' & inc == `inc'
			if (`r(N)' != 0) gl ru_plot`i' = `r(mean)' 
			else gl ru_plot`i' = 0

			sum count_rep_year if clim == `clim' & inc == `inc'
			if (`r(N)' != 0) gl ry_plot`i' = `r(mean)' 
			else gl ry_plot`i' = 0

			* risk-specific counts (N, varies by low vs high)
			sum count_lr if clim == `clim' & inc == `inc'
			if (`r(N)' != 0) gl risk_lr_plot`i' = `r(mean)' 
			else gl risk_lr_plot`i' = 0

			sum count_hr if clim == `clim' & inc == `inc'
			if (`r(N)' != 0) gl risk_hl_plot`i' = `r(mean)' 
			else gl risk_hl_plot`i' = 0
			
			* total N, sum of HR and LR --> don't worry, I know the shorthand
			* is massively confusing. hr = marginal, hl = high risk.
			global risk_hr_plot`i' = ${risk_hl_plot`i'} + ${risk_lr_plot`i'}
			local ++i
		}
	}


end




cap program drop generate_temperature
program define generate_temperature

	args min max ref

	cap drop if _n > 0
	cap drop _all
	cap drop temp
	gen temp=.
	local obs = `max' - `min' + 1
	*expand dataset by length of temperature vector
	set obs `obs'
	replace temp = _n - 1 + `min'
	gen ref = `ref'
	gen mins_worked = 0
end



cap program drop gen_plot
program define gen_plot 
	args plot_title g plot_style risk weight yspec 

	local plot_name = "plot`g'"
	local range_hr = "-50 80"
	local range_lr = "-20 60"
	local range_hl = "-50 100"

	local cutoffs = "xline(${p1`g'`risk'_`weight'}, lcol(gold) lpatt(-)) xline(${p99`g'`risk'_`weight'}, lcol(gold) lpatt(-)) xline(${p5`g'`risk'_`weight'}, lcol(orange) lpatt(_)) xline(${p95`g'`risk'_`weight'}, lcol(orange) lpatt(_))"
	di "`cutoffs'"
	preserve 
	if "`plot_style'" == "all_data_with_ci"{
		* all data ci
		tw rarea upper_ci lower_ci temp, col(ltbluishgray) || line yhat temp, lc (dknavy) yline(0) `cutoffs' title("`plot_title'") legend(off) ylab(#8,labs(vsmall) ang(vertical)) `yspec' ytitle("mins worked", size(small)) xlab("",labs(small)) fysize(20) xtitle("") name(`plot_name', replace) graphregion(margin(zero) color(white)) subtitle("${risk`risk'_`plot_name'} obs, ${ru_`plot_name'} rep-units, ${ry_`plot_name'} rep-unit-years.", size(small)) ysc(r(`range`risk'')) xsc(off)
	}
	if "`plot_style'" == "all_data_no_ci"{
		tw  line yhat temp, lc (dknavy) yline(0) `cutoffs' title("`plot_title'") legend(off) ylab(#8,labs(vsmall) ang(vertical)) `yspec' ytitle("mins worked", size(small)) xlab("",labs(small)) fysize(20) xtitle("") name(`plot_name', replace) graphregion(margin(zero) color(white)) subtitle("${risk`risk'_`plot_name'} obs, ${ru_`plot_name'} rep-units, ${ry_`plot_name'} rep-unit-years.", size(small)) ysc(r(`range`risk'')) xsc(off)
	}

	if "`plot_style'" == "above0_with_ci"{
		drop if temp < 0
		tw rarea upper_ci lower_ci temp, col(ltbluishgray) || line yhat temp, lc (dknavy) yline(0) title("`plot_title'") legend(off) graphregion(color(white)) ylabel(,angle(horizontal)) `yspec'  ytitle("mins worked") xtitle("Temperature C", height(6)) name(`plot_name', replace) 
	}
	if "`plot_style'" == "above0_no_ci"{
		drop if temp < 0
		tw  line yhat temp, lc (dknavy) yline(0) title("`plot_title'") legend(off) graphregion(color(white)) ylabel(,angle(horizontal))  `yspec' ytitle("mins worked") xtitle("Temperature C", height(6)) name(`plot_name', replace)
	}
	restore
end

cap program drop gen_marg_plot
program define gen_marg_plot 
	args plot_title plot_name plot_style yspec
	preserve 
	if "`plot_style'" == "all_data_with_ci"{
		* all data ci
		tw rarea upper_ci lower_ci temp, col(ltbluishgray) || line yhat temp, lc (dknavy) yline(0) title("`plot_title'") legend(off) graphregion(color(white)) ylabel(,angle(horizontal)) `yspec' 	ytitle("mins worked") xtitle("Temperature C", height(6)) name(`plot_name', replace)
	}
	if "`plot_style'" == "all_data_no_ci"{
		tw  line yhat temp, lc (dknavy) yline(0) title("`plot_title'") legend(off) graphregion(color(white)) ylabel(,angle(horizontal)) `yspec' ytitle("mins worked") xtitle("Temperature C", height(6)) name(`plot_name', replace)
	}

	if "`plot_style'" == "above0_with_ci"{
		drop if temp < 0
		tw rarea upper_ci lower_ci temp, col(ltbluishgray) || line yhat temp, lc (dknavy) yline(0) title("`plot_title'") legend(off) graphregion(color(white)) ylabel(,angle(horizontal)) `yspec'  ytitle("mins worked") xtitle("Temperature C", height(6)) name(`plot_name', replace)
	}
	if "`plot_style'" == "above0_no_ci"{
		drop if temp < 0
		tw  line yhat temp, lc (dknavy) yline(0) title("`plot_title'") legend(off) graphregion(color(white)) ylabel(,angle(horizontal))  `yspec' ytitle("mins worked") xtitle("Temperature C", height(6)) name(`plot_name', replace)
	}
	restore
end






* generate coefficients for plotting
cap program drop generate_coef_spline
program define generate_coef_spline
	args N_knots spl_varname

	local N_new_vars=`N_knots'-2 
	di "new var"
	di "`N_new_vars'"

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

		global b_T_spline_`k'_hr _b[1.high_risk#c.tmax_`spl_varname'_`N_knots'kn_t`k']
		global b_T_x_gdp_spline_`k'_hr _b[1.high_risk#c.tmax_`spl_varname'_`N_knots'kn_t`k'#c.log_gdp_pc_adm1]
		global b_T_x_lrtmax_spline_`k'_hr _b[1.high_risk#c.tmax_`spl_varname'_`N_knots'kn_t`k'#c.lr_tmax_p1]			
		
		forval lag=1/6{

			global b_T_spline_`k'_lr ${b_T_spline_`k'_lr}+_b[tmax_`spl_varname'_`N_knots'kn_t`k'_v`lag']
			global b_T_x_gdp_spline_`k'_lr ${b_T_x_gdp_spline_`k'_lr}+_b[c.tmax_`spl_varname'_`N_knots'kn_t`k'_v`lag'#c.log_gdp_pc_adm1]
			global b_T_x_lrtmax_spline_`k'_lr ${b_T_x_lrtmax_spline_`k'_lr}+_b[c.tmax_`spl_varname'_`N_knots'kn_t`k'_v`lag'#c.lr_tmax_p1]

			global b_T_spline_`k'_hr ${b_T_spline_`k'_hr}+_b[1.high_risk#c.tmax_`spl_varname'_`N_knots'kn_t`k'_v`lag']
			global b_T_x_gdp_spline_`k'_hr ${b_T_x_gdp_spline_`k'_hr}+_b[1.high_risk#c.tmax_`spl_varname'_`N_knots'kn_t`k'_v`lag'#c.log_gdp_pc_adm1]
			global b_T_x_lrtmax_spline_`k'_hr ${b_T_x_lrtmax_spline_`k'_hr}+_b[1.high_risk#c.tmax_`spl_varname'_`N_knots'kn_t`k'_v`lag'#c.lr_tmax_p1]

		}

		global b_T_spline_`k'_hl ${b_T_spline_`k'_lr} + ${b_T_spline_`k'_hr}
		global b_T_x_gdp_spline_`k'_hl  ${b_T_x_gdp_spline_`k'_lr} + ${b_T_x_gdp_spline_`k'_hr}
		global b_T_x_lrtmax_spline_`k'_hl ${b_T_x_lrtmax_spline_`k'_lr} + ${b_T_x_lrtmax_spline_`k'_hr}	
	}
end   




* generate coefficients for plotting
cap program drop generate_coef_polynomials
program define generate_coef_polynomials
	macro drop b_*

	* compute coefficients for each variable at each polylnomial 
	forval degree = 1/4{
		global b_temp_`degree'_lr _b[tmax_p`degree'] 
		global b_temp_gdp_`degree'_lr _b[c.tmax_p`degree'#c.log_gdp_pc_adm1]
		global b_temp_lrtmax_`degree'_lr _b[c.tmax_p`degree'#c.lr_tmax_p1]


		forval lag = 1/6 {
			global b_temp_`degree'_lr ${b_temp_`degree'_lr}+_b[tmax_p`degree'_v`lag']		
			global b_temp_gdp_`degree'_lr ${b_temp_gdp_`degree'_lr}+_b[c.tmax_p`degree'_v`lag'#c.log_gdp_pc_adm1]
			global b_temp_lrtmax_`degree'_lr ${b_temp_lrtmax_`degree'_lr}+_b[c.tmax_p`degree'_v`lag'#c.lr_tmax_p1]
		
		}
	}

	forval degree = 1/4{
		global b_temp_`degree'_hr _b[1.high_risk#c.tmax_p`degree'] 
		global b_temp_gdp_`degree'_hr _b[1.high_risk#c.tmax_p`degree'#c.log_gdp_pc_adm1]
		global b_temp_lrtmax_`degree'_hr _b[1.high_risk#c.tmax_p`degree'#c.lr_tmax_p1]

		forval lag = 1/6 {
			global b_temp_`degree'_hr ${b_temp_`degree'_hr}+_b[1.high_risk#c.tmax_p`degree'_v`lag']		
			global b_temp_gdp_`degree'_hr ${b_temp_gdp_`degree'_hr}+_b[1.high_risk#c.tmax_p`degree'_v`lag'#c.log_gdp_pc_adm1]
			global b_temp_lrtmax_`degree'_hr ${b_temp_lrtmax_`degree'_hr}+_b[1.high_risk#c.tmax_p`degree'_v`lag'#c.lr_tmax_p1]
		}
	}

	forval degree = 1/4{
		global b_temp_`degree'_hl ${b_temp_`degree'_lr}+${b_temp_`degree'_hr}
		global b_temp_gdp_`degree'_hl  ${b_temp_gdp_`degree'_lr}+${b_temp_gdp_`degree'_hr}
		global b_temp_lrtmax_`degree'_hl  ${b_temp_lrtmax_`degree'_lr}+${b_temp_lrtmax_`degree'_hr}

	}
end   

cap program drop select_data_subset 
program define select_data_subset 
	args data_subset
	local countries "BRA CHN MEX IND USA FRA ESP GBR"
	* get climate/income terciles and quartiles for subsetting
	merge m:1 rep_unit using "/mnt/CIL_labor/2_regression/time_use/input/rep_unit_terciles_uncollapsed.dta", keepusing(inc_t clim_t inc_q clim_q) nogen

	if "`data_subset'"=="weekly" keep if iso=="BRA"|iso=="CHN"|iso=="MEX"
	else if "`data_subset'"=="daily" drop if iso=="BRA"|iso=="CHN"|iso=="MEX"
	else if "`data_subset'"=="EU" keep if iso=="ESP"|iso=="FRA"|iso=="GBR"	
	else if "`data_subset'"=="no_chn" drop if iso=="CHN"	
	else if "`data_subset'" == "CHN_mon" keep if iso == "CHN" & dow == 1
	else if "`data_subset'" == "CHN_tue" keep if iso == "CHN" & dow == 2
	else if "`data_subset'" == "CHN_wed" keep if iso == "CHN" & dow == 3
	else if "`data_subset'" == "CHN_thu" keep if iso == "CHN" & dow == 4
	else if "`data_subset'" == "CHN_fri" keep if iso == "CHN" & dow == 5
	else if "`data_subset'" == "CHN_sat" keep if iso == "CHN" & dow == 6
	else if "`data_subset'" == "CHN_sun" keep if iso == "CHN" & dow == 0
	foreach country in `countries' {
		else if "`data_subset'" == "no_`country'" keep if iso != "`country'"
	}
	else if "`data_subset'"!= "all_data" & inlist("`data_subset'", "BRA","CHN","MEX","IND","USA","FRA","ESP","GBR") {
		keep if iso == "`data_subset'"
	}
	* these are the tercile stuffs
	else if "`data_subset'" == "inc_t1" keep if iso!= "CHN" & inc_t == 1
	else if "`data_subset'" == "inc_t2" keep if iso!= "CHN" & inc_t == 2
	else if "`data_subset'" == "inc_t3" keep if iso!= "CHN" & inc_t == 3
	else if "`data_subset'" == "clim_t1" keep if iso!= "CHN" & clim_t == 1
	else if "`data_subset'" == "clim_t2" keep if iso!= "CHN" & clim_t == 2
	else if "`data_subset'" == "clim_t3" keep if iso!= "CHN" & clim_t == 3
	else if "`data_subset'" == "inc_q1_clim_q1" keep if  iso!= "CHN" & inc_q == 1 & clim_q == 1
	else if "`data_subset'" == "inc_q1_clim_q2" keep if  iso!= "CHN" & inc_q == 1 & clim_q == 2
	else if "`data_subset'" == "inc_q2_clim_q1" keep if  iso!= "CHN" & inc_q == 2 & clim_q == 1
	else if "`data_subset'" == "inc_q2_clim_q2" keep if  iso!= "CHN" & inc_q == 2 & clim_q == 2
	else if "`data_subset'" != "all_data" di "wrong specification of data scope!"
end // note that "wrong specification of scope" keeps showing up incorrectly



cap program drop get_RF_uninteracted_splines
program define get_RF_uninteracted_splines
	args leads_lags differentiated_treatment ster_name filename_stem t_version chn_week spl_varname fe N_knots knots_loc weights data_subset output_folder default_ref_temp
	
	di "get RF for uninteracted splines"
	* determine the list of RFs to generate based on if the regression includes lead and lag weeks
	if "`leads_lags'" == "all_weeks" global LL_list lead lag sum CT
	else if "`leads_lags'" == "this_week" global LL_list CTO
	else di "misspecified leads_lags week"

	* find the range and mean of the subset of data
	* if the spline dataset didn't contain china data, use the distribution of temperatures from the dataset with chn_prev7days
	if "`chn_week'" == "no_chn" local chn_week_temp_distribution chn_prev7days
	else local chn_week_temp_distribution `chn_week'
	import delim using "$data_dir/temp_distributions/`t_version'_`chn_week_temp_distribution'/`data_subset'.csv", clear
	tempfile bins
	save `bins', replace

	sum max_realised, meanonly
	loc max_realised = r(mean)
	sum min_realised, meanonly
	loc min_realised = r(mean)
	sum center, meanonly
	loc center = r(mean)

	local obs = ( `max_realised' - `min_realised' + 1 ) / $bin_step


	di "`ster_name'.ster"

	* Note - we need one less term than the number of knots
	capture confirm file "`ster_name'.ster"
	if _rc == 0 { 
		
		estimates use "`ster_name'.ster"

		local knots ${`knots_loc'}
		di "`knots'"

		local knot1 : word 1 of `knots'
		local knot2 : word 2 of `knots'
		local knot3 : word 3 of `knots'
		loc knot_string = "`knot1'_`knot2'_`knot3'_"


		foreach LL in $LL_list {		
			foreach ref_temp in `center' `default_ref_temp' {	
				clear 
				gen temp=.
				set obs `obs'
				gen ref = `ref_temp'
				* generate temperature vector within the range of the data
				replace temp = `min_realised' + $bin_step * (_n - 1)  + ($bin_step / 2)
				gen mins_worked = .
				qui merge 1:1 temp using `bins'
				replace density= 0 if _merge == 1
				assert _merge != 2
				drop _merge


				make_spline_terms `knot1' `knot2' `knot3'
				
				* Get the relevant variable name tag
				if("`LL'" == "lead") {
					loc ll "_wk1"
				}
				if("`LL'" == "CT") {
					loc ll ""
				}
				if("`LL'" == "lag") {
					loc ll "_wkn1"
				}
				

				* if treatment was not differentiated between high and low risk, gen RF for only low risk
				if "`differentiated_treatment'" == "yes" local risk_list low high
				else local risk_list low

				foreach risk in `risk_list' {

					if "`risk'" == "high" {
						loc risk_tag = "1.high_risk#c."
					}
					else{
						loc risk_tag = ""
					}
					di "checker - made it to point 1"
					* Loop over polynomial order 

					loc max_spline_term =`N_knots' - 2
					forvalues p = 0/`max_spline_term' {
						di "`p'"
						* Loop over leads and lags
						forvalues v = 0/6{ 
							if (`v'==0){
								di "`v'"
								if("`LL'" == "sum"){
									loc beta_`risk'_t`p' = "_b[`risk_tag'`t_version'_`spl_varname'_3kn_t`p'] + _b[`risk_tag'`t_version'_`spl_varname'_3kn_t`p'_wkn1] + _b[`risk_tag'`t_version'_`spl_varname'_3kn_t`p'_wk1] "
								}
								else{
									loc beta_`risk'_t`p' =  "_b[`risk_tag'`t_version'_`spl_varname'_3kn_t`p'`ll'] "
								}
							}
							else{
								if("`LL'" == "sum"){
									loc beta_`risk'_t`p'  = "`beta_`risk'_t`p'' + _b[`risk_tag'`t_version'_`spl_varname'_3kn_t`p'_v`v'] + _b[`risk_tag'`t_version'_`spl_varname'_3kn_t`p'_wkn1_v`v'] + _b[`risk_tag'`t_version'_`spl_varname'_3kn_t`p'_wk1_v`v']"
								}
								else{
									loc beta_`risk'_t`p' = "`beta_`risk'_t`p'' + _b[`risk_tag'`t_version'_`spl_varname'_3kn_t`p'`ll'_v`v']"
								}
							}
						}
						di "Sum of coefficients for risk category `risk', spline term `p' is ... "
						di `beta_`risk'_t`p''
					}

					if("`risk'" == "low") {

						loc predict_command "predictnl yhat_`risk'_`iso' = (`beta_`risk'_t0') * (T_spline0 - ref_spline0)"
						forval p = 1/`max_spline_term'  {
							loc predict_command "`predict_command'  + (`beta_`risk'_t`p'') * (T_spline`p' - ref_spline`p') "
						}
					}
								
					if("`risk'" == "high") {
						loc predict_command "predictnl yhat_`risk'_`iso' = (`beta_high_t0'+ `beta_low_t0') * (T_spline0 - ref_spline0)"
						forval p = 1/`max_spline_term'  {
							loc predict_command "`predict_command' + (`beta_high_t`p''+ `beta_low_t`p'')  * (T_spline`p' - ref_spline`p') "
						}
					}
					di "predicting for `risk' risk"
					di "`predict_command'"
					`predict_command', ci(lowerci_`risk'_`iso' upperci_`risk'_`iso') se(se_`risk'_`iso')
					gen significant_`risk'_`iso' = 0
					replace significant_`risk'_`iso' = 1 if (lowerci_`risk'_`iso' > 0 | upperci_`risk'_`iso' < 0 )
					
					tempfile `risk'
					save ``risk'', replace 
				}


				if "`differentiated_treatment'" == "yes" {
				di "merging high and low risk response functions"
				merge 1:1 temp ref using `low', nogen assert(3)			
				}

				keep temp ref yhat* se* upper* lower* density* significant* rep_unit_year_sample_wgt

				gen within_R2 = e(r2_within)
			
				* generate a suffix to indicate which ref temperature is being used
				if `ref_temp' == `default_ref_temp' local ref_temp_suffix default_ref 
				else local ref_temp_suffix center_ref
				* save
				cap mkdir "${output_dir}/response_functions/`output_folder'"
				cap mkdir "${output_dir}/response_functions/`output_folder'/`filename_stem'_`t_version'_`chn_week'"
				export delim using "${output_dir}/response_functions/`output_folder'/`filename_stem'_`t_version'_`chn_week'/`fe'_`N_knots'_knots_`data_subset'_`weights'_`LL'_`ref_temp_suffix'.csv", replace
			}
		}
	}
	else{
		di "the ster..."
		di "`ster_name'.ster"
		di "doesn't exist! check wherther we have run that kind of regression!"
	}
end 

cap program drop get_RF_uninteracted_polynomials
program define get_RF_uninteracted_polynomials

	args leads_lags differentiated_treatment ster_name t_version chn_week fe N_order weights data_subset output_folder default_ref_temp

	di "get RF for uninteracted polynomials"
	* determine the list of RFs to generate based on if the regression includes lead and lag weeks
	if "`leads_lags'" == "all_weeks" global LL_list lead lag sum CT
	else if "`leads_lags'" == "this_week" global LL_list CTO
	else di "misspecified leads_lags week"

	* find the range and mean of the subset of data
	import delim using "$data_dir/temp_distributions/`t_version'_`chn_week'/`data_subset'.csv", clear
	tempfile bins
	save `bins', replace
	
	sum max_realised, meanonly
	loc max_realised = r(mean)
	sum min_realised, meanonly
	loc min_realised = r(mean)
	sum center, meanonly
	loc center = r(mean)

	local obs = ( `max_realised' - `min_realised' + 1 ) / $bin_step
	* check if the ster file exists
	di "`ster_name'.ster"
	capture confirm file "`ster_name'.ster"
	* if ster file exists
	if _rc == 0 { 
	* loop through the list of RFs, and for each subset of data, 
	* we want to generate RFs for both with ref temperature at 27, and ref temp at the median of data
		foreach LL in $LL_list {		
			foreach ref_temp in `center' `default_ref_temp' {
				clear 
				gen temp=.
				set obs `obs'
				gen ref = `ref_temp'
				* generate temperature vector within the range of the data
				replace temp = `min_realised' + $bin_step * (_n - 1)  + ($bin_step / 2)
				gen mins_worked = .
				qui merge 1:1 temp using `bins'
				replace density= 0 if _merge == 1
				assert _merge != 2
				drop _merge
									
				* Get the relevant variable name tag
				if("`LL'" == "lead") {
					loc ll "_wk1"
				}
				if("`LL'" == "CT") {
					loc ll ""
				}
				if("`LL'" == "lag") {
					loc ll "_wkn1"
				}

				* if treatment was not differentiated between high and low risk, gen RF for only low risk
				if "`differentiated_treatment'" == "yes" local risk_list low high
				else local risk_list low

				foreach risk in `risk_list' {

					if "`risk'" == "high" {
						loc risk_tag = "1.high_risk#c."
					}
					else{
						loc risk_tag = ""
					}
					* Loop over polynomial order 
					forvalues p = 1/`N_order' {
						di "`p'"
						* Loop over leads and lags
						forvalues v = 0/6{ 
							if (`v'==0){
								di "`v'"
								if("`LL'" == "sum"){
									loc beta_`risk'_t`p' = "_b[`risk_tag'`t_version'_p`p'] + _b[`risk_tag'`t_version'_p`p'_wkn1] + _b[`risk_tag'`t_version'_p`p'_wk1]"
								}
								else{
									loc beta_`risk'_t`p' = "_b[`risk_tag'`t_version'_p`p'`ll']"
								}
							}
							else{
								if("`LL'" == "sum"){
									loc beta_`risk'_t`p'  = "`beta_`risk'_t`p'' + _b[`risk_tag'`t_version'_p`p'_v`v'] + _b[`risk_tag'`t_version'_p`p'_wkn1_v`v'] + _b[`risk_tag'`t_version'_p`p'_wk1_v`v']"
								}
								else{
									loc beta_`risk'_t`p' = "`beta_`risk'_t`p'' + _b[`risk_tag'`t_version'_p`p'`ll'_v`v']"
								}
							}
						}
						di "Sum of coefficients for risk category `risk', polynomial term `p' is ... "
						di `beta_`risk'_t`p''
					}

					if ("`risk'" == "low") {

						loc predict_command "predictnl yhat_`risk'_`iso' = (`beta_`risk'_t1') * (temp - ref)"
						forval p = 2/`N_order' {
							loc predict_command "`predict_command'  + (`beta_`risk'_t`p'') * (temp ^`p' - ref ^`p') "
						}
					}
								
					if ("`risk'" == "high") {
						loc predict_command "predictnl yhat_`risk'_`iso' = (`beta_high_t1'+ `beta_low_t1') * (temp - ref)"
						forval p = 2/`N_order' {
							loc predict_command "`predict_command' + (`beta_high_t`p''+ `beta_low_t`p'')  * (temp ^`p' - ref ^`p') "
						}
					}

					di "predicting for `risk' risk"
					loc predict_command "`predict_command' , ci(lowerci_`risk'_`iso' upperci_`risk'_`iso') se(se_`risk'_`iso') p(p_`risk')"
					di "`predict_command'"
					`predict_command'
					gen significant_`risk'_`iso' = 0
					replace significant_`risk'_`iso' = 1 if (lowerci_`risk'_`iso' > 0 | upperci_`risk'_`iso' < 0 )
					
					tempfile `risk'
					save ``risk'', replace 
				}

				if "`differentiated_treatment'" == "yes" {
				di "merging high and low risk response functions"
				merge 1:1 temp ref using `low', nogen assert(3)			
				}

				cap keep temp ref yhat* se* upper* lower* density significant*
				gen within_R2 = e(r2_within)

				* generate a suffix to indicate which ref temperature is being used
				if `ref_temp' == `default_ref_temp' local ref_temp_suffix default_ref 
				else local ref_temp_suffix center_ref
				* save
				cap mkdir "${output_dir}/response_functions/`output_folder'"
				cap mkdir "${output_dir}/response_functions/`output_folder'/polynomials_`t_version'_`chn_week'"
				export delim using "${output_dir}/response_functions/`output_folder'/polynomials_`t_version'_`chn_week'/`fe'_poly_`N_order'_`weights'_`data_subset'_`LL'_`ref_temp_suffix'.csv", replace
			}
		}
	}
	else{
	di "the ster file"
	di "`ster_name'.ster"
	di "doesn't exist! check wherther we have run that kind of regression!"
}
end 




cap program drop make_spline_terms
program define make_spline_terms
	args knot1 knot2 knot3
	* local knot1 = 16.6
	* local knot2 = 30.3
	* local knot3 = 36.6
	glob knots = "`knot1' `knot2' `knot3'"
	di "$knots"

	local scaling_factor=(`knot3'-`knot1')^2
	mkspline T_spline=temp, cubic knots($knots)
	mkspline ref_spline=ref, cubic knots($knots)

	di "matching these splines with the transformed-after-aggregated data"

	forval k=2/2{
		replace T_spline`k'=T_spline`k'*`scaling_factor'
		replace ref_spline`k'=ref_spline`k'*`scaling_factor'
	}

	forval k = 1/2{
		loc j = `k' - 1
		ren T_spline`k' T_spline`j'
		ren ref_spline`k' ref_spline`j'
	}
end 




