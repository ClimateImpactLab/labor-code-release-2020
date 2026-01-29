use "/project/cil/battuta_shares/gcp/estimation/labor/code_release_int_data/regression_ready_data/labor_dataset_splines_nochn_tmax_chn_prev_week_no_ll_0_agnonag_272841_0129.dta"

preserve
collapse ///
    (median) med = mins_worked ///
    (p25) p25 = mins_worked ///
    (p75) p75 = mins_worked, ///
    by(month)

gen iqr_low  = med - p25
gen iqr_high = p75 - med

twoway ///
    (rcap p75 p25 month, lcolor(gs8)) ///
    (scatter med month, mcolor(navy)), ///
    ytitle("Minutes worked") ///
    title("Median and IQR of mins_worked by month") ///
    graphregion(color(white))
restore
