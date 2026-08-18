
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

	* define fixed effect specifications (MAIN PAPER SPEC IS fe_adm0_wk)
	global fe_adm0_y	"adm3_id dow_week adm0_id#year"
	global fe_adm0_my	"adm3_id dow_week adm0_id#month#year" 
	global fe_adm0_wk 	"adm3_id dow_week adm0_id#year adm0_id#week_fe" 
	global fe_adm3_my	"adm3_id dow_week adm3_id#month#year"
	global fe_adm0_m_y 	"adm3_id dow_week adm0_id#year adm0_id#month" 
	global fe_adm1_w_y      "adm3_id dow_week adm1_id#year adm1_id#week_fe"
    global fe_adm0_y_adm1_w "adm3_id dow_week adm0_id#year adm1_id#week_fe"
	global fe_adm1_y_adm0_w "adm3_id dow_week adm1_id#year adm0_id#week_fe"
	global fe_adm0_wk_country_spec "adm3_id dow_week year week_fe"

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

* 	generate macro of poly terms
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
*	GEN_TREATMENT_BINS

* 	generate macro of bin terms
*************************************** 

cap program drop gen_treatment_bins 
program define gen_treatment_bins
	* all arguments are numbers 
	* see variable labels in this file 
	* "${DIR_DATA_INT}/regression_ready_data/labor_dataset_bins_wchn_tmax_chn_prev_week_no_ll_0_0Cto42C_3Cbins.dta"
	* for the correspondence of bins with temperature 
	args start_bin end_bin ref_bin below_temp above_temp

	global varlist_bins_${bin_width}
	forval t = `start_bin'/`end_bin' {
		if `t' == `ref_bin' continue
		global varlist_bins_${bin_width} ${varlist_bins_${bin_width}} c.b${bin_width}_`t'
	}

	global varlist_bins_${bin_width} ${varlist_bins_${bin_width}} c.below`below_temp' c.above`above_temp'

	foreach v in ${varlist_bins_${bin_width}} {
		forval lag = 1/6 {
			global varlist_bins_${bin_width} ${varlist_bins_${bin_width}} `v'_v`lag'	
		}
	}

	di "${varlist_bins_${bin_width}}"
end   


***************************************
*	MAKE_TEMP_DIST

* 	make a list of temps accordingly
***************************************
cap program drop make_temp_dist
program define make_temp_dist
    // Build temp/ref/min from an arbitrary list of temperatures
    syntax , list(numlist) ref(real)

    clear

    local n : word count `list'
    set obs `n'

    gen double temp = .
    forvalues i = 1/`n' {
        local v : word `i' of `list'
        replace temp = `v' in `i'
    }

    gen double ref = `ref'
    gen double min = temp - ref

    order temp ref min
    label var temp "temperature for prediction"
    label var ref  "reference temperature"
    label var min  "temp - ref"
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
			_b[1.risk_level#c.tmax_rcspl_3kn_t`i'] + 
			_b[1.risk_level#c.tmax_rcspl_3kn_t`i'_v1] + 
			_b[1.risk_level#c.tmax_rcspl_3kn_t`i'_v2] + 
			_b[1.risk_level#c.tmax_rcspl_3kn_t`i'_v3] + 
			_b[1.risk_level#c.tmax_rcspl_3kn_t`i'_v4] + 
			_b[1.risk_level#c.tmax_rcspl_3kn_t`i'_v5] +
			_b[1.risk_level#c.tmax_rcspl_3kn_t`i'_v6] "
		;

		#d cr
	}

end



cap prog drop collect_indu_spline_terms
prog def collect_indu_spline_terms
    // splines: which t index (0,1)
    // unint : prefix for uninteracted spline sums  -> e.g. ${unint0}
    // int1  : prefix for risk_level==1 (high-risk ag)  -> e.g. ${int_ag0}
    // int2  : prefix for risk_level==2 (high-risk nonag)-> e.g. ${int_noag0}
    syntax , splines(numlist) unint(string) int1(string) int2(string)

    foreach i in `splines' {

        // ----- baseline: low-risk (risk_level==0) -----;
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

        // ----- interaction for high-risk agriculture: risk_level == 1 -----;
        gl `int1'`i' = "
            _b[1.risk_level#c.tmax_rcspl_3kn_t`i'] +
            _b[1.risk_level#c.tmax_rcspl_3kn_t`i'_v1] +
            _b[1.risk_level#c.tmax_rcspl_3kn_t`i'_v2] +
            _b[1.risk_level#c.tmax_rcspl_3kn_t`i'_v3] +
            _b[1.risk_level#c.tmax_rcspl_3kn_t`i'_v4] +
            _b[1.risk_level#c.tmax_rcspl_3kn_t`i'_v5] +
            _b[1.risk_level#c.tmax_rcspl_3kn_t`i'_v6] "
        ;

        // ----- interaction for high-risk non-agriculture: risk_level == 2 -----;
        gl `int2'`i' = "
            _b[2.risk_level#c.tmax_rcspl_3kn_t`i'] +
            _b[2.risk_level#c.tmax_rcspl_3kn_t`i'_v1] +
            _b[2.risk_level#c.tmax_rcspl_3kn_t`i'_v2] +
            _b[2.risk_level#c.tmax_rcspl_3kn_t`i'_v3] +
            _b[2.risk_level#c.tmax_rcspl_3kn_t`i'_v4] +
            _b[2.risk_level#c.tmax_rcspl_3kn_t`i'_v5] +
            _b[2.risk_level#c.tmax_rcspl_3kn_t`i'_v6] "
        ;
        #d cr
    }

end


cap program drop collect_agcoma_spline_terms
program define collect_agcoma_spline_terms

    syntax , splines(numlist) unint(name) int_ag(name) int_ma(name) int_co(name)

    foreach i of numlist `splines' {

        #delimit ;
        global `unint'`i'  ///
            _b[tmax_rcspl_3kn_t`i']     + ///
            _b[tmax_rcspl_3kn_t`i'_v1]  + ///
            _b[tmax_rcspl_3kn_t`i'_v2]  + ///
            _b[tmax_rcspl_3kn_t`i'_v3]  + ///
            _b[tmax_rcspl_3kn_t`i'_v4]  + ///
            _b[tmax_rcspl_3kn_t`i'_v5]  + ///
            _b[tmax_rcspl_3kn_t`i'_v6]  ;
        #delimit cr

        #delimit ;
        global `int_ag'`i'  ///
            _b[1.agri#c.tmax_rcspl_3kn_t`i']     + ///
            _b[1.agri#c.tmax_rcspl_3kn_t`i'_v1]  + ///
            _b[1.agri#c.tmax_rcspl_3kn_t`i'_v2]  + ///
            _b[1.agri#c.tmax_rcspl_3kn_t`i'_v3]  + ///
            _b[1.agri#c.tmax_rcspl_3kn_t`i'_v4]  + ///
            _b[1.agri#c.tmax_rcspl_3kn_t`i'_v5]  + ///
            _b[1.agri#c.tmax_rcspl_3kn_t`i'_v6]  ;
        #delimit cr

        #delimit ;
        global `int_ma'`i'  ///
            _b[1.manuft#c.tmax_rcspl_3kn_t`i']     + ///
            _b[1.manuft#c.tmax_rcspl_3kn_t`i'_v1]  + ///
            _b[1.manuft#c.tmax_rcspl_3kn_t`i'_v2]  + ///
            _b[1.manuft#c.tmax_rcspl_3kn_t`i'_v3]  + ///
            _b[1.manuft#c.tmax_rcspl_3kn_t`i'_v4]  + ///
            _b[1.manuft#c.tmax_rcspl_3kn_t`i'_v5]  + ///
            _b[1.manuft#c.tmax_rcspl_3kn_t`i'_v6]  ;
        #delimit cr
	
	#delimit ;
        global `int_co'`i'  ///
            _b[1.connmine#c.tmax_rcspl_3kn_t`i']     + ///
            _b[1.connmine#c.tmax_rcspl_3kn_t`i'_v1]  + ///
            _b[1.connmine#c.tmax_rcspl_3kn_t`i'_v2]  + ///
            _b[1.connmine#c.tmax_rcspl_3kn_t`i'_v3]  + ///
            _b[1.connmine#c.tmax_rcspl_3kn_t`i'_v4]  + ///
            _b[1.connmine#c.tmax_rcspl_3kn_t`i'_v5]  + ///
            _b[1.connmine#c.tmax_rcspl_3kn_t`i'_v6]  ;
        #delimit cr
    }
end

cap program drop collect_sector_spline_terms
program define collect_sector_spline_terms

    syntax , splines(numlist) unint(name) int_ag(name) int_nonag(name)

    foreach i of numlist `splines' {

        #delimit ;
        global `unint'`i'  ///
            _b[tmax_rcspl_3kn_t`i']     + ///
            _b[tmax_rcspl_3kn_t`i'_v1]  + ///
            _b[tmax_rcspl_3kn_t`i'_v2]  + ///
            _b[tmax_rcspl_3kn_t`i'_v3]  + ///
            _b[tmax_rcspl_3kn_t`i'_v4]  + ///
            _b[tmax_rcspl_3kn_t`i'_v5]  + ///
            _b[tmax_rcspl_3kn_t`i'_v6]  ;
        #delimit cr

        #delimit ;
        global `int_ag'`i'  ///
            _b[1.risk_level#c.tmax_rcspl_3kn_t`i']     + ///
            _b[1.risk_level#c.tmax_rcspl_3kn_t`i'_v1]  + ///
            _b[1.risk_level#c.tmax_rcspl_3kn_t`i'_v2]  + ///
            _b[1.risk_level#c.tmax_rcspl_3kn_t`i'_v3]  + ///
            _b[1.risk_level#c.tmax_rcspl_3kn_t`i'_v4]  + ///
            _b[1.risk_level#c.tmax_rcspl_3kn_t`i'_v5]  + ///
            _b[1.risk_level#c.tmax_rcspl_3kn_t`i'_v6]  ;
        #delimit cr

	#delimit ;
	global `int_nonag'`i'  ///
	    _b[2.risk_level#c.tmax_rcspl_3kn_t`i']     + ///
	    _b[2.risk_level#c.tmax_rcspl_3kn_t`i'_v1]  + ///
	    _b[2.risk_level#c.tmax_rcspl_3kn_t`i'_v2]  + ///
	    _b[2.risk_level#c.tmax_rcspl_3kn_t`i'_v3]  + ///
	    _b[2.risk_level#c.tmax_rcspl_3kn_t`i'_v4]  + ///
	    _b[2.risk_level#c.tmax_rcspl_3kn_t`i'_v5]  + ///
	    _b[2.risk_level#c.tmax_rcspl_3kn_t`i'_v6]  ;
	#delimit cr

    }
end

cap program drop collect_sector_spline_terms_42
program define collect_sector_spline_terms_42

    syntax , splines(numlist) unint(name) int_hr4(name) int_manuf2(name)

    foreach i of numlist `splines' {

        #delimit ;
        global `unint'`i'  ///
            _b[tmax_rcspl_3kn_t`i']     + ///
            _b[tmax_rcspl_3kn_t`i'_v1]  + ///
            _b[tmax_rcspl_3kn_t`i'_v2]  + ///
            _b[tmax_rcspl_3kn_t`i'_v3]  + ///
            _b[tmax_rcspl_3kn_t`i'_v4]  + ///
            _b[tmax_rcspl_3kn_t`i'_v5]  + ///
            _b[tmax_rcspl_3kn_t`i'_v6]  ;
        #delimit cr

        #delimit ;
        global `int_hr3'`i'  ///
            _b[1.risk_level4#c.tmax_rcspl_3kn_t`i']     + ///
            _b[1.risk_level4#c.tmax_rcspl_3kn_t`i'_v1]  + ///
            _b[1.risk_level4#c.tmax_rcspl_3kn_t`i'_v2]  + ///
            _b[1.risk_level4#c.tmax_rcspl_3kn_t`i'_v3]  + ///
            _b[1.risk_level4#c.tmax_rcspl_3kn_t`i'_v4]  + ///
            _b[1.risk_level4#c.tmax_rcspl_3kn_t`i'_v5]  + ///
            _b[1.risk_level4#c.tmax_rcspl_3kn_t`i'_v6]  ;
        #delimit cr

        #delimit ;
        global `int_manuf'`i'  ///
            _b[1.manuf2#c.tmax_rcspl_3kn_t`i']     + ///
            _b[1.manuf2#c.tmax_rcspl_3kn_t`i'_v1]  + ///
            _b[1.manuf2#c.tmax_rcspl_3kn_t`i'_v2]  + ///
            _b[1.manuf2#c.tmax_rcspl_3kn_t`i'_v3]  + ///
            _b[1.manuf2#c.tmax_rcspl_3kn_t`i'_v4]  + ///
            _b[1.manuf2#c.tmax_rcspl_3kn_t`i'_v5]  + ///
            _b[1.manuf2#c.tmax_rcspl_3kn_t`i'_v6]  ;
        #delimit cr
    }
end

*==========================================================
* GDP spline terms for risk_level = 0 (low), 1 (hr_ag), 2 (hr_noag)
*==========================================================
cap prog drop collect_gdp_spline_terms_level
prog def collect_gdp_spline_terms_level
    // splines: list of spline indices (e.g. 0 1)
    // unint_gdp : prefix for baseline (low, risk_level==0)
    // agri_gdp  : prefix for hr_ag (risk_level==1)
    // noag_gdp  : prefix for hr_noag (risk_level==2)
    syntax , splines(numlist) unint_gdp(string) ag_gdp(string) nonag_gdp(string)

    foreach i in `splines' {

        #d ;

        * ---------- baseline: low risk (risk_level==0) ----------;
        gl `unint_gdp'`i' = "
            _b[c.tmax_rcspl_3kn_t`i'#c.log_gdp_pc_adm1] +
            _b[c.tmax_rcspl_3kn_t`i'_v1#c.log_gdp_pc_adm1] +
            _b[c.tmax_rcspl_3kn_t`i'_v2#c.log_gdp_pc_adm1] +
            _b[c.tmax_rcspl_3kn_t`i'_v3#c.log_gdp_pc_adm1] +
            _b[c.tmax_rcspl_3kn_t`i'_v4#c.log_gdp_pc_adm1] +
            _b[c.tmax_rcspl_3kn_t`i'_v5#c.log_gdp_pc_adm1] +
            _b[c.tmax_rcspl_3kn_t`i'_v6#c.log_gdp_pc_adm1]
        " ;

        * ---------- increment: hr_ag (risk_level==1) vs low ----------;
        gl `ag_gdp'`i' = "
            _b[1.risk_level#c.tmax_rcspl_3kn_t`i'#c.log_gdp_pc_adm1] +
            _b[1.risk_level#c.tmax_rcspl_3kn_t`i'_v1#c.log_gdp_pc_adm1] +
            _b[1.risk_level#c.tmax_rcspl_3kn_t`i'_v2#c.log_gdp_pc_adm1] +
            _b[1.risk_level#c.tmax_rcspl_3kn_t`i'_v3#c.log_gdp_pc_adm1] +
            _b[1.risk_level#c.tmax_rcspl_3kn_t`i'_v4#c.log_gdp_pc_adm1] +
            _b[1.risk_level#c.tmax_rcspl_3kn_t`i'_v5#c.log_gdp_pc_adm1] +
            _b[1.risk_level#c.tmax_rcspl_3kn_t`i'_v6#c.log_gdp_pc_adm1]
        " ;

        * ---------- increment: hr_noag (risk_level==2) vs low ----------;
        gl `nonag_gdp'`i' = "
            _b[2.risk_level#c.tmax_rcspl_3kn_t`i'#c.log_gdp_pc_adm1] +
            _b[2.risk_level#c.tmax_rcspl_3kn_t`i'_v1#c.log_gdp_pc_adm1] +
            _b[2.risk_level#c.tmax_rcspl_3kn_t`i'_v2#c.log_gdp_pc_adm1] +
            _b[2.risk_level#c.tmax_rcspl_3kn_t`i'_v3#c.log_gdp_pc_adm1] +
            _b[2.risk_level#c.tmax_rcspl_3kn_t`i'_v4#c.log_gdp_pc_adm1] +
            _b[2.risk_level#c.tmax_rcspl_3kn_t`i'_v5#c.log_gdp_pc_adm1] +
            _b[2.risk_level#c.tmax_rcspl_3kn_t`i'_v6#c.log_gdp_pc_adm1]
        " ;

        #d cr
    }
end

*==========================================================
* LRT spline terms for risk_level = 0 (low), 1 (hr_ag), 2 (hr_noag)
* NOTE: replace log_lrt_pc_adm1 with your actual LRT variable
*==========================================================
cap prog drop collect_lrt_spline_terms_level
prog def collect_lrt_spline_terms_level
    syntax , splines(numlist) unint_lrt(string) ag_lrt(string) nonag_lrt(string)

    foreach i in `splines' {

        #d ;

        * ---------- baseline: low risk ----------;
        gl `unint_lrt'`i' = "
            _b[c.tmax_rcspl_3kn_t`i'#c.lr_tmax_p1] +
            _b[c.tmax_rcspl_3kn_t`i'_v1#c.lr_tmax_p1] +
            _b[c.tmax_rcspl_3kn_t`i'_v2#c.lr_tmax_p1] +
            _b[c.tmax_rcspl_3kn_t`i'_v3#c.lr_tmax_p1] +
            _b[c.tmax_rcspl_3kn_t`i'_v4#c.lr_tmax_p1] +
            _b[c.tmax_rcspl_3kn_t`i'_v5#c.lr_tmax_p1] +
            _b[c.tmax_rcspl_3kn_t`i'_v6#c.lr_tmax_p1]
        " ;

        * ---------- increment: hr_ag vs low ----------;
        gl `ag_lrt'`i' = "
            _b[1.risk_level#c.tmax_rcspl_3kn_t`i'#c.lr_tmax_p1] +
            _b[1.risk_level#c.tmax_rcspl_3kn_t`i'_v1#c.lr_tmax_p1] +
            _b[1.risk_level#c.tmax_rcspl_3kn_t`i'_v2#c.lr_tmax_p1] +
            _b[1.risk_level#c.tmax_rcspl_3kn_t`i'_v3#c.lr_tmax_p1] +
            _b[1.risk_level#c.tmax_rcspl_3kn_t`i'_v4#c.lr_tmax_p1] +
            _b[1.risk_level#c.tmax_rcspl_3kn_t`i'_v5#c.lr_tmax_p1] +
            _b[1.risk_level#c.tmax_rcspl_3kn_t`i'_v6#c.lr_tmax_p1]
        " ;

        * ---------- increment: hr_noag vs low ----------;
        gl `nonag_lrt'`i' = "
            _b[2.risk_level#c.tmax_rcspl_3kn_t`i'#c.lr_tmax_p1] +
            _b[2.risk_level#c.tmax_rcspl_3kn_t`i'_v1#c.lr_tmax_p1] +
            _b[2.risk_level#c.tmax_rcspl_3kn_t`i'_v2#c.lr_tmax_p1] +
            _b[2.risk_level#c.tmax_rcspl_3kn_t`i'_v3#c.lr_tmax_p1] +
            _b[2.risk_level#c.tmax_rcspl_3kn_t`i'_v4#c.lr_tmax_p1] +
            _b[2.risk_level#c.tmax_rcspl_3kn_t`i'_v5#c.lr_tmax_p1] +
            _b[2.risk_level#c.tmax_rcspl_3kn_t`i'_v6#c.lr_tmax_p1]
        " ;

        #d cr
    }
end


cap prog drop collect_gdp_spline_terms
prog def collect_gdp_spline_terms
	syntax , splines(numlist) unint_gdp(string) int_gdp(string)

	foreach i in `splines' {

		#d ;

		gl `unint_gdp'`i' = "
			_b[tmax_rcspl_3kn_t`i'#c.log_gdp_pc_adm1] + 
			_b[tmax_rcspl_3kn_t`i'_v1#c.log_gdp_pc_adm1] + 
			_b[tmax_rcspl_3kn_t`i'_v2#c.log_gdp_pc_adm1] + 
			_b[tmax_rcspl_3kn_t`i'_v3#c.log_gdp_pc_adm1] + 
			_b[tmax_rcspl_3kn_t`i'_v4#c.log_gdp_pc_adm1] + 
			_b[tmax_rcspl_3kn_t`i'_v5#c.log_gdp_pc_adm1] +
			_b[tmax_rcspl_3kn_t`i'_v6#c.log_gdp_pc_adm1] "
		;
		
		gl `int_gdp'`i' = "
			_b[1.risk_level#c.tmax_rcspl_3kn_t`i'#c.log_gdp_pc_adm1] + 
			_b[1.risk_level#c.tmax_rcspl_3kn_t`i'_v1#c.log_gdp_pc_adm1] + 
			_b[1.risk_level#c.tmax_rcspl_3kn_t`i'_v2#c.log_gdp_pc_adm1] + 
			_b[1.risk_level#c.tmax_rcspl_3kn_t`i'_v3#c.log_gdp_pc_adm1] + 
			_b[1.risk_level#c.tmax_rcspl_3kn_t`i'_v4#c.log_gdp_pc_adm1] + 
			_b[1.risk_level#c.tmax_rcspl_3kn_t`i'_v5#c.log_gdp_pc_adm1] +
			_b[1.risk_level#c.tmax_rcspl_3kn_t`i'_v6#c.log_gdp_pc_adm1] "
		;

		#d cr
	}

end


cap program drop collect_mix_spline_terms
program define collect_mix_spline_terms

    syntax , splines(numlist) unint_gdp(string) int_gdp(string)

    foreach i in `splines' {

        // ---------- UNINT:${unint_gdpi'} = LR----------
        #delimit ;
        global `unint_gdp'`i' = "
            _b[tmax_rcspl_3kn_t`i'_lr]   +
            _b[tmax_rcspl_3kn_t`i'_lr_v1]+
            _b[tmax_rcspl_3kn_t`i'_lr_v2]+
            _b[tmax_rcspl_3kn_t`i'_lr_v3]+
            _b[tmax_rcspl_3kn_t`i'_lr_v4]+
            _b[tmax_rcspl_3kn_t`i'_lr_v5]+
            _b[tmax_rcspl_3kn_t`i'_lr_v6]
        " ;
        #delimit cr

        // ---------- INT: ${int_gdpi'} = (HR*GDP) − (LR)----------
        #delimit ;
        global `int_gdp'`i' = "
            (  _b[tmax_rcspl_3kn_t`i'_hr_g]   +
               _b[tmax_rcspl_3kn_t`i'_hr_g_v1]+
               _b[tmax_rcspl_3kn_t`i'_hr_g_v2]+
               _b[tmax_rcspl_3kn_t`i'_hr_g_v3]+
               _b[tmax_rcspl_3kn_t`i'_hr_g_v4]+
               _b[tmax_rcspl_3kn_t`i'_hr_g_v5]+
               _b[tmax_rcspl_3kn_t`i'_hr_g_v6]
            )
            -
            (  _b[tmax_rcspl_3kn_t`i'_lr]   +
               _b[tmax_rcspl_3kn_t`i'_lr_v1]+
               _b[tmax_rcspl_3kn_t`i'_lr_v2]+
               _b[tmax_rcspl_3kn_t`i'_lr_v3]+
               _b[tmax_rcspl_3kn_t`i'_lr_v4]+
               _b[tmax_rcspl_3kn_t`i'_lr_v5]+
               _b[tmax_rcspl_3kn_t`i'_lr_v6]
            )
        " ;
        #delimit cr
    }
end


cap program drop collect_mix_lrt_spline_terms
program define collect_mix_lrt_spline_terms

    syntax , splines(numlist) unint(string) int_lrt(string)

    foreach i in `splines' {

        // ---------- UNINT:${unint_gdpi'} = LR----------
        #delimit ;
        global `unint'`i' = "
            _b[tmax_rcspl_3kn_t`i'_lr]   +
            _b[tmax_rcspl_3kn_t`i'_lr_v1]+
            _b[tmax_rcspl_3kn_t`i'_lr_v2]+
            _b[tmax_rcspl_3kn_t`i'_lr_v3]+
            _b[tmax_rcspl_3kn_t`i'_lr_v4]+
            _b[tmax_rcspl_3kn_t`i'_lr_v5]+
            _b[tmax_rcspl_3kn_t`i'_lr_v6]
        " ;
        #delimit cr

        // ---------- INT: ${int_gdpi'} = (HR*GDP) − (LR)----------
        #delimit ;
        global `int_lrt'`i' = "
            (  _b[tmax_rcspl_3kn_t`i'_hr_l]   +
               _b[tmax_rcspl_3kn_t`i'_hr_l_v1]+
               _b[tmax_rcspl_3kn_t`i'_hr_l_v2]+
               _b[tmax_rcspl_3kn_t`i'_hr_l_v3]+
               _b[tmax_rcspl_3kn_t`i'_hr_l_v4]+
               _b[tmax_rcspl_3kn_t`i'_hr_l_v5]+
               _b[tmax_rcspl_3kn_t`i'_hr_l_v6]
            )
            -
            (  _b[tmax_rcspl_3kn_t`i'_lr]   +
               _b[tmax_rcspl_3kn_t`i'_lr_v1]+
               _b[tmax_rcspl_3kn_t`i'_lr_v2]+
               _b[tmax_rcspl_3kn_t`i'_lr_v3]+
               _b[tmax_rcspl_3kn_t`i'_lr_v4]+
               _b[tmax_rcspl_3kn_t`i'_lr_v5]+
               _b[tmax_rcspl_3kn_t`i'_lr_v6]
            )
        " ;
        #delimit cr
    }
end

cap prog drop collect_lrt_spline_terms
prog def collect_lrt_spline_terms
	syntax , splines(numlist) unint_lrt(string) int_lrt(string)

	foreach i in `splines' {

		#d ;

		gl `unint_lrt'`i' = "
			_b[tmax_rcspl_3kn_t`i'#c.lr_tmax_p1] + 
			_b[tmax_rcspl_3kn_t`i'_v1#c.lr_tmax_p1] + 
			_b[tmax_rcspl_3kn_t`i'_v2#c.lr_tmax_p1] + 
			_b[tmax_rcspl_3kn_t`i'_v3#c.lr_tmax_p1] + 
			_b[tmax_rcspl_3kn_t`i'_v4#c.lr_tmax_p1] + 
			_b[tmax_rcspl_3kn_t`i'_v5#c.lr_tmax_p1] +
			_b[tmax_rcspl_3kn_t`i'_v6#c.lr_tmax_p1] "
		;
		
		gl `int_lrt'`i' = "
			_b[1.risk_level#c.tmax_rcspl_3kn_t`i'#c.lr_tmax_p1] + 
			_b[1.risk_level#c.tmax_rcspl_3kn_t`i'_v1#c.lr_tmax_p1] + 
			_b[1.risk_level#c.tmax_rcspl_3kn_t`i'_v2#c.lr_tmax_p1] + 
			_b[1.risk_level#c.tmax_rcspl_3kn_t`i'_v3#c.lr_tmax_p1] + 
			_b[1.risk_level#c.tmax_rcspl_3kn_t`i'_v4#c.lr_tmax_p1] + 
			_b[1.risk_level#c.tmax_rcspl_3kn_t`i'_v5#c.lr_tmax_p1] +
			_b[1.risk_level#c.tmax_rcspl_3kn_t`i'_v6#c.lr_tmax_p1] "
		;

		#d cr
	}

end

***************************************
*	COLLECT_POLYNOMIAL_TERMS

* 	put coefficients in macros
***************************************

cap prog drop collect_polynomial_terms
prog def collect_polynomial_terms
	syntax , order(numlist) unint(string) int(string)

	forval degree=1(1)`order' {

		#d ;

		gl `unint'`degree' =
			"_b[tmax_p`degree'] +" +
			"_b[tmax_p`degree'_v1] +" + 
			"_b[tmax_p`degree'_v2] +" +
			"_b[tmax_p`degree'_v3] +" +
			"_b[tmax_p`degree'_v4] +" +
			"_b[tmax_p`degree'_v5] +" +
			"_b[tmax_p`degree'_v6] "
		;

		gl `int'`degree' = 
			"_b[1.risk_level#c.tmax_p`degree'] +" + 
			"_b[1.risk_level#c.tmax_p`degree'_v1] +" + 
			"_b[1.risk_level#c.tmax_p`degree'_v2] +" +
			"_b[1.risk_level#c.tmax_p`degree'_v3] +" + 
			"_b[1.risk_level#c.tmax_p`degree'_v4] +" +
			"_b[1.risk_level#c.tmax_p`degree'_v5] +" +
			"_b[1.risk_level#c.tmax_p`degree'_v6] "
		;

		#d cr
	}

end

***************************************
*	COLLECT_BIN_TERMS

* 	put coefficients in macros
***************************************

cap prog drop collect_bin_terms
prog def collect_bin_terms
	syntax , bins(string) unint(string) int(string)
	
	di in red "Bin values are hard-coded in " 		///
	"this function (14 = (0,2) ... etc). Ensure "	///
	"they are correct."

	* get values corresponding to each bin (because
	* bins are very randomly named)
	gl min_below0 = -30
	gl max_below0 = 0
	gl min_above42 = 42
	gl max_above42 = 60
	gl min_14 = 0
	gl max_14 = 3
	forval bin=15(1)27 {
		loc prev_bin = `bin' - 1
		gl min_`bin' = ${min_`prev_bin'} + 3
		gl max_`bin' = ${max_`prev_bin'} + 3
	}

	* collect numeric and string names of bins
	numlist "14(1)27"
	gl `bins' "`r(numlist)' above42 below0"

	* collect the coefficients for each bin
	foreach bin in $`bins' {

		* add prefix for numerical bins
		if ("`bin'" != "above42") & ("`bin'" != "below0") loc coef "b3C_`bin'"
		else loc coef `bin'

		#d ;

		gl `unint'`bin' =
			"_b[`coef'] +" +
			"_b[`coef'_v1] +" + 
			"_b[`coef'_v2] +" + 
			"_b[`coef'_v3] +" + 
			"_b[`coef'_v4] +" + 
			"_b[`coef'_v5] +" + 
			"_b[`coef'_v6] "

		;

		gl `int'`bin' = 
			"_b[1.risk_level#c.`coef'] +" + 
			"_b[1.risk_level#c.`coef'_v1] +" + 
			"_b[1.risk_level#c.`coef'_v2] +" + 
			"_b[1.risk_level#c.`coef'_v3] +" + 
			"_b[1.risk_level#c.`coef'_v4] +" + 
			"_b[1.risk_level#c.`coef'_v5] +" + 
			"_b[1.risk_level#c.`coef'_v6] "
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

	syntax , categories(string) r2(numlist) n(numlist)

	di in red "R2, N and regression categories must all have the same order."

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

	* add R2 and N
	set obs `=_N+2'
	replace temp = "\hline Adj. R2" 	in `=_N-1'
	replace temp = "N" 					in `=_N'
	loc i = 1
	foreach cat in `categories' {

		cap replace `cat' = "`: word `i' of `r2''"	in `=_N-1'
		cap replace `cat' = "`: word `i' of `n''" 	in `=_N'

		loc ++i
	}


end

***************************************
*	SUBSAMPLE DATA

* 	drop data that's not in the subsample
***************************************

cap prog drop subsample_data
prog def subsample_data

	args reg

	* this is *truly* ugly, please fix it
	if "`reg'" == "inc_t1" keep if inc_t == 1
	if "`reg'" == "inc_t2" keep if inc_t == 2
	if "`reg'" == "inc_t3" keep if inc_t == 3
	if "`reg'" == "clim_t1" keep if clim_t == 1
	if "`reg'" == "clim_t2" keep if clim_t == 2
	if "`reg'" == "clim_t3" keep if clim_t == 3
	if "`reg'" == "inc_q1_clim_q1" keep if inc_q == 1 & clim_q == 1
	if "`reg'" == "inc_q1_clim_q2" keep if inc_q == 1 & clim_q == 2
	if "`reg'" == "inc_q2_clim_q1" keep if inc_q == 2 & clim_q == 1
	if "`reg'" == "inc_q2_clim_q2" keep if inc_q == 2 & clim_q == 2

end
