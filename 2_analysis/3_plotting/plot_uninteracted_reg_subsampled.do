
*****************
*	INITIALIZE
*****************

* get functions and paths
run "/home/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"
run "${DIR_REPO_LABOR}/2_analysis/0_subroutines/functions.do"

gl output_dir = "${DIR_FIG}/subsampled_splines"
cap mkdir $output_dir

gl inc_t = "inc_t1 inc_t2 inc_t3"
gl clim_t = "clim_t1 clim_t2 clim_t3"
gl inc_clim_q = "inc_q2_clim_q1 inc_q2_clim_q2 inc_q1_clim_q1 inc_q1_clim_q2"

gl reg_weight_list risk_adj_sample_wgt

gl interaction_list triple_int interacted income

**************************
*		GET COUNTS
**************************

use "{ROOT_INT_DATA}/xtiles/rep_unit_terciles_uncollapsed.dta"

* Climate and income terciles
foreach var in clim inc {
	forval i=1(1)3 {
		* get number of rep units in each tercile
		count if `var'_t == `i'
		gl ru_`var'_t`i' = `r(N)'
		* get number of rep_unit_years
		sum rep_unit_year if `var'_t == `i'
		gl ruy_`var'_t`i' = `r(sum)'
	}
}

* Climate-income quantiles
forval i=1(1)2 {
	forval c=1(1)2 {
		count if inc_q == `i' & clim_q == `c'
		gl ru_inc_q`i'_clim_q`c' = `r(N)'
		sum rep_unit_year if inc_q == `i' & clim_q == `c'
		gl ruy_inc_q`i'_clim_q`c' = `r(sum)'
	}
}

**************************
*	PLOTTING FUNCTION
**************************

cap prog drop plot_rfs
prog def plot_rfs
	
	args input_dir output_dir subsample percent type interaction reg_weight

	foreach weight in no_wgt `reg_weight' {

		foreach risk in high low {

			foreach plot in ${`subsample'} {

				loc subsample_hist = "`subsample_hist' `plot'_hist"

				import delim "${DIR_OUTPUT}/temp_dist/nochn_temp_dist.csv", clear
				tempfile temp_dist
				save `temp_dist'

				di "IMPORTING ... `input_dir'/fe_week_adm0_3_knots_`plot'_`reg_weight'_CTO_default_ref.csv"
				import delimited "`input_dir'/fe_week_adm0_3_knots_`plot'_`reg_weight'_CTO_default_ref.csv", clear
				
				merge 1:1 temp using `temp_dist', keepus(no_wgt_`risk' `reg_weight'*) keep(1 3) nogen

				** merge in interacted model data to create overlay plots 
				if "`type'" == "overlay" {
					if "`risk'" == "high" loc stem "hl"
					else loc stem "lr"
					merge 1:1 temp using "${dir}/regression_results/plots/`interaction'_splines_by_risk/splines_27_37_39_tmax_chn_prev_week_rep_unit/all_data_no_ci/interacted_plot_`stem'_`plot'.dta"
					loc overlay = "|| rarea upper_ci_int lower_ci_int temp, col(pink%5) || line yhat_int temp, lc (pink) "
				}
				else if "`type'" == "" loc overlay ""
				di "OVERLAY: `overlay'"

				* get percentile line values & obs counts
				sum no_wgt_`risk', det
				loc obs = `r(sum)'				
				sum temp [aweight=`weight'_`risk'], det
				loc p99 = `r(p99)'
				loc p95 = `r(p95)'
				loc p5 = `r(p5)'
				loc p1 = `r(p1)'

				* get histogram range according to the weight
				if "`weight'" == "no_wgt" loc hist_range = "0 50000"
				else if "`weight'" == "risk_adj_sample_wgt" loc hist_range = "0 0.003"
				else if "`weight'" == "rep_unit_year_sample_wgt" loc hist_range = "0 1.5"
				if strpos("`plot'","q") > 0 loc percent_range = "0 5"
				else loc percent_range = "0 5"

				#delimit ;
				tw 	rarea upperci_`risk' lowerci_`risk' temp, col(ltbluishgray%60) || 
					line yhat_`risk' temp, lc (dknavy) 
					`overlay'
					yline(0)
					xline(`p1', lcolor(gold) lpattern(-)) xline(`p99', lcolor(gold) lpattern(-))
					xline(`p5', lcolor(orange) lpattern(_)) xline(`p95', lcolor(orange) lpattern(_))	
					ylab(#7,labs(vsmall)) ytitle("") ysc(range(-40 80))
					xlab(#5,labs(vsmall)) xtitle("") xsc(range(-20 60))
					graphregion(margin(zero) color(white)) 
					title(`plot', size(small)) legend(off) 
					subtitle("`obs' obs, ${ru_`plot'} rep units, ${ruy_`plot'} rep-unit-years", size(vsmall))
					name(`plot', replace) 
					;
				#delimit cr

				if "`percent'" == "percent" {

					gegen tot = total(`weight'_`risk') 
					gen pct = `weight'_`risk'/tot * 100

				#delimit ;
					tw bar pct temp, color(mint%10) barw(0.1)
						ylab(#3,labs(vsmall)) ytitle("") ysc(range(`percent_range'))
						xlab(#5,labs(vsmall)) xtitle("Temp (C)", size(small)) xsc(range(-20 60))
						graphregion(margin(zero) color(white)) 	
						title("") legend(off)
						name(`plot'_hist, replace) 
						;
				#delimit cr
					}

				if "`percent'" == "abs" {

				#delimit ;
					tw bar `weight'_`risk' temp, color(mint%10) barw(0.1)
						ylab(#3,labs(vsmall)) ytitle("") ysc(range(`hist_range'))
						xlab(#5,labs(vsmall)) xtitle("Temp (C)", size(small)) xsc(range(-20 60))
						graphregion(margin(zero) color(white)) 	
						title("") legend(off)
						name(`plot'_hist, replace) 
						;
				#delimit cr
					}

				

			}

				* titles
				if "`subsample'" == "inc_t" loc title "Income terciles"
				else if "`subsample'" == "clim_t" loc title "Climate terciles"
				else loc title "Income-climate quantiles"
				if "`percent'" == "percent" loc ytitle "%"
				else loc ytitle "obs"

				* 4-graph version
				if "`subsample'" == "inc_clim_q" {
					graph combine inc_q2_clim_q1 inc_q2_clim_q2, l1("Minutes worked", size(small)) xcomm ycomm rows(1) graphregion(margin(zero) color(white)) name(subsample1, replace)
					graph combine inc_q2_clim_q1_hist inc_q2_clim_q2_hist, fysize(20) l1("`ytitle'", size(small)) xcomm rows(1) graphregion(margin(zero) color(white)) name(hists1, replace)
					graph combine inc_q1_clim_q1 inc_q1_clim_q2, l1("Minutes worked", size(small)) xcomm ycomm rows(1) graphregion(margin(zero) color(white)) name(subsample2, replace)
					graph combine inc_q1_clim_q1_hist inc_q1_clim_q2_hist, fysize(20) l1("`ytitle'", size(small)) xcomm  rows(1) graphregion(margin(zero) color(white)) name(hists2, replace)
					
					graph combine subsample1 hists1 subsample2 hists2, xcomm graphregion(margin(zero) color(white)) rows(4) title("`title': `risk' risk") ///
					note("Vertical lines show 5th/95th percentile (orange) and 1st/99th percentile (yellow) of temperature.  Histogram weighting: `weight'.", size(vsmall))
				}

				* 3-graph version
				else {
					graph combine ${`subsample'}, l1("Minutes worked", size(small)) xcomm ycomm rows(1) graphregion(margin(zero) color(white)) name(subsample, replace)
					graph combine `subsample_hist', l1("`ytitle'", size(small)) fysize(20) xcomm ycomm rows(1) graphregion(margin(zero) color(white)) name(hists, replace)
					graph combine subsample hists, xcomm graphregion(margin(zero) color(white)) rows(2) title("`title': `risk' risk") ///
						note("Vertical lines show 5th/95th percentile (orange) and 1st/99th percentile (yellow) of temperature.  Histogram weighting: `weight'.", size(vsmall))
				}
				cap mkdir "$output_dir/`interaction'/`reg_weight'_reg"
				cap mkdir "$output_dir/`interaction'/`reg_weight'_reg/`weight'"
				cap mkdir "$output_dir/`interaction'/`reg_weight'_reg/`weight'/`percent'"
				graph export "$output_dir/`interaction'/`reg_weight'_reg/`weight'/`percent'/`type'`subsample'_`risk'_`weight'_`percent'.pdf", replace

				loc subsample_hist = ""
	 
		}

	}

end

foreach reg_wgt in $reg_weight_list {
	foreach int in $interaction_list {

		di "plotting `reg_wgt' `int' ..."

		plot_rfs $input_dir $output_dir inc_clim_q abs overlay `int' `reg_wgt'
		plot_rfs $input_dir $output_dir inc_clim_q percent overlay `int' `reg_wgt'

	}
}

* plot_rfs $input_dir $output_dir inc_t percent
* plot_rfs $input_dir $output_dir clim_t percent
