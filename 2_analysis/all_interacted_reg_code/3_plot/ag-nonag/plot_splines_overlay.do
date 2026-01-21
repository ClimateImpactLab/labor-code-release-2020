* most programs are similar in function and structure to plot_interacted_polynomials.do
* the only difference is that instead of looping from poly 1 to poly N,
* we loop from term 0 to term (N_knots - 2)
* and we generate special temperature variables using mkspline function
cap log close

log using "/home/`c(username)'/repos/logs/risk_overlay.smcl", replace
clear all 

* get paths
run "/home/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"
run "/home/`c(username)'/repos/labor-code-release-2020/2_analysis/0_subroutines/utils.do"
run "/home/`c(username)'/repos/labor-code-release-2020/2_analysis/all_interacted_reg_code/plot_histograms.do"

* select input and output folder
gl ster_dir "${DIR_OUTPUT}/interacted_reg_output/ster"
gl rf_folder "${DIR_OUTPUT}/interacted_reg_output"

**************************************
***** OVERLAY SPECIFIC FUNCTIONS *****
**************************************

* generate response function
cap program drop gen_response_overlay
program define gen_response_overlay

	args N_knots risk grid

	* N_new_vars = 1 in 3 knots case
	local N_new_vars=`N_knots'-2 
	global response_surface 0
	* i = 0/1
	* sum up the terms in the response function
	forval i=0/`N_new_vars'{
		gl response_surface ${response_surface}+(${b_T_spline_`i'`risk'})*(T_spline`i'-T_ref_spline`i')
		gl response_surface ${response_surface}+(${b_T_x_gdp_spline_`i'`risk'})*(T_spline`i'-T_ref_spline`i')*${minc`grid'}
		if "$interaction" == "interacted" |  "$interaction" == "triple_int" {
			gl response_surface ${response_surface}+(${b_T_x_lrtmax_spline_`i'`risk'})*(T_spline`i'-T_ref_spline`i')*${lrtmax`grid'}
		}
		if "$interaction" == "triple_int" {
			gl response_surface ${response_surface}+(${b_T_x_gdp_x_lrtmax_spline_`i'`risk'})*(T_spline`i'-T_ref_spline`i')*${minc`grid'}*${lrtmax`grid'}
		}

	}
	cap drop yhat`risk' *_ci`risk'
	di "`risk' `grid': $response_surface"
	predictnl yhat`risk' = $response_surface, ci(lower_ci`risk' upper_ci`risk')
	tempfile `risk'
	save ``risk'', replace 

	import delim using "${DIR_OUTPUT}/rf/uninteracted_reg_comlohi/uninteracted_reg_comlohi_full_response.csv", clear
	merge 1:1 temp using ``risk'' , nogen keep(3)

end

* generate plot
cap program drop gen_plot_overlay
program define gen_plot_overlay 
	args plot_title g plot_style weight 

	local plot_name = "plot`g'"
	local range_overlay = "-50 100"

	* local cutoffs = "xline(${p1`g'`risk'_`weight'}, lcol(gold) lpatt(-)) xline(${p99`g'`risk'_`weight'}, lcol(gold) lpatt(-)) xline(${p5`g'`risk'_`weight'}, lcol(orange) lpatt(_)) xline(${p95`g'`risk'_`weight'}, lcol(orange) lpatt(_))"
	* di "`cutoffs'"
	preserve 
	* if "`plot_style'" == "all_data_with_ci"{
	* 	* all data ci
	* 	tw rarea upper_ci lower_ci temp, col(ltbluishgray) || line yhat temp, lc (dknavy) yline(0) `cutoffs' title("`plot_title'") legend(off) ylab(#8,labs(vsmall) ang(vertical)) ytitle("mins worked", size(small)) xlab("",labs(small)) fysize(65) xtitle("") name(`plot_name', replace) graphregion(margin(zero) color(white)) subtitle("${risk`risk'_`plot_name'} obs, ${ru_`plot_name'} rep-units, ${ry_`plot_name'} rep-unit-years.", size(small)) ysc(r(`range`risk'')) xsc(off)
	* }
	if "`plot_style'" == "all_data_no_ci"{
		tw line yhat_low yhat_hl temp, yline(0, lcol(black) lpattern(dot)) title("`plot_title'") legend(label(1 "unint low risk") label(2 "int 1_factor high risk") size(small) symxsize(*.5) cols(1)) ylab(#10,labs(vsmall) ang(vertical)) ytitle("mins worked", size(small)) xlab(#10,labs(vsmall)) xmtick(##2) xtitle("temperature", size(small)) name(`plot_name', replace) graphregion(margin(zero) color(white)) subtitle("${ru_`plot_name'} rep-units, ${ry_`plot_name'} rep-unit-years.", size(small)) ysc(r(`range_overlay')) xsc(r(-20(5)60)) 
	}
	restore
end

* call the other functions to put together the plots
cap program drop plot_interacted_spline_overlay
program define plot_interacted_spline_overlay
	args interaction f N_knots data_subset plot_style ster_name

	cd "${DIR_OUTPUT}/diagnostics"
	cap mkdir "plankpose_diagnostics"
	cd "plankpose_diagnostics"
	
	di "Using: ${ster_dir}/`ster_name'.ster"
	estimates use "${ster_dir}/`ster_name'.ster"

	generate_temperature -20 50 27
	spline_temperature_range 3

	if "`interaction'" == "income" loc size = 50
	else loc size = 20

	di "INTERACTION : `interaction' `size'"

	* lr: low risk, hr: high risk (risk interaction terms only), hl: lr + hr = response of high risk 
	foreach risk in _hl {
		* generate the 3 or 9 plots
		forval g = 1/$max_g {
			gen_response_overlay `N_knots' `risk' `g' 
			gen_plot_overlay "${tag`g'}" `g' `plot_style' `risk' 
		}
		local plot_tag overlaid_high_1factor_low_unint_response
		
		if "`interaction'" != "income" {
			graph combine plot7 plot8 plot9 plot4 plot5 plot6 plot1 plot2 plot3, plotregion(color(white)) graphregion(color(white) margin(t=5 b=5)) xcomm imargin(0 0 0 0) cols(3) title("`plot_tag'") subtitle("`ster_name'", size(vsmall))
		}
		else {
			graph combine plot1 plot2 plot3, plotregion(color(white)) graphregion(color(white) margin(t=5 b=5)) xcomm imargin(0 0 0 0) cols(3) title("`plot_tag'") subtitle("`ster_name'", size(vsmall))
		}
		graph export "`ster_name'_`plot_tag'.pdf", replace
	}

 	cd ..
end


*****************
*	MAKE PLOTS
*****************

* other selections

local N_knots 3 

global reg_list 1_factor
* takes: 1_factor 2_factor

global data_subset_list no_chn
*global data_subset_list FRA GBR ESP IND CHN USA BRA MEX EU daily weekly no_chn all_data 

global weights_list rep_unit_year_sample_wgt

global fe_list fe_week_adm0 

global interaction "income"
* takes: interacted, income, triple_int

global tercile rep_unit
* takes: rep_unit, hierid

global max_g 3
* takes 3 and 9


generate_grids $tercile $interaction
generate_coef_spline 3 rcspl

foreach reg in $reg_list{
	forval p = 3/3 {
		foreach weight in $weights_list {
			foreach f in ${fe_list} {
				foreach data_subset in ${data_subset_list} {
					di "`reg_list'"
					loc ster_name "interacted_reg_`reg'"
					plot_interacted_spline_overlay $interaction `f' `p' `data_subset' all_data_no_ci `ster_name'
				}
			}
		}
	}	
}
