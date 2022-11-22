* king of all csvv writers


clear all
macro drop _all
set more off
cap log close
set matsize 10000
cilpath


global ster_dir = "/home/`c(username)'/repos/labor-code-release-2020/output/ster"
global csvv_dir = "/home/`c(username)'/repos/labor-code-release-2020/3_projection/1_run_projections/single_test_correct_rebasing"
*global fun_form = "polynomials"
global fun_form = "splines"
* N is polynomial order or number of knots
global N = 3

*global interaction = "interacted"
global interaction = "uninteracted"

global ster_folder = "uninteracted_reg_comlohi"

* may need to change interacted weight
if "${interaction}" == "interacted" global weight = "adm1_adj_sample_wgt"
else if "${interaction}" == "uninteracted" global weight = "risk_adj_sample_wgt"
else di "wrong specification of interaction"

global FE = "fe_week_adm0"

if "${fun_form}" == "splines" {

	global knots_loc  "21_37_41"
	global dataset = "uninteracted_reg_comlohi"
	global spline_varname = "rcspl"
	global ster_filename = "uninteracted_reg_by_risk.ster"

} 
else if "${fun_form}" == "polynomials" {
	global dataset = "polynomials_tmax_chn_prev7days"
	* the filename for interacted regression is temporary!!!!!! 
	if "${interaction}" == "interacted" global ster_filename = "fe_week_adm0_poly_4_this_week_no_chn_reg_test_deltabeta.ster"
	else if "${interaction}" == "uninteracted" global ster_filename = "${FE}_poly_${N}_this_week_no_chn_${weight}_reghdfe.ster"

}
else di "wrong specification of functional form"

* change this to your repo on ther server, pull from master first
global repo = "/home/`c(username)'/repos/labor-code-release-2020"
do "$repo/2_analysis/0_subroutines/utils.do"
do "$repo/2_analysis/0_subroutines/functions.do"


* generate varlists for the gammas
cap program drop generate_gammas_splines
program define generate_gammas_splines
	args N spline_varname interaction

	* call this function in the common_functions.do to generate the globals 
	generate_coef_spline `N' "`spline_varname'"

	local N_new_terms = `N' - 2
	local gcount = 0
	foreach risk in lr hl {
		forval i = 0/`N_new_terms' {
		 	local gcount = `gcount' + 1
		 	global gamma`gcount' ${b_T_spline_`i'_`risk'}
		 	* if interacted, add the interaction terms
		}
	 	if "`interaction'" == "interacted" {
	 		forval i = 0/`N_new_terms' {
				local gcount = `gcount' + 1
				global gamma`gcount' ${b_T_x_lrtmax_spline_`i'_`risk'}
 			}
 			forval i = 0/`N_new_terms' {
				local gcount = `gcount' + 1
	 			global gamma`gcount' ${b_T_x_gdp_spline_`i'_`risk'}
 			}
		}
	}
 	
 	* Get rid of the plus signs, and stata _b[] so we can evaluate when we want later!
	forval i = 1/`gcount'{
		global gamma`i' = subinstr("${gamma`i'}","+"," ",.)
		global gamma`i' = subinstr("${gamma`i'}","_b[","",.)
		global gamma`i' = subinstr("${gamma`i'}","]","",.)
	}

	global N_gamma = `gcount'
end

* testing command:
* generate_gammas_spline 3 "rcspl_best" "interacted"

* generate varlists for the gammas
cap program drop generate_gammas_polynomials
program define generate_gammas_polynomials
	args N interaction

	* call this function in the common_functions.do to generate the globals 
	generate_coef_polynomials 

	local gcount 0
	foreach risk in lr hl {
		forval i = 1/`N' {
		 	local gcount = `gcount' + 1
		 	global gamma`gcount' ${b_temp_`i'_`risk'}
		 	* if interacted, add the interaction terms
		}
	 	if "`interaction'" == "interacted" {
	 		forval i = 1/`N' {
				local gcount = `gcount' + 1
				global gamma`gcount' ${b_temp_lrtmax_`i'_`risk'}
 			}
 			forval i = 1/`N' {
				local gcount = `gcount' + 1
	 			global gamma`gcount' ${b_temp_gdp_`i'_`risk'}
 			}
		}
	}
 	* Get rid of the plus signs, and stata _b[] so we can evaluate when we want later!
	forval i = 1/`gcount'{
		global gamma`i' = subinstr("${gamma`i'}","+"," ",.)
		global gamma`i' = subinstr("${gamma`i'}","_b[","",.)
		global gamma`i' = subinstr("${gamma`i'}","]","",.)
	}

	global N_gamma = `gcount'
end
* for testing
* generate_gammas_polynomials 2 interacted

* write csvv header 
cap drop program write_csvv_header_splines
program define write_csvv_header_splines
	args N interaction knots_loc ster_path

	local N_clim_terms = `N' - 1
	if "`interaction'" == "interacted" {
		local N_clim_terms  = `N_clim_terms' * 3
		local interaction_string "(lrtmax and income interaction)"
	}

	file write csvv "---" _n
	file write csvv "oneline: Labor `interaction' regression `interaction_string' with a restricted cubic spline term (3 knots), located at `knots_loc'" _n
	file write csvv "version: LABOR-RCSPLINE-`N'KNOTS-`interaction'-Knots-`knots_loc'" _n
	file write csvv "dependencies: `ster_path'" _n
	file write csvv "description: Generated with csvv_writer_timeuse.do, from labor `interaction' regression with restricted cubic spline, `N' knots. The first `N_clim_terms' gammas are for the low-risk sector. The next `N_clim_terms' for the high-risk sector." _n
	file write csvv "csvv-version: girdin-2017-01-10" _n

	file write csvv "variables:" _n
	file write csvv "  tasmax: daily maximum temperature [C]" _n
	file write csvv "  tasmax_rcspline1: restricted cubic spline term of daily max temperature [C^3]" _n
	
	if "`interaction'" == "interacted" {
		file write csvv "  climtasmax: long run average daily maximum temperature [C]" _n
		file write csvv "  loggdppc: log of gdp per capita [log USD2000]" _n		
	}
	file write csvv "  outcome: labor productivity [minutes worked by individual]" _n
	file write csvv "..." _n
	file write csvv "observations"_n
	file write csvv "$nobs" _n

end

* for testing:
* write_csvv_header_spline 3 uninteracted 27_37_39 "${ster_filename}"

* write csvv header 
cap drop program write_csvv_header_polynomials
program define write_csvv_header_polynomials
	args N interaction ster_path
	
	local N_clim_terms = `N'
	if "`interaction'" == "interacted" {
		local N_clim_terms  = `N_clim_terms' * 3
		local interaction_string "(lrtmax and income interaction)"
	}
	file write csvv "---" _n
	file write csvv "oneline: Labor `interaction' regression `interaction_string' with a `N'-th order polynomial" _n
	file write csvv "version: LABOR-POLY`N'-`interaction'" _n
	file write csvv "dependencies: `ster_path'" _n
	file write csvv "description: Generated with csvv_writer_timeuse.do, from labor `interaction' regression with `N'-th order polynomial. The first `N_clim_terms' gammas are for the low-risk sector. The next `N_clim_terms' for the high-risk sector." _n
	file write csvv "csvv-version: girdin-2017-01-10" _n
	file write csvv "variables:" _n
	file write csvv "  tasmax: order 1 daily maximum temperature [C]" _n

	forval i = 2/`N' {
		file write csvv "  tasmax`i': order `i' daily maximum temperature [C^`i']" _n
	}
	if "`interaction'" == "interacted" {
		file write csvv "  climtasmax: long run average daily maximum temperature [C]" _n
		file write csvv "  loggdppc: log of gdp per capita " _n
	}
	file write csvv "  outcome: labor productivity [minutes worked by individual]" _n
	file write csvv "..." _n
	file write csvv "observations"_n
	file write csvv "$nobs" _n

end



cap program drop write_csvv_prednames_covarnames
program define write_csvv_prednames_covarnames
	* functional form = polynomials/spline, N (order of polynomial or number of knots)
	args FUN N interaction

	* tasmax is always the first predname
	local prednames_base tasmax 

	* construct the list of prednames that are repeated 2 times for uninteracted regressions (low, high)
	* and 6 times for interacted regressions (low/high x uninteracted/gdp interaction/climate interaction)
	if "`FUN'" == "polynomials" {
		forval i = 2/`N' {
			local prednames_base `prednames_base', tasmax`i'
		}
		local N_clim_terms = `N'		
	} 
	else if "`FUN'" == "splines" {
		local N_new_terms = `N' - 2
		forval i = 1/`N_new_terms' {
			local prednames_base `prednames_base', tasmax_rcspline`i'
		}	
		local N_clim_terms = `N' - 1
	} 
	else di "unknown functional form"

	file write csvv "prednames" _n
	file write csvv "`prednames_base', `prednames_base'"
	
	* construct a list of covarnames_base, which is "1" for uninteracted, 
	* and "1 climtasmax loggdppc" for interacted
	local covarnames_base 1
	if "`interaction'" ==  "interacted" {
		* if regression is interacted, repeat prednames_base for 4 more times
		forval i = 1/4 {
			file write csvv ", `prednames_base'" 
		}
		local covarnames_base 1 climtasmax loggdppc
	}
	file write csvv _n
	file write csvv "covarnames" _n
	
	* construct the string of the covarnames, which is a repetition of covarnames_base
	
	foreach risk in lowrisk highrisk {
		foreach covar in `covarnames_base' {
			forval i = 1/`N_clim_terms' {
				local covarnames_supplement "`covarnames_supplement' `covar'," 
			}
		}
	}
	* remove the last comma and the space in front
	local covarnames_supplement = substr("`covarnames_supplement'", 2, length("`covarnames_supplement'") - 2)
	file write csvv "`covarnames_supplement'" _n

end


* calculate coefficient for each gamma and write to csvv
* sum coefficients for lags
cap program drop write_csvv_gammas
program define write_csvv_gammas
	args N_gamma

	file write csvv "gamma" _n

	forval i = 1/`N_gamma'{
		local b = 0
		foreach v of global gamma`i' {
			local b = `b'+ _b[`v'] 
		}
		if `i' == `N_gamma' {
			file write csvv "`b'"
		}
		else {
			file write csvv "`b',"
		}
	}
	file write csvv  _n
	end


* calculate and write vcv matrix
* sum covariance for all variables in the varlist
cap program drop write_csvv_vcv
program define write_csvv_vcv
	args N_gamma

	file write csvv "gammavcv" _n

	* get the covariance matrix V
	matrix V = get(VCE)

	forval i = 1/`N_gamma'{
		forval j = 1/`N_gamma'{

			local cov = 0
			foreach iv of global gamma`i' {
				foreach jv of global gamma`j' {

				local col = colnumb(V,"`iv'")
				local row = colnumb(V,"`jv'")

				local cov=`cov'+V[`col',`row']

				}
			}

			if `j' == `N_gamma' {
				file write csvv "`cov'"
			}
			else {
				file write csvv "`cov',"
			}
		}
		file write csvv _n
	}

	file write csvv "residvcv" _n
	file write csvv "$residvcv" 

end

* calculate residvcv
cap program drop calculate_nobs_residvcv
program define calculate_nobs_residvcv
	
	global nobs = e(N)
	global residvcv=(e(rmse)^2)

end

* assemble
cap program drop write_csvv
program define write_csvv

	di "LOADING ESTIMATES: "
	local ster_path  "${ster_dir}/${ster_folder}/${ster_filename}"
	di "`ster_path'"
	estimates use "`ster_path'"

	calculate_nobs_residvcv

	local csvv_path  "${csvv_dir}/${ster_folder}_${weight}_old.csvv"
	local csvv `csvv_path'

	* cd "$csvv_dir" 
	file open csvv using "`csvv'", write replace

	di "writing header"
	if "${fun_form}" == "polynomials" {
		generate_gammas_polynomials ${N} ${interaction}
		write_csvv_header_polynomials ${N} "${interaction}" "`ster_path'"
	}
	else if "${fun_form}" == "splines" {
		generate_gammas_splines ${N} "${spline_varname}" "${interaction}"
		write_csvv_header_splines ${N} "${interaction}" "${knots_loc}" "`ster_path'"
	}

	di "writing prednames and covarnames"

	write_csvv_prednames_covarnames "${fun_form}" ${N} "${interaction}"
	
	di "writing gammas"
	write_csvv_gammas ${N_gamma}

	di "writing vcv"
	write_csvv_vcv ${N_gamma}

	di "closing file"
	file close csvv
	di "csv written at: `csvv_path'"

end

* note that interacted polynomials is run with adm2 weights right now, so need to manually change filename
write_csvv


