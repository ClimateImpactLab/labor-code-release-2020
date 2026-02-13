/****************************************************************************************
 extract_bin_coefs.do

 PURPOSE
 -------
 Extract binned-temperature regression effects (coefficients + standard errors) from
 saved Stata estimates files (.ster) produced by reghdfe, where the treatment is:

     (bins)##i.<riskvar>

 and bins are the global fixed 3°C bins (index-based naming):
     below0, b3C_14, ..., b3C_27, above42

 This version runs the extractor for both risk definitions:
   - riskvar = high_risk      (Agriculture only; "new" definition)
   - riskvar = high_risk_old  (Ag + Construction + Manufacturing; "old" definition)

 OUTPUT (CSV)
 ------------
 Writes plot-ready CSVs (one per risk definition) with one row per bin (incl. reference):
   - bin_code:  "below0", "14", ..., "27", "above42"
   - temp_mid:  midpoint temperature 
   - low, se_low:     
   - high, se_high:   
   - diff, se_diff:   HIGH - LOW difference 
   - is_ref:          1 if reference bin, else 0
   - ord:             plot ordering key (below0 first, above42 last)

 WRITTEN BY: Marine de Franciosi (mdefranciosi@uchicago.edu)
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
log using "${DIR_LOG}/extract_bin_coefs.smcl", replace

* Folder for extracted coefficients
global RF_OUT "${DIR_RF}/uninteracted_bins"
cap mkdir "$RF_OUT"

* Reference bin code (INDEX-BASED): 22 corresponds to [24,27]°C midpoint 25.5
local refcode "22"

/*
  Inputs:
  - Update these filenames to match what your regression scripts produce.
  - This code will safely SKIP a spec if the ster file is missing.
*/
local ster_highrisk     "${DIR_STER}/uninteracted_bins/uninteracted_bins_nochn_3C_ag.ster"
local ster_highrisk_old "${DIR_STER}/uninteracted_bins/uninteracted_bins_nochn_3C_oldrisk.ster"

local out_highrisk      "${RF_OUT}/uninteracted_bins_coefs_3C_highrisk.csv"
local out_highrisk_old  "${RF_OUT}/uninteracted_bins_coefs_3C_highrisk_old.csv"


/**************************************
 STEP 1) HELPER PROGRAM: BUILD LINCOM EXPRESSIONS
**************************************/

cap program drop __mkexpr_global
program define __mkexpr_global, rclass
    * Minimal change: accept riskvar() so interaction terms are correct for both specs
    syntax, root(string) riskvar(string)

    local cols : colnames e(b)

    * Initialize expressions
    local L "0"
    local H "0"
    local D "0"

    * Base term name variants
    local base_plain     "`root'"
    local base_cpref     "c.`root'"

    * Interaction term name variants
    local ih_base_plain  "1.`riskvar'#`base_plain'"
    local ih_base_cpref  "1.`riskvar'#`base_cpref'"

    * ---- Add contemporaneous main effect to LOW (if present) ----
    if `=strpos(" `cols' "," `base_cpref' ")>0' {
        local L "`L' + _b[`base_cpref']"
    }
    else if `=strpos(" `cols' "," `base_plain' ")>0' {
        local L "`L' + _b[`base_plain']"
    }

    * ---- Build HIGH and DIFF from contemporaneous interaction (if present) ----
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

    * ---- Add lags/leads root_v1..root_v6 if present ----
    forvalues j=1/6 {

        local lag_plain     "`root'_v`j'"
        local lag_cpref     "c.`root'_v`j'"

        local ih_lag_plain  "1.`riskvar'#`lag_plain'"
        local ih_lag_cpref  "1.`riskvar'#`lag_cpref'"

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
 STEP 2) DEFINE GLOBAL BIN ROOT LIST (INDEX-BASED)
**************************************/

local roots "below0"
forvalues c=14/27 {
    local roots "`roots' b3C_`c'"
}
local roots "`roots' above42"


/**************************************
 STEP 3) LOOP OVER RISK SPECS (NEW + OLD)
**************************************/

* spec list: riskvar | sterfile | outfile

local riskvars "high_risk high_risk_old"

foreach rv of local riskvars {

    * choose ster/out based on rv
    local sterfile ""
    local outfile  ""

    if "`rv'"=="high_risk" {
        local sterfile "`ster_highrisk'"
        local outfile  "`out_highrisk'"
    }
    else if "`rv'"=="high_risk_old" {
        local sterfile "`ster_highrisk_old'"
        local outfile  "`out_highrisk_old'"
    }

    * Skip if missing ster file (prevents annoying crashes)
    cap confirm file "`sterfile'"
    if _rc {
        di as error "SKIP: Missing ster file for `rv': `sterfile'"
        continue
    }

    di as result "------------------------------------------------------------"
    di as result "Extracting bin coefs for riskvar = `rv'"
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

    gen str10  bin_code = ""
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
        if "`r'"=="below0"  local code "below0"
        if "`r'"=="above42" local code "above42"
        if substr("`r'",1,4)=="b3C_" local code = substr("`r'",5,.)   // "14".."27"

        * Skip reference during extraction (it is omitted from e(b))
        if "`code'"=="`refcode'" continue

        quietly __mkexpr_global, root("`r'") riskvar("`rv'")
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

    * Fix is_ref defaults (avoid missings)
    replace is_ref = 0 if missing(is_ref)

    /**************************************
     STEP 3D) COMPUTE TEMP MIDPOINTS DIRECTLY (NO MERGE)
    **************************************/

    replace bin_code = trim(bin_code)
    replace temp_mid = .

    * tails
    replace temp_mid = -1.5 if bin_code == "below0"
    replace temp_mid = 43.5 if bin_code == "above42"

    * numeric bins 14..27:
    * midpoint = 1.5 + 3*(code - 14)
    replace temp_mid = 1.5 + 3*(real(bin_code) - 14) ///
        if missing(temp_mid) & inrange(real(bin_code), 14, 27)

    /**************************************
     STEP 3E) ORDERING + SORT
    **************************************/

    replace ord = temp_mid
    replace ord = -999 if bin_code=="below0"
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
