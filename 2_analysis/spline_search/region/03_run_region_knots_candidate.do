*-------------------------------------------------------------------------------
* 03_run_region_knots_candidate.do
*-------------------------------------------------------------------------------
* PURPOSE
*   Run the knot-search regressions for one region
*
*   The Slurm scripts set the region name and, if needed, an array chunk. This
*   file reads the candidate knots for that region, builds the spline terms for
*   each knot triple, runs the region regression, and writes one small CSV row
*   with the within R2. 
* 	Those rows are later combined by 04_merge_region_knots_outputs.R 
*
* STEPS
*   1. Read the region name and Slurm array chunk
*   2. Load the candidate knot triples for that region
*   3. Build spline terms from the daily climate data for each country
*   4. Merge the spline terms back to the region sample
*   5. Rebuild the weights on the region sample
*   6. Run the regression and save one CSV row per knot triple
*
* INPUTS
*   Global base with temperature powers and the filtered regional knot grid
*
* OUTPUTS
*   Row-level R2 CSVs used to rank candidate knots by region
*-------------------------------------------------------------------------------

version 16.1
clear all
set more off
set rmsg on
set trace off

local NPROC = real("`: env SLURM_CPUS_PER_TASK'")
if missing(`NPROC') local NPROC = 8
set processors `NPROC'

run "/project/cil/home_dirs/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"

local LOGDIR "${DIR_REPO_LABOR}/2_analysis/spline_search/region/logs"
cap mkdir "`LOGDIR'"

*-------------------------------------------------------------------------------
* Region and Slurm inputs
*-------------------------------------------------------------------------------

local ISO  = trim("`: env ISO'")
if "`ISO'" == "" local ISO "EuropeUS"

local ARRID = real("`: env SLURM_ARRAY_TASK_ID'")
if missing(`ARRID') local ARRID = 1

local BATCH = real("`: env BATCH_SIZE'")
if missing(`BATCH') local BATCH = 9999

capture log close
log using "`LOGDIR'/03_run_region_knots_candidate_`ISO'_`ARRID'.log", replace text

di as res ">> REGION=`ISO' | ARRID=`ARRID' | BATCH_SIZE=`BATCH' | processors=`NPROC'"

*-------------------------------------------------------------------------------
* Paths and input files
*-------------------------------------------------------------------------------

run "${DIR_REPO_LABOR}/2_analysis/0_subroutines/functions.do"

local regression_data_dir "${ROOT_INT_DATA}/regression_ready_data"
local BASE "`regression_data_dir'/global_base_polys_tmax_nochn_no_ll_0_MASTER.dta"
confirm file "`BASE'"

local region_search_dir "${ROOT_INT_DATA}/spline_search/region"
local KNCSV "`region_search_dir'/knots_filter/knot_candidates_master_region.csv"
confirm file "`KNCSV'"

global DIR_R2       "`region_search_dir'/r2_output"
global DIR_SIDECAR  "${DIR_R2}/sidecars"
global DIR_SIDE_ISO "${DIR_SIDECAR}/`ISO'"

cap mkdir "`region_search_dir'"
cap mkdir "${DIR_R2}"
cap mkdir "${DIR_SIDECAR}"
cap mkdir "${DIR_SIDE_ISO}"

* SouthAsia also writes a second set of rows using adj_sample_wgt
global DIR_SIDE_ISO_ADJ "${DIR_SIDECAR}/`ISO'_adjwgt"
if "`ISO'"=="SouthAsia" cap mkdir "${DIR_SIDE_ISO_ADJ}"

*-------------------------------------------------------------------------------
* Region membership and climate admin level
*-------------------------------------------------------------------------------

cap program drop _countries_for_region
program define _countries_for_region, rclass
    syntax , region(string)
    if "`region'"=="LatinAmerica"        return local countries "MEX BRA"
    else if "`region'"=="EuropeUS"       return local countries "FRA GBR ESP USA"
    else if "`region'"=="SouthAsia"      return local countries "IND"
    else {
        di as err "Unknown region: `region' (expected EuropeUS, LatinAmerica, or SouthAsia)"
        exit 198
    }
end

cap program drop _adm_level_for_country
program define _adm_level_for_country, rclass
    syntax , iso(string)
    if inlist("`iso'","FRA","GBR","ESP")            return local adm "adm1"
    else if inlist("`iso'","USA","MEX","IND","BRA") return local adm "adm2"
    else {
        di as err "Unknown iso in _adm_level_for_country: `iso'"
        exit 198
    }
end

*-------------------------------------------------------------------------------
* Load daily temperature powers
*-------------------------------------------------------------------------------

cap program drop _load_climate_polys
program define _load_climate_polys
    args iso adm
    tempname ok
    scalar `ok' = 0
    capture noisily use "${ROOT_INT_DATA}/climate/final/`iso'/`adm'/GMFD_`iso'_tmax_polynomials_`adm'.dta", clear
    if _rc==0 scalar `ok' = 1
    if `ok'==0 {
        capture noisily use "${ROOT_INT_DATA}/climate/final/`iso'/`adm'/GMFD_`iso'_tmax_polynomials_nochn_`adm'.dta", clear
        if _rc==0 scalar `ok' = 1
    }
    if `ok'==0 {
        capture noisily use "${ROOT_INT_DATA}/climate/final/`iso'/`adm'/GMFD_`iso'_tmax_polynomials_wchn_`adm'.dta", clear
        if _rc==0 scalar `ok' = 1
    }
    if `ok'==0 {
        di as err "Cannot find climate tmax_polynomials for `iso'/`adm'"
        exit 198
    }
end

*-------------------------------------------------------------------------------
* Build daily exposure lags
*-------------------------------------------------------------------------------

cap program drop _mk_dayslots_panel
program define _mk_dayslots_panel
    syntax varlist
    quietly {
        tempvar __dow
        gen byte `__dow' = dow(date)
        foreach v of local varlist {
            forvalues i = 1/6 {
                local j = 7-`i'
                cap drop `v'_v`i'
                gen double `v'_v`i' = F`j'.`v'
                replace `v'_v`i' = L`i'.`v' if `__dow' >= `i'
            }
        }
        drop `__dow'
    }
end

*-------------------------------------------------------------------------------
* Build weekly exposure terms for Brazil and Mexico
*-------------------------------------------------------------------------------

cap program drop _weekly_sum_and_repeat
program define _weekly_sum_and_repeat
    syntax varlist
    quietly {
        foreach v of local varlist {
            tempvar w
            gen double `w' = `v'
            forvalues i=1/6 {
                replace `w' = `w' + L`i'.`v'
            }
            replace `v' = `w'
            drop `w'
            forvalues i=1/6 {
                cap drop `v'_v`i'
                gen double `v'_v`i' = `v'
            }
        }
    }
end

*-------------------------------------------------------------------------------
* Build spline terms for this knot triple
*-------------------------------------------------------------------------------

cap program drop _make_rcs_from_raw_polys
program define _make_rcs_from_raw_polys
    args K1 K2 K3
    foreach z in 1 2 3 {
        confirm variable tmax_p`z'
    }
    cap drop tmax_rcspl_3kn_t0_raw tmax_rcspl_3kn_t1_raw
    gen double tmax_rcspl_3kn_t0_raw = tmax_p1
    gen double tmax_rcspl_3kn_t1_raw = 0
    replace tmax_rcspl_3kn_t1_raw = (tmax_p3 - 3*`K1'*tmax_p2 + 3*(`K1'^2)*tmax_p1 - (`K1'^3)) if tmax_p1 >= `K1'
    replace tmax_rcspl_3kn_t1_raw = tmax_rcspl_3kn_t1_raw ///
        - (tmax_p3 - 3*`K2'*tmax_p2 + 3*(`K2'^2)*tmax_p1 - (`K2'^3)) * ((`K3'-`K1')/(`K3'-`K2')) if tmax_p1 >= `K2'
    replace tmax_rcspl_3kn_t1_raw = tmax_rcspl_3kn_t1_raw ///
        + (tmax_p3 - 3*`K3'*tmax_p2 + 3*(`K3'^2)*tmax_p1 - (`K3'^3)) * ((`K2'-`K1')/(`K3'-`K2')) if tmax_p1 >= `K3'
end

*-------------------------------------------------------------------------------
* Load this region's candidate knots
*-------------------------------------------------------------------------------

tempfile ISO_KNOTS
preserve
    import delimited using "`KNCSV'", varnames(1) clear
    capture confirm variable k1
    if _rc {
        cap rename knot1 k1
        cap rename knot2 k2
        cap rename knot3 k3
    }
    confirm variable iso

    keep if iso == "`ISO'"
    keep iso k1 k2 k3
    count
    if r(N)==0 {
        di as error "No rows for REGION=`ISO' in knots CSV"
        log close
        exit 198
    }

    gen long __row = _n
    local N = _N

    local start = (`ARRID' - 1)*`BATCH' + 1
    local end   = min(`ARRID'*`BATCH', `N')
    if (`start' > `N') {
        di as txt "Nothing to do for ARRID=`ARRID'"
        restore
        log close
        exit 0
    }

    keep if inrange(__row, `start', `end')
    order iso k1 k2 k3
    save "`ISO_KNOTS'", replace
restore

*-------------------------------------------------------------------------------
* Loop over candidate knot triples
*-------------------------------------------------------------------------------

use "`ISO_KNOTS'", clear
quietly count
local shardN = r(N)

forvalues r = 1/`shardN' {

    local k1val = k1[`r']
    local k2val = k2[`r']
    local k3val = k3[`r']

    local k1s = string(round(`k1val'), "%9.0f")
    local k2s = string(round(`k2val'), "%9.0f")
    local k3s = string(round(`k3val'), "%9.0f")

    * One small CSV is written per knot triple
    local SIDECAR_MAIN "${DIR_SIDE_ISO}/`ISO'_`k1s'_`k2s'_`k3s'.csv"
    local SIDECAR_ADJ  "${DIR_SIDE_ISO_ADJ}/`ISO'_`k1s'_`k2s'_`k3s'.csv"

    * Skip knot triples that already have output files
    cap confirm file "`SIDECAR_MAIN'"
    local main_exists = (_rc==0)

    local adj_exists = 0
    if "`ISO'"=="SouthAsia" {
        cap confirm file "`SIDECAR_ADJ'"
        local adj_exists = (_rc==0)
    }

    if "`ISO'"!="SouthAsia" & `main_exists' {
        di as txt "Skip existing: `SIDECAR_MAIN'"
        continue
    }
    if "`ISO'"=="SouthAsia" & `main_exists' & `adj_exists' {
        di as txt "Skip existing (both specs): `SIDECAR_MAIN' and `SIDECAR_ADJ'"
        continue
    }

    di as res ">>> REGION=`ISO' ARRID=`ARRID' knots=(`k1val',`k2val',`k3val')"

    preserve
        quietly _countries_for_region, region("`ISO'")
        local REG_CNTS = r(countries)

        * Build the region sample one country at a time
        tempfile STACK
        clear
        save "`STACK'", emptyok replace

        foreach cISO of local REG_CNTS {

            di as txt "    -> country `cISO'"

            quietly _adm_level_for_country, iso("`cISO'")
            local cADM = r(adm)

            * Person-level rows for this country
            tempfile SLICE
            use "`BASE'", clear
            keep if iso=="`cISO'" & mins_worked>0

            * Common admin id used for the climate merge
            gen long adm_id = `cADM'_id
            save "`SLICE'", replace

            * Daily climate data for this country
            tempfile CLIM
            _load_climate_polys "`cISO'" "`cADM'"

            capture confirm variable date
            if _rc {
                confirm variable year
                confirm variable month
                confirm variable day
                gen int date = mdy(month, day, year)
            }
            format date %td

            tsset `cADM'_id date

            * Build spline terms for this knot triple
            _make_rcs_from_raw_polys `k1val' `k2val' `k3val'

            * Match the exposure timing used in the main data construction
            gen byte __weekly = inlist("`cISO'","BRA","MEX")

            if __weekly {
                gen double tmax_rcspl_3kn_t0 = tmax_rcspl_3kn_t0_raw
                gen double tmax_rcspl_3kn_t1 = tmax_rcspl_3kn_t1_raw
                _weekly_sum_and_repeat tmax_rcspl_3kn_t0 tmax_rcspl_3kn_t1
            }
            else {
                gen double tmax_rcspl_3kn_t0 = tmax_rcspl_3kn_t0_raw*sqrt(7)
                gen double tmax_rcspl_3kn_t1 = tmax_rcspl_3kn_t1_raw*sqrt(7)
                _mk_dayslots_panel tmax_rcspl_3kn_t0 tmax_rcspl_3kn_t1
            }
            drop __weekly

            * Keep the variables needed for the merge
            cap drop iso
            gen str3 iso = "`cISO'"
            gen long adm_id = `cADM'_id

            keep iso adm_id date tmax_rcspl_3kn_t0 tmax_rcspl_3kn_t1 ///
                 tmax_rcspl_3kn_t0_v* tmax_rcspl_3kn_t1_v*

            save "`CLIM'", replace

            * Merge the new spline terms to the person-level rows
            use "`SLICE'", clear
            merge m:1 iso adm_id date using "`CLIM'", nogen keep(3)

            * Add this country to the region sample
            append using "`STACK'"
            save "`STACK'", replace
        }

        * Load the full region sample for this knot triple
        use "`STACK'", clear

        * Build controls and treatment terms
        gen_controls_and_FEs
        gen_treatment_splines rcspl 3 tmax this_week 1

        local reg_treat   (${vars_T_splines})##i.high_risk
        local reg_ctrl    (${usual_controls})##i.high_risk

        * Fixed effects used in the region regressions
        local FE_MACRO "fe_adm0_wk"
        if "`ISO'"=="SouthAsia" local FE_MACRO "fe_adm0_wk_country_spec"

        local reg_fe ""
        foreach f in $`FE_MACRO' {
            local reg_fe `reg_fe' `f'#high_risk
        }

        *-----------------------------------------------------------------------
        * Rebuild weights after stacking the countries in this region
        *-----------------------------------------------------------------------

        * Drop weights from the global base before rebuilding region weights
        foreach w in adj_sample_wgt pop_adj_sample_wgt risk_adj_sample_wgt ///
                    risk_prop risk_sum total_risk_share weight __nrows __raw_adj __sum_adj {
            cap drop `w'
        }

        * Use equal survey weights if sample_wgt is missing
        cap confirm variable sample_wgt
        if _rc gen double sample_wgt = 1
        replace sample_wgt = 1 if missing(sample_wgt)

        * Rebuild survey weights within each country
        bys iso ind_id: gen double __nrows = _N
        gen double weight = 1/__nrows
        gen double __raw_adj = weight * sample_wgt
        bys iso: egen double __sum_adj = total(__raw_adj)
        gen double adj_sample_wgt = __raw_adj/__sum_adj
        drop __nrows __raw_adj __sum_adj

        * Add population weights across the full region sample
        confirm variable adm0_pop
        gen double pop_adj_sample_wgt = adm0_pop * adj_sample_wgt
        quietly summarize pop_adj_sample_wgt, meanonly
        replace pop_adj_sample_wgt = pop_adj_sample_wgt / r(sum)

        * Add the risk-share adjustment used by the main regressions
        bys iso high_risk: gen double risk_prop = _N
        bys iso: replace risk_prop = risk_prop / _N

        gen double risk_adj_sample_wgt = pop_adj_sample_wgt * risk_prop

        bys high_risk: egen double risk_sum = total(risk_adj_sample_wgt)
        gen double total_risk_share = _N
        bys high_risk: replace total_risk_share = _N / total_risk_share

        replace risk_adj_sample_wgt = risk_adj_sample_wgt / risk_sum * total_risk_share
        drop risk_sum total_risk_share

        *-----------------------------------------------------------------------
        * Run regressions and write one result row
        *-----------------------------------------------------------------------

        * Main weight specification: risk_adj_sample_wgt
        if !`main_exists' {

            reghdfe mins_worked `reg_treat' `reg_ctrl' ///
                [pweight = risk_adj_sample_wgt], absorb(`reg_fe') vce(cl cluster_adm1yymm) resid

            tempvar __inc __uhat __uhat2 __t1
            gen byte `__inc' = e(sample)

            count if `__inc'
            local Ntot = r(N)
            scalar __r2w = e(r2_within)
            local rmse   = e(rmse)

            predict double `__uhat' if `__inc', resid
            gen double `__uhat2' = `__uhat'^2 if `__inc'
            quietly total `__uhat2' if `__inc'
            local rss_unw = r(sum)

            gen double `__t1' = tmax_rcspl_3kn_t1 if `__inc'
            quietly summarize `__t1', meanonly
            local sd1 = r(sd)
            if missing(`sd1') local sd1 = 0

            di as res "DONE REGION=`ISO' WEIGHT=risk_adj_sample_wgt knots=(`k1val',`k2val',`k3val') within_R2=" %20.16f __r2w " N=" `Ntot'

            cap file close f1
            file open f1 using "`SIDECAR_MAIN'", write replace
            file write f1 "iso,k1,k2,k3,within_r2,N,rmse,rss_unw,sd_spline1" _n

            local k1_out = string(`k1val',      "%12.6f")
            local k2_out = string(`k2val',      "%12.6f")
            local k3_out = string(`k3val',      "%12.6f")
            local r2ws   = string(__r2w,        "%20.16f")
            local Ns     = string(`Ntot',       "%12.0f")
            local rmse_s = string(`rmse',       "%20.16f")
            local rss_s  = string(`rss_unw',    "%20.16f")
            local sd1_s  = string(`sd1',        "%20.16f")

            file write f1 "`ISO',`k1_out',`k2_out',`k3_out',`r2ws',`Ns',`rmse_s',`rss_s',`sd1_s'" _n
            file close f1

            di as res "Sidecar written: `SIDECAR_MAIN'"
        }

        * Extra SouthAsia check using adj_sample_wgt
        if "`ISO'"=="SouthAsia" & !`adj_exists' {

            reghdfe mins_worked `reg_treat' `reg_ctrl' ///
                [pweight = adj_sample_wgt], absorb(`reg_fe') vce(cl cluster_adm1yymm) resid

            tempvar __incA __uhatA __uhat2A __t1A
            gen byte `__incA' = e(sample)

            count if `__incA'
            local NtotA = r(N)
            scalar __r2wA = e(r2_within)
            local rmseA   = e(rmse)

            predict double `__uhatA' if `__incA', resid
            gen double `__uhat2A' = `__uhatA'^2 if `__incA'
            quietly total `__uhat2A' if `__incA'
            local rss_unwA = r(sum)

            gen double `__t1A' = tmax_rcspl_3kn_t1 if `__incA'
            quietly summarize `__t1A', meanonly
            local sd1A = r(sd)
            if missing(`sd1A') local sd1A = 0

            di as res "DONE REGION=`ISO' WEIGHT=adj_sample_wgt knots=(`k1val',`k2val',`k3val') within_R2=" %20.16f __r2wA " N=" `NtotA'

            cap file close f2
            file open f2 using "`SIDECAR_ADJ'", write replace
            file write f2 "iso,k1,k2,k3,within_r2,N,rmse,rss_unw,sd_spline1" _n

            local k1_outA = string(`k1val',      "%12.6f")
            local k2_outA = string(`k2val',      "%12.6f")
            local k3_outA = string(`k3val',      "%12.6f")
            local r2wsA   = string(__r2wA,       "%20.16f")
            local NsA     = string(`NtotA',      "%12.0f")
            local rmse_sA = string(`rmseA',      "%20.16f")
            local rss_sA  = string(`rss_unwA',   "%20.16f")
            local sd1_sA  = string(`sd1A',       "%20.16f")

            file write f2 "`ISO',`k1_outA',`k2_outA',`k3_outA',`r2wsA',`NsA',`rmse_sA',`rss_sA',`sd1_sA'" _n
            file close f2

            di as res "Sidecar written: `SIDECAR_ADJ'"
        }

    restore
}

di as result "Done region knot search for REGION=`ISO' ARRID=`ARRID' (rows `start'..`end')."
log close
exit 0
