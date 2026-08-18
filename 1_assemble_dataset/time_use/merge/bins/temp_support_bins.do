********************************************************************************
* temp_support_bins.do
*
* PURPOSE:
*   Construct temperature-bin support distributions (weighted by 
*   risk_adj_sample_wgt) under alternative high-risk definitions and bin 
*   structures, and export plotting-ready CSV files.
*
*   These files are used to generate the temperature bin histograms displayed 
*   beneath the labor supply–temperature non-parametric (bin) response. 
*
*
* RISK DEFINITIONS:
*
*   1) high_risk  (definition post-revision)
*        = Agriculture only
*
*   2) high_risk_old  (pre-revision definition)
*        = Agriculture + Construction + Manufacturing
*
*   Support distributions are computed under both definitions to:
*     (i) document how temperature exposure differs across definitions, and
*     (ii) motivate the decision to merge cold-tail 3°C bins.
*
*   In the revised specification, the preferred cold-tail cutoff is:
*        Below 9°C
*   (We also evaluate Below 12°C as a robustness check.)
*
*
* BIN STRUCTURES PRODUCED:
*   (A) Baseline 3°C bins:
*         below0, 0–3, 3–6, ..., 39–42, above42
*       → exported for BOTH risk definitions
*
*   (B) Cold-tail merged bins (ag high_risk only):
*         below9, 9–12, ..., 39–42, above42
*         below12, 12–15, ..., 39–42, above42
*
* INPUT FILE:
*   Regression-ready dataset:
*   labor_dataset_splines_nochn_tmax_chn_prev_week_no_ll_0_agnonag_272841_0129.dta
*
*
* OUTPUT FILES:
*   ${DIR_RF}/uninteracted_bins_global_coef/
*       temp_support_global_weighted_risk.csv
*       temp_support_global_weighted_old_risk.csv
*       temp_support_global_weighted_risk_coldle9.csv
*       temp_support_global_weighted_risk_coldle12.csv
*
*
* AUTHOR: Marine de Franciosi (mdefranciosi@uchicago.edu)
* LAST MODIFIED: 12/11/2025
********************************************************************************


version 16.1
clear all
set more off


* ---------- paths ----------
run "/project/cil/home_dirs/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"

* ---------- inputs ----------
local data "${ROOT_INT_DATA}/regression_ready_data/labor_dataset_splines_nochn_tmax_chn_prev_week_no_ll_0_agnonag_272841_0129.dta"


global output_dir "${DIR_OUTPUT/temp_dist/temp_support_bins"
cap mkdir "$output_dir"


* =====================================================
* Helper: compute support and export (expects bin_code)
* =====================================================
capture program drop _support_export
program define _support_export

    * Required vars in memory:
    *   - `1' = risk variable name (0/1)
    *   - bin_code (string)
    *   - real_temperature (double) 
    *   - risk_adj_sample_wgt (double)

    args riskvar outfile coldcut

    * enforce 0/1 for riskvar
    cap confirm numeric variable `riskvar'
    if _rc destring `riskvar', replace force
    replace `riskvar' = (`riskvar'!=0) if !missing(`riskvar')
    recast byte `riskvar'

    * collapse to GLOBAL totals by bin × risk
    gen double wn = risk_adj_sample_wgt
    collapse (sum) wn, by(`riskvar' bin_code)

    * totals + shares within each risk group
    bys `riskvar': egen double W_total = total(wn)
    gen double wshare = cond(W_total > 0, wn / W_total, 0)

    * bin labels + midpoints
    gen str30 bin_range = ""
    gen double temp_mid = .

    * ---- tails and interior differ by whether coldcut is provided ----
    if "`coldcut'" == "" {
        * baseline: below0, 0–3,...,39–42, above42

        replace bin_range = "Below 0 °C" if bin_code=="below0"
        replace temp_mid  = -5           if bin_code=="below0"

        forvalues k = 14/27 {
            local lo = 0 + 3*(`k' - 14)
            local hi = `lo' + 3
            replace bin_range = "`lo'–`hi' °C"     if bin_code=="`k'"
            replace temp_mid  = (`lo' + `hi')/2    if bin_code=="`k'"
        }

        replace bin_range = "Above 42 °C" if bin_code=="above42"
        replace temp_mid  = 45            if bin_code=="above42"
    }
    else {
        * coldcut variant: below{coldcut}, coldcut..42 by 3, above42

        replace bin_range = "Below `coldcut' °C" if bin_code=="below`coldcut'"
        replace temp_mid  = `coldcut' - 1.5      if bin_code=="below`coldcut'"  // <9 -> 7.5, <12 -> 10.5

        replace bin_range = "Above 42 °C" if bin_code=="above42"
        replace temp_mid  = 45            if bin_code=="above42"

        * interior numeric bins: bin_code is "9","12",... (string)
        gen double lo_num = .
        replace lo_num = real(bin_code) if regexm(bin_code, "^[0-9]+$")

        replace bin_range = string(lo_num, "%9.0g") + "–" + string(lo_num+3, "%9.0g") + " °C" if !missing(lo_num)
        replace temp_mid  = lo_num + 1.5 if !missing(lo_num)

        drop lo_num
    }

    * risk label 
    gen str12 risk = cond(`riskvar'==1, "High-risk", "Low-risk")
    gen str20 risk_var = "`riskvar'"
    gen byte   risk_value = `riskvar'

    * plotting order (ordering bins)
    gen double ord = temp_mid
    replace ord = -999 if inlist(bin_code, "below0", "below`coldcut'")
    replace ord =  999 if bin_code=="above42"

    sort risk ord
    order risk risk_var risk_value bin_code bin_range temp_mid wn W_total wshare ord

    export delimited "`outfile'", replace
    di as result "Wrote: `outfile'"
end



* =====================================================
* Load once per variant (baseline vs coldcut loop)
* =====================================================

* ---------- load data ----------
use "`data'", clear
keep if mins_worked > 0

* ---------- temperature variable ----------
cap confirm variable real_temperature
if _rc {
    di as error "No temperature variable found (real_temperature)"
    exit 198
}
cap confirm numeric variable real_temperature
if _rc destring real_temperature, replace force
recast double real_temperature

* ---------- weight variable ----------
capture confirm variable risk_adj_sample_wgt
if _rc {
    di as error "Missing risk_adj_sample_wgt"
    exit 198
}
cap confirm numeric variable risk_adj_sample_wgt
if _rc destring risk_adj_sample_wgt, replace force
recast double risk_adj_sample_wgt

* =====================================================
* (A) Baseline bins (below0 + 3C bins + above42)
*     -> output for BOTH risk definitions
* =====================================================

* --- high_risk ---
preserve
    gen str12 bin_code = ""
    replace bin_code = "below0" if real_temperature < 0

    forvalues k = 14/27 {
        local lo = 0 + 3*(`k' - 14)
        local hi = `lo' + 3
        replace bin_code = "`k'" if real_temperature >= `lo' & real_temperature < `hi'
    }

    replace bin_code = "above42" if real_temperature >= 42
    drop if bin_code == "" | missing(bin_code)

    _support_export high_risk ///
        "${output_dir}/temp_support_global_weighted_risk.csv" ""
restore

* --- high_risk_old ---
preserve
    gen str12 bin_code = ""
    replace bin_code = "below0" if real_temperature < 0

    forvalues k = 14/27 {
        local lo = 0 + 3*(`k' - 14)
        local hi = `lo' + 3
        replace bin_code = "`k'" if real_temperature >= `lo' & real_temperature < `hi'
    }

    replace bin_code = "above42" if real_temperature >= 42
    drop if bin_code == "" | missing(bin_code)

    _support_export high_risk_old ///
        "${output_dir}/temp_support_global_weighted_old_risk.csv" ""
restore


* =====================================================
* (B) Cold-tail merged variants (<9 and <12), high_risk only
* =====================================================
foreach coldcut in 9 12 {

    preserve
        gen str12 bin_code = ""

        * cold tail
        replace bin_code = "below`coldcut'" if real_temperature < `coldcut'

        * interior 3C bins: coldcut..42 by 3 (up to 39–42)
        forvalues lo = `coldcut'(3)39 {
            local hi = `lo' + 3
            replace bin_code = "`lo'" if real_temperature >= `lo' & real_temperature < `hi'
        }

        * upper tail
        replace bin_code = "above42" if real_temperature >= 42

        drop if bin_code == "" | missing(bin_code)

        _support_export high_risk "${output_dir}/temp_support_global_weighted_risk_coldle`coldcut'.csv" "`coldcut'"
    restore
}

di as result "All global temperature-support outputs generated in: ${output_dir}"
