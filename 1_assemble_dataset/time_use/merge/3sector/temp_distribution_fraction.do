/****************************************************
* Build temperature distribution (fractions) by group
* - One CSV per ISO (incl. "global")
* - For each temp bin and group:
*     - weighted counts
*     - fraction of total weighted exposure within group
****************************************************/

*****************
*   INITIALIZE   *
*****************

* get functions and paths
run "/project/cil/home_dirs/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"
run "${DIR_REPO_LABOR}/2_analysis/0_subroutines/functions.do"

* dataset
global dataset "/project/cil/battuta_shares/gcp/estimation/labor/code_release_int_data/regression_ready_data/labor_dataset_splines_nochn_tmax_chn_prev_week_no_ll_0_3sector.dta"

* output folder for FRACTION-based temp distributions
local output_folder "${DIR_OUTPUT}/temp_dist/2_high_risk/"
cap mkdir "`output_folder'"

* list of countries / global
global country "global BRA MEX FRA GBR ESP IND USA"

* step size for temperature bins
global bin_step 0.1


*****************************
*   GET DENSITY OF TEMP DIST
*****************************

foreach iso of global country {

    * reload full dataset each iteration
    use "$dataset", clear

    * set weights and restrict sample (for country-specific files)
    if "`iso'" == "global" {
        local weight_list "risk_adj_sample_wgt pop_adj_sample_wgt"
    }
    else {
        keep if iso == "`iso'"
        local weight_list "adj_sample_wgt"
    }

    * quick check
    count
    di "`iso': " r(N) " observations"

    /********************************
    *   CREATE GROUP-SPECIFIC WEIGHTS
    ********************************/

    * unweighted exposure (counts)
    gen no_wgt_comm   = 1
    gen no_wgt_low    = 1 if high_risk  == 0
    gen no_wgt_high   = 1 if high_risk  == 1
    gen no_wgt_manuf  = 1 if manuf      == 1
    gen no_wgt_hr3    = 1 if high_risk3 == 1

    * weighted exposure by each weight + group
    foreach wgt of local weight_list {

        gen `wgt'_comm   = `wgt'
        gen `wgt'_low    = `wgt' if high_risk  == 0
        gen `wgt'_high   = `wgt' if high_risk  == 1
        gen `wgt'_manuf  = `wgt' if manuf      == 1
        gen `wgt'_hr3    = `wgt' if high_risk3 == 1
    }

    /********************
    *   BUILD TEMP BINS
    ********************/

    quietly summarize real_temp, detail
    local max = ceil(r(max))
    local min = floor(r(min))

    * bin real_temp into [min, max) with step = $bin_step
    egen double bin = cut(real_temp), at(`min'($bin_step)`max')

    /**********************
    *   COLLAPSE TO BINS
    **********************/

    * sum exposure within each temp bin for all groups/weights
    gcollapse (sum) *_comm *_low *_high *_manuf *_hr3, by(bin)

    rename bin temp

    /********************************************
    *   CONVERT COUNTS TO FRACTIONS BY GROUP
    *
    *   For each variable v in:
    *       *_comm, *_low, *_high, *_manuf, *_hr3
    *   create:
    *       frac_v = v / sum(v over all temp bins)
    *
    *   Interpretation:
    *   - frac_no_wgt_comm: fraction of all (unweighted) obs in each temp bin
    *   - frac_adj_sample_wgt_low: fraction of low-risk weighted exposure in each bin
    *   - etc.
    ********************************************/

    foreach v of varlist *_comm *_low *_high *_manuf *_hr3 {
        quietly summarize `v', meanonly
        if r(sum) > 0 {
            gen frac_`v' = `v' / r(sum)
        }
    }

    /**********************
    *   EXPORT RESULTS
    **********************/

    export delim "`output_folder'/`iso'_temp_dist_frac.csv", replace

    di "Saved: `output_folder'/`iso'_temp_dist_frac.csv"
}

****************************************************
* End of file
****************************************************
