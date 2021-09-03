* most programs are similar in function and structure to plot_interacted_polynomials.do
* the only difference is that instead of looping from poly 1 to poly N,
* we loop from term 0 to term (N_knots - 2)
* and we generate special temperature variables using mkspline function

global REPO = "/home/kschwarz/repos"
run "${REPO}/gcp-labor/2_regression/time_use/common_functions.do"
run "${REPO}/gcp-labor/2_regression/time_use/plot_histograms.do"

cap program drop spline_temperature_range
program define spline_temperature_range
	* after generating the normal temperature variables
	* we transform them into spline terms with this program

	args N_knots  


	if `N_knots' == 3 {
		local knots 27 37 39
	}
	
	*Stata formula is different from the formula we used to get the spline of real temperatures, by a scalar factor. 
	*We use Stata formula to transform the range of temperature that we multiply by the estimates 
	*Hence after Stata processed the ranged we need to rescale the output to use it with our estimates based on aggregated splines (not if those were computed by Stata)

	local N_vars_sp=`N_knots'-1

	loc count=1
	* find the first and last knots, the scaling factor, and use 
	* stata's mkspline to generate the temperature vectors 
	* which we'll then multiply with the corresponding coefficients to generate the plots
	foreach k in `knots'{

		if `count'==1{
			loc first_knot=`k'
		}
		if `count'==`N_knots'{
			loc last_knot=`k'
		}
		loc count=`count'+1
	}

	local scaling_factor=(`last_knot'-`first_knot')^2

	mkspline T_spline=temp, cubic knots(`knots')
	mkspline T_ref_spline=ref, cubic knots(`knots')

	di "matching these splines with the transformed-after-aggregated data"

	* linear term doesn't need to be scaled
	forval k=2/`N_vars_sp'{
		replace T_spline`k'=T_spline`k'*`scaling_factor'
		replace T_ref_spline`k'=T_ref_spline`k'*`scaling_factor'
	}

	rename T_spline1 T_spline0
	rename T_spline2 T_spline1
	rename T_ref_spline1 T_ref_spline0
	rename T_ref_spline2 T_ref_spline1
end


cap program drop gen_response_surface_spline
program define gen_response_surface_spline

	args N_knots risk grid

	* N_new_vars = 1 in 3 knots case
	local N_new_vars=`N_knots'-2 
	global response_surface 0
	* i = 0/1
	* sum up the terms in the response function
	forval i=0/`N_new_vars'{
		global response_surface ${response_surface}+(${b_T_spline_`i'`risk'})*(T_spline`i'-T_ref_spline`i')
		global response_surface ${response_surface}+(${b_T_x_gdp_spline_`i'`risk'})*(T_spline`i'-T_ref_spline`i')*${minc`grid'}
		global response_surface ${response_surface}+(${b_T_x_lrtmax_spline_`i'`risk'})*(T_spline`i'-T_ref_spline`i')*${lrtmax`grid'}
	}
	cap drop yhat *_ci
	di "$response_surface"
	predictnl yhat = $response_surface, ci(lower_ci upper_ci)
end


* generate the marginal response of long run gdp or tmax
cap program drop gen_marginal_resp_spline
program define gen_marginal_resp_spline

	args N_knots marginal_var risk

	local N_new_vars=`N_knots'-2 

	global response 0

	forval i=0/`N_new_vars'{
		global response $response + (${b_T_x_`marginal_var'_spline_`i'`risk'}) * (T_spline`i'-T_ref_spline`i')
	}
	cap drop yhat *_ci
	di "$response"
	predictnl yhat = $response, ci(lower_ci upper_ci)
end


* call the other functions to put together the plots
cap program drop plot_interacted_spline
program define plot_interacted_spline
	args f N_knots data_subset plot_style ster_name wgt yspec

	cap mkdir `plot_style'
	cd `plot_style'

	estimates use "${ster_dir}/`ster_name'.ster"

	generate_temperature -20 50 27
	spline_temperature_range 3

	* lr: low risk, hr: high risk (risk interaction terms only), hl: lr + hr = response of high risk 
	foreach hist_weight in no_wgt rep_unit_year_sample_wgt  {
	 	foreach risk in _lr _hr _hl {
	 		* generate the 9 plots
	 		forval g = 1/9 {
	 			gen_response_surface_spline `N_knots' `risk' `g'
	 			gen_plot "${tag`g'}" `g' `plot_style' `risk' `hist_weight' `yspec' 
	 		}
	 		if "`risk'" == "_lr" local plot_tag low_risk
	 		if "`risk'" == "_hl" local plot_tag high_risk
	 		if "`risk'" == "_hr" local plot_tag marginal_risk

	 		* add in the histogram subplots
	 		forval i=1(1)9 {
	 			local h`i'_abs = "/shares/gcp/estimation/labor/regression_results/histograms/$tercile/`hist_weight'/hist`i'`risk'_abs.gph"
	 			local h`i'_pct = "/shares/gcp/estimation/labor/regression_results/histograms/$tercile/`hist_weight'/hist`i'`risk'_pct.gph"

	 		}
	 		foreach t in abs pct {
	 			graph combine plot7 plot8 plot9 "`h7_`t''" "`h8_`t''" "`h9_`t''" plot4 plot5 plot6 "`h4_`t''" "`h5_`t''" "`h6_`t''" plot1 plot2 plot3 "`h1_`t''" "`h2_`t''" "`h3_`t''", plotregion(color(white)) graphregion(color(white) margin(t=5 b=5)) xcomm imargin(0 0 0 0) cols(3) title("`plot_tag'") subtitle("`ster_name'", size(small))
	 			graph export "`t'_`wgt'_`f'_`N_knots'_knots_this_week_`data_subset'_`plot_tag'_`hist_weight'.pdf", replace
	 		}
	 	}
	}

	foreach marginal_var in lrtmax gdp {
		* plot marginal effect of lrtmax and log gdp per capita
		foreach risk in _lr _hl {

			gen_marginal_resp_spline `N_knots' `marginal_var' `risk'
			if "`risk'" == "_lr" local plot_tag low_risk
			if "`risk'" == "_hl" local plot_tag high_risk
			
			gen_marg_plot "`plot_tag'" `plot_tag' `plot_style' `yspec'	
		}
		graph combine low_risk high_risk, plotregion(color(white)) graphregion(color(white)) cols(2) ycommon title("`marginal_var'") subtitle("`ster_name'")
		graph export "`wgt'_`f'_`N_knots'_knots_this_week_`data_subset'_marginal_`marginal_var'.pdf", replace
	}
	cd ..
end


cap program drop test_interaction_spline
program define test_interaction_spline
	args f N_knots data_subset ster_name wgt
	
	estimates use "${ster_dir}/`ster_name'.ster"

	local N_new_vars=`N_knots'-2 

	* matrix for F test results
	putexcel set "test_spline_results.xlsx", sheet("`wgt'") modify
	mat results = J(2,6,.)
	local j = 1

	foreach risk in lr hl {
		global test_exp_gdp 0
		global test_exp_lrtmax 0
		global test_exp_gdp_and_lrtmax 0

		forval i=0/`N_new_vars'{
			global test_exp_gdp $test_exp_gdp = (${b_T_x_gdp_spline_`i'_`risk'}) 
			global test_exp_lrtmax $test_exp_lrtmax = (${b_T_x_lrtmax_spline_`i'_`risk'}) 
			global test_exp_gdp_and_lrtmax $test_exp_gdp_and_lrtmax = (${b_T_x_gdp_spline_`i'_`risk'}) = (${b_T_x_lrtmax_spline_`i'_`risk'}) 

		}

		local colnames = "`colnames' `risk'_GDP_interaction"
		test ${test_exp_gdp} 
		mat results[1, `j'] = `r(F)'
		mat results[2, `j'] = `r(p)'
		local ++j
		local colnames = "`colnames' `risk'_lrtmax_interaction"
		test ${test_exp_lrtmax}
		mat results[1, `j'] = `r(F)'
		mat results[2, `j'] = `r(p)'
		local ++j
		local colnames = "`colnames' `risk'_joint_interaction"
		test ${test_exp_gdp_and_lrtmax}
		mat results[1, `j'] = `r(F)'
		mat results[2, `j'] = `r(p)'
		local ++j
	}
	
	mat colnames results  = `colnames'
	mat rownames results  = F pval
	putexcel A1 = matrix(results), names

end



global t_version_list tmax
global chn_week_list chn_prev_week

global variables_list splines_27_37_39
global data_subset_list no_chn
*global data_subset_list FRA GBR ESP IND CHN USA BRA MEX EU daily weekly no_chn all_data 

global weights_list rep_unit_year_sample_wgt

global skip_existing_plot "no"
global run_lcl "no"

global data_ll_version no_ll_0

global fe_list  fe_week_adm0 

global plot_dir "/shares/gcp/estimation/labor/regression_results/plots/interacted_splines_by_risk"

global tercile rep_unit
* takes: rep_unit, hierid

generate_grids $tercile
generate_coef_spline 3 rcspl
plot_histograms rep_unit no_wgt
plot_histograms rep_unit rep_unit_year_sample_wgt

local N_knots 3 


foreach t_version in $t_version_list {
	foreach chn_week in $chn_week_list {
		foreach spl_varname in $variables_list {
			local data_filename `spl_varname'_`t_version'_`chn_week'
			cd "${plot_dir}"
			cap mkdir `data_filename'_$tercile
			cd `data_filename'_$tercile
			global ster_dir "/shares/gcp/estimation/labor/regression_results/estimates/interacted_splines_by_risk/`data_filename'"
			forval p = 3/3 {
				foreach weight in $weights_list {
					foreach f in ${fe_list} {
						foreach data_subset in ${data_subset_list} {
							local ster_name = "`f'_`p'_knots_this_week_`data_subset'_`weight'_reghdfe"
							plot_interacted_spline `f' `p' `data_subset' all_data_no_ci `ster_name' `weight'
							test_interaction_spline `f' `p' `data_subset' `ster_name' `weight'
							}
						}
					}
			}
		}
	}
}


