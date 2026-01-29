cap program drop plot_histograms
program define plot_histograms
	
	args tercile_unit weight interaction
	
	* Set collapser based on interaction type
	if "`interaction'" == "interacted" | "`interaction'" == "triple_int" {
		global collapser = "clim_t inc_t"
	}
	else if "`interaction'" == "income" {
		global collapser = "inc_t"
	}
	
	di "COLLAPSER $collapser"
	
	*****************
	* PATHS
	*****************
	local datapath = "/mnt/CIL_labor/2_regression/time_use/input"
	
	*****************
	* PULL IN TERCILE CUTOFF DATA
	*****************
	if "`tercile_unit'" == "hierid" {
		use "`datapath'/loggdppc_2010_grid.dta", clear
		merge 1:1 group using "`datapath'/lrtmax_tercile_cutoff.dta", nogen
	}
	else if "`tercile_unit'" == "rep_unit" {
		use "${ROOT_INT_DATA}/xtiles/rep_unit_terciles_grid_nested.dta", clear
	}
	
	di "GETTING TERCILE MAX CUTOFFS (NESTED)..."

	******************************************************************
	* IMPORTANT (NESTED LOGIC):
	*   - Climate cutoffs are GLOBAL cutoffs (need ONLY two numbers):
	*       cutoff1 = max lr_tmax_p1 in clim_t=1 block
	*       cutoff2 = max lr_tmax_p1 in clim_t=2 block
	*     (clim_t=3 is the residual > cutoff2)
	*
	*   - Income cutoffs are WITHIN clim_t:
	*       cutoff_g1(c) = max log_gdp_pc in inc_t=1 within clim_t=c
	*       cutoff_g2(c) = max log_gdp_pc in inc_t=2 within clim_t=c
	*     (inc_t=3 is the residual > cutoff_g2)
	*
	* We keep your original macro naming to minimize downstream changes:
	*   $lrtmax1, $lrtmax2 are the two climate cutoffs
	*   ${loggdppc`c'_1}, ${loggdppc`c'_2} are nested income cutoffs
	******************************************************************

	* --- 1) Climate cutoffs: define ONLY cutoff1 and cutoff2 ---
	quietly summarize max_lrtmax if clim_t == 1, meanonly
	global lrtmax1 = r(max)

	quietly summarize max_lrtmax if clim_t == 2, meanonly
	global lrtmax2 = r(max)

	* for completeness (not used in assignment), keep lrtmax3 as max of clim=3
	quietly summarize max_lrtmax if clim_t == 3, meanonly
	global lrtmax3 = r(max)

	* --- 2) GDP cutoffs nested within each climate tercile ---
	* store as: ${loggdppc{clim}_{1 or 2}}
	forvalues c = 1/3 {

		quietly summarize max_loggdppc if clim_t == `c' & inc_t == 1, meanonly
		global loggdppc`c'_1 = r(max)

		quietly summarize max_loggdppc if clim_t == `c' & inc_t == 2, meanonly
		global loggdppc`c'_2 = r(max)

		* (optional) keep a "3" macro for debugging (not used)
		quietly summarize max_loggdppc if clim_t == `c' & inc_t == 3, meanonly
		global loggdppc`c'_3 = r(max)
	}

	di "Climate (LRT) cutoffs: $lrtmax1, $lrtmax2 (lrtmax3=$lrtmax3 for debug)"
	forvalues c = 1/3 {
		di "Income (GDP) cutoffs within clim_t=`c': g1=${loggdppc`c'_1}, g2=${loggdppc`c'_2} (g3=${loggdppc`c'_3} debug)"
	}
	
	*****************
	* PULL IN THE ACTUAL DATASET
	*****************
	use "/project/cil/battuta_shares/gcp/estimation/labor/code_release_int_data/regression_ready_data/labor_dataset_splines_nochn_tmax_chn_prev_week_no_ll_0_agnonag_272841_0129.dta", clear
	
	di "ASSIGNING TO TERCILES..."
	
	* ----------------------------
	* Assign climate terciles
	* ----------------------------
	cap drop clim_t
	gen byte clim_t = .

	replace clim_t = 1 if !missing(lr_tmax_p1) & lr_tmax_p1 <= $lrtmax1
	replace clim_t = 2 if !missing(lr_tmax_p1) & lr_tmax_p1 >  $lrtmax1 & lr_tmax_p1 <= $lrtmax2
	replace clim_t = 3 if !missing(lr_tmax_p1) & lr_tmax_p1 >  $lrtmax2
	
	* ----------------------------
	* Assign income terciles nested within climate tercile
	* (use ONLY _1 and _2 cutoffs)
	* ----------------------------
	cap drop inc_t
	gen byte inc_t = .

	forvalues c = 1/3 {
		replace inc_t = 1 if clim_t == `c' & !missing(log_gdp_pc_adm1) ///
			& log_gdp_pc_adm1 <= ${loggdppc`c'_1}

		replace inc_t = 2 if clim_t == `c' & !missing(log_gdp_pc_adm1) ///
			& log_gdp_pc_adm1 >  ${loggdppc`c'_1} & log_gdp_pc_adm1 <= ${loggdppc`c'_2}

		replace inc_t = 3 if clim_t == `c' & !missing(log_gdp_pc_adm1) ///
			& log_gdp_pc_adm1 >  ${loggdppc`c'_2}
	}

	* Quick sanity check (very helpful)
	tab clim_t inc_t, missing
	
	* Verify tercile assignments by country (can be huge)
	* bysort clim_t inc_t: tab iso

	* Check for missing tercile assignments
	count if missing(clim_t)
	if r(N) > 0 {
		di as error "WARNING: `r(N)' observations have missing clim_t"
		di as error "Check if lr_tmax_p1 is missing or outside expected range"
	}
	count if missing(inc_t)
	if r(N) > 0 {
		di as error "WARNING: `r(N)' observations have missing inc_t"
		di as error "Likely missing log_gdp_pc_adm1 within some clim_t"
	}
	
	* Set weighting option
	if "`weight'" == "no_wgt" {
		local weighting = ""
	}
	else {
		local weighting = "[aweight=`weight']"
	}
	
	******************************** 
	* PLOT HISTOGRAMS 
	********************************
	preserve
	
	* Get overall temperature statistics
	sum real_temperature `weighting', det
	local min = `r(min)'
	local max_realised = ceil(`r(max)')
	local min_realised = floor(`r(min)')
	local center = round(`r(p50)', 0.1)
	
	* Set global temperature range for plots
	global temp_min = -20
	global temp_max = 50
	
	gen bin = floor(real_temperature / 0.1) * 0.1
	
	di "Collapsing to bins..."
	
	* Create weight variables for high and low risk groups
	gen no_wgt = 1
	gen `weight'_high = `weight' if high_risk == 1
	gen `weight'_low  = `weight' if high_risk == 0

	* Save temporary file with all data
	tempfile all_data
	save `all_data', replace
	
	* Collapse to bin level, summing weights by tercile combination
	gcollapse (sum) `weight' `weight'_high `weight'_low, by(bin $collapser)
	
	* Calculate total weights for each tercile combination
	gegen tot_high = total(`weight'_high), by($collapser)
	gegen tot_low  = total(`weight'_low),  by($collapser)
	gegen tot      = total(`weight'),      by($collapser)
	
	* Calculate percentages within each tercile combination
	gen `weight'_hp = (`weight'_high / tot_high) * 100
	gen `weight'_lp = (`weight'_low  / tot_low)  * 100
	gen `weight'_p  = (`weight'      / tot)      * 100
	
	* Find maximum percentage for unified y-axis scaling
	sum `weight'_hp, det
	local max_hp = `r(max)'
	sum `weight'_lp, det
	local max_lp = `r(max)'
	sum `weight'_p, det
	local max_p  = `r(max)'
	
	* Set unified y-axis maximum for percentage plots
	local ymax_pct = max(`max_hp', `max_lp', `max_p')
	local ymax_pct = ceil(`ymax_pct' * 2) / 2 
	if `ymax_pct' < 2 local ymax_pct = 2
	
	di "Unified Y-axis max for percentages: `ymax_pct'"
	
	* Set y-axis maximum for absolute count plots
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
	
	* Create temperature variable for plotting
	gen temp = bin
	
	*****************
	* INTERACTED PLOTS (9 tercile combinations)
	*****************
	if "`interaction'" == "interacted" | "`interaction'" == "triple_int" {
		local i = 1
		forvalues inc=1(1)3 {
			forvalues clim=1(1)3 {
				di "=== PLOTTING HIST FOR TERCILE `clim' X `inc' ==="
				
				* Check if data exists for this tercile combination
				count if clim_t == `clim' & inc_t == `inc'
				
				if r(N) > 0 {
					* Set x-axis options
					local opts_x `"xlab(${temp_min}(10)${temp_max}, labs(small)) xsc(range(${temp_min} ${temp_max})) xtitle("")"'
					
					* Set options for absolute count plots
					local opts_abs `"barwidth(0.09) ylab(#4, labs(vsmall) angle(vertical)) graphregion(color(white) margin(zero)) plotregion(margin(zero)) fysize(10) `opts_x'"'
					
					* Set options for percentage plots
					local opts_pct `"barwidth(0.09) ylab(#4, labs(vsmall) angle(vertical)) graphregion(color(white) margin(zero)) plotregion(margin(zero)) fysize(10) `opts_x'"'
					
					* Plot high risk absolute counts
					tw bar `weight'_high temp if clim_t == `clim' & inc_t == `inc', ///
						`opts_abs' ysc(range(`range_abs')) ytitle("Obs", size(small)) ///
						name(hist`i'_hl_abs, replace)
					
					* Plot low risk absolute counts
					tw bar `weight'_low temp if clim_t == `clim' & inc_t == `inc', ///
						`opts_abs' ysc(range(`range_abs')) ytitle("Obs", size(small)) ///
						name(hist`i'_lr_abs, replace)
					
					* Plot all observations absolute counts
					tw bar `weight' temp if clim_t == `clim' & inc_t == `inc', ///
						`opts_abs' ysc(range(`range_abs')) ytitle("Obs", size(small)) ///
						name(hist`i'_hr_abs, replace)
					
					* Plot high risk percentages
					tw bar `weight'_hp temp if clim_t == `clim' & inc_t == `inc', ///
						`opts_pct' ysc(range(0 `ymax_pct')) ytitle("%", size(small)) ///
						name(hist`i'_hl_pct, replace)
					
					* Plot low risk percentages
					tw bar `weight'_lp temp if clim_t == `clim' & inc_t == `inc', ///
						`opts_pct' ysc(range(0 `ymax_pct')) ytitle("%", size(small)) ///
						name(hist`i'_lr_pct, replace)
					
					* Plot all observations percentages
					tw bar `weight'_p temp if clim_t == `clim' & inc_t == `inc', ///
						`opts_pct' ysc(range(0 `ymax_pct')) ytitle("%", size(small)) ///
						name(hist`i'_hr_pct, replace)
					
					* Save all histogram graphs
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
	
	*****************
	* INCOME-ONLY PLOTS (3 income terciles)
	*****************
	else if "`interaction'" == "income" {
		local i = 1
		forvalues inc=1(1)3 {
			di "=== PLOTTING HIST FOR INCOME TERCILE `inc' ==="
			
			* Check if data exists for this income tercile
			count if inc_t == `inc'
			
			if r(N) > 0 {
				* Set x-axis options
				local opts_x `"xlab(${temp_min}(10)${temp_max}, labs(small)) xsc(range(${temp_min} ${temp_max})) xtitle("")"'
				
				* Set options for absolute count plots
				local opts_abs `"barwidth(0.09) ylab(#5, labs(vsmall) angle(vertical)) graphregion(color(white) margin(zero)) plotregion(margin(zero)) fysize(40) `opts_x'"'
				
				* Set options for percentage plots
				local opts_pct `"barwidth(0.09) ylab(#5, labs(vsmall) angle(vertical)) graphregion(color(white) margin(zero)) plotregion(margin(zero)) fysize(40) `opts_x'"'
				
				* Plot high risk absolute counts
				tw bar `weight'_high temp if inc_t == `inc', ///
					`opts_abs' ysc(range(`range_abs')) ytitle("Obs", size(small)) ///
					name(hist`i'_hl_abs, replace)
				
				* Plot low risk absolute counts
				tw bar `weight'_low temp if inc_t == `inc', ///
					`opts_abs' ysc(range(`range_abs')) ytitle("Obs", size(small)) ///
					name(hist`i'_lr_abs, replace)
				
				* Plot all observations absolute counts
				tw bar `weight' temp if inc_t == `inc', ///
					`opts_abs' ysc(range(`range_abs')) ytitle("Obs", size(small)) ///
					name(hist`i'_hr_abs, replace)
				
				* Plot high risk percentages
				tw bar `weight'_hp temp if inc_t == `inc', ///
					`opts_pct' ysc(range(0 `ymax_pct')) ytitle("%", size(small)) ///
					name(hist`i'_hl_pct, replace)
				
				* Plot low risk percentages
				tw bar `weight'_lp temp if inc_t == `inc', ///
					`opts_pct' ysc(range(0 `ymax_pct')) ytitle("%", size(small)) ///
					name(hist`i'_lr_pct, replace)
				
				* Plot all observations percentages
				tw bar `weight'_p temp if inc_t == `inc', ///
					`opts_pct' ysc(range(0 `ymax_pct')) ytitle("%", size(small)) ///
					name(hist`i'_hr_pct, replace)
				
				* Save all histogram graphs
				foreach h in hr lr hl {
					cap mkdir "${DIR_OUTPUT}/interacted_reg_output/plots/histograms/`interaction'"
					graph save hist`i'_`h'_abs "${DIR_OUTPUT}/interacted_reg_output/plots/histograms/`interaction'/hist`i'_`h'_abs.gph", replace
					graph save hist`i'_`h'_pct "${DIR_OUTPUT}/interacted_reg_output/plots/histograms/`interaction'/hist`i'_`h'_pct.gph", replace
				}
			}
			local ++i
		}
	}
	
	******************************** 
	* GET PERCENTILE CUTOFFS FOR GRAPHS
	********************************
	restore
	di "GETTING PERCENTILE CUTOFFS FOR GRAPHS..."
	
	*****************
	* INTERACTED PERCENTILES (9 combinations)
	*****************
	if "`interaction'" == "interacted" | "`interaction'" == "triple_int" {
		local i = 1
		forvalues inc=1(1)3 {
			forvalues clim=1(1)3 {
				* Get percentiles for high risk group
				sum real_temperature `weighting' if clim_t==`clim' & inc_t==`inc' & high_risk == 1, det
				global p1`i'_hl_`weight' = `r(p1)'
				global p5`i'_hl_`weight' = `r(p5)'
				global p95`i'_hl_`weight' = `r(p95)'
				global p99`i'_hl_`weight' = `r(p99)'
				
				* Get percentiles for low risk group
				sum real_temperature `weighting' if clim_t==`clim' & inc_t==`inc' & high_risk == 0, det
				global p1`i'_lr_`weight' = `r(p1)'
				global p5`i'_lr_`weight' = `r(p5)'
				global p95`i'_lr_`weight' = `r(p95)'
				global p99`i'_lr_`weight' = `r(p99)'
				
				* Get percentiles for all observations
				sum real_temperature `weighting' if clim_t==`clim' & inc_t==`inc', det
				global p1`i'_hr_`weight' = `r(p1)'
				global p5`i'_hr_`weight' = `r(p5)'
				global p95`i'_hr_`weight' = `r(p95)'
				global p99`i'_hr_`weight' = `r(p99)'
				local ++i
			}
		}
	}
	
	*****************
	* INCOME-ONLY PERCENTILES (3 terciles)
	*****************
	else if "`interaction'" == "income" {
		local i = 1
		forvalues inc=1(1)3 {
			* Get percentiles for high risk group
			sum real_temperature `weighting' if inc_t==`inc' & high_risk == 1, det
			global p1`i'_hl_`weight' = `r(p1)'
			global p5`i'_hl_`weight' = `r(p5)'
			global p95`i'_hl_`weight' = `r(p95)'
			global p99`i'_hl_`weight' = `r(p99)'
			
			* Get percentiles for low risk group
			sum real_temperature `weighting' if inc_t==`inc' & high_risk == 0, det
			global p1`i'_lr_`weight' = `r(p1)'
			global p5`i'_lr_`weight' = `r(p5)'
			global p95`i'_lr_`weight' = `r(p95)'
			global p99`i'_lr_`weight' = `r(p99)'
			
			* Get percentiles for all observations
			sum real_temperature `weighting' if inc_t==`inc', det
			global p1`i'_hr_`weight' = `r(p1)'
			global p5`i'_hr_`weight' = `r(p5)'
			global p95`i'_hr_`weight' = `r(p95)'
			global p99`i'_hr_`weight' = `r(p99)'
			local ++i
		}
	}
	
	******************************** 
	* GET COUNTS FOR PLOT SUBTITLES
	********************************
	di "STARTING COUNTS..."
	
	* Generate count variables
	gen count_lr = 1 if high_risk == 0
	gen count_hr = 1 if high_risk == 1
	gegen count_rep_unit = tag(rep_unit)
	gegen count_rep_year = tag(rep_unit year)
	
	* Collapse to get counts by tercile combination
	gcollapse (sum) count_lr count_hr count_rep_year count_rep_unit, by($collapser)
	
	* Save counts file
	save "${ROOT_INT_DATA}/xtiles/`tercile_unit'_terciles_count.dta", replace
	di "COUNTS COMPLETE."
end
