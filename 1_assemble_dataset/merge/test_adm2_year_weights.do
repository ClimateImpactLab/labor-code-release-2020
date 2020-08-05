data_path = "/mnt/sacagawea_shares/gcp/estimation/labor/time_use_data/final/"   
use "${data_path}/labor_dataset_splines_25_27_39_tmax_chn_prev_week_no_ll_0.dta", clear

// Sample weights sum to 1 for each ADM2-by-year
gegen adm2_year_tot_wgt = total(adm2_adj_sample_wgt), by(adm2_id year)
gen adm2_year_adj_sample_wgt = adm2_adj_sample_wgt/adm2_year_tot_wgt
gegen test_sum = total(adm2_year_adj_sample_wgt), by(adm2_id year)
count if round(test_sum) != 1
if `r(N)' != 0 {
	di "Whoops, you biffed it! Sample weights don't add to 1 by ADM2-year."
	}
else {
	di "Great job, sample weights correctly generated."
	drop adm2_year_tot_wgt test_sum
	}
	
