
***************************************
*	GEN_CONTROLS_AND_FES

* 	generate macro of controls
*	generate macro of fixed effect specifications
***************************************

cap program drop gen_controls_and_FEs
program define gen_controls_and_FEs

	* generate the list of 'usual controls'
	global usual_controls c.age c.age2 c.male c.hhsize

	* generate precipitation control macros	
	forval poly = 1/2 {
		global usual_controls ${usual_controls} c.precip_p`poly'
		forval lead_lag = 1/6 {
			global usual_controls ${usual_controls} c.precip_p`poly'_v`lead_lag'
		}
	}

	* define fixed effect specifications
	global fe_adm0_y	"adm3_id dow_week adm0_id#year"
	global fe_adm0_my	"adm3_id dow_week adm0_id#month#year" 
	global fe_adm0_wk 	"adm3_id dow_week adm0_id#year adm0_id#week_fe"
	global fe_adm3_my	"adm3_id dow_week adm3_id#month#year"

end 

***************************************
*	GEN_TREATMENT_SPLINES

* 	generate macro of spline terms
***************************************

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

***************************************
*	GEN_TREATMENT_POLYNOMIALS

* 	generate macro of spline terms
*************************************** 

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

***************************************
*	MAKE_TEMP_DIST

* 	put coefficients in macros
***************************************

cap prog drop make_temp_dist
prog def make_temp_dist
	syntax , list(numlist) ref(real)

	loc num : word count `list'
	set obs `num'

	gen temp = .
	gen ref = `ref'

	loc i = 1
	foreach temp in `list' {
		replace temp = `temp' in `i'
		loc ++i
	}

end


***************************************
*	MAKE_SPLINE_TERMS

* 	generate interpretable spline versions
***************************************

cap program drop make_spline_terms
program define make_spline_terms
	args knot1 knot2 knot3

	glob knots = "`knot1' `knot2' `knot3'"

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


***************************************
*	COLLECT_SPLINE_TERMS

* 	put coefficients in macros
***************************************

cap prog drop collect_spline_terms
prog def collect_spline_terms
	syntax , splines(numlist) unint(string) int(string)

	foreach i in `splines' {

		#d ;

		gl `unint'`i' = "
			_b[tmax_rcspl_3kn_t`i'] + 
			_b[tmax_rcspl_3kn_t`i'_v1] + 
			_b[tmax_rcspl_3kn_t`i'_v2] + 
			_b[tmax_rcspl_3kn_t`i'_v3] + 
			_b[tmax_rcspl_3kn_t`i'_v4] + 
			_b[tmax_rcspl_3kn_t`i'_v5] +
			_b[tmax_rcspl_3kn_t`i'_v6] "
		;

		gl `int'`i' = "
			_b[1.high_risk#c.tmax_rcspl_3kn_t`i'] + 
			_b[1.high_risk#c.tmax_rcspl_3kn_t`i'_v1] + 
			_b[1.high_risk#c.tmax_rcspl_3kn_t`i'_v2] + 
			_b[1.high_risk#c.tmax_rcspl_3kn_t`i'_v3] + 
			_b[1.high_risk#c.tmax_rcspl_3kn_t`i'_v4] + 
			_b[1.high_risk#c.tmax_rcspl_3kn_t`i'_v5] +
			_b[1.high_risk#c.tmax_rcspl_3kn_t`i'_v6] "
		;

		#d cr
	}

end

***************************************
*	CONVERT_TABLE

* 	change a response function CSV
*	into a Latex table
***************************************

cap prog drop convert_table
prog def convert_table

	syntax , categories(string)

	keep yhat* se* temp

	foreach j in `categories' {

		* get stars
		gen t_stats`j' 	= abs(yhat_`j'/se_`j')
		gen p`j' 		= ""
		replace p`j' 	= "*" if t_stats`j' > 1.645
		replace p`j' 	= "**" if t_stats`j' > 1.960
		replace p`j' 	= "***" if t_stats`j' > 2.576

		* reformat yhat
		gen double `j'1 = round(yhat_`j', 0.01)
		format `j'1 %03.2f
		tostring `j'1, replace force
		replace `j'1 = `j'1 + p`j'
		
		* reformat standard errors
		gen double `j'2 = round(se_`j', 0.01)
		format `j'2 %03.2f
		tostring `j'2, replace force
		replace `j'2 = "(" + `j'2 + ")"

	}

	* reshape to table format (yhat with se below)
	reshape long `categories', i(temp) j(line)
	sort temp line
	tostring temp, replace force
	replace temp = "" if line == 2
	keep `categories' temp

end
