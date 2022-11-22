* Labor csvv writer
* Ruixue Li
* updated by: Nishka Sharma
* created: Sep 2019
* updated: Nov 2022

* set some parameters
cap program drop init
program define init 
	clear all
	macro drop _all
	set more off
	cap log close
	cilpath

end

quietly init 


* generate varlists for the gammas
cap program drop generate_coefs
program define generate_coefs
	args have_fe
	if "`have_fe'" == "have_fe"{
		global gamma_list "_cons log_inc tavg_1_pop_ma_30yr tavg_2_pop_ma_30yr tavg_3_pop_ma_30yr tavg_4_pop_ma_30yr 2bn.continent_code 3bn.continent_code 4bn.continent_code"
	}
	else{
		global gamma_list "_cons log_inc tavg_1_pop_ma_30yr tavg_2_pop_ma_30yr tavg_3_pop_ma_30yr tavg_4_pop_ma_30yr"
	}
end



* write csvv header 
cap drop program write_csvv_header
program define write_csvv_header
	args have_fe

	file write csvv "---" _n

	if "`have_fe'" == "have_fe"{
		file write csvv "oneline: Employment share regression for labor sector, with continent fixed effects" _n
		file write csvv "version: empshareFE_2019_10" _n
		file write csvv "dependencies: LogIncPoly4ContinentFEs.ster" _n
		file write csvv "description: Generated with labor_empshares_csvv_writer.do, from employment share regression without continent fixed effects, for the labor sector. " _n

	}
	else{
		file write csvv "oneline: Employment share regression for labor sector, without continent fixed effects" _n
		file write csvv "version: empshare_2019_10" _n
		file write csvv "dependencies: LogIncPoly4.ster" _n
		file write csvv "description: Generated with labor_empshares_csvv_writer.do, from employment share regression without continent fixed effects, for the labor sector. " _n

	}


	file write csvv "csvv-version: girdin-2017-01-10" _n

	file write csvv "variables:" _n
	file write csvv "  loggdppc: 15-year moving average of log GDP per capita [log USD2000]" _n
	file write csvv "  climmeantas: poly 1 daily mean temperature, population weighted to aggregate to IR level, then averaged for 15 years [C]" _n
	file write csvv "  climmeantas-poly-2: poly 2 daily mean temperature, population weighted to aggregate to IR level, then averaged for 15 years [C^2]" _n
	file write csvv "  climmeantas-poly-3: poly 3 daily mean temperature, population weighted to aggregate to IR level, then averaged for 15 years [C^3]" _n
	file write csvv "  climmeantas-poly-4: poly 4 daily mean temperature, population weighted to aggregate to IR level, then averaged for 15 years [C^4]" _n
	file write csvv "  outcome: share of high-risk labor [NA]" _n

	if "`have_fe'" == "have_fe"{
		file write csvv "  hierid-america: dummy variable for north and south America [NA]" _n
		file write csvv "  hierid-asia: dummy variable for Asia and Oceania [NA]" _n
		file write csvv "  hierid-europe: dummy variable for Europe [NA]" _n

	}

	file write csvv "..." _n
	file write csvv "observations"_n
	file write csvv "$nobs" _n

end

* write covarnames
cap drop program write_csvv_prednames_covarnames
program define write_csvv_prednames_covarnames
	args have_fe

	if "`have_fe'" == "have_fe"{
		di "1"
		estimates use "/home/`c(username)'/repos/labor-code-release-2020/output/employment_shares/ster/log_inc_poly4_continent_fes.ster"

	}
	else {
		di "2"
		estimates use "/home/`c(username)'/repos/labor-code-release-2020/output/employment_shares/ster/log_inc_poly4.ster"
	}

	file write csvv "prednames" _n
	file write csvv "1, 1, 1, 1, 1, 1" 

	if "`have_fe'" == "have_fe"{
		file write csvv ", 1, 1, 1"
	}
	file write csvv _n

	file write csvv "covarnames" _n
	file write csvv "1, loggdppc,climmeantas,climmeantas-poly-2,climmeantas-poly-3,climmeantas-poly-4" 

	if "`have_fe'" == "have_fe"{
		file write csvv ",hierid-america,hierid-asia,hierid-europe"
	}
	file write csvv _n

end


* calculate coefficient for each gamma and write to csvv
* sum coefficients for lags
cap drop program write_csvv_gammas
program define write_csvv_gammas

	args have_fe

	file write csvv "gamma" _n

	local pi = $p - 1
	forval i = 1/`pi' {
		local v: word `i' of $gamma_list
		local b = _b[`v']
		file write csvv "`b',"
	}

	if "`have_fe'" == "have_fe"{
		local b = _b[4bn.continent_code]
	}
	else{
		local b = _b[tavg_4_pop_ma_30yr]
	}


	file write csvv "`b'" _n


end


* calculate and write vcv matrix
* sum covariance for all variables in the varlist
cap drop program write_csvv_vcv
program define write_csvv_vcv
	args have_fe

	file write csvv "gammavcv" _n

	* get the covariance matrix V
	matrix V = get(VCE)
	matrix list V

	forval i = 1/$p{
		local iv: word `i' of $gamma_list

		loc col_i = colnumb(V, "`iv'")

		forval j = 1/$p{
			local jv: word `j' of $gamma_list
			loc row_j = rownumb(V, "`jv'")
			local value = V[`col_i',`row_j']
			if `j' == $p {
				file write csvv "`value'" _n
			}
			else {
				file write csvv "`value',"
			}


		}
	}

	file write csvv "residvcv" _n
	file write csvv "$residvcv" 

end


* calculate residvcv
cap drop program calculate_nobs_residvcv
program define calculate_nobs_residvcv
	args have_fe
	di "`have_fe'"

	if "`have_fe'" == "have_fe"{
		di "1"
		estimates use "/home/`c(username)'/repos/labor-code-release-2020/output/employment_shares/ster/log_inc_poly4_continent_fes.ster"

	}
	else{
		di "2"
		estimates use "/home/`c(username)'/repos/labor-code-release-2020/output/employment_shares/ster/log_inc_poly4.ster"
	}	
	global nobs = e(N)

	global p = e(rank) + e(df_a)
	global residvcv = e(N) * (e(rmse)^2) / (e(N) - $p)

end


* assemble
cap drop program write_csvv
program define write_csvv
	* have_fe/no_fe
	args have_fe 

	calculate_nobs_residvcv `have_fe'

	generate_coefs `have_fe'

	if "`have_fe'" == "have_fe"{
		local csvv_filename "labor_empshare_continentFE.csvv"	
	}
	else {
		local csvv_filename "labor_empshare_noFE.csvv"	

	}

	local csvv_path "/home/`c(username)'/repos/labor-code-release-2020/3_projection/1_run_projections/single_test_correct_rebasing"
	local csvv "`csvv_path'/`csvv_filename'"

	cd `csvv_path'
	file open csvv using "`csvv'", write replace
	write_csvv_header `have_fe'
	write_csvv_prednames_covarnames `have_fe'
	write_csvv_gammas `have_fe'
	write_csvv_vcv `have_fe'

	file close csvv

end


* write_csvv have_fe
write_csvv no_fe