****************************************
* EXPLORATION OF CROSSVAL RESULTS
* Kit, csschwarz@uchicago.edu
* Date: 2020.08.11
****************************************


gl dir = "/shares/gcp/estimation/labor/regression_results/estimates/crossval"
gl unint = "$dir/uninteracted_splines_by_risk/splines_27_37_39_tmax_chn_prev_week/fe_week_adm0_3_knots_this_week_no_chn_risk_adj_sample_wgt.dta"
* gl unint = "$dir/uninteracted_splines_by_risk/splines_27_37_39_tmax_chn_prev_week/fe_week_adm0_3_knots_this_week_no_chn_rep_unit_year_sample_wgt.dta"
gl int = "$dir/interacted_splines_by_risk/splines_27_37_39_tmax_chn_prev_week/fe_week_adm0_3_knots_this_week_no_chn_rep_unit_year_sample_wgt.dta"

gl unint_weight "unint_risk_adj_sample_wgt"

* open up the saved crossval file -- has residualized vars, yhat, and mins_worked-yhat=diff
use Yhat mins_worked_rsd diff using $int, clear
rename * int_*
merge 1:1 _n using $unint, keepus(iso real_temp Yhat mins_worked_rsd diff high_risk) nogen

* get squared errors
gen diffsq = diff^2
gen int_diffsq = int_diff^2

*******************
*	HISTOGRAMS
*******************

* cap prog drop plot_hist
* prog def plot_hist
* 	syntax varlist [if/] [, bin(integer 50) high(string) low(string)] [using/]

* 	preserve
* 	if "`if'" != "" keep if `if'

* 	sum `varlist', det
* 	loc phigh = `r(`high')'
* 	loc plow = `r(`low')'

* 	sum int_`varlist', det
* 	loc int_phigh = `r(`high')'
* 	loc int_plow = `r(`low')'

* 	loc width = round((`phigh'-`plow')/`bin') + 0.5
* 	loc start = min(`plow', `int_plow')
* 	di "Bin width: `width'"
* 	di "Unint cutoffs `phigh' `plow'"
* 	di "Int cutoffs `int_phigh' `int_plow'"

* 	tw (hist `varlist' if `varlist' <= `phigh' & `varlist' >= `plow', width(`width') start(`start') color(ebblue%40) percent)		///        
* 	   (hist int_`varlist' if int_`varlist' <= `int_phigh' & int_`varlist' >= `int_plow', width(`width') start(`start') color(cranberry%30) percent), 	///
* 	   title("`varlist', `high'/`low' cutoffs") graphregion(color(white))	///
* 	   legend(order(1 "Uninteracted" 2 "Interacted" ))

* 	gr export "$dir/analysis/$unint_weight/`if'/hist_`varlist'_`high'`low'cutoff`if'.pdf", replace
* 	restore

* end

* plot_hist Yhat if high_risk==0, bin(50) high(p95) low(p5)
* plot_hist Yhat if high_risk==0, bin(50) high(max) low(min)
* plot_hist diffsq if high_risk==0, bin(50) high(p95) low(p5)
* plot_hist diffsq if high_risk==0, bin(50) high(max) low(min)
* plot_hist diff if high_risk==0, bin(50) high(p95) low(p5)
* plot_hist diff if high_risk==0, bin(50) high(max) low(min)

* plot_hist Yhat if high_risk==1, bin(50) high(p95) low(p5)
* plot_hist Yhat if high_risk==1, bin(50) high(max) low(min)
* plot_hist diffsq if high_risk==1, bin(50) high(p95) low(p5)
* plot_hist diffsq if high_risk==1, bin(50) high(max) low(min)
* plot_hist diff if high_risk==1, bin(50) high(p95) low(p5)
* plot_hist diff if high_risk==1, bin(50) high(max) low(min)

* plot_hist Yhat, bin(50) high(p95) low(p5)
* plot_hist Yhat, bin(50) high(max) low(min)
* plot_hist diffsq, bin(50) high(p95) low(p5)
* plot_hist diffsq, bin(50) high(max) low(min)
* plot_hist diff, bin(50) high(p95) low(p5)
* plot_hist diff, bin(50) high(max) low(min)


****************************
* MEAN SQ ERRORS BY QUANTILE
****************************

* gquantiles quant = diffsq, xtile nq(4)
* gquantiles int_quant = int_diffsq, xtile nq(4)

* cap drop prog mse_quant
* prog def mse_quant

* 	syntax [if/]

* 	if "`if'" != "" loc iff = "& `if'"
* 	else loc iff = ""

* 	file open resultcsv using "$dir/analysis/$unint_weight/`if'/mean_sq_errors_by_quantile`if'.csv", write replace
* 	file write resultcsv "quantile, MSE (unint), MSE (int)" _n
* 	forval quant=1(1)4 {
* 		sum diffsq if quant == `quant' `iff'
* 		loc mse = `r(mean)'
* 		sum int_diffsq if int_quant == `quant' `iff'
* 		loc int_mse = `r(mean)'
* 		file write resultcsv "`quant',`mse', `int_mse'" _n
* 	}
			
* 	file close resultcsv

* end

* mse_quant
* mse_quant if high_risk==1
* mse_quant if high_risk==0

****************
* RMSE BY ISO
****************

cap drop prog rmse_by_iso
prog def rmse_by_iso

	syntax [if/]

	if "`if'" != "" loc iff = "& `if'"
	else loc iff = ""

	file open resultcsv using "$dir/analysis/$unint_weight/`if'/rmse_by_iso`if'.csv", write replace
	file write resultcsv "ISO,RMSE (unint), RMSE (int)" _n
	glevelsof iso, local(isos)
	foreach iso in `isos' {
		sum diffsq if iso == "`iso'" `iff'
		loc mse = `r(mean)'
		loc `iso'_rmse = sqrt(`mse')
		sum int_diffsq if iso == "`iso'" `iff'
		loc int_mse = `r(mean)'
		loc int_`iso'_rmse = sqrt(`int_mse')
		file write resultcsv "`iso',``iso'_rmse', `int_`iso'_rmse'" _n
	}

		sum diffsq if iso !="BRA" & iso!="MEX" `iff'
		loc mse = `r(mean)'
		loc rmse = sqrt(`mse')
		sum int_diffsq if iso !="BRA" & iso!="MEX" `iff'
		loc int_mse = `r(mean)'
		loc int_rmse = sqrt(`int_mse')
		file write resultcsv "drop_BRA_MEX,`rmse', `int_rmse'" _n

		sum diffsq if iso!="" `iff'
		loc mse = `r(mean)'
		loc rmse = sqrt(`mse')
		sum int_diffsq if iso!="" `iff'
		loc int_mse = `r(mean)'
		loc int_rmse = sqrt(`int_mse')
		file write resultcsv "all_ISOs,`rmse', `int_rmse'" _n
			
	file close resultcsv

end

rmse_by_iso if high_risk==0
rmse_by_iso if high_risk==1
rmse_by_iso


**********************
*	TEMP DISTRIBUTION
**********************

* cap prog drop plot_temp_dist
* prog def plot_temp_dist
* 	syntax varlist [if/] [, title(string)] 

* 	preserve
* 	if "`if'" != "" keep if `if'
* 	gen round_temp = round(real_temp)
* 	gcollapse (mean) `varlist' int_`varlist', by(round_temp)

* 	tw (bar `varlist' round_temp , color(ebblue%40))			///
* 		(bar int_`varlist' round_temp, color(cranberry%30)),	///
* 	   	title("`title'")										///
* 	   	legend(order(1 "Uninteracted" 2 "Interacted" ))

* 	gr export "$dir/analysis/$unint_weight/`if'/temp_dist_`varlist'`if'.pdf", replace
* 	restore

* end

* plot_temp_dist diff, title("Average error by temp bin")
* plot_temp_dist diffsq, title("Average squared error by temp bin")
* plot_temp_dist Yhat, title("Average Yhat by temp bin")

* plot_temp_dist diff if high_risk==0, title("Average error by temp bin - LOW RISK")
* plot_temp_dist diff if high_risk==1, title("Average error by temp bin - HIGH RISK")

* plot_temp_dist diffsq if high_risk==0, title("Average sq error by temp bin - LOW RISK")
* plot_temp_dist diffsq if high_risk==1, title("Average sq error by temp bin - HIGH RISK")

* plot_temp_dist Yhat if high_risk==0, title("Average Yhat by temp bin - LOW RISK")
* plot_temp_dist Yhat if high_risk==1, title("Average Yhat by temp bin - HIGH RISK")


* **********************
* *	SINGLE TEMP DISTRIBUTION
* **********************

* cap prog drop plot_one_temp_dist
* prog def plot_one_temp_dist
* 	syntax varlist [if/] [, title(string)] 

* 	preserve
* 	if "`if'" != "" keep if `if'
* 	gen round_temp = round(real_temp)
* 	gcollapse (mean) `varlist' int_`varlist', by(round_temp)

* 	tw (bar `varlist' round_temp , color(ebblue%40)),				///
* 	   	title("`title'")										///
* 	   	legend(order(1 "Uninteracted" 2 "Interacted" ))

* 	gr export "$dir/analysis/$unint_weight/`if'/temp_dist_`varlist'`if'.pdf", replace
* 	restore

* end

* plot_one_temp_dist mins_worked_rsd, title("Average mins worked by temp bin")
* plot_one_temp_dist mins_worked_rsd if high_risk==0, title("Average mins worked by temp bin - LOW RISK")
* plot_one_temp_dist mins_worked_rsd if high_risk==1, title("Average mins worked by temp bin - HIGH RISK")


		
