use "/project/cil/battuta_shares/gcp/estimation/labor/code_release_int_data/regression_ready_data/labor_dataset_splines_nochn_tmax_chn_prev_week_no_ll_0_agnonag_272841_0129.dta"

gen real_mins=mins_worked/7
replace real_mins=mins_worked/(7^0.5) if !inlist(iso, "BRA","MEX")


gen real_age=age
replace real_age=age*(7^0.5) if !inlist(iso, "BRA","MEX")

gen real_hhsize=hhsize
replace real_hhsize=hhsize*(7^0.5) if !inlist(iso, "BRA","MEX")

gen real_male=male
replace real_male=male*(7^0.5) if !inlist(iso, "BRA","MEX")

* change vars to get by countries value
collapse (mean) avg_hhsize=hhsize, by(iso)
replace avg_hhsize=avg_hhsize*(7^0.5) if !inlist(iso, "BRA","MEX")
