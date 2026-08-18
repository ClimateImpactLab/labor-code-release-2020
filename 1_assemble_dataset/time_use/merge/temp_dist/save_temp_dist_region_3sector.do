********************************************************************************
* save_temp_dist_region_3sector.do
*
* PURPOSE:
*   Export 1°C temperature distributions for each region:
*     - comm   : all workers
*     - low    : sector==0  (Low-risk)
*     - ag     : sector==1  (Agriculture)
*     - nonag  : sector==2  (Constr. & Manuf.)
*
*   Produces ONE output per region with BOTH:
*     (A) raw bin sums:
*         - no_wgt_comm, no_wgt_low, no_wgt_ag, no_wgt_nonag
*         - pop_wgt_comm, pop_wgt_low, pop_wgt_ag, pop_wgt_nonag
*         - risk_wgt_comm, risk_wgt_low, risk_wgt_ag, risk_wgt_nonag
*     (B) fractional/share versions (sum to 1 within group across bins):
*         - frac_no_wgt_*
*         - frac_pop_wgt_*
*         - frac_risk_wgt_*
*
* OUTPUT:
*   ${DIR_OUTPUT}/temp_dist/region_new/<REG>_temp_dist_ag_1.csv
********************************************************************************

version 16.0
clear all
set more off

*****************
* INITIALIZE
*****************
run "/project/cil/home_dirs/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"
run "${DIR_REPO_LABOR}/2_analysis/0_subroutines/functions.do"

local DATA_DIR "${ROOT_INT_DATA}/regression_ready_data"

local output_folder "${DIR_OUTPUT}/temp_dist/region_new"
cap mkdir "${DIR_OUTPUT}/temp_dist"
cap mkdir "`output_folder'"

local regions "EuropeUS LatinAmerica SouthAsia"
global bin_step 1

*****************************
* GET DENSITY OF TEMP DIST
*****************************

foreach REG of local regions {

    di as txt "============================================================"
    di as txt ">>> `REG'"
    di as txt "============================================================"

    use "`DATA_DIR'/labor_dataset_region_`REG'.dta", clear
    gen real_temperature = tmax_p1
    keep if mins_worked > 0

    * sanity: sector categories should exist and have no missing
    capture assert !missing(sector)
    if _rc {
        di as error "`REG': sector has missing values; fix before exporting temp dist."
        continue
    }

    capture assert inlist(sector,0,1,2)
    if _rc {
        di as error "`REG': sector not coded 0/1/2."
        tab sector, missing
        continue
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
    gen double pop_wgt_comm  = pop_adj_sample_wgt
    gen double pop_wgt_low   = pop_adj_sample_wgt * (sector == 0)
    gen double pop_wgt_ag    = pop_adj_sample_wgt * (sector == 1)
    gen double pop_wgt_nonag = pop_adj_sample_wgt * (sector == 2)

    gen double risk_wgt_comm  = risk_adj_sample_wgt_sector
    gen double risk_wgt_low   = risk_adj_sample_wgt_sector * (sector == 0)
    gen double risk_wgt_ag    = risk_adj_sample_wgt_sector * (sector == 1)
    gen double risk_wgt_nonag = risk_adj_sample_wgt_sector * (sector == 2)

    *****************************
    * BIN TEMPERATURES
    *****************************
    gen double temp = floor(real_temperature / $bin_step) * $bin_step
    replace temp = round(temp, 0.1)

    *****************************
    * COLLAPSE TO BINS (RAW SUMS)
    *****************************
    gcollapse (sum) ///
        no_wgt_comm no_wgt_low no_wgt_ag no_wgt_nonag ///
        pop_wgt_comm pop_wgt_low pop_wgt_ag pop_wgt_nonag ///
        risk_wgt_comm risk_wgt_low risk_wgt_ag risk_wgt_nonag, ///
        by(temp)

    *****************************
    * FRACTIONAL / SHARE VERSIONS
    *****************************
    foreach v in ///
        no_wgt_comm no_wgt_low no_wgt_ag no_wgt_nonag ///
        pop_wgt_comm pop_wgt_low pop_wgt_ag pop_wgt_nonag ///
        risk_wgt_comm risk_wgt_low risk_wgt_ag risk_wgt_nonag {

        egen double tot = total(`v')
        gen double frac_`v' = cond(tot > 0, `v' / tot, .)
        drop tot
    }

    *****************************
    * EXPORT
    *****************************
    export delimited using "`output_folder'/`REG'_temp_dist_ag_1.csv", replace
    di as result "Wrote: `output_folder'/`REG'_temp_dist_ag_1.csv"
}
