******************************************************
* plot_histograms (modified to support climate)
******************************************************
cap program drop plot_histograms
program define plot_histograms
	
	args tercile_unit weight interaction
	
	if "`interaction'" == "interacted" | "`interaction'" == "triple_int" {
		global collapser = "clim_t inc_t"
	}
	else if "`interaction'" == "income" {
		global collapser = "inc_t"
	}
	else if "`interaction'" == "climate" {
		global collapser = "clim_t"
	}
	
	di "COLLAPSER $collapser"
	
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
	
	foreach x in loggdppc lrtmax {
		sum max_`x', det
		global `x'1 = `r(min)'
		global `x'2 = `r(p50)'
		global `x'3 = `r(max)'
	}
	
	** PULL IN THE ACTUAL DATASET
	use "/project/cil/battuta_shares/gcp/estimation/labor/code_release_int_data/regression_ready_data/labor_dataset_splines_nochn_tmax_chn_prev_week_no_ll_0_noMEXBRA.dta", clear
	
	di "ASSIGNING TO TERCILES..."
	
	gen clim_t = 3 if lr_tmax_p1 <= $lrtmax3
	replace clim_t = 2 if lr_tmax_p1 <= $lrtmax2
	replace clim_t = 1 if lr_tmax_p1 <= $lrtmax1
	
	gen inc_t = 3 if log_gdp_pc_adm1 <= $loggdppc3
	replace inc_t = 2 if log_gdp_pc_adm1 <= $loggdppc2
	replace inc_t = 1 if log_gdp_pc_adm1 <= $loggdppc1
	
	bysort clim_t inc_t: tab iso
	
	if "`weight'" == "no_wgt" {
		local weighting = ""
	}
	else {
		local weighting = "[aweight=`weight']"
	}
	
	******************************** PLOT HISTOGRAMS ***********************************
	preserve
	
	sum real_temperature `weighting', det
	local min = `r(min)'
	local max_realised = ceil(`r(max)')
	local min_realised = floor(`r(min)')
	local center = round(`r(p50)', 0.1)
	
	global temp_min = -20
	global temp_max = 50
	
	gen bin = floor(real_temperature / 0.1) * 0.1
	
	di "collapsing to bins"
	gen no_wgt = 1
	gen `weight'_high = `weight' if high_risk == 1
	gen `weight'_low = `weight' if high_risk == 0
	
	tempfile all_data
	save `all_data', replace
	
	gcollapse (sum) `weight' `weight'_high `weight'_low, by(bin $collapser)
	
	gegen tot_high = total(`weight'_high), by($collapser)
	gegen tot_low = total(`weight'_low), by($collapser)
	gegen tot = total(`weight'), by($collapser)
	
	gen `weight'_hp = (`weight'_high / tot_high) * 100
	gen `weight'_lp = (`weight'_low / tot_low) * 100
	gen `weight'_p = (`weight' / tot) * 100
	
	sum `weight'_hp, det
	local max_hp = `r(max)'
	sum `weight'_lp, det
	local max_lp = `r(max)'
	sum `weight'_p, det
	local max_p = `r(max)'
	
	local ymax_pct = max(`max_hp', `max_lp', `max_p')
	local ymax_pct = ceil(`ymax_pct' * 2) / 2
	if `ymax_pct' < 2 local ymax_pct = 2
	
	di "Unified Y-axis max for percentages: `ymax_pct'"
	
	if "`weight'" == "no_wgt" {
		sum `weight', det
		local ymax_abs = ceil(`r(max)' * 1.1)
		local range_abs = "0 `ymax_abs'"
	}
	else {
		sum `weight', det
		local ymax_abs = `r(max)'
		local ymax_abs = ceil(`ymax_abs' * 20) / 20
		if `ymax_abs' < 0.1 local ymax_abs = 0.1
		local range_abs = "0 `ymax_abs'"
	}
	
	gen temp = bin
	
	if "`interaction'" == "climate" {
		local i = 1
		forvalues clim=1(1)3 {
			di "=== PLOTTING HIST FOR CLIMATE TERCILE `clim' ==="
			
			count if clim_t == `clim'
			
			if r(N) > 0 {
				local opts_x `"xlab(${temp_min}(10)${temp_max}, labs(small)) xsc(range(${temp_min} ${temp_max})) xtitle("")"'
				
				local opts_abs `"barwidth(0.09) ylab(#4, labs(vsmall) angle(vertical)) graphregion(color(white) margin(zero)) plotregion(margin(zero)) fysize(10) `opts_x'"'
				
				local opts_pct `"barwidth(0.09) ylab(#4, labs(vsmall) angle(vertical)) graphregion(color(white) margin(zero)) plotregion(margin(zero)) fysize(10) `opts_x'"'
				
				tw bar `weight'_high temp if clim_t == `clim', ///
					`opts_abs' ysc(range(`range_abs')) ytitle("Obs", size(small)) ///
					name(hist`i'_hl_abs, replace)
				
				tw bar `weight'_low temp if clim_t == `clim', ///
					`opts_abs' ysc(range(`range_abs')) ytitle("Obs", size(small)) ///
					name(hist`i'_lr_abs, replace)
				
				tw bar `weight' temp if clim_t == `clim', ///
					`opts_abs' ysc(range(`range_abs')) ytitle("Obs", size(small)) ///
					name(hist`i'_hr_abs, replace)
				
				tw bar `weight'_hp temp if clim_t == `clim', ///
					`opts_pct' ysc(range(0 `ymax_pct')) ytitle("%", size(small)) ///
					name(hist`i'_hl_pct, replace)
				
				tw bar `weight'_lp temp if clim_t == `clim', ///
					`opts_pct' ysc(range(0 `ymax_pct')) ytitle("%", size(small)) ///
					name(hist`i'_lr_pct, replace)
				
				tw bar `weight'_p temp if clim_t == `clim', ///
					`opts_pct' ysc(range(0 `ymax_pct')) ytitle("%", size(small)) ///
					name(hist`i'_hr_pct, replace)
				
				foreach h in hr lr hl {
					cap mkdir "${DIR_OUTPUT}/interacted_reg_output/plots/histograms/`interaction'"
					graph save hist`i'_`h'_abs "${DIR_OUTPUT}/interacted_reg_output/plots/histograms/`interaction'/hist`i'_`h'_abs.gph", replace
					graph save hist`i'_`h'_pct "${DIR_OUTPUT}/interacted_reg_output/plots/histograms/`interaction'/hist`i'_`h'_pct.gph", replace
				}
			}
			else {
				di "WARNING: No observations in climate tercile `clim'"
			}
			local ++i
		}
	}
	
	else if "`interaction'" == "interacted" | "`interaction'" == "triple_int" {
		local i = 1
		forvalues inc=1(1)3 {
			forvalues clim=1(1)3 {
				di "=== PLOTTING HIST FOR TERCILE `clim' X `inc' ==="
				
				count if clim_t == `clim' & inc_t == `inc'
				
				if r(N) > 0 {
					local opts_x `"xlab(${temp_min}(10)${temp_max}, labs(small)) xsc(range(${temp_min} ${temp_max})) xtitle("")"'
					
					local opts_abs `"barwidth(0.09) ylab(#4, labs(vsmall) angle(vertical)) graphregion(color(white) margin(zero)) plotregion(margin(zero)) fysize(10) `opts_x'"'
					
					local opts_pct `"barwidth(0.09) ylab(#4, labs(vsmall) angle(vertical)) graphregion(color(white) margin(zero)) plotregion(margin(zero)) fysize(10) `opts_x'"'
					
					tw bar `weight'_high temp if clim_t == `clim' & inc_t == `inc', ///
						`opts_abs' ysc(range(`range_abs')) ytitle("Obs", size(small)) ///
						name(hist`i'_hl_abs, replace)
					
					tw bar `weight'_low temp if clim_t == `clim' & inc_t == `inc', ///
						`opts_abs' ysc(range(`range_abs')) ytitle("Obs", size(small)) ///
						name(hist`i'_lr_abs, replace)
					
					tw bar `weight' temp if clim_t == `clim' & inc_t == `inc', ///
						`opts_abs' ysc(range(`range_abs')) ytitle("Obs", size(small)) ///
						name(hist`i'_hr_abs, replace)
					
					tw bar `weight'_hp temp if clim_t == `clim' & inc_t == `inc', ///
						`opts_pct' ysc(range(0 `ymax_pct')) ytitle("%", size(small)) ///
						name(hist`i'_hl_pct, replace)
					
					tw bar `weight'_lp temp if clim_t == `clim' & inc_t == `inc', ///
						`opts_pct' ysc(range(0 `ymax_pct')) ytitle("%", size(small)) ///
						name(hist`i'_lr_pct, replace)
					
					tw bar `weight'_p temp if clim_t == `clim' & inc_t == `inc', ///
						`opts_pct' ysc(range(0 `ymax_pct')) ytitle("%", size(small)) ///
						name(hist`i'_hr_pct, replace)
					
					foreach h in hr lr hl {
						cap mkdir "${DIR_OUTPUT}/interacted_reg_output/plots/histograms/`interaction'"
						graph save hist`i'_`h'_abs "${DIR_OUTPUT}/interacted_reg_output/plots/histograms/`interaction'/hist`i'_`h'_abs.gph", replace
						graph save hist`i'_`h'_pct "${DIR_OUTPUT}/interacted_reg_output/plots/histograms/`interaction'/hist`i'_`h'_pct.gph", replace
					}
				}
				else {
					di "WARNING: No observations in tercile `clim' x `inc'"
				}
				local ++i
			}
		}
	}
	
	else if "`interaction'" == "income" {
		local i = 1
		forvalues inc=1(1)3 {
			di "=== PLOTTING HIST FOR INCOME TERCILE `inc' ==="
			
			count if inc_t == `inc'
			
			if r(N) > 0 {
				local opts_x `"xlab(${temp_min}(10)${temp_max}, labs(small)) xsc(range(${temp_min} ${temp_max})) xtitle("")"'
				
				local opts_abs `"barwidth(0.09) ylab(#5, labs(vsmall) angle(vertical)) graphregion(color(white) margin(zero)) plotregion(margin(zero)) fysize(40) `opts_x'"'
				
				local opts_pct `"barwidth(0.09) ylab(#5, labs(vsmall) angle(vertical)) graphregion(color(white) margin(zero)) plotregion(margin(zero)) fysize(40) `opts_x'"'
				
				tw bar `weight'_high temp if inc_t == `inc', ///
					`opts_abs' ysc(range(`range_abs')) ytitle("Obs", size(small)) ///
					name(hist`i'_hl_abs, replace)
				
				tw bar `weight'_low temp if inc_t == `inc', ///
					`opts_abs' ysc(range(`range_abs')) ytitle("Obs", size(small)) ///
					name(hist`i'_lr_abs, replace)
				
				tw bar `weight' temp if inc_t == `inc', ///
					`opts_abs' ysc(range(`range_abs')) ytitle("Obs", size(small)) ///
					name(hist`i'_hr_abs, replace)
				
				tw bar `weight'_hp temp if inc_t == `inc', ///
					`opts_pct' ysc(range(0 `ymax_pct')) ytitle("%", size(small)) ///
					name(hist`i'_hl_pct, replace)
				
				tw bar `weight'_lp temp if inc_t == `inc', ///
					`opts_pct' ysc(range(0 `ymax_pct')) ytitle("%", size(small)) ///
					name(hist`i'_lr_pct, replace)
				
				tw bar `weight'_p temp if inc_t == `inc', ///
					`opts_pct' ysc(range(0 `ymax_pct')) ytitle("%", size(small)) ///
					name(hist`i'_hr_pct, replace)
				
				foreach h in hr lr hl {
					cap mkdir "${DIR_OUTPUT}/interacted_reg_output/plots/histograms/`interaction'"
					graph save hist`i'_`h'_abs "${DIR_OUTPUT}/interacted_reg_output/plots/histograms/`interaction'/hist`i'_`h'_abs.gph", replace
					graph save hist`i'_`h'_pct "${DIR_OUTPUT}/interacted_reg_output/plots/histograms/`interaction'/hist`i'_`h'_pct.gph", replace
				}
			}
			local ++i
		}
	}
	
	******************************** GET CUTOFFS ***********************************
	restore
	di "GETTING PERCENTILE CUTOFFS FOR GRAPHS..."
	
	if "`interaction'" == "climate" {
		local i = 1
		forvalues clim=1(1)3 {
			sum real_temperature `weighting' if clim_t==`clim' & high_risk == 1, det
			global p1`i'_hl_`weight' = `r(p1)'
			global p5`i'_hl_`weight' = `r(p5)'
			global p95`i'_hl_`weight' = `r(p95)'
			global p99`i'_hl_`weight' = `r(p99)'
			
			sum real_temperature `weighting' if clim_t==`clim' & high_risk == 0, det
			global p1`i'_lr_`weight' = `r(p1)'
			global p5`i'_lr_`weight' = `r(p5)'
			global p95`i'_lr_`weight' = `r(p95)'
			global p99`i'_lr_`weight' = `r(p99)'
			
			sum real_temperature `weighting' if clim_t==`clim', det
			global p1`i'_hr_`weight' = `r(p1)'
			global p5`i'_hr_`weight' = `r(p5)'
			global p95`i'_hr_`weight' = `r(p95)'
			global p99`i'_hr_`weight' = `r(p99)'
			local ++i
		}
	}
	
	else if "`interaction'" == "interacted" | "`interaction'" == "triple_int" {
		local i = 1
		forvalues inc=1(1)3 {
			forvalues clim=1(1)3 {
				sum real_temperature `weighting' if clim_t==`clim' & inc_t==`inc' & high_risk == 1, det
				global p1`i'_hl_`weight' = `r(p1)'
				global p5`i'_hl_`weight' = `r(p5)'
				global p95`i'_hl_`weight' = `r(p95)'
				global p99`i'_hl_`weight' = `r(p99)'
				
				sum real_temperature `weighting' if clim_t==`clim' & inc_t==`inc' & high_risk == 0, det
				global p1`i'_lr_`weight' = `r(p1)'
				global p5`i'_lr_`weight' = `r(p5)'
				global p95`i'_lr_`weight' = `r(p95)'
				global p99`i'_lr_`weight' = `r(p99)'
				
				sum real_temperature `weighting' if clim_t==`clim' & inc_t==`inc', det
				global p1`i'_hr_`weight' = `r(p1)'
				global p5`i'_hr_`weight' = `r(p5)'
				global p95`i'_hr_`weight' = `r(p95)'
				global p99`i'_hr_`weight' = `r(p99)'
				local ++i
			}
		}
	}
	
	else if "`interaction'" == "income" {
		local i = 1
		forvalues inc=1(1)3 {
			sum real_temperature `weighting' if inc_t==`inc' & high_risk == 1, det
			global p1`i'_hl_`weight' = `r(p1)'
			global p5`i'_hl_`weight' = `r(p5)'
			global p95`i'_hl_`weight' = `r(p95)'
			global p99`i'_hl_`weight' = `r(p99)'
			
			sum real_temperature `weighting' if inc_t==`inc' & high_risk == 0, det
			global p1`i'_lr_`weight' = `r(p1)'
			global p5`i'_lr_`weight' = `r(p5)'
			global p95`i'_lr_`weight' = `r(p95)'
			global p99`i'_lr_`weight' = `r(p99)'
			
			sum real_temperature `weighting' if inc_t==`inc', det
			global p1`i'_hr_`weight' = `r(p1)'
			global p5`i'_hr_`weight' = `r(p5)'
			global p95`i'_hr_`weight' = `r(p95)'
			global p99`i'_hr_`weight' = `r(p99)'
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
