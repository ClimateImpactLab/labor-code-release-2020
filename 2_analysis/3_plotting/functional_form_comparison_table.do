*****************
*	INITIALIZE
*****************

* get functions and paths
run "/home/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"
run "${DIR_REPO_LABOR}/2_analysis/0_subroutines/functions.do"

* reg list 
gl reg_list  nochn wchn

*****************
*	GET RMSE
*****************

foreach reg in $reg_list {

	foreach risk in  high low {
		
		* read in the functional form response functions
		import delim "${DIR_RF}/functional_form_comparison_`reg'.csv", clear
		keep if risk == "`risk'"

		* get the names of the functional forms
		ds temp risk, not
		loc form_list "`r(varlist)'"

		* save
		tempfile forms
		save `forms'

		* read in the temperature distribution by risk weight
		import delim "${DIR_OUTPUT}/temp_dist/`reg'_temp_dist.csv", clear
		merge 1:1 temp using `forms'

		* CHECK
		count if _merge == 1
		if `r(N)' > 0 {
			di in red "You have a problem! The temperature distribution does not match up."
			break
		}
		else {
			drop _merge
		}

		* categorize temperature into 3C bins
		egen temp_bin = cut(temp), at(0(3)50)

		* we put all <0 observations into the 0-3C bin 
		* this is just a choice we made
		replace temp_bin = 0 if temp < 0

		* collapse relevant variables by bin
		ds *wgt_`risk'
		gcollapse (sum) `r(varlist)' (mean) `form_list' (first) bin_check=bins, by(temp_bin)

		* CHECK
		count if bins != bin_check
		if `r(N)' > 0 {
			di in red "Uh oh! Your bin value isn't consistent across the bin..."
			break
		} 
		else {
			drop bin_check
		}

		save `forms', replace

		* read in the 2010/2099 population weights
		* note: need to move get_2099_IR_temp_distributions..R code to the labour code release repo
		import delim "${DIR_OUTPUT}/temp_dist/pop_weighted_daily_binned_temps.csv", clear
		rename bin temp_bin
		merge 1:1 temp_bin using `forms'

		* normalize the by-risk weights
		egen total = total(risk_adj_sample_wgt_`risk')
		gen norm_wgt_`risk' = risk_adj_sample_wgt_`risk'/total

		* get the mean squared error, sum, and sqrt
		foreach form in `form_list' {
			gen mse_no_wgt_`form'		= (bins - `form')^2
			gen mse_risk_wgt_`form' 	= mse_no_wgt_`form' * norm_wgt_`risk'
			gen mse_99_wgt_`form' 		= mse_no_wgt_`form' * pop_95_times_temp_99
			gen mse_10_wgt_`form' 		= mse_no_wgt_`form' * pop_10_times_temp_10			
			gen mse_05_10_wgt_`form' 	= mse_no_wgt_`form' * pop_10_times_temp_05
		}

		* sum the weighted squared errors (but get the plain mean for the no-wgt RMSE)
		gcollapse (sum) mse_risk* mse_99* mse_10* mse_05* (mean) mse_no_wgt*

		* get the square root
		foreach form in `form_list' {
			gen rmse_`form' 			= sqrt(mse_no_wgt_`form')
			gen rmse_risk_wgt_`form' 	= sqrt(mse_risk_wgt_`form')
			gen rmse_99_wgt_`form' 		= sqrt(mse_99_wgt_`form')
			gen rmse_10_wgt_`form' 		= sqrt(mse_10_wgt_`form')			
			gen rmse_05_10_wgt_`form' 	= sqrt(mse_05_10_wgt_`form')
		}

		* reshape into a nice table
		gen n = _n
		keep rmse* n
		reshape long rmse_ rmse_risk_wgt_ rmse_99_wgt_ rmse_10_wgt_ rmse_05_10_wgt_, i(n) j(model) str

		* tidy up
		rename *_ *
		drop n
		drop if model == "bins"

		dataout, save("${DIR_TABLE}/rmse_`risk'_`reg'") noauto tex replace

	}
}
