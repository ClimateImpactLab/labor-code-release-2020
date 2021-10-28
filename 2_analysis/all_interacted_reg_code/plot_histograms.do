************
* SET UP
************

* get paths
run "/home/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"

***********************************
* PROGRAM: PLOT HISTOGRAMS & COUNTS
***********************************

cap program drop plot_histograms
program define plot_histograms
	
	args tercile_unit weight interaction

	if "`interaction'" == "interacted" | "`interaction'" == "triple_int" gl collapser = "clim_t inc_t"
	else if "`interaction'" == "income" gl collapser = "inc_t"

	di " COLLAPSER $collapser"

	** PATHS
	local datapath = "/mnt/CIL_labor/2_regression/time_use/input"

	** PULL IN TERCILE CUTOFF DATA
	if "`tercile_unit'" == "hierid" {
		use "`datapath'/loggdppc_2010_grid.dta", clear
		merge 1:1 group using "`datapath'/lrtmax_tercile_cutoff.dta", nogen
	}
	else if "`tercile_unit'" == "rep_unit" {
		use "${ROOT_INT_DATA}/xtiles/rep_unit_terciles_grid.dta", clear
	}
	di "GETTING TERCILE MAX CUTOFFS..."
	
	* ignore the 'min' 'p50' 'max', it's just a way to get 1 of 3 values

	foreach x in loggdppc lrtmax {
		sum max_`x', det
		global `x'1 = `r(min)'
		global `x'2 = `r(p50)'
		global `x'3 = `r(max)'
	}

	** PULL IN THE ACTUAL DATASET
	use "${ROOT_INT_DATA}/regression_ready_data/labor_dataset_splines_nochn_tmax_chn_prev_week_no_ll_0.dta", clear
	di "ASSIGNING TO TERCILES..."
	
	gen clim_tercile = 3 if lr_tmax_p1 <= $lrtmax3
	replace clim_t = 2 if lr_tmax_p1 <= $lrtmax2
	replace clim_t = 1 if lr_tmax_p1 <= $lrtmax1

	gen inc_tercile = 3 if log_gdp_pc_adm1 <= $loggdppc3
	replace inc_t = 2 if log_gdp_pc_adm1 <= $loggdppc2
	replace inc_t = 1 if log_gdp_pc_adm1 <= $loggdppc1

	bysort clim_t inc_t: tab iso

	if "`weight'" == "no_wgt" loc weighting = ""
	else loc weighting = "[aweight=`weight']"
	if "`weight'" == "no_wgt" loc range = "0 50000"
	else loc range = "0 1.5"

	******************************** PLOT HISTOGRAMS ***********************************

	preserve

	sum real_temperature `weighting', det
	local min = `r(min)'
	loc max_realised = ceil(r(max))
	loc min_realised = floor(r(min))
	loc center = round(r(p50), 0.1)
	gen bin = .
	forvalues temp = `min_realised'(0.1)`max_realised' {
		qui replace bin = round(`temp', 0.1) if(real_temperature >= `temp')
	}

	di "collapsing to bins"
	gen no_wgt = 1

	gen `weight'_high = `weight' if high_risk == 1
	gen `weight'_low = `weight' if high_risk == 0

	gcollapse (sum) `weight' `weight'_high `weight'_low, by(bin $collapser)

	* because twoway bar does not take percent. If you can think of a better
	* solution later, change this!!!
	gegen tot_high = total(`weight'_high),by($collapser)
	gegen tot_low = total(`weight'_low),by($collapser)
	gegen tot = total(`weight'),by($collapser)
	gen `weight'_hp = `weight'_high/tot_high * 100
	gen `weight'_lp = `weight'_low/tot_low * 100
	gen `weight'_p = `weight'/tot * 100

	gen temp = bin + (0.1 / 2)
	replace temp = round(temp, 0.1 / 10)

	if "`interaction'" == "interacted" | "`interaction'" == "triple_int" {

		local i = 1
		forvalues inc=1(1)3 {
			forvalues clim=1(1)3 {

			di "PLOTTING HIST FOR TERCILE `clim' X `inc'..."
			di "HOPE YOU DON'T SEE THIS"
			
			local opts `"barw(0.1) aspectratio(0.1) ylab(#4,labs(vsmall) angle(vertical)) xtitle("") graphregion(color(white) margin(zero)) fysize(10) xlab(,labs(small))"'

			tw bar `weight'_high temp if clim_t == `clim' & inc_t == `inc', `opts' ysc(range(`range')) ytitle("Obs", size(small)) name(hist`i'_hl_abs, replace) 
			tw bar `weight'_low temp if clim_t == `clim' & inc_t == `inc', `opts' ysc(range(`range')) ytitle("Obs", size(small)) name(hist`i'_lr_abs, replace) 
			tw bar `weight' temp if clim_t == `clim' & inc_t == `inc', `opts' ysc(range(`range')) ytitle("Obs", size(small)) name(hist`i'_hr_abs, replace)

			tw bar `weight'_hp temp if clim_t == `clim' & inc_t == `inc', `opts' ysc(range(0 5)) ytitle("%", size(small)) name(hist`i'_hl_pct, replace) 
			tw bar `weight'_lp temp if clim_t == `clim' & inc_t == `inc', `opts' ysc(range(0 5)) ytitle("%", size(small)) name(hist`i'_lr_pct, replace) 
			tw bar `weight'_p temp if clim_t == `clim' & inc_t == `inc', `opts' ysc(range(0 5)) ytitle("%", size(small)) name(hist`i'_hr_pct, replace)  

			foreach h in hr lr hl {
				cap mkdir "${DIR_OUTPUT}/interacted_reg_output/plots/histograms/`interaction'"
				graph save hist`i'_`h'_abs "${DIR_OUTPUT}/interacted_reg_output/plots/histograms/`interaction'/hist`i'_`h'_abs.gph", replace
				graph save hist`i'_`h'_pct "${DIR_OUTPUT}/interacted_reg_output/plots/histograms/`interaction'/hist`i'_`h'_pct.gph", replace
			}

			local ++i

			}
		}

	}

	else if "`interaction'" == "income" {
		local i = 1
		forvalues inc=1(1)3 {

			di "PLOTTING HIST FOR TERCILE `inc'..."

			local opts `"barw(0.1) ylab(#5,labs(vsmall) angle(vertical)) xtitle("") graphregion(color(white) margin(zero)) fysize(40) xlab(,labs(small))"'

			tw bar `weight'_high temp if inc_t == `inc', `opts' ysc(range(`range')) ytitle("Obs", size(small)) name(hist`i'_hl_abs, replace) 
			tw bar `weight'_low temp if inc_t == `inc', `opts' ysc(range(`range')) ytitle("Obs", size(small)) name(hist`i'_lr_abs, replace) 
			tw bar `weight' temp if inc_t == `inc', `opts' ysc(range(`range')) ytitle("Obs", size(small)) name(hist`i'_hr_abs, replace)

			tw bar `weight'_hp temp if inc_t == `inc', `opts' ysc(range(0 5)) ytitle("%", size(small)) name(hist`i'_hl_pct, replace) 
			tw bar `weight'_lp temp if inc_t == `inc', `opts' ysc(range(0 5)) ytitle("%", size(small)) name(hist`i'_lr_pct, replace) 
			tw bar `weight'_p temp if inc_t == `inc', `opts' ysc(range(0 5)) ytitle("%", size(small)) name(hist`i'_hr_pct, replace)  

			foreach h in hr lr hl {
				cap mkdir "${DIR_OUTPUT}/interacted_reg_output/plots/histograms/`interaction'"
				graph save hist`i'_`h'_abs "${DIR_OUTPUT}/interacted_reg_output/plots/histograms/`interaction'/hist`i'_`h'_abs.gph", replace
				graph save hist`i'_`h'_pct "${DIR_OUTPUT}/interacted_reg_output/plots/histograms/`interaction'/hist`i'_`h'_pct.gph", replace
			}

			local ++i

		}
	}


	******************************** GET CUTOFFS ***********************************

	restore

	di "GETTING PERCENTILE CUTOFFS FOR GRAPHS..."

	if "`interaction'" == "interacted" | "`interaction'" == "triple_int" {

		local i = 1
		forvalues inc=1(1)3 {
			forvalues clim=1(1)3 {
				sum real_temp `weighting' if clim==`clim' & inc==`inc' & high_risk == 1, det
				gl p1`i'_hl_`weight' = `r(p1)'
				gl p5`i'_hl_`weight' = `r(p5)'
				gl p95`i'_hl_`weight' = `r(p95)'
				gl p99`i'_hl_`weight' = `r(p99)'

				sum real_temp `weighting' if clim==`clim' & inc==`inc' & high_risk == 0, det
				gl p1`i'_lr_`weight' = `r(p1)'
				gl p5`i'_lr_`weight' = `r(p5)'
				gl p95`i'_lr_`weight' = `r(p95)'
				gl p99`i'_lr_`weight' = `r(p99)'

				sum real_temp `weighting' if clim==`clim' & inc==`inc', det
				gl p1`i'_hr_`weight' = `r(p1)'
				gl p5`i'_hr_`weight' = `r(p5)'
				gl p95`i'_hr_`weight' = `r(p95)'
				gl p99`i'_hr_`weight' = `r(p99)'

				local ++i
			}
		}
	}

	else if "`interaction'" == "income" {

		local i = 1
		forvalues inc=1(1)3 {
				sum real_temp `weighting' if  inc==`inc' & high_risk == 1, det
				gl p1`i'_hl_`weight' = `r(p1)'
				gl p5`i'_hl_`weight' = `r(p5)'
				gl p95`i'_hl_`weight' = `r(p95)'
				gl p99`i'_hl_`weight' = `r(p99)'

				sum real_temp `weighting' if inc==`inc' & high_risk == 0, det
				gl p1`i'_lr_`weight' = `r(p1)'
				gl p5`i'_lr_`weight' = `r(p5)'
				gl p95`i'_lr_`weight' = `r(p95)'
				gl p99`i'_lr_`weight' = `r(p99)'

				sum real_temp `weighting' if  inc==`inc', det
				gl p1`i'_hr_`weight' = `r(p1)'
				gl p5`i'_hr_`weight' = `r(p5)'
				gl p95`i'_hr_`weight' = `r(p95)'
				gl p99`i'_hr_`weight' = `r(p99)'

				local ++i
		}

	}

	******************************** GET COUNTS ***********************************


	di "STARTING COUNTS..."
	gen count_lr = 1 if high_risk == 0
	gen count_hr = 1 if high_risk == 1
	gegen count_rep_unit = tag(rep_unit)
	gegen count_rep_year = tag(rep_unit year)
	gcollapse (sum) count_lr count_hr count_rep_year count_rep_unit, by($collapser)
	save "${ROOT_INT_DATA}/xtiles/`tercile_unit'_terciles_count.dta", replace
	di "COUNTS COMPLETE."


end


