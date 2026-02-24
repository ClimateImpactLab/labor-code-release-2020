********************************************************************************
* save_temp_distribution.do
*
* PURPOSE:
*   Export temperature distributions (0.1°C bins) for:
*     - comm : all workers
*     - low  : high_risk == 0
*     - high : high_risk == 1
*
*   Produces ONE output with BOTH:
*     (A) raw bin sums:
*         - no_wgt_comm, no_wgt_low, no_wgt_high
*         - pop_wgt_comm
*         - risk_wgt_low, risk_wgt_high
*     (B) fractional/share versions (sum to 1 within group across bins):
*         - frac_no_wgt_*
*         - frac_pop_wgt_comm
*         - frac_risk_wgt_low
*         - frac_risk_wgt_high
*
* OUTPUT:
*   ${DIR_OUTPUT}/temp_dist/temp_dist.csv
********************************************************************************

version 16.0
clear all
set more off

*****************
* INITIALIZE
*****************
run "/project/cil/home_dirs/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"
run "${DIR_REPO_LABOR}/2_analysis/0_subroutines/functions.do"

global dataset "/project/cil/battuta_shares/gcp/estimation/labor/code_release_int_data/regression_ready_data/labor_dataset_splines_nochn_tmax_chn_prev_week_no_ll_0_agnonag_272841_0218.dta"

local output_folder "${DIR_OUTPUT}/temp_dist"
cap mkdir "`output_folder'"

global bin_step 0.1

*****************************
* GET DENSITY OF TEMP DIST
*****************************

    use "$dataset", clear

    *****************************
    * UNWEIGHTED COUNTS
    *****************************
    gen double no_wgt_comm = 1
    gen double no_wgt_low  = (high_risk == 0)
    gen double no_wgt_high = (high_risk == 1)

    *****************************
    * WEIGHTED COUNTS
    *****************************
    gen double pop_wgt_comm = pop_adj_sample_wgt

    gen double risk_wgt_low  = risk_adj_sample_wgt * (high_risk == 0)
    gen double risk_wgt_high = risk_adj_sample_wgt * (high_risk == 1)

    *****************************
    * BIN TEMPERATURE
    *****************************
    quietly summarize real_temperature, detail
    local max = ceil(r(max))
    local min = floor(r(min))

    egen double bin = cut(real_temperature), at(`min'($bin_step)`max')
    rename bin temp

    *****************************
    * COLLAPSE TO BINS (RAW SUMS)
    *****************************
    gcollapse (sum) ///
        no_wgt_comm no_wgt_low no_wgt_high ///
        pop_wgt_comm ///
        risk_wgt_low ///
        risk_wgt_high, ///
        by(temp)

    *****************************
    * FRACTIONAL VERSIONS
    *****************************
    egen double tot_no_wgt_comm = total(no_wgt_comm)
    egen double tot_no_wgt_low  = total(no_wgt_low)
    egen double tot_no_wgt_high = total(no_wgt_high)

    egen double tot_pop_comm  = total(pop_wgt_comm)
    egen double tot_risk_low  = total(risk_wgt_low)
    egen double tot_risk_high = total(risk_wgt_high)

    gen double frac_no_wgt_comm = cond(tot_no_wgt_comm > 0, no_wgt_comm / tot_no_wgt_comm, .)
    gen double frac_no_wgt_low  = cond(tot_no_wgt_low  > 0, no_wgt_low  / tot_no_wgt_low,  .)
    gen double frac_no_wgt_high = cond(tot_no_wgt_high > 0, no_wgt_high / tot_no_wgt_high, .)

    gen double frac_pop_wgt_comm  = cond(tot_pop_comm  > 0, pop_wgt_comm  / tot_pop_comm,  .)
    gen double frac_risk_wgt_low  = cond(tot_risk_low  > 0, risk_wgt_low  / tot_risk_low,  .)
    gen double frac_risk_wgt_high = cond(tot_risk_high > 0, risk_wgt_high / tot_risk_high, .)

    drop tot_no_wgt_comm tot_no_wgt_low tot_no_wgt_high ///
         tot_pop_comm tot_risk_low tot_risk_high

    *****************************
    * EXPORT
    *****************************
    export delimited using "`output_folder'/temp_dist.csv", replace
    di as result "Wrote: `output_folder'/temp_dist.csv"
