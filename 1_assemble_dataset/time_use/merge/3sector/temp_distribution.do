*****************
*   INITIALIZE
*****************

* get functions and paths
run "/project/cil/home_dirs/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"
run "${DIR_REPO_LABOR}/2_analysis/0_subroutines/functions.do"

* dataset and output folder
global dataset "/project/cil/battuta_shares/gcp/estimation/labor/code_release_int_data/regression_ready_data/labor_dataset_splines_nochn_tmax_chn_prev_week_no_ll_0_3sector_agcoma.dta"

local output_folder "${DIR_OUTPUT}/temp_dist/2_high_risk"
cap mkdir "`output_folder'"

* list of countries
global country "global"

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
        local weight_list "risk_adj_sample_wgt"
        keep if iso == "`iso'"
    }

    * test: number of observations
    count
    di "`iso': " r(N) " observations"

    * unweighted density variables
    gen no_wgt_comm  = 1
    gen no_wgt_low   = 1 if high_risk  == 0
    gen no_wgt_high  = 1 if high_risk  == 1
    gen no_wgt_manuf = 1 if manuf      == 1
    gen no_wgt_hr3    = 1 if high_risk3 == 1

    * weighted density variables
    foreach weight in `weight_list' {
        gen `weight'_comm  = `weight'
        gen `weight'_low   = `weight' if high_risk  == 0
        gen `weight'_high  = `weight' if high_risk  == 1
        gen `weight'_manuf = `weight' if manuf      == 1
        gen `weight'_hr3    = `weight' if high_risk3 == 1
    }

    quietly summarize real_temp, detail
    local max = ceil(r(max))
    local min = floor(r(min))

    egen double bin = cut(real_temp), at(`min'($bin_step)`max')

    * collapse to bins
    gcollapse (sum) *_comm *_low *_high *_manuf *_hr3, by(bin)

    rename bin temp

    * export: one file per iso / global
    export delim "`output_folder'/noeu_temp_dist.csv", replace
}
