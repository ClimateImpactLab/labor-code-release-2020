********************************************************************************
* save_temp_dist_sector.do
*
* PURPOSE:
*   Export temperature distributions (0.1°C bins) for:
*     - comm   : all workers
*     - low    : sector==0  (Low-risk)
*     - ag     : sector==1  (Agriculture)
*     - nonag  : sector==2  (Constr. & Manuf.)
*
*   Produces ONE output with BOTH:
*     (A) raw bin sums:
*         - no_wgt_comm, no_wgt_low, no_wgt_ag, no_wgt_nonag
*         - pop_wgt_comm
*         - risk_wgt_sector_low, risk_wgt_sector_ag, risk_wgt_sector_nonag
*     (B) fractional/share versions (sum to 1 within group across bins):
*         - frac_no_wgt_*
*         - frac_pop_wgt_comm
*         - frac_risk_wgt_sector_{low,ag,nonag}
*
* OUTPUT:
*   ${DIR_OUTPUT}/temp_dist/temp_dist_sector.csv
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

    * sanity: sector categories should exist and have no missing
    capture assert !missing(sector)
    if _rc {
        di as error "sector has missing values; fix before exporting temp dist."
        exit 459
    }
    capture assert inlist(sector,0,1,2)
    if _rc {
        di as error "sector not coded 0/1/2."
        exit 459
    }

    *****************************
    * UNWEIGHTED COUNTS
    *****************************
    gen double no_wgt_comm   = 1
    gen double no_wgt_low    = (sector == 0)
    gen double no_wgt_ag     = (sector == 1)
    gen double no_wgt_nonag  = (sector == 2)

    *****************************
    * WEIGHTED COUNTS
    *****************************
    gen double pop_wgt_comm = pop_adj_sample_wgt

    gen double risk_wgt_sector_low   = risk_adj_sample_wgt_sector * (sector == 0)
    gen double risk_wgt_sector_ag    = risk_adj_sample_wgt_sector * (sector == 1)
    gen double risk_wgt_sector_nonag = risk_adj_sample_wgt_sector * (sector == 2)

    *****************************
    * BIN TEMPERATURES
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
        no_wgt_comm no_wgt_low no_wgt_ag no_wgt_nonag ///
        pop_wgt_comm ///
        risk_wgt_sector_low ///
        risk_wgt_sector_ag ///
        risk_wgt_sector_nonag, ///
        by(temp)

    *****************************
    * FRACTIONAL / SHARE VERSIONS
    *****************************
    egen double tot_no_wgt_comm   = total(no_wgt_comm)
    egen double tot_no_wgt_low    = total(no_wgt_low)
    egen double tot_no_wgt_ag     = total(no_wgt_ag)
    egen double tot_no_wgt_nonag  = total(no_wgt_nonag)

    egen double tot_pop_comm      = total(pop_wgt_comm)
    egen double tot_risk_low      = total(risk_wgt_sector_low)
    egen double tot_risk_ag       = total(risk_wgt_sector_ag)
    egen double tot_risk_nonag    = total(risk_wgt_sector_nonag)

    gen double frac_no_wgt_comm  = cond(tot_no_wgt_comm  > 0, no_wgt_comm  / tot_no_wgt_comm,  .)
    gen double frac_no_wgt_low   = cond(tot_no_wgt_low   > 0, no_wgt_low   / tot_no_wgt_low,   .)
    gen double frac_no_wgt_ag    = cond(tot_no_wgt_ag    > 0, no_wgt_ag    / tot_no_wgt_ag,    .)
    gen double frac_no_wgt_nonag = cond(tot_no_wgt_nonag > 0, no_wgt_nonag / tot_no_wgt_nonag, .)

    gen double frac_pop_wgt_comm = cond(tot_pop_comm > 0, pop_wgt_comm / tot_pop_comm, .)

    gen double frac_risk_wgt_sector_low   = cond(tot_risk_low   > 0, risk_wgt_sector_low   / tot_risk_low,   .)
    gen double frac_risk_wgt_sector_ag    = cond(tot_risk_ag    > 0, risk_wgt_sector_ag    / tot_risk_ag,    .)
    gen double frac_risk_wgt_sector_nonag = cond(tot_risk_nonag > 0, risk_wgt_sector_nonag / tot_risk_nonag, .)

    drop tot_no_wgt_comm tot_no_wgt_low tot_no_wgt_ag tot_no_wgt_nonag ///
         tot_pop_comm tot_risk_low tot_risk_ag tot_risk_nonag

    *****************************
    * EXPORT
    *****************************
    export delimited using "`output_folder'/temp_dist_sector.csv", replace
    di as result "Wrote: `output_folder'/temp_dist_sector.csv"
