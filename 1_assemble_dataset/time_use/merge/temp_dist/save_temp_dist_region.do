********************************************************************************
* save_temp_dist_region.do
*
* PURPOSE:
*   Export temperature distributions for each region:
*     - comm      : all workers
*     - lowrisk   : high_risk == 0
*     - highrisk  : high_risk == 1
*
* OUTPUT:
*   ${DIR_OUTPUT}/temp_dist/region_highrisk/<REG>_temp_dist_highrisk_1.csv
********************************************************************************

version 16.0
clear all
set more off

*****************
* INITIALIZE
*****************
run "/project/cil/home_dirs/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"
run "${DIR_REPO_LABOR}/2_analysis/0_subroutines/functions.do"

local DATA_DIR "${ROOT_INT_DATA}/regression_ready_data/region_datasets_final"

local output_folder "${DIR_OUTPUT}/temp_dist/region_highrisk"
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
    
    gen double real_temperature = .
    
    replace real_temperature = tmax_p1 / sqrt(7) ///
        if !inlist(iso, "BRA", "MEX") 
    
    replace real_temperature = tmax_p1 / 7 ///
        if inlist(iso, "BRA", "MEX")
	
    keep if mins_worked > 0

    * sanity: high_risk should exist and be coded 0/1
    capture assert !missing(high_risk)
    if _rc {
        di as error "`REG': high_risk has missing values; fix before exporting temp dist."
        continue
    }

    capture assert inlist(high_risk, 0, 1)
    if _rc {
        di as error "`REG': high_risk not coded 0/1."
        tab high_risk, missing
        continue
    }

    *****************************
    * UNWEIGHTED COUNTS
    *****************************
    gen double no_wgt_comm     = 1
    gen double no_wgt_lowrisk  = (high_risk == 0)
    gen double no_wgt_highrisk = (high_risk == 1)

    *****************************
    * WEIGHTED COUNTS
    *****************************
    gen double pop_wgt_comm     = pop_adj_sample_wgt
    gen double pop_wgt_lowrisk  = pop_adj_sample_wgt * (high_risk == 0)
    gen double pop_wgt_highrisk = pop_adj_sample_wgt * (high_risk == 1)

    gen double risk_wgt_comm     = risk_adj_sample_wgt_sector
    gen double risk_wgt_lowrisk  = risk_adj_sample_wgt_sector * (high_risk == 0)
    gen double risk_wgt_highrisk = risk_adj_sample_wgt_sector * (high_risk == 1)

    *****************************
    * BIN TEMPERATURES
    *****************************
    gen double temp = floor(real_temperature / $bin_step) * $bin_step
    replace temp = round(temp, 0.1)

    *****************************
    * COLLAPSE TO BINS (RAW SUMS)
    *****************************
    gcollapse (sum) ///
        no_wgt_comm no_wgt_lowrisk no_wgt_highrisk ///
        pop_wgt_comm pop_wgt_lowrisk pop_wgt_highrisk ///
        risk_wgt_comm risk_wgt_lowrisk risk_wgt_highrisk, ///
        by(temp)

    *****************************
    * FRACTIONAL / SHARE VERSIONS
    *****************************
    foreach v in ///
        no_wgt_comm no_wgt_lowrisk no_wgt_highrisk ///
        pop_wgt_comm pop_wgt_lowrisk pop_wgt_highrisk ///
        risk_wgt_comm risk_wgt_lowrisk risk_wgt_highrisk {

        egen double tot = total(`v')
        gen double frac_`v' = cond(tot > 0, `v' / tot, .)
        drop tot
    }

    *****************************
    * EXPORT
    *****************************
    export delimited using "`output_folder'/`REG'_temp_dist_highrisk_1.csv", replace
    di as result "Wrote: `output_folder'/`REG'_temp_dist_highrisk_1.csv"
}
