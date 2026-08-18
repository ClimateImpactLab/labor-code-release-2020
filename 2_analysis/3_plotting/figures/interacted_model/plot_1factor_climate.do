*-------------------------------------------------------------------------------
* plot_1factor_climate.do
*-------------------------------------------------------------------------------
* PURPOSE
*   Draw the high-risk tercile figure for the 1-factor climate model
*   The figure combines response curves, confidence bands, and temperature histograms
*
* STEPS
*   1. Load climate terciles and model estimates
*   2. Predict the high-risk response at each climate tercile
*   3. Build histogram data from high-risk survey rows
*   4. Draw the three-panel figure
*
* INPUTS
*   Climate-tercile grid set in config.do
*   Regression-ready spline dataset set in config.do
*   Stata estimates file from run_1factor_climate.do
*
* OUTPUTS
*   Plot-data CSV, PDF figure, and PNG figure
*-------------------------------------------------------------------------------

clear all
set more off

*-------------------------------------------------------------------------------
* Setup
*-------------------------------------------------------------------------------

run "/project/cil/home_dirs/`c(username)'/repos/labor-code-release-2020/2_analysis/1_regression/interacted_model/config.do"

cap log close
log using "${APPG_ROOT}/logs/plot_1factor_climate.log", replace

tempfile terciles predictions histdata

use "${APPG_TERCILE_GRID}", clear
keep tercile mean_lrtmax min_lrtmax max_lrtmax
sort tercile
save `terciles', replace

forvalues g = 1/3 {
	qui sum mean_lrtmax if tercile == `g'
	global appg_lrt`g' = r(mean)
	qui sum min_lrtmax if tercile == `g'
	global appg_lrt_min`g' = r(mean)
	qui sum max_lrtmax if tercile == `g'
	global appg_lrt_max`g' = r(mean)
}

*-------------------------------------------------------------------------------
* Build prediction dataset
*-------------------------------------------------------------------------------

numlist "-20(0.1)47"
local temps `r(numlist)'
local ntemps : word count `temps'

clear
set obs `=`ntemps' * 3'
gen double temp = .
gen byte tercile = .

local row = 1
forvalues g = 1/3 {
	foreach t of local temps {
		replace tercile = `g' in `row'
		replace temp = `t' in `row'
		local ++row
	}
}

gen double ref = ${APPG_REF_TEMP}
make_spline_terms ${APPG_KNOT1} ${APPG_KNOT2} ${APPG_KNOT3}
gen mins_worked = .
gen double lrt_eval = .
forvalues g = 1/3 {
	replace lrt_eval = ${appg_lrt`g'} if tercile == `g'
}

estimates use "${APPG_REG_FOLDER}/${APPG_OUTPUT_TAG}.ster"

#delimit ;
predictnl yhat =
	(T_spline0 - ref_spline0) *
		(_b[tmax_rcspl_3kn_t0_hr] + _b[tmax_rcspl_3kn_t0_hr_v1] + _b[tmax_rcspl_3kn_t0_hr_v2] +
		 _b[tmax_rcspl_3kn_t0_hr_v3] + _b[tmax_rcspl_3kn_t0_hr_v4] + _b[tmax_rcspl_3kn_t0_hr_v5] +
		 _b[tmax_rcspl_3kn_t0_hr_v6] +
		 lrt_eval * (_b[tmax_rcspl_3kn_t0_hr_l] + _b[tmax_rcspl_3kn_t0_hr_l_v1] +
		 _b[tmax_rcspl_3kn_t0_hr_l_v2] + _b[tmax_rcspl_3kn_t0_hr_l_v3] +
		 _b[tmax_rcspl_3kn_t0_hr_l_v4] + _b[tmax_rcspl_3kn_t0_hr_l_v5] +
		 _b[tmax_rcspl_3kn_t0_hr_l_v6])) +
	(T_spline1 - ref_spline1) *
		(_b[tmax_rcspl_3kn_t1_hr] + _b[tmax_rcspl_3kn_t1_hr_v1] + _b[tmax_rcspl_3kn_t1_hr_v2] +
		 _b[tmax_rcspl_3kn_t1_hr_v3] + _b[tmax_rcspl_3kn_t1_hr_v4] + _b[tmax_rcspl_3kn_t1_hr_v5] +
		 _b[tmax_rcspl_3kn_t1_hr_v6] +
		 lrt_eval * (_b[tmax_rcspl_3kn_t1_hr_l] + _b[tmax_rcspl_3kn_t1_hr_l_v1] +
		 _b[tmax_rcspl_3kn_t1_hr_l_v2] + _b[tmax_rcspl_3kn_t1_hr_l_v3] +
		 _b[tmax_rcspl_3kn_t1_hr_l_v4] + _b[tmax_rcspl_3kn_t1_hr_l_v5] +
		 _b[tmax_rcspl_3kn_t1_hr_l_v6])),
	ci(lower_ci upper_ci) se(se);
#delimit cr

drop T* ref_* min* mins_worked
export delimited using "${APPG_PLOT_FOLDER}/${APPG_OUTPUT_TAG}_g1_highrisk_plot_data.csv", replace
save `predictions', replace

*-------------------------------------------------------------------------------
* Build high-risk histogram data from the configured dataset
*-------------------------------------------------------------------------------

use "${APPG_DATASET}", clear
keep if ${APPG_RISK_VAR} == 1
keep real_temperature lr_tmax_p1 ${APPG_WEIGHT}

gen byte tercile = .
replace tercile = 1 if lr_tmax_p1 <= ${appg_lrt_max1} & !missing(lr_tmax_p1)
replace tercile = 2 if lr_tmax_p1 > ${appg_lrt_max1} & lr_tmax_p1 <= ${appg_lrt_max2}
replace tercile = 3 if lr_tmax_p1 > ${appg_lrt_max2} & !missing(lr_tmax_p1)

gen double bin = floor(real_temperature / 0.2) * 0.2
gen double w = ${APPG_WEIGHT}

forvalues g = 1/3 {
	_pctile real_temperature [aw = w] if tercile == `g', p(1 5 95 99)
	global appg_p1_`g' = r(r1)
	global appg_p5_`g' = r(r2)
	global appg_p95_`g' = r(r3)
	global appg_p99_`g' = r(r4)
}

gcollapse (sum) w, by(tercile bin)
bys tercile: egen double total_w = total(w)
gen double pct = 100 * w / total_w
rename bin temp
save `histdata', replace

*-------------------------------------------------------------------------------
* Draw panels
*-------------------------------------------------------------------------------

local panel_title1 "A"
local panel_title2 "B"
local panel_title3 "C"

forvalues g = 1/3 {
	preserve
	use `predictions', clear
	keep if tercile == `g'
	tempfile pred`g'
	save `pred`g'', replace
	restore

	preserve
	use `histdata', clear
	keep if tercile == `g'
	qui sum pct
	gen double hist_base = -410
	gen double hist_top = hist_base + (pct / r(max)) * 55
	tempfile hist`g'
	save `hist`g'', replace
	restore

	preserve
	use `pred`g'', clear
	append using `hist`g''
	gen double yhat_plot = yhat if inrange(yhat, -340, 430)
	gen double lower_plot = max(lower_ci, -340) if !missing(lower_ci)
	gen double upper_plot = min(upper_ci, 430) if !missing(upper_ci)
	replace lower_plot = . if lower_ci > 430 | upper_ci < -340
	replace upper_plot = . if lower_ci > 430 | upper_ci < -340
	local ytitle ""
	local ylabel "ylabel(none)"
	if `g' == 1 {
		local ytitle "{bf:Minutes worked}"
		local ylabel "ylabel(-200 0 200 400, labsize(medlarge) angle(vertical) nogrid tlcolor(gs8))"
	}
	else {
		local ylabel "ylabel(-200 0 200 400, labcolor(white) angle(vertical) nogrid tlcolor(gs8))"
	}
	twoway ///
		(rarea upper_plot lower_plot temp if !missing(upper_plot), sort color(ltbluishgray) lcolor(ltbluishgray)) ///
		(rbar hist_top hist_base temp if !missing(hist_top), color(navy) lcolor(navy) barwidth(0.18)) ///
		(line yhat_plot temp if !missing(yhat_plot), lcolor(navy) lwidth(medthick)) ///
		(pci -340 ${appg_p1_`g'} 430 ${appg_p1_`g'}, lcolor(gold) lpattern(longdash) lwidth(medthin)) ///
		(pci -340 ${appg_p99_`g'} 430 ${appg_p99_`g'}, lcolor(gold) lpattern(longdash) lwidth(medthin)) ///
		(pci -340 ${appg_p5_`g'} 430 ${appg_p5_`g'}, lcolor(orange_red) lpattern(longdash) lwidth(medthin)) ///
		(pci -340 ${appg_p95_`g'} 430 ${appg_p95_`g'}, lcolor(orange_red) lpattern(longdash) lwidth(medthin)) ///
		, ///
		yline(0, lcolor(cranberry) lwidth(medthin)) ///
		xscale(range(-20 50) lcolor(gs8)) ///
		yscale(range(-425 440) lcolor(gs8)) ///
		xlabel(-20(20)40, labsize(medlarge)) ///
		`ylabel' ///
		xtitle("") ///
		ytitle("`ytitle'", size(medlarge)) ///
		title("{bf:`panel_title`g''}", position(11) ring(1) justification(left) size(large) color(black)) ///
		legend(off) ///
		graphregion(color(white) margin(zero)) ///
		plotregion(color(white) margin(small) lcolor(none)) ///
		name(appg_panel`g', replace)
	restore
}

graph combine appg_panel1 appg_panel2 appg_panel3, ///
	cols(3) ///
	xcommon ///
	imargin(0 0 0 0) ///
	plotregion(color(white) margin(zero)) ///
	graphregion(color(white) margin(t=8 b=8 l=6 r=6)) ///
	b1title("{bf:Temperature (C)}", size(medlarge)) ///
	iscale(0.9) ///
	xsize(11) ysize(5.8) ///
	name(appg_g1_highrisk, replace)

graph export "${APPG_FIG_FOLDER}/${APPG_OUTPUT_TAG}_g1_highrisk_pretty.pdf", replace
graph export "${APPG_FIG_FOLDER}/${APPG_OUTPUT_TAG}_g1_highrisk_pretty.png", width(2400) replace

cap log close
