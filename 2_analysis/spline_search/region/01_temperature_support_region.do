*-------------------------------------------------------------------------------
* 01_temperature_support_region.do
*-------------------------------------------------------------------------------
* PURPOSE
*   Summarize the temperature range used by each regional estimation sample
*
* STEPS
*   1. Load the global base with temperature powers
*   2. Keep one regional sample at a time
*   3. Compute temperature percentiles and basic support checks
*   4. Save one summary file per region and one combined summary file
*
* INPUT
*   Global base file built by the global spline-search code
*
* OUTPUTS
*   Region temperature-support summaries used to filter candidate knots
*-------------------------------------------------------------------------------

version 16.1
clear all
set more off

*-------------------------------------------------------------------------------
* Paths and regions
*-------------------------------------------------------------------------------
run "/project/cil/home_dirs/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"

local regression_data_dir "${ROOT_INT_DATA}/regression_ready_data"
local region_search_dir "${ROOT_INT_DATA}/spline_search/region"
local OUTDIR "`region_search_dir'/temp_support"
cap mkdir "`OUTDIR'"

local MASTER "`OUTDIR'/temp_support_master_region.csv"
global dataset  "`regression_data_dir'/global_base_polys_tmax_nochn_no_ll_0_MASTER.dta"

*-------------------------------------------------------------------------------
* Master summary setup
*-------------------------------------------------------------------------------
tempname PM
tempfile MASTER_DTA
postfile `PM' str20 iso long N double min max p1 p5 p10 p25 p50 p75 p90 p95 p99 ///
                  str20 weight_used byte flag_tight_support using "`MASTER_DTA'", replace

local regions "LatinAmerica EuropeUS SouthAsia"


*-------------------------------------------------------------------------------
* Region loop
*-------------------------------------------------------------------------------
foreach region_name of local regions {

    use ${dataset}, clear

    gen real_temperature = tmax_p1

    gen sample_region = ""
    replace sample_region = "LatinAmerica" if iso == "BRA" | iso == "MEX"
    replace sample_region = "EuropeUS" if iso == "FRA" | iso == "ESP" | iso == "GBR" | iso == "USA"
    replace sample_region = "SouthAsia" if iso == "IND"

    * Keep this region
    keep if sample_region == "`region_name'"
	
    * Estimation sample
    keep if mins_worked > 0
    drop if missing(real_temperature)

    quietly count
    if r(N)==0 {
        * One-row file for empty regions
        preserve
            clear
            set obs 1
            gen str20  iso = "`region_name'"
            gen long  N   = 0
            foreach v in min max p1 p5 p10 p25 p50 p75 p90 p95 p99 {
                gen double `v' = .
            }
            gen str20 weight_used = "unweighted"
            gen byte  flag_tight_support = .
            order iso N min max p1 p5 p10 p25 p50 p75 p90 p95 p99 weight_used flag_tight_support
            export delimited using "`OUTDIR'/temp_support_`region_name'_summary.csv", replace nolabel
        restore

        * Add one empty row to the master file and continue
        post `PM' ("`region_name'") (0) (.) (.) (.) (.) (.) (.) (.) (.) (.) (.) ///
                 ("unweighted") (.)
        continue
    }

    * Make sure real_temperature is numeric
    capture confirm numeric variable real_temperature
    if _rc {
        tempvar rt_num
        gen double `rt_num' = real(real_temperature)
        drop real_temperature
        rename `rt_num' real_temperature
    }

    * Use risk-adjusted weights when available
    cap drop __w
    local weight_used "unweighted"

    capture confirm variable risk_adj_sample_wgt
    if !_rc {
        capture confirm numeric variable risk_adj_sample_wgt
        if _rc destring risk_adj_sample_wgt, replace force
        gen double __w = risk_adj_sample_wgt
        replace __w = . if __w<=0
        quietly count if __w>0
        if r(N)>0 local weight_used "risk_adj_sample_wgt"
        else drop __w
    }

    if ("`weight_used'"=="unweighted") {
        capture confirm variable risk_adj_sample_wgt
        if !_rc {
            capture confirm numeric variable risk_adj_sample_wgt
            if _rc destring risk_adj_sample_wgt, replace force
            gen double __w = risk_adj_sample_wgt
            replace __w = . if __w<=0
            quietly count if __w>0
            if r(N)>0 local weight_used "risk_adj_sample_wgt"
            else drop __w
        }
    }

    * Temperature support
    quietly count
    local N = r(N)
    quietly summarize real_temperature, meanonly
    local min = r(min)
    local max = r(max)

    * Weighted percentiles
    local WCLAUSE ""
    capture confirm variable __w
    if !_rc {
        quietly count if __w>0
        if r(N)>0 local WCLAUSE "[pw=__w]"
    }
    quietly _pctile real_temperature `WCLAUSE', p(1 5 10 25 50 75 90 95 99)
    local p1  = r(r1)
    local p5  = r(r2)
    local p10 = r(r3)
    local p25 = r(r4)
    local p50 = r(r5)
    local p75 = r(r6)
    local p90 = r(r7)
    local p95 = r(r8)
    local p99 = r(r9)

    * Tight-support flag
    local flag_tight = cond((`p95' - `p5') < 6, 1, 0)

    * Save one row for this region
    preserve
        clear
        set obs 1
        gen str20  iso  = "`iso'"
        gen long  N    = `N'
        gen double min = `min'
        gen double max = `max'
        gen double p1  = `p1'
        gen double p5  = `p5'
        gen double p10 = `p10'
        gen double p25 = `p25'
        gen double p50 = `p50'
        gen double p75 = `p75'
        gen double p90 = `p90'
        gen double p95 = `p95'
        gen double p99 = `p99'
        gen str20 weight_used = "`weight_used'"
        gen byte  flag_tight_support = `flag_tight'
        order iso N min max p1 p5 p10 p25 p50 p75 p90 p95 p99 weight_used flag_tight_support
        export delimited using "`OUTDIR'/temp_support_`region_name'_summary.csv", replace nolabel
    restore

    * Add row to master summary
    post `PM' ("`region_name'") (`N') (`min') (`max') ///
             (`p1') (`p5') (`p10') (`p25') (`p50') (`p75') (`p90') (`p95') (`p99') ///
             ("`weight_used'") (`flag_tight')
    }


*-------------------------------------------------------------------------------
* Save combined support summary
*-------------------------------------------------------------------------------
postclose `PM'
use "`MASTER_DTA'", clear
order iso N min max p1 p5 p10 p25 p50 p75 p90 p95 p99 weight_used flag_tight_support
export delimited using "`MASTER'", replace nolabel

di as res "02 complete. Master summary: `MASTER'"
