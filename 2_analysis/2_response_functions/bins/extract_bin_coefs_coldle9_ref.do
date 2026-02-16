/****************************************************************************************
 extract_bin_coefs_coldle9_ref.do

 PURPOSE
 -------
 Extract binned-temperature regression effects (coefficients + standard errors) from
 saved Stata estimates files (.ster) produced by reghdfe, for the cold-tail merged
 bin structure (cold tail <= 9°C), under alternative reference bins.

 Regressions are of the form:

     (bins)##i.high_risk

 where bins are TEMPERATURE-BASED 3°C bins constructed by transform_bins_ag_coldtail.do:
     below9, b3C_9, b3C_12, ..., b3C_39, above42

 This script extracts coefficients for two reference-bin choices:
   - refcode = 24  (reference = 24–27°C, i.e., b3C_24 omitted)
   - refcode = 27  (reference = 27–30°C, i.e., b3C_27 omitted)

 OUTPUT (CSV)
 ------------
 Writes plot-ready CSVs (one per reference) with one row per bin (incl. reference):
   - bin_code:  "below9", "9","12",...,"39", "above42"
   - temp_mid:  midpoint temperature 
   - low, se_low:     
   - high, se_high:  
   - diff, se_diff:   
   - is_ref:          1 if reference bin, else 0
   - ord:             plot ordering key (below9 first, above42 last)


 AUTHOR: Marine de Franciosi (mdefranciosi@uchicago.edu)
 LAST MODIFIED: 12/15/2025
 
****************************************************************************************/

version 16.1
clear all
set more off

/**************************************
 STEP 0) USER INPUTS
**************************************/

run "/project/cil/home_dirs/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"

cap log close
log using "${DIR_LOG}/extract_global_bin_coefs_coldle9.smcl", replace

* Folder for extracted tables
global RF_OUT "${DIR_RF}/uninteracted_bins"
cap mkdir "$RF_OUT"

* Cold tail cutoff (fixed)
local coldcut 9

* Reference-bin options to extract
local ref_list "24 27"

* --- Inputs: update if your ster names differ ---
* ref=24 -> older coldle9 ster (no explicit ref in filename)
local ster_ref24 "${DIR_STER}/uninteracted_bins_ag/uninteracted_bins_nochn_3C_coldle9_ref24_ag.ster"

* ref=27 -> explicit ref27 filename
local ster_ref27 "${DIR_STER}/uninteracted_bins_ag/uninteracted_bins_nochn_3C_coldle9_ref27_ag.ster"

* --- Outputs ---
local out_ref24  "${RF_OUT}/uninteracted_bins_coefs_3C_coldle9_ref24.csv"
local out_ref27  "${RF_OUT}/uninteracted_bins_coefs_3C_coldle9_ref27.csv"


/**************************************
 STEP 1) HELPER PROGRAM: BUILD LINCOM EXPRESSIONS
**************************************/

cap program drop __mkexpr_global
program define __mkexpr_global, rclass
    syntax, root(string)

    local cols : colnames e(b)

    local L "0"
    local H "0"
    local D "0"

    local base_plain     "`root'"
    local base_cpref     "c.`root'"
    local ih_base_plain  "1.high_risk#`base_plain'"
    local ih_base_cpref  "1.high_risk#`base_cpref'"

    * LOW: contemporaneous main effect if present
    if `=strpos(" `cols' "," `base_cpref' ")>0' {
        local L "`L' + _b[`base_cpref']"
    }
    else if `=strpos(" `cols' "," `base_plain' ")>0' {
        local L "`L' + _b[`base_plain']"
    }

    * HIGH + DIFF: contemporaneous interaction if present
    if `=strpos(" `cols' "," `ih_base_cpref' ")>0' {
        local H "`L' + _b[`ih_base_cpref']"
        local D "0 + _b[`ih_base_cpref']"
    }
    else if `=strpos(" `cols' "," `ih_base_plain' ")>0' {
        local H "`L' + _b[`ih_base_plain']"
        local D "0 + _b[`ih_base_plain']"
    }
    else {
        local H "`L'"
        local D "0"
    }

    * Add lags/leads root_v1..root_v6 if present
    forvalues j=1/6 {

        local lag_plain     "`root'_v`j'"
        local lag_cpref     "c.`root'_v`j'"
        local ih_lag_plain  "1.high_risk#`lag_plain'"
        local ih_lag_cpref  "1.high_risk#`lag_cpref'"

        * LOW: add main lag if present
        if `=strpos(" `cols' "," `lag_cpref' ")>0' {
            local L "`L' + _b[`lag_cpref']"
        }
        else if `=strpos(" `cols' "," `lag_plain' ")>0' {
            local L "`L' + _b[`lag_plain']"
        }

        * HIGH + DIFF: add interaction lag if present
        if `=strpos(" `cols' "," `ih_lag_cpref' ")>0' {
            local H "`H' + _b[`ih_lag_cpref'] + _b[`lag_cpref']"
            local D "`D' + _b[`ih_lag_cpref']"
        }
        else if `=strpos(" `cols' "," `ih_lag_plain' ")>0' {
            local H "`H' + _b[`ih_lag_plain'] + _b[`lag_plain']"
            local D "`D' + _b[`ih_lag_plain']"
        }
    }

    return local low  = trim("`L'")
    return local high = trim("`H'")
    return local diff = trim("`D'")
end


/**************************************
 STEP 2) DEFINE BIN ROOTS (coldcut = 9)
**************************************/

local roots "below`coldcut'"
forvalues t = `coldcut'(3)39 {
    local roots "`roots' b3C_`t'"
}
local roots "`roots' above42"


/**************************************
 STEP 3) LOOP OVER REFERENCES (24–27 vs 27–30)
**************************************/

foreach refcode of local ref_list {

    * Choose sterfile + outfile based on refcode
    local sterfile ""
    local outfile  ""

    if "`refcode'"=="24" {
        local sterfile "`ster_ref24'"
        local outfile  "`out_ref24'"
    }
    else if "`refcode'"=="27" {
        local sterfile "`ster_ref27'"
        local outfile  "`out_ref27'"
    }

    * Skip if missing ster file
    cap confirm file "`sterfile'"
    if _rc {
        di as error "SKIP: Missing ster file for ref=`refcode': `sterfile'"
        continue
    }

    di as result "------------------------------------------------------------"
    di as result "Extracting coldle`coldcut' bin coefs with refcode = `refcode'"
    di as result "Input : `sterfile'"
    di as result "Output: `outfile'"
    di as result "------------------------------------------------------------"

    /**************************************
     STEP 3A) LOAD SAVED ESTIMATES (.ster)
    **************************************/
    estimates clear
    est use "`sterfile'"

    /**************************************
     STEP 3B) CREATE EMPTY RESULTS DATASET
    **************************************/
    clear
    set obs 0

    gen str12  bin_code = ""
    gen double temp_mid = .
    gen double low      = .
    gen double se_low   = .
    gen double high     = .
    gen double se_high  = .
    gen double diff     = .
    gen double se_diff  = .
    gen byte   is_ref   = .
    gen double ord      = .

    local row = 0

    /**************************************
     STEP 3C) EXTRACT BIN EFFECTS VIA LINCOM
    **************************************/
    foreach r of local roots {

        * root -> bin_code
        local code ""
        if "`r'"=="below`coldcut'"    local code "below`coldcut'"
        if "`r'"=="above42"          local code "above42"
        if substr("`r'",1,4)=="b3C_" local code = substr("`r'",5,.)   // "9","12",...,"39"

        * Skip reference (omitted in e(b))
        if "`code'"=="`refcode'" continue

        quietly __mkexpr_global, root("`r'")
        local L = r(low)
        local H = r(high)
        local D = r(diff)

        local ++row
        set obs `row'
        replace bin_code = "`code'" in `row'

        quietly lincom `L'
        replace low    = r(estimate) in `row'
        replace se_low = r(se)       in `row'

        quietly lincom `H'
        replace high    = r(estimate) in `row'
        replace se_high = r(se)       in `row'

        quietly lincom `D'
        replace diff    = r(estimate) in `row'
        replace se_diff = r(se)       in `row'
    }

    * Add reference bin explicitly (0 effect by construction)
    local ++row
    set obs `row'
    replace bin_code = "`refcode'" in `row'
    replace low      = 0 in `row'
    replace high     = 0 in `row'
    replace diff     = 0 in `row'
    replace se_low   = . in `row'
    replace se_high  = . in `row'
    replace se_diff  = . in `row'
    replace is_ref   = 1 in `row'

    * Fix is_ref defaults
    replace is_ref = 0 if missing(is_ref)

    /**************************************
     STEP 3D) COMPUTE TEMP MIDPOINTS (NO MERGE)
    **************************************/
    replace bin_code = trim(bin_code)
    replace temp_mid = .

    * tails (plot placement)
    replace temp_mid = `coldcut' - 6 if bin_code == "below`coldcut'"
    * If you prefer midpoint placement instead:
    * replace temp_mid = `coldcut' - 1.5 if bin_code == "below`coldcut'"

    replace temp_mid = 45 if bin_code == "above42"

    * numeric bins: midpoint = lb + 1.5
    replace temp_mid = real(bin_code) + 1.5 ///
        if missing(temp_mid) & regexm(bin_code, "^[0-9]+$")

    /**************************************
     STEP 3E) ORDERING + SORT
    **************************************/
    replace ord = temp_mid
    replace ord = -999 if bin_code=="below`coldcut'"
    replace ord =  999 if bin_code=="above42"
    sort ord

    /**************************************
     STEP 3F) EXPORT CSV
    **************************************/
    order bin_code temp_mid low se_low high se_high diff se_diff is_ref ord
    export delimited "`outfile'", replace
    di as result "Wrote: `outfile'"
}

cap log close
