****11111new high*************************************************************************************
******************************************************************************************************
*****************
*   INITIALIZE
*****************

* get functions and paths
run "/project/cil/home_dirs/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"
run "${DIR_REPO_LABOR}/2_analysis/0_subroutines/functions.do"

* dataset and output folder
global dataset "/project/cil/battuta_shares/gcp/estimation/labor/code_release_int_data/regression_ready_data/labor_dataset_splines_nochn_tmax_chn_prev_week_no_ll_0.dta"

local output_folder "${DIR_OUTPUT}/temp_dist/Dec2025"
cap mkdir "`output_folder'"

* list of countries
global country "global BRA MEX FRA GBR ESP IND USA"

* step size for temperature bins
global bin_step 0.1


*****************************
*   GET DENSITY OF TEMP DIST
*****************************

foreach iso of global country {

    * reload full dataset each iteration
    use "$dataset", clear

    * set weight list depending on global vs country
    if "`iso'" == "global" {
        local weight_list "risk_adj_sample_wgt pop_adj_sample_wgt"
    }
    else {
        local weight_list "adj_sample_wgt"
        keep if iso == "`iso'"
    }

    * test: number of observations
    count
    di "`iso': " r(N) " observations"

    * unweighted density variables
    gen no_wgt_comm  = 1
    gen no_wgt_low   = 1 if high_risk  == 0
    gen no_wgt_high  = 1 if high_risk  == 1

    * weighted density variables
    foreach weight in `weight_list' {
        gen `weight'_comm  = `weight'
        gen `weight'_low   = `weight' if high_risk  == 0
        gen `weight'_high  = `weight' if high_risk  == 1
    }

    quietly summarize real_temp, detail
    local max = ceil(r(max))
    local min = floor(r(min))

    egen double bin = cut(real_temp), at(`min'($bin_step)`max')

    * collapse to bins
    gcollapse (sum) *_comm *_low *_high, by(bin)

    rename bin temp

    * export: one file per iso / global
    export delim "`output_folder'/`iso'_temp_dist.csv", replace
}


*****22222old***************************************************************************************
******************************************************************************************************
*****************
*   INITIALIZE
*****************
clear
* get functions and paths
run "/project/cil/home_dirs/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"
run "${DIR_REPO_LABOR}/2_analysis/0_subroutines/functions.do"

* dataset and output folder
global dataset "/project/cil/battuta_shares/gcp/estimation/labor/code_release_int_data/regression_ready_data/labor_dataset_splines_nochn_tmax_chn_prev_week_no_ll_0.dta"

local output_folder "${DIR_OUTPUT}/temp_dist/Dec2025"
cap mkdir "`output_folder'"

* list of countries
global country "global BRA MEX FRA GBR ESP IND USA"

* step size for temperature bins
global bin_step 0.1


*****************************
*   GET DENSITY OF TEMP DIST
*****************************

foreach iso of global country {

    * reload full dataset each iteration
    use "$dataset", clear

    * set weight list depending on global vs country
    if "`iso'" == "global" {
        local weight_list "risk_adj_sample_wgt_old pop_adj_sample_wgt"
    }
    else {
        local weight_list "adj_sample_wgt"
        keep if iso == "`iso'"
    }

    * test: number of observations
    count
    di "`iso': " r(N) " observations"

    * unweighted density variables
    gen no_wgt_comm  = 1
    gen no_wgt_low   = 1 if high_risk_old  == 0
    gen no_wgt_high  = 1 if high_risk_old  == 1

    * weighted density variables
    foreach weight in `weight_list' {
        gen `weight'_comm  = `weight'
        gen `weight'_low   = `weight' if high_risk_old  == 0
        gen `weight'_high  = `weight' if high_risk_old  == 1
    }

    quietly summarize real_temp, detail
    local max = ceil(r(max))
    local min = floor(r(min))

    egen double bin = cut(real_temp), at(`min'($bin_step)`max')

    * collapse to bins
    gcollapse (sum) *_comm *_low *_high, by(bin)

    rename bin temp

    * export: one file per iso / global
    export delim "`output_folder'/`iso'_temp_dist_old.csv", replace
}



*****33333sector***************************************************************************************
******************************************************************************************************
*****************
*   INITIALIZE
*****************
clear
* get functions and paths
run "/project/cil/home_dirs/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"
run "${DIR_REPO_LABOR}/2_analysis/0_subroutines/functions.do"

* dataset and output folder
global dataset "/project/cil/battuta_shares/gcp/estimation/labor/code_release_int_data/regression_ready_data/labor_dataset_splines_nochn_tmax_chn_prev_week_no_ll_0.dta"

local output_folder "${DIR_OUTPUT}/temp_dist/Dec2025"
cap mkdir "`output_folder'"

* list of countries
global country "global BRA MEX FRA GBR ESP IND USA"

* step size for temperature bins
global bin_step 0.1


*****************************
*   GET DENSITY OF TEMP DIST
*****************************

foreach iso of global country {

    * reload full dataset each iteration
    use "$dataset", clear

    * set weight list depending on global vs country
    if "`iso'" == "global" {
        local weight_list "risk_adj_sample_wgt_sector pop_adj_sample_wgt"
    }
    else {
        local weight_list "adj_sample_wgt"
        keep if iso == "`iso'"
    }

    * test: number of observations
    count
    di "`iso': " r(N) " observations"

    * unweighted density variables
    gen no_wgt_comm  = 1
    gen no_wgt_low   = 1 if sector  == 0
    gen no_wgt_ag  = 1 if sector  == 1
    gen no_wgt_nonag  = 1 if sector  == 2
    
    * weighted density variables
    foreach weight in `weight_list' {
        gen `weight'_comm  = `weight'
        gen `weight'_low   = `weight' if sector  == 0
        gen `weight'_ag  = `weight' if sector  == 1
	gen `weight'_nonag  = `weight' if sector  == 2
    }

    quietly summarize real_temp, detail
    local max = ceil(r(max))
    local min = floor(r(min))

    egen double bin = cut(real_temp), at(`min'($bin_step)`max')

    * collapse to bins
    gcollapse (sum) *_comm *_low *_ag *_nonag, by(bin)

    rename bin temp

    * export: one file per iso / global
    export delim "`output_folder'/`iso'_temp_dist_sector.csv", replace
}



