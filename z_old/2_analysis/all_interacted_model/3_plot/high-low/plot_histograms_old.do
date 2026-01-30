cap program drop plot_histograms
program define plot_histograms
	
	args tercile_unit weight interaction
	
	if "`interaction'" == "interacted" | "`interaction'" == "triple_int" {
		global collapser = "clim_t inc_t"
	}
	else if "`interaction'" == "income" {
		global collapser = "inc_t"
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
	use "${ROOT_INT_DATA}/regression_ready_data/labor_dataset_splines_nochn_tmax_chn_prev_week_no_ll_0.dta", clear
	
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
	
	* 设置全局温度范围用于x轴对齐 - 与线图一致使用-20到50
	global temp_min = -20
	global temp_max = 50
	
	* 生成bins
	gen bin = floor(real_temperature / 0.1) * 0.1
	
	di "collapsing to bins"
	gen no_wgt = 1
	gen `weight'_h = `weight' if high_risk_old == 1
	gen `weight'_l = `weight' if high_risk_old == 0
	
	* 先计算所有terciles的百分比最大值，用于统一y轴
	tempfile all_data
	save `all_data', replace
	
	gcollapse (sum) `weight' `weight'_h `weight'_l, by(bin $collapser)
	
	gegen tot_h = total(`weight'_h), by($collapser)
	gegen tot_l = total(`weight'_l), by($collapser)
	gegen tot = total(`weight'), by($collapser)
	
	gen `weight'_hp = (`weight'_h / tot_h) * 100
	gen `weight'_lp = (`weight'_l / tot_l) * 100
	gen `weight'_p = (`weight' / tot) * 100
	
	* 找到所有terciles中的最大百分比值
	sum `weight'_hp, det
	local max_hp = `r(max)'
	sum `weight'_lp, det
	local max_lp = `r(max)'
	sum `weight'_p, det
	local max_p = `r(max)'
	
	* 取最大值并设置统一的y轴上限
	local ymax_pct = max(`max_hp', `max_lp', `max_p')
	local ymax_pct = ceil(`ymax_pct' * 2) / 2  // 向上取整到0.5
	if `ymax_pct' < 2 local ymax_pct = 2
	
	di "Unified Y-axis max for percentages: `ymax_pct'"
	
	* 对于绝对值，也统一范围
	if "`weight'" == "no_wgt" {
		sum `weight', det
		local ymax_abs = ceil(`r(max)' * 1.1)
		local range_abs = "0 `ymax_abs'"
	}
	else {
		sum `weight', det
		local ymax_abs = `r(max)'
		local ymax_abs = ceil(`ymax_abs' * 20) / 20  // 向上取整
		if `ymax_abs' < 0.1 local ymax_abs = 0.1
		local range_abs = "0 `ymax_abs'"
	}
	
	gen temp = bin
	
	if "`interaction'" == "interacted" | "`interaction'" == "triple_int" {
		local i = 1
		forvalues inc=1(1)3 {
			forvalues clim=1(1)3 {
				di "=== PLOTTING HIST FOR TERCILE `clim' X `inc' ==="
				
				count if clim_t == `clim' & inc_t == `inc'
				
				if r(N) > 0 {
					* 统一的图形选项 - x轴刻度
					local opts_x `"xlab(${temp_min}(10)${temp_max}, labs(small)) xsc(range(${temp_min} ${temp_max})) xtitle("")"'
					
					* 绝对值图的选项 - 加上"Obs"作为y轴标签
					local opts_abs `"barwidth(0.09) ylab(#4, labs(vsmall) angle(vertical)) graphregion(color(white) margin(zero)) plotregion(margin(zero)) fysize(10) `opts_x'"'
					
					* 百分比图的选项 - 加上"%"作为y轴标签  
					local opts_pct `"barwidth(0.09) ylab(#4, labs(vsmall) angle(vertical)) graphregion(color(white) margin(zero)) plotregion(margin(zero)) fysize(10) `opts_x'"'
					
					* 绝对值图 - 统一y轴范围，y轴标签为"Obs"
					tw bar `weight'_h temp if clim_t == `clim' & inc_t == `inc', ///
						`opts_abs' ysc(range(`range_abs')) ytitle("Obs", size(small)) ///
						name(hist`i'_hl_abs, replace)
					
					tw bar `weight'_l temp if clim_t == `clim' & inc_t == `inc', ///
						`opts_abs' ysc(range(`range_abs')) ytitle("Obs", size(small)) ///
						name(hist`i'_lr_abs, replace)
					
					tw bar `weight' temp if clim_t == `clim' & inc_t == `inc', ///
						`opts_abs' ysc(range(`range_abs')) ytitle("Obs", size(small)) ///
						name(hist`i'_hr_abs, replace)
					
					* 百分比图 - 统一y轴范围为0-ymax_pct，y轴标签为"%"
					tw bar `weight'_hp temp if clim_t == `clim' & inc_t == `inc', ///
						`opts_pct' ysc(range(0 `ymax_pct')) ytitle("%", size(small)) ///
						name(hist`i'_hl_pct, replace)
					
					tw bar `weight'_lp temp if clim_t == `clim' & inc_t == `inc', ///
						`opts_pct' ysc(range(0 `ymax_pct')) ytitle("%", size(small)) ///
						name(hist`i'_lr_pct, replace)
					
					tw bar `weight'_p temp if clim_t == `clim' & inc_t == `inc', ///
						`opts_pct' ysc(range(0 `ymax_pct')) ytitle("%", size(small)) ///
						name(hist`i'_hr_pct, replace)
					
					* 保存图形
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
				* 统一的图形选项
				local opts_x `"xlab(${temp_min}(10)${temp_max}, labs(small)) xsc(range(${temp_min} ${temp_max})) xtitle("")"'
				
				local opts_abs `"barwidth(0.09) ylab(#5, labs(vsmall) angle(vertical)) graphregion(color(white) margin(zero)) plotregion(margin(zero)) fysize(40) `opts_x'"'
				
				local opts_pct `"barwidth(0.09) ylab(#5, labs(vsmall) angle(vertical)) graphregion(color(white) margin(zero)) plotregion(margin(zero)) fysize(40) `opts_x'"'
				
				tw bar `weight'_h temp if inc_t == `inc', ///
					`opts_abs' ysc(range(`range_abs')) ytitle("Obs", size(small)) ///
					name(hist`i'_hl_abs, replace)
				
				tw bar `weight'_l temp if inc_t == `inc', ///
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
	
	if "`interaction'" == "interacted" | "`interaction'" == "triple_int" {
		local i = 1
		forvalues inc=1(1)3 {
			forvalues clim=1(1)3 {
				sum real_temperature `weighting' if clim_t==`clim' & inc_t==`inc' & high_risk_old == 1, det
				global p1`i'_hl_`weight' = r(p1)
				global p5`i'_hl_`weight' = r(p5)
				global p95`i'_hl_`weight' = r(p95)
				global p99`i'_hl_`weight' = r(p99)
				
				sum real_temperature `weighting' if clim_t==`clim' & inc_t==`inc' & high_risk_old == 0, det
				global p1`i'_lr_`weight' = r(p1)
				global p5`i'_lr_`weight' = r(p5)
				global p95`i'_lr_`weight' = r(p95)
				global p99`i'_lr_`weight' = r(p99)
				
				sum real_temperature `weighting' if clim_t==`clim' & inc_t==`inc', det
				global p1`i'_hr_`weight' = r(p1)
				global p5`i'_hr_`weight' = r(p5)
				global p95`i'_hr_`weight' = r(p95)
				global p99`i'_hr_`weight' = r(p99)
				local ++i
			}
		}
	}
	else if "`interaction'" == "income" {
		local i = 1
		forvalues inc=1(1)3 {
			sum real_temperature `weighting' if inc_t==`inc' & high_risk_old == 1, det
			global p1`i'_hl_`weight' = r(p1)
			global p5`i'_hl_`weight' = r(p5)
			global p95`i'_hl_`weight' = r(p95)
			global p99`i'_hl_`weight' = r(p99)
			
			sum real_temperature `weighting' if inc_t==`inc' & high_risk_old == 0, det
			global p1`i'_lr_`weight' = r(p1)
			global p5`i'_lr_`weight' = r(p5)
			global p95`i'_lr_`weight' = r(p95)
			global p99`i'_lr_`weight' = r(p99)
			
			sum real_temperature `weighting' if inc_t==`inc', det
			global p1`i'_hr_`weight' = r(p1)
			global p5`i'_hr_`weight' = r(p5)
			global p95`i'_hr_`weight' = r(p95)
			global p99`i'_hr_`weight' = r(p99)
			local ++i
		}
	}
	
	******************************** GET COUNTS ***********************************
	di "STARTING COUNTS..."
	gen count_lr = 1 if high_risk_old == 0
	gen count_hr = 1 if high_risk_old == 1
	gegen count_rep_unit = tag(rep_unit)
	gegen count_rep_year = tag(rep_unit year)
	
	gcollapse (sum) count_lr count_hr count_rep_year count_rep_unit, by($collapser)
	save "${ROOT_INT_DATA}/xtiles/`tercile_unit'_terciles_count.dta", replace
	di "COUNTS COMPLETE."
end
