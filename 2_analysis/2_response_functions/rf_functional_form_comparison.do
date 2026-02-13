/****************************************************************************************
* rf_functional_form_comparison.do
* --------------------------------------------------------------------------------------
* PURPOSE
*   Build a single, consolidated temp×risk grid of predicted response functions for
*   multiple functional forms, normalized at a chosen reference temperature, and export
*   CSV ready for RMSE calculations. 
*
*   This master file consolidates predictions from:
*     (A) Binned (3°C) specification, interacted by i.high_risk
*     (B) Polynomial specifications (order 2, 3, 4), interacted by i.high_risk
*     (C) Restricted cubic spline (RCS), interacted by i.high_risk
*
* BIN SPECIFICATION (AG “new high-risk” spec)
*   - Cold tail merged:       below9   (<= 9°C)
*   - Interior 3°C bins:      9–12, 12–15, …, 39–42  (b3C_9, b3C_12, …, b3C_39)
*   - Hot tail merged:        above42  (>= 42°C)
*   - Reference bin omitted:  27–30°C  => b3C_27 omitted from regression
*
* NORMALIZATION
*   The output is normalized such that the predicted effect equals 0 at REF_TEMP
*   (e.g., REF_TEMP = 27). For polynomials and splines this is done by subtracting
*   their value at ref; for bins the ref interval is set to 0 by construction.
*
* OUTPUT
*   Writes one CSV:
*     ${DIR_RF}/functional_form_comparison_2026.csv
*
*   Output columns:
*     temp   : temperature grid value
*     risk   : "low" or "high"
*     bins   : binned RF prediction at temp for the given risk group
*     poly2  : 2nd-order polynomial RF prediction
*     poly3  : 3rd-order polynomial RF prediction
*     poly4  : 4th-order polynomial RF prediction
*     rcs    : RCS RF prediction
*
* AUTHOR
*   Marine de Franciosi
*
* LAST MODIFIED
*   2026-01-05
****************************************************************************************/

version 16.1
clear all
set more off


*****************
* 0) INITIALIZE
*****************

run "/project/cil/home_dirs/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"
run "${DIR_REPO_LABOR}/2_analysis/0_subroutines/functions.do"


* =============================================================================
* 1) USER SETTINGS
* =============================================================================

* Temperature grid used for functional form comparison
* (stored as a numlist macro for make_temp_dist)
numlist "-20(0.1)47"
global full_response `r(numlist)'

* ------------------------- BINS: AG spec -------------------------
local bins_ster_folder   "${DIR_STER}/uninteracted_bins"
local bins_ster_file     "uninteracted_bins_nochn_3C_coldle9_ref27_ag.ster"

* ---------------------- POLYNOMIALS (i.high_risk) ----------------------
local poly_ster_folder   "/project/cil/home_dirs/mdefranciosi/repos/labor-code-release-2020/output/ster/uninteracted_polynomials"
local poly_name_suffix   ""

* ---------------------- RCS SPLINE (i.high_risk) ----------------------
local rcs_ster_folder    "/project/cil/home_dirs/mdefranciosi/repos/labor-code-release-2020/output/ster/uninteracted_reg_comlohi"
local rcs_by_risk_file   "uninteracted_reg_by_risk_2026.ster"

* RCS knot locations (update if your spline regression used different knots)
local knot1 27
local knot2 28
local knot3 41

* ------------------------- BIN SPEC PARAMS ---------------------------
global coldcut 9
global ref_bin 27     // reference interior bin is 27–30 (b3C_27 omitted)



/********************************************************************************
* Helper 1: collect_bin_terms_ag
********************************************************************************/

cap program drop collect_bin_terms_ag
program define collect_bin_terms_ag
    syntax , bins(string) unint(string) int(string)

    * Bin boundaries (must match regression bin construction)
    global min_below9  = -30
    global max_below9  = ${coldcut}

    global min_above42 = 42
    global max_above42 = 60

    forval b = ${coldcut}(3)39 {
        global min_`b' = `b'
        global max_`b' = `b' + 3
    }

    * Create bin list: interior lower bounds + tails
    numlist "${coldcut}(3)39"
    global `bins' "`r(numlist)' above42 below9"

    * Coefficient expressions (sum contemporaneous + v1..v6)
    foreach bin in $`bins' {

        if ("`bin'" == "above42") local coef "above42"
        else if ("`bin'" == "below9") local coef "below9"
        else local coef "b3C_`bin'"

        #d ;
        global `unint'`bin' =
            "_b[`coef'] +" +
            "_b[`coef'_v1] +" +
            "_b[`coef'_v2] +" +
            "_b[`coef'_v3] +" +
            "_b[`coef'_v4] +" +
            "_b[`coef'_v5] +" +
            "_b[`coef'_v6] " ;

        global `int'`bin' =
            "_b[1.high_risk#c.`coef'] +" +
            "_b[1.high_risk#c.`coef'_v1] +" +
            "_b[1.high_risk#c.`coef'_v2] +" +
            "_b[1.high_risk#c.`coef'_v3] +" +
            "_b[1.high_risk#c.`coef'_v4] +" +
            "_b[1.high_risk#c.`coef'_v5] +" +
            "_b[1.high_risk#c.`coef'_v6] " ;
        #d cr
    }
end


/********************************************************************************
* Helper 2: collect_poly_risk
*   Builds polynomial coefficient expressions that match polynomial regressions
*   interacted by i.high_risk:
********************************************************************************/
cap program drop collect_poly_risk
program define collect_poly_risk
    syntax , order(integer) unint(string) int(string)

    forval degree = 1/`order' {

        #d ;
        global `unint'`degree' =
            "_b[tmax_p`degree'] +" +
            "_b[tmax_p`degree'_v1] +" +
            "_b[tmax_p`degree'_v2] +" +
            "_b[tmax_p`degree'_v3] +" +
            "_b[tmax_p`degree'_v4] +" +
            "_b[tmax_p`degree'_v5] +" +
            "_b[tmax_p`degree'_v6] " ;

        global `int'`degree' =
            "_b[1.high_risk#c.tmax_p`degree'] +" +
            "_b[1.high_risk#c.tmax_p`degree'_v1] +" +
            "_b[1.high_risk#c.tmax_p`degree'_v2] +" +
            "_b[1.high_risk#c.tmax_p`degree'_v3] +" +
            "_b[1.high_risk#c.tmax_p`degree'_v4] +" +
            "_b[1.high_risk#c.tmax_p`degree'_v5] +" +
            "_b[1.high_risk#c.tmax_p`degree'_v6] " ;
        #d cr
    }
end




* =============================================================================
* 2) PRODUCING GRID OF PREDICTED RESPONSE FUNCTIONS
* =============================================================================

local REF_TEMP 27

    di in yellow "============================================================"
    di in yellow "Building functional form comparison (REF_TEMP = `REF_TEMP')"
    di in yellow "============================================================"

    ********************************
    * A) Base grid: temp and ref
    ********************************
    clear
    qui make_temp_dist, list($full_response) ref(`REF_TEMP')
    tempfile base
    save `base', replace

    * Build master key: temp × risk (low/high)
    use `base', clear
    gen risk = "low"
    tempfile master_low
    save `master_low', replace

    use `base', clear
    gen risk = "high"
    tempfile master_high
    save `master_high', replace

    use `master_low', clear
    append using `master_high'
    sort temp risk
    tempfile master
    save `master', replace


    ********************************
    * B) BINS RF (i.high_risk)
    ********************************
    use `base', clear
    gen mins_worked = .   // required for predictnl

    est use "`bins_ster_folder'/`bins_ster_file'"
    collect_bin_terms_ag, bins(bins) unint(unint) int(int)

    gen bins_low  = .
    gen bins_high = .

    foreach bin in $bins {
        if "`bin'" == "${ref_bin}" continue

        * Low-risk prediction in this bin interval
        predictnl tmp_low  = ${unint`bin'} ///
            if temp < ${max_`bin'} & temp >= ${min_`bin'}

        * High-risk = low-risk + interaction increment
        predictnl tmp_high = ${unint`bin'} + ${int`bin'} ///
            if temp < ${max_`bin'} & temp >= ${min_`bin'}

        replace bins_low  = tmp_low  if missing(bins_low)  & temp < ${max_`bin'} & temp >= ${min_`bin'}
        replace bins_high = tmp_high if missing(bins_high) & temp < ${max_`bin'} & temp >= ${min_`bin'}

        drop tmp_low tmp_high
    }

    * Reference interval is normalized to 0 by construction (27–30°C here)
    replace bins_low  = 0 if temp < ${max_${ref_bin}} & temp >= ${min_${ref_bin}}
    replace bins_high = 0 if temp < ${max_${ref_bin}} & temp >= ${min_${ref_bin}}

    keep temp bins_low bins_high
    tempfile bins_wide
    save `bins_wide', replace

    * Reshape to long: temp × risk
    use `bins_wide', clear
    gen risk="low"
    rename bins_low bins
    keep temp risk bins
    tempfile bins_long_low
    save `bins_long_low', replace

    use `bins_wide', clear
    gen risk="high"
    rename bins_high bins
    keep temp risk bins
    append using `bins_long_low'
    sort temp risk
    tempfile bins_long
    save `bins_long', replace


    ********************************
    * C) POLYNOMIAL RF (i.high_risk), orders 2–4
    ********************************
    forval N_order=2/4 {

        use `base', clear
        gen mins_worked = .   // required for predictnl

        local poly_ster "uninteracted_polynomials_nochn_`N_order'`poly_name_suffix'.ster"
        est use "`poly_ster_folder'/`poly_ster'"

        collect_poly_risk, order(`N_order') unint(unint) int(int)

        * NOTE: leaving your behavior unchanged here (you asked not to change logic).
        * (If you ever see weird poly results across runs, consider explicitly clearing
        *  the globals low_predict/high_predict before building them.)
        global low_predict
        global high_predict

        forval p=1/`N_order' {
            global low_predict  = "$low_predict"  + "(${unint`p'}) * (temp^`p' - ref^`p')"
            global high_predict = "$high_predict" + "(${unint`p'} + ${int`p'}) * (temp^`p' - ref^`p')"
            if `p' != `N_order' {
                global low_predict  = "$low_predict"  + " + "
                global high_predict = "$high_predict" + " + "
            }
        }

        predictnl poly`N_order'_low  = $low_predict
        predictnl poly`N_order'_high = $high_predict

        keep temp poly`N_order'_low poly`N_order'_high
        tempfile poly_wide_`N_order'
        save `poly_wide_`N_order'', replace

        * Reshape to long: temp × risk
        use `poly_wide_`N_order'', clear
        gen risk="low"
        rename poly`N_order'_low poly`N_order'
        keep temp risk poly`N_order'
        tempfile poly_long_low_`N_order'
        save `poly_long_low_`N_order'', replace

        use `poly_wide_`N_order'', clear
        gen risk="high"
        rename poly`N_order'_high poly`N_order'
        keep temp risk poly`N_order'
        append using `poly_long_low_`N_order''
        sort temp risk
        tempfile poly_long_`N_order'
        save `poly_long_`N_order'', replace
    }


    ********************************
    * D) RCS RF (i.high_risk)
    ********************************
    use `base', clear
    gen mins_worked = .   // required for predictnl

    est use "`rcs_ster_folder'/`rcs_by_risk_file'"

    make_spline_terms `knot1' `knot2' `knot3'
    collect_spline_terms, splines(0 1) unint(unint) int(int)

    * Normalize at ref by subtracting spline basis at ref (ref_spline*)
    predictnl rcs_low  = (T_spline0 - ref_spline0) * (${unint0}) + ///
                         (T_spline1 - ref_spline1) * (${unint1})

    predictnl rcs_high = (T_spline0 - ref_spline0) * (${unint0} + ${int0}) + ///
                         (T_spline1 - ref_spline1) * (${unint1} + ${int1})

    keep temp rcs_low rcs_high
    tempfile rcs_wide
    save `rcs_wide', replace

    * Reshape to long: temp × risk
    use `rcs_wide', clear
    gen risk="low"
    rename rcs_low rcs
    keep temp risk rcs
    tempfile rcs_long_low
    save `rcs_long_low', replace

    use `rcs_wide', clear
    gen risk="high"
    rename rcs_high rcs
    keep temp risk rcs
    append using `rcs_long_low'
    sort temp risk
    tempfile rcs_long
    save `rcs_long', replace


    ********************************
    * E) Merge all into master + export
    ********************************
    use `master', clear

    merge 1:1 temp risk using `bins_long',    nogen
    merge 1:1 temp risk using `poly_long_2',  nogen
    merge 1:1 temp risk using `poly_long_3',  nogen
    merge 1:1 temp risk using `poly_long_4',  nogen
    merge 1:1 temp risk using `rcs_long',     nogen

    order temp risk bins poly2 poly3 poly4 rcs
    sort risk temp

    local outname "functional_form_comparison_2026.csv"

    export delim using "${DIR_RF}/`outname'", replace
    di in green "Wrote: ${DIR_RF}/`outname'"


