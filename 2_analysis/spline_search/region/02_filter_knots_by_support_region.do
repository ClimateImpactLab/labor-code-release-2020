*-------------------------------------------------------------------------------
* 02_filter_knots_by_support_region.do
*-------------------------------------------------------------------------------
* PURPOSE
*   Build the regional knot candidate lists used in the region spline search
*
*   The file starts from the temperature support summaries created by
*   01_temperature_support_region.do. For each region, it builds candidate knot
*   triples from the region's own temperature percentiles, drops candidates that
*   fall outside the usable temperature range, checks how much data sits in each
*   spline segment, and saves the candidates that should be tested in the
*   region-level regressions.
*
* STEPS
*   1. Read the temperature support summaries
*   2. Build a percentile grid for each region
*   3. Convert the percentiles into temperature values
*   4. Drop candidates outside the region's usable temperature range
*   5. Check the share of data in each spline segment
*   6. Save one candidate file per region and one combined candidate file
*
* INPUTS
*   Region temperature support summaries and the global base with temperature powers
*
* OUTPUTS
*   Regional knot candidate CSV files used by the region knot-search script
*-------------------------------------------------------------------------------

version 16.1
clear all
set more off

*-------------------------------------------------------------------------------
* Paths
*-------------------------------------------------------------------------------
run "/project/cil/home_dirs/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"

local regression_data_dir "${ROOT_INT_DATA}/regression_ready_data"
local region_search_dir "${ROOT_INT_DATA}/spline_search/region"
local INDIR_SUPP     "`region_search_dir'/temp_support"
local OUTDIR         "`region_search_dir'/knots_filter"
local SUPPORTCSV     "`INDIR_SUPP'/temp_support_master_region.csv"
cap mkdir "`OUTDIR'"

global dataset "`regression_data_dir'/global_base_polys_tmax_nochn_no_ll_0_MASTER.dta"
local regions "EuropeUS LatinAmerica SouthAsia"

* Minimum tail share needed to let knots use the 1st or 99th percentile
local min_tail_share = 0.02

* Candidate knots are rounded to full degrees
local ROUND_INC = 1

* Width of the main temperature range, measured as p95 - p5
local W_NARROW = 8
local W_MID    = 12

* Small fallback grid used when the first candidate list is too short
local W_FALLBACK  = 6
local MIN_TARGET  = 20
local FG_HALFSPAN = 1
local FG_STEP     = 0.5

* Maximum number of candidates kept per region after filtering
local CAP_NARROW = 120
local CAP_MID    = 180
local CAP_WIDE   = 250

*-------------------------------------------------------------------------------
* Load temperature support summaries
*-------------------------------------------------------------------------------
import delimited using "`SUPPORTCSV'", varnames(1) clear
tempfile SUPPORT
save "`SUPPORT'", replace

*-------------------------------------------------------------------------------
* Master candidate file setup
*-------------------------------------------------------------------------------
tempname post_master
tempfile MASTER_CAND
* The output column is still called iso because the next script expects that name.
* In this file, the values are region names.
postfile `post_master' ///
    str20 iso double k1 double k2 double k3 ///
    double seg1_share double seg2_share double seg3_share double seg4_share ///
    double k1_min double k3_max byte tail_relaxed ///
    using "`MASTER_CAND'", replace

*-------------------------------------------------------------------------------
* Reduce very large candidate lists while keeping spread over k1, k2, and k3
*-------------------------------------------------------------------------------
cap program drop _thin_even
program define _thin_even
    syntax , cap(integer)
    quietly count
    local N = r(N)
    if (`N' <= `cap') exit
    sort k1 k2 k3
    gen long __seq = _n
    local stride = ceil(`N' / `cap')
    keep if mod(__seq-1, `stride')==0
    drop __seq
end

*-------------------------------------------------------------------------------
* Build candidates region by region
*-------------------------------------------------------------------------------
foreach region_name of local regions {

    di as res ">> building knot candidates for `region_name'"

    * Load this region's temperature support summary
    use "`SUPPORT'", clear
    keep if iso=="`region_name'"
    if _N!=1 {
        di as error "   support row missing for `region_name'"
        continue
    }

    local p1  = p1[1]
    local p5  = p5[1]
    local p10 = p10[1]
    local p25 = p25[1]
    local p50 = p50[1]
    local p75 = p75[1]
    local p90 = p90[1]
    local p95 = p95[1]
    local p99 = p99[1]
    local temp_width = `p95' - `p5'

    * Wider temperature ranges need a higher minimum share in each spline segment
    local min_seg_share = cond(`temp_width' < `W_NARROW', 0.005, cond(`temp_width' < `W_MID', 0.010, 0.020))

    * Load this region's estimation sample and weights
    use ${dataset}, clear
    gen real_temperature = tmax_p1

    gen sample_region = ""
    replace sample_region = "LatinAmerica" if iso == "BRA" | iso == "MEX"
    replace sample_region = "EuropeUS"     if iso == "FRA" | iso == "ESP" | iso == "GBR" | iso == "USA"
    replace sample_region = "SouthAsia"    if iso == "IND"
    keep if sample_region == "`region_name'"

    keep if mins_worked > 0
    drop if missing(real_temperature)

    capture confirm numeric variable real_temperature
    if _rc {
        tempvar rt_num
        gen double `rt_num' = real(real_temperature)
        drop real_temperature
        rename `rt_num' real_temperature
    }

    cap drop __w
    gen double __w = 1
    capture confirm variable risk_adj_sample_wgt
    if !_rc {
        capture confirm numeric variable risk_adj_sample_wgt
        if _rc destring risk_adj_sample_wgt, replace force
        replace __w = risk_adj_sample_wgt
    }
    replace __w = 1 if __w<=0 | missing(__w)
    quietly summarize __w, meanonly
    local total_weight = r(sum)

    * Check how much weight is in the lower and upper tails
    quietly summarize __w if real_temperature < `p5', meanonly
    local lower_tail_weight = r(sum)
    quietly summarize __w if real_temperature >= `p95', meanonly
    local upper_tail_weight = r(sum)

    local lower_tail_share = cond(`total_weight'>0, `lower_tail_weight'/`total_weight', 0)
    local upper_tail_share = cond(`total_weight'>0, `upper_tail_weight'/`total_weight', 0)

    local allow_low  = (`lower_tail_share'  >= `min_tail_share')
    local allow_high = (`upper_tail_share' >= `min_tail_share')

    local k1_min = cond(`allow_low',  `p1',  `p5')
    local k3_max = cond(`allow_high', `p99', `p95')

    di as txt "   temp_width=" %5.2f `temp_width' " | min_seg_share=" %5.3f `min_seg_share' ///
              " | k1_min=" %6.2f `k1_min' " | k3_max=" %6.2f `k3_max' ///
              " | tail_low=" %4.1f (100*`lower_tail_share') "% | tail_high=" %4.1f (100*`upper_tail_share') "%"

    tempfile BASE
    save `BASE', replace

*-------------------------------------------------------------------------------
* Choose percentile grids for the three knots
*-------------------------------------------------------------------------------
    * Wide-support regions get a slightly tighter grid so the number of candidate
    * regressions stays manageable. Narrower regions get a broader grid so the
    * search still has enough candidate triples.
    if (`temp_width' >= `W_MID') {
        * Wide-support regions
        preserve
            clear
            set obs 0
            gen double k1 = .
            forvalues p = 10(5)35 {
                set obs `=_N+1'
                replace k1 = `p' in L
            }
            tempfile K1P
            save `K1P', replace
        restore

        preserve
            clear
            set obs 0
            gen double k2 = .
            forvalues p = 50(5)70 {
                set obs `=_N+1'
                replace k2 = `p' in L
            }
            tempfile K2P
            save `K2P', replace
        restore

        preserve
            clear
            set obs 0
            gen double k3 = .
            forvalues p = 80(5)95 {
                set obs `=_N+1'
                replace k3 = `p' in L
            }
            * Keep the 99th percentile option for SouthAsia so the upper tail is covered
            if ("`region_name'"=="SouthAsia") {
                set obs `=_N+1'
                replace k3 = 99 in L
            }
            tempfile K3P
            save `K3P', replace
        restore
    }
    else {
        * Narrow or middle-support regions
        preserve
            clear
            set obs 0
            gen double k1 = .
            forvalues p = 10(5)40 {
                set obs `=_N+1'
                replace k1 = `p' in L
            }
            tempfile K1P
            save `K1P', replace
        restore

        preserve
            clear
            set obs 0
            gen double k2 = .
            forvalues p = 45(5)75 {
                set obs `=_N+1'
                replace k2 = `p' in L
            }
            tempfile K2P
            save `K2P', replace
        restore

        preserve
            clear
            set obs 0
            gen double k3 = .
            forvalues p = 80(5)98 {
                set obs `=_N+1'
                replace k3 = `p' in L
            }
            tempfile K3P
            save `K3P', replace
        restore
    }

*-------------------------------------------------------------------------------
* Combine the low, middle, and high knot percentiles
*-------------------------------------------------------------------------------
    * This creates every increasing k1-k2-k3 percentile triple before converting
    * percentiles into actual temperatures.
    use `K1P', clear
    cross using `K2P'
    keep if k1 < k2
    tempfile K12P
    save `K12P', replace

    use `K12P', clear
    cross using `K3P'
    keep if k2 < k3
    tempfile GRIDP
    save `GRIDP', replace

*-------------------------------------------------------------------------------
* Convert percentile triples into temperature triples
*-------------------------------------------------------------------------------
    * The percentiles are computed using the same risk-adjusted weights used in
    * the search regressions.
    preserve
        use `BASE', clear
        keep real_temperature __w
        _pctile real_temperature [pw=__w], p(1(1)99)
        clear
        set obs 99
        gen double pct  = _n
        gen double tval = .
        forvalues i = 1/99 {
            replace tval = r(r`i') in `i'
        }
        tempfile MAP
        save "`MAP'", replace
    restore

*-------------------------------------------------------------------------------
* Round and filter candidate temperatures
*-------------------------------------------------------------------------------
    * After rounding, different percentile triples can collapse to the same
    * temperature triple. Drop duplicates, require increasing knots, and keep only
    * candidates inside the usable temperature range for the region.
    use `GRIDP', clear

    rename k1 pct
    merge m:1 pct using "`MAP'", nogen keep(3)
    rename pct  k1_pct
    rename tval k1

    rename k2 pct
    merge m:1 pct using "`MAP'", nogen keep(3)
    rename pct  k2_pct
    rename tval k2

    rename k3 pct
    merge m:1 pct using "`MAP'", nogen keep(3)
    rename pct  k3_pct
    rename tval k3

    replace k1 = round(k1, `ROUND_INC')
    replace k2 = round(k2, `ROUND_INC')
    replace k3 = round(k3, `ROUND_INC')
    duplicates drop k1 k2 k3, force

    keep if k1 < k2 & k2 < k3
    keep if k1 >= `k1_min' & k3 <= `k3_max'

    tempfile GRIDF
    save `GRIDF', replace

*-------------------------------------------------------------------------------
* Add extra high-knot candidates for SouthAsia
*-------------------------------------------------------------------------------
    * SouthAsia's hot tail matters for the regional response function, so keep a
    * wider set of upper-knot values from 36 to 41 degrees.
    if ("`region_name'"=="SouthAsia") {
        preserve
            use `GRIDF', clear
            keep k1 k2
            duplicates drop k1 k2, force
            tempfile K12_FORCE
            save `K12_FORCE', replace
        restore

        preserve
            clear
            set obs 6
            gen double k3 = 35 + _n   // 36,37,38,39,40,41
            tempfile K3_FORCE
            save `K3_FORCE', replace
        restore

        use `K12_FORCE', clear
        cross using `K3_FORCE'
        keep if k2 < k3
        keep if k1 >= `k1_min' & k3 <= `k3_max'
        tempfile FORCE_TRIPLES
        save `FORCE_TRIPLES', replace

        use `GRIDF', clear
        append using `FORCE_TRIPLES'
        duplicates drop k1 k2 k3, force
        keep if k1 < k2 & k2 < k3
        keep if k1 >= `k1_min' & k3 <= `k3_max'
        save `GRIDF', replace
    }

*-------------------------------------------------------------------------------
* Add a small fallback grid if too few candidates remain
*-------------------------------------------------------------------------------
    * This only matters when the region has a narrow temperature range or the
    * first filters leave fewer than 20 candidate triples.
    use `GRIDF', clear
    quietly count
    local preN = r(N)

    if (`preN' < `MIN_TARGET') | (`temp_width' < `W_FALLBACK') {
        di as txt "   adding fallback grid around p25, p50, and p75"
        local lo1 = max(`k1_min', `p25' - `FG_HALFSPAN')
        local hi1 = min(`p50',    `p25' + `FG_HALFSPAN')
        local lo2 = max(`p25',    `p50' - `FG_HALFSPAN')
        local hi2 = min(`p90',    `p50' + `FG_HALFSPAN')
        local lo3 = max(`p50',    `p75' - `FG_HALFSPAN')
        local hi3 = min(`k3_max', `p75' + `FG_HALFSPAN')

        preserve
            clear
            set obs 0
            gen double k1 = .
            forvalues i = 0/`=round((`hi1'-`lo1')/`FG_STEP')' {
                local v = `lo1' + `i'*`FG_STEP'
                set obs `=_N+1'
                replace k1 = round(`v', `ROUND_INC') in L
            }
            tempfile K1F
            save `K1F', replace
        restore

        preserve
            clear
            set obs 0
            gen double k2 = .
            forvalues i = 0/`=round((`hi2'-`lo2')/`FG_STEP')' {
                local v = `lo2' + `i'*`FG_STEP'
                set obs `=_N+1'
                replace k2 = round(`v', `ROUND_INC') in L
            }
            tempfile K2F
            save `K2F', replace
        restore

        preserve
            clear
            set obs 0
            gen double k3 = .
            forvalues i = 0/`=round((`hi3'-`lo3')/`FG_STEP')' {
                local v = `lo3' + `i'*`FG_STEP'
                set obs `=_N+1'
                replace k3 = round(`v', `ROUND_INC') in L
            }
            tempfile K3F
            save `K3F', replace
        restore

        use `K1F', clear
        cross using `K2F'
        keep if k1 < k2
        tempfile K12F
        save `K12F', replace

        use `K12F', clear
        cross using `K3F'
        keep if k2 < k3
        keep if k1 >= `k1_min' & k3 <= `k3_max'

        append using `GRIDF'
        duplicates drop k1 k2 k3, force
        keep if k1 < k2 & k2 < k3
        keep if k1 >= `k1_min' & k3 <= `k3_max'
        save `GRIDF', replace
    }

*-------------------------------------------------------------------------------
* Check how much data falls in each spline segment
*-------------------------------------------------------------------------------
    * For EuropeUS and LatinAmerica, drop candidates if any spline segment has too
    * little data. For SouthAsia, keep the candidates but still save the segment
    * shares, because the hot-tail coverage is more important here.
    tempname post_region
    tempfile REGION_CANDS
    postfile `post_region' ///
        double k1 double k2 double k3 ///
        double seg1_share double seg2_share double seg3_share double seg4_share ///
        using "`REGION_CANDS'", replace

    use `GRIDF', clear
    quietly count
    local R = r(N)

    forvalues r = 1/`R' {

        su k1 in `r', meanonly
        local K1 = r(mean)
        su k2 in `r', meanonly
        local K2 = r(mean)
        su k3 in `r', meanonly
        local K3 = r(mean)

        use `BASE', clear

        quietly summarize __w if real_temperature < `K1', meanonly
        local S1 = r(sum)
        quietly summarize __w if real_temperature >= `K1' & real_temperature < `K2', meanonly
        local S2 = r(sum)
        quietly summarize __w if real_temperature >= `K2' & real_temperature < `K3', meanonly
        local S3 = r(sum)
        quietly summarize __w if real_temperature >= `K3', meanonly
        local S4 = r(sum)

        local sh1 = cond(`total_weight'>0, `S1'/`total_weight', 0)
        local sh2 = cond(`total_weight'>0, `S2'/`total_weight', 0)
        local sh3 = cond(`total_weight'>0, `S3'/`total_weight', 0)
        local sh4 = cond(`total_weight'>0, `S4'/`total_weight', 0)

        if ("`region_name'"=="SouthAsia") {
            * Keep SouthAsia candidates even when a segment is thin
            post `post_region' (`K1') (`K2') (`K3') (`sh1') (`sh2') (`sh3') (`sh4')
        }
        else {
            * Other regions must pass the segment-share rule
            if (`sh1' >= `min_seg_share' & `sh2' >= `min_seg_share' & `sh3' >= `min_seg_share' & `sh4' >= `min_seg_share') {
                post `post_region' (`K1') (`K2') (`K3') (`sh1') (`sh2') (`sh3') (`sh4')
            }
        }

        use `GRIDF', clear
    }
    postclose `post_region'

*-------------------------------------------------------------------------------
* Save this region's candidate list
*-------------------------------------------------------------------------------
    * If the list is still very large, thin it evenly before writing the region
    * file and adding its rows to the combined master file.
    use "`REGION_CANDS'", clear
    sort k1 k2 k3

    local CAP = cond(`temp_width' < `W_NARROW', `CAP_NARROW', cond(`temp_width' < `W_MID', `CAP_MID', `CAP_WIDE'))
    quietly count
    local Nprecap = r(N)
    if (`Nprecap' > `CAP') {
        _thin_even, cap(`CAP')
        di as txt "   thinned " `Nprecap' " -> " _N " (cap=" `CAP' ")"
    }

    gen str20 iso = "`region_name'"
    gen double k1_min = `k1_min'
    gen double k3_max = `k3_max'
    gen byte tail_relaxed = (`allow_low' | `allow_high')
    order iso k1 k2 k3 seg1_share seg2_share seg3_share seg4_share k1_min k3_max tail_relaxed
    sort k1 k2 k3

    export delimited using "`OUTDIR'/knot_candidates_`region_name'.csv", replace nolabel
    di as txt "   wrote: knot_candidates_`region_name'.csv (N=" _N ")"

    quietly {
        forvalues i = 1/`=_N' {
            su k1 in `i', meanonly
            local rk1 = r(mean)
            su k2 in `i', meanonly
            local rk2 = r(mean)
            su k3 in `i', meanonly
            local rk3 = r(mean)
            su seg1_share in `i', meanonly
            local rs1 = r(mean)
            su seg2_share in `i', meanonly
            local rs2 = r(mean)
            su seg3_share in `i', meanonly
            local rs3 = r(mean)
            su seg4_share in `i', meanonly
            local rs4 = r(mean)

            post `post_master' ("`region_name'") (`rk1') (`rk2') (`rk3') ///
                       (`rs1') (`rs2') (`rs3') (`rs4') ///
                       (`k1_min') (`k3_max') ( (`allow_low' | `allow_high') )
        }
    }
}

*-------------------------------------------------------------------------------
* Save combined candidate file
*-------------------------------------------------------------------------------
postclose `post_master'
use "`MASTER_CAND'", clear
order iso k1 k2 k3 seg1_share seg2_share seg3_share seg4_share k1_min k3_max tail_relaxed
export delimited using "`OUTDIR'/knot_candidates_master_region.csv", replace nolabel

di as res "Region knot candidates saved to `OUTDIR'/knot_candidates_master_region.csv"
