********************************************************************************
* save_temp_dist_region_4sector.do
*
* PURPOSE:
*   Export 1°C temperature distributions for each region using sector2:
*     - comm : all workers with nonmissing sector2
*     - low  : sector2==0 (low-risk)
*     - ag   : sector2==1 (agriculture, forestry, and fishing)
*     - mt   : sector2==2 (manufacturing, transportation, utilities, related)
*     - cm   : sector2==3 (construction and mining)
*
*   Produces one output per region with:
*     - raw unweighted, population-weighted, and risk-weighted bin sums
*     - fractional versions that sum to one within each group
*
*   Europe has no sector2 classification. Missing sector2 observations are
*   dropped to match the 4-sector regressions, so EuropeUS is USA-only.
*
*   risk_adj_sample_wgt_sector is retained to match the 4-sector regression.
*   Groups 2 and 3 therefore inherit the old combined sector-2 weighting.
*
* OUTPUT:
*   ${DIR_OUTPUT}/temp_dist/region_4sector/<REG>_temp_dist_4sector.csv
********************************************************************************

version 16.0
clear all
set more off

*****************
* INITIALIZE
*****************

run "/project/cil/home_dirs/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"
run "${DIR_REPO_LABOR}/2_analysis/0_subroutines/functions.do"

* Use the same rebuilt regional datasets as the 4-sector regressions.
local DATA_DIR "${ROOT_INT_DATA}/regression_ready_data/region_datasets"

local output_folder "${DIR_OUTPUT}/temp_dist/region_4sector"
cap mkdir "${DIR_OUTPUT}/temp_dist"
cap mkdir "`output_folder'"

* Run one region when ISO is supplied; otherwise run all regions.
local ISO_env = trim("`: env ISO'")

if inlist("`ISO_env'","EuropeUS","LatinAmerica","SouthAsia") {
    local regions "`ISO_env'"
}
else {
    local regions "EuropeUS LatinAmerica SouthAsia"
}

global bin_step 1

*****************************
* GET DENSITY OF TEMP DIST
*****************************

foreach REG of local regions {

    di as txt "============================================================"
    di as txt ">>> `REG'"
    di as txt "============================================================"

    local INFILE "`DATA_DIR'/labor_dataset_region_`REG'.dta"

    cap confirm file "`INFILE'"
    if _rc {
        di as error "Missing region dataset: `INFILE'"
        continue
    }

    use "`INFILE'", clear

    capture confirm variable sector2
    if _rc {
        di as error "`REG': sector2 is missing from the dataset."
        continue
    }

    * Recover daily Celsius temperature from the weekly treatment aggregate.
    * Brazil and Mexico use a weekly sum; the other surveys use the scaled
    * weekly aggregate used by the established regional temp-dist script.
    gen double real_temperature = .
    replace real_temperature = tmax_p1 / sqrt(7) ///
        if !inlist(iso, "BRA", "MEX")
    replace real_temperature = tmax_p1 / 7 ///
        if inlist(iso, "BRA", "MEX")

    keep if mins_worked > 0

    * Drop observations that cannot be assigned to one of the four groups.
    quietly count if missing(sector2)
    if r(N) > 0 {
        di as txt "`REG': dropping " r(N) " observations with missing sector2."
        capture tab iso if missing(sector2), missing
        drop if missing(sector2)
    }

    capture assert inlist(sector2,0,1,2,3)
    if _rc {
        di as error "`REG': sector2 is not coded 0/1/2/3."
        tab sector2, missing
        continue
    }

    quietly count
    if r(N) == 0 {
        di as error "`REG': no observations remain after sector2 filtering."
        continue
    }

    *****************************
    * UNWEIGHTED COUNTS
    *****************************

    gen double no_wgt_comm = 1
    gen double no_wgt_low  = (sector2 == 0)
    gen double no_wgt_ag   = (sector2 == 1)
    gen double no_wgt_mt   = (sector2 == 2)
    gen double no_wgt_cm   = (sector2 == 3)

    *****************************
    * WEIGHTED COUNTS
    *****************************

    gen double pop_wgt_comm = pop_adj_sample_wgt
    gen double pop_wgt_low  = pop_adj_sample_wgt * (sector2 == 0)
    gen double pop_wgt_ag   = pop_adj_sample_wgt * (sector2 == 1)
    gen double pop_wgt_mt   = pop_adj_sample_wgt * (sector2 == 2)
    gen double pop_wgt_cm   = pop_adj_sample_wgt * (sector2 == 3)

    gen double risk_wgt_comm = risk_adj_sample_wgt_sector
    gen double risk_wgt_low  = risk_adj_sample_wgt_sector * (sector2 == 0)
    gen double risk_wgt_ag   = risk_adj_sample_wgt_sector * (sector2 == 1)
    gen double risk_wgt_mt   = risk_adj_sample_wgt_sector * (sector2 == 2)
    gen double risk_wgt_cm   = risk_adj_sample_wgt_sector * (sector2 == 3)

    *****************************
    * BIN TEMPERATURES
    *****************************

    gen double temp = floor(real_temperature / $bin_step) * $bin_step
    replace temp = round(temp, 0.1)

    *****************************
    * COLLAPSE TO BINS
    *****************************

    gcollapse (sum) ///
        no_wgt_comm no_wgt_low no_wgt_ag no_wgt_mt no_wgt_cm ///
        pop_wgt_comm pop_wgt_low pop_wgt_ag pop_wgt_mt pop_wgt_cm ///
        risk_wgt_comm risk_wgt_low risk_wgt_ag risk_wgt_mt risk_wgt_cm, ///
        by(temp)

    *****************************
    * FRACTIONAL / SHARE VERSIONS
    *****************************

    foreach v in ///
        no_wgt_comm no_wgt_low no_wgt_ag no_wgt_mt no_wgt_cm ///
        pop_wgt_comm pop_wgt_low pop_wgt_ag pop_wgt_mt pop_wgt_cm ///
        risk_wgt_comm risk_wgt_low risk_wgt_ag risk_wgt_mt risk_wgt_cm {

        egen double tot = total(`v')
        gen double frac_`v' = cond(tot > 0, `v' / tot, .)
        drop tot
    }

    *****************************
    * EXPORT
    *****************************

    local OUTFILE "`output_folder'/`REG'_temp_dist_4sector.csv"
    export delimited using "`OUTFILE'", replace
    di as result "Wrote: `OUTFILE'"
}

exit 0
