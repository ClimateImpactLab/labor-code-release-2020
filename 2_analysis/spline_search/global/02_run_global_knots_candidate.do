*-------------------------------------------------------------------------------
* 02_run_global_knots_candidate.do
*-------------------------------------------------------------------------------
* PURPOSE
*   Run one global 3-knot candidate from the knot grid
*
* HOW TO RUN
*   Use slurm/run_global_knots.sbatch. The Slurm array passes one row number to
*   this file, so the 320 candidate knot triples can run as separate Stata jobs.
*   Each regression takes about 2 hours.
*
* STEPS
*   1. Read one knot triple from the candidate-knot CSV
*   2. Load the global base built by 01_build_global_base.do
*   3. Build spline terms for that knot triple
*   4. Run the high-risk/low-risk regression
*   5. Save the estimates and one CSV row with within R2
*
* INPUTS
*   Global base with temperature powers, plus within_R2_original.csv with the
*   candidate knots
*
* OUTPUTS
*   One ster file and one row-level CSV for this knot triple
*-------------------------------------------------------------------------------

version 16.1
clear all
set more off
set rmsg on
set processors 6

*-------------------------------------------------------------------------------
* Knot-grid row passed by the Slurm array
*-------------------------------------------------------------------------------
local knot_grid_row 1
if "`0'" != "" {
    local stata_args "`0'"
    if regexm("`stata_args'","row\(([0-9]+)\)") {
        local knot_grid_row = real(regexs(1))
    }
}
di as res ">>>> knot grid row = `knot_grid_row'"

*-------------------------------------------------------------------------------
* Stata packages
*-------------------------------------------------------------------------------
cap which reghdfe
if _rc ssc install reghdfe, replace
cap which ftools
if _rc ssc install ftools, replace
cap which ivreg2
if _rc ssc install ivreg2, replace
cap which estout
if _rc ssc install estout, replace
cap which moremata
if _rc ssc install moremata, replace
cap which egenmore
if _rc ssc install egenmore, replace
cap which ranktest
if _rc ssc install ranktest, replace

*-------------------------------------------------------------------------------
* Paths and inputs
*-------------------------------------------------------------------------------
run "/project/cil/home_dirs/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"
run "${DIR_REPO_LABOR}/2_analysis/0_subroutines/functions.do"

* Base has admin-level temperature powers and ready-to-use precip terms
local regression_data_dir "${ROOT_INT_DATA}/regression_ready_data"
local global_base_file "`regression_data_dir'/global_base_polys_tmax_nochn_no_ll_0_MASTER.dta"
confirm file "`global_base_file'"

local spline_search_dir "${ROOT_INT_DATA}/spline_search/global"

* Candidate knot grid: one row is one knot triple
local knot_grid_csv "`spline_search_dir'/inputs/within_R2_original.csv"
confirm file "`knot_grid_csv'"

* CSV output for this candidate
cap mkdir "`spline_search_dir'"
cap mkdir "`spline_search_dir'/results"
local candidate_result_csv "`spline_search_dir'/results/full_run_row`knot_grid_row'.csv"

* Regression estimates for this candidate
local ster_dir "`spline_search_dir'/ster"
cap mkdir "`ster_dir'"

*-------------------------------------------------------------------------------
* Read this knot triple
*-------------------------------------------------------------------------------
tempfile selected_knot_row
preserve
    import delimited using "`knot_grid_csv'", varnames(1) clear
    cap confirm variable knot1
    if _rc {
        cap rename k1 knot1
        cap rename k2 knot2
        cap rename k3 knot3
    }
    keep knot1 knot2 knot3
    count
    if r(N)==0 | `knot_grid_row' > _N {
        di as error "Invalid knot-grid row: `knot_grid_row'"
        exit 198
    }
    keep in `knot_grid_row'
    gen id = `knot_grid_row'
    save "`selected_knot_row'", replace
restore

*-------------------------------------------------------------------------------
* Small programs used below
*-------------------------------------------------------------------------------

* Admin level used for the climate merge
cap program drop _adm_level_for_iso
program define _adm_level_for_iso, rclass
    syntax , iso(string)
    if inlist("`iso'","FRA","GBR","ESP")  return local adm "adm1"
    else if inlist("`iso'","USA","MEX","IND","BRA") return local adm "adm2"
    else if "`iso'"=="CHN" return local adm "adm3"
    else exit 198
end

* Load daily temperature powers for one country
cap program drop _load_climate_polys
program define _load_climate_polys
    args iso adm
    tempname found_file
    scalar `found_file' = 0
    capture noisily use "${ROOT_INT_DATA}/climate/final/`iso'/`adm'/GMFD_`iso'_tmax_polynomials_`adm'.dta", clear
    if _rc==0 scalar `found_file' = 1
    if `found_file'==0 {
        capture noisily use "${ROOT_INT_DATA}/climate/final/`iso'/`adm'/GMFD_`iso'_tmax_polynomials_nochn_`adm'.dta", clear
        if _rc==0 scalar `found_file' = 1
    }
    if `found_file'==0 {
        capture noisily use "${ROOT_INT_DATA}/climate/final/`iso'/`adm'/GMFD_`iso'_tmax_polynomials_wchn_`adm'.dta", clear
        if _rc==0 scalar `found_file' = 1
    }
    if `found_file'==0 {
        di as err "Cannot find climate tmax_polynomials for `iso'/`adm'"
        exit 198
    }
end

* Build the 3-knot spline variables from temperature powers
cap program drop _make_rcs_from_raw_polys
program define _make_rcs_from_raw_polys
    args knot1 knot2 knot3
    foreach z in 1 2 3 {
        confirm variable tmax_p`z'
    }
    cap drop tmax_rcspl_3kn_t0_raw tmax_rcspl_3kn_t1_raw
    gen double tmax_rcspl_3kn_t0_raw = tmax_p1
    gen double tmax_rcspl_3kn_t1_raw = 0
    replace tmax_rcspl_3kn_t1_raw = (tmax_p3 - 3*`knot1'*tmax_p2 + 3*(`knot1'^2)*tmax_p1 - (`knot1'^3)) if tmax_p1 >= `knot1'
    replace tmax_rcspl_3kn_t1_raw = tmax_rcspl_3kn_t1_raw ///
        - (tmax_p3 - 3*`knot2'*tmax_p2 + 3*(`knot2'^2)*tmax_p1 - (`knot2'^3)) * ((`knot3'-`knot1')/(`knot3'-`knot2')) if tmax_p1 >= `knot2'
    replace tmax_rcspl_3kn_t1_raw = tmax_rcspl_3kn_t1_raw ///
        + (tmax_p3 - 3*`knot3'*tmax_p2 + 3*(`knot3'^2)*tmax_p1 - (`knot3'^3)) * ((`knot2'-`knot1')/(`knot3'-`knot2')) if tmax_p1 >= `knot3'
end

* Daily countries: build the six lag terms using the weekday rule
cap program drop _mk_dayslots_panel
program define _mk_dayslots_panel
    syntax varlist
    quietly {
        tempvar weekday
        gen byte `weekday' = dow(date)
        foreach v of local varlist {
            forvalues i = 1/6 {
                local j = 7-`i'
                cap drop `v'_v`i'
                gen double `v'_v`i' = F`j'.`v'
                replace `v'_v`i' = L`i'.`v' if `weekday' >= `i'
            }
        }
        drop `weekday'
    }
end

* Weekly countries: sum the current day plus six lags
cap program drop _weekly_sum_and_repeat
program define _weekly_sum_and_repeat
    syntax varlist
    quietly {
        foreach v of local varlist {
            tempvar weekly_total
            gen double `weekly_total' = `v'
            forvalues i=1/6 {
                replace `weekly_total' = `weekly_total' + L`i'.`v'
            }
            replace `v' = `weekly_total'
            drop `weekly_total'
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
use "`selected_knot_row'", clear
local k1 = knot1[1]
local k2 = knot2[1]
local k3 = knot3[1]
local id = id[1]
di as res ">>> knot grid row=`id' with knots: (`k1', `k2', `k3')"

use "`global_base_file'", clear
keep if mins_worked > 0

* Variables needed for the regression
foreach v in high_risk age age2 male hhsize log_gdp_pc_adm1 ///
            precip_p1 precip_p2 precip_p1_v1 precip_p2_v1 ///
            lr_tmax_p1 risk_adj_sample_wgt cluster_adm1yymm ///
            week_fe dow_week tmax_p1 tmax_p2 tmax_p3 date iso {
    confirm variable `v'
}

* Keep daily_ctry for functions.do programs
capture confirm variable daily_ctry
if _rc gen byte daily_ctry = !inlist(iso,"BRA","MEX")

* Set up the pooled sample file
tempfile pooled_sample base_sample
save "`base_sample'", replace
clear
save "`pooled_sample'", emptyok replace

* Loop over countries present in the base file
use "`base_sample'", clear
levelsof iso, local(countries_in_sample)

foreach iso of local countries_in_sample {

    di as txt "  -> Processing ISO: `iso'"

    * Survey rows for this country
    use "`base_sample'", clear
    keep if iso=="`iso'"

    quietly _adm_level_for_iso, iso("`iso'")
    local adm_level = r(adm)

    tempfile climate_spline_terms country_with_splines country_sample
    save "`country_sample'", replace

    * Daily climate data for this country
    _load_climate_polys "`iso'" "`adm_level'"
    capture confirm variable date
    if _rc gen int date = mdy(month,day,year)
    format date %td
    tsset `adm_level'_id date

    * Brazil and Mexico use weekly exposure timing
    local is_weekly_survey = inlist("`iso'","BRA","MEX")

    * Convert temperature powers to this spline
    _make_rcs_from_raw_polys `k1' `k2' `k3'

    * Build current-week and lag terms
    if `is_weekly_survey' {
        * Weekly countries: current day plus six lags
        gen double tmax_rcspl_3kn_t0 = tmax_rcspl_3kn_t0_raw
        gen double tmax_rcspl_3kn_t1 = tmax_rcspl_3kn_t1_raw
        _weekly_sum_and_repeat tmax_rcspl_3kn_t0 tmax_rcspl_3kn_t1
    }
    else {
        * Daily countries: scale by sqrt(7), then use weekday lags
        gen double tmax_rcspl_3kn_t0 = tmax_rcspl_3kn_t0_raw*sqrt(7)
        gen double tmax_rcspl_3kn_t1 = tmax_rcspl_3kn_t1_raw*sqrt(7)
        _mk_dayslots_panel tmax_rcspl_3kn_t0 tmax_rcspl_3kn_t1
    }

    keep `adm_level'_id date tmax_rcspl_3kn_t0 tmax_rcspl_3kn_t1 ///
         tmax_rcspl_3kn_t0_v* tmax_rcspl_3kn_t1_v*
    save "`climate_spline_terms'", replace

    * Merge spline terms into the survey rows
    use "`country_sample'", clear
    merge m:1 `adm_level'_id date using "`climate_spline_terms'", nogen keep(3)
    save "`country_with_splines'", replace

    * Add this country to the pooled sample
    use "`pooled_sample'", clear
    append using "`country_with_splines'"
    save "`pooled_sample'", replace
}

*-------------------------------------------------------------------------------
* Load the pooled sample
*-------------------------------------------------------------------------------
use "`pooled_sample'", clear


*-------------------------------------------------------------------------------
* Build controls, fixed effects, and temperature interaction macros
*-------------------------------------------------------------------------------
gen_controls_and_FEs
gen_treatment_splines rcspl 3 tmax this_week 1

local reg_treat   (${vars_T_splines})##i.high_risk
local reg_ctrl    (${usual_controls})##i.high_risk

local reg_fe ""
foreach f in $fe_adm0_wk {
    local reg_fe `reg_fe' `f'#high_risk
}

*-------------------------------------------------------------------------------
* Run the regression
*-------------------------------------------------------------------------------
reghdfe mins_worked `reg_treat' `reg_ctrl' ///
    [pweight = risk_adj_sample_wgt], absorb(`reg_fe') vce(cl cluster_adm1yymm)

*-------------------------------------------------------------------------------
* Add sample counts before saving the estimates
*-------------------------------------------------------------------------------
tempvar regression_sample
gen byte `regression_sample' = e(sample)

count if `regression_sample'
local total_obs = r(N)

count if `regression_sample' & high_risk==1
local high_risk_obs = r(N)

count if `regression_sample' & high_risk==0
local low_risk_obs = r(N)

estadd scalar N_total = `total_obs'
estadd scalar high_N  = `high_risk_obs'
estadd scalar low_N   = `low_risk_obs'

drop `regression_sample'

*-------------------------------------------------------------------------------
* Save estimates for this knot triple
*-------------------------------------------------------------------------------
local ster_name "`ster_dir'/row`knot_grid_row'_k_`k1'_`k2'_`k3'.ster"
local spec_desc "row=`knot_grid_row', rcspl3 (`k1' `k2' `k3'), tmax this_week, by-risk, fe=fe_adm0_wk#high_risk, weight=risk_adj_sample_wgt"

estimates notes: "`spec_desc'"
estimates save "`ster_name'", replace

di as res "Saved STER: `ster_name' (N_total=`total_obs', high_N=`high_risk_obs', low_N=`low_risk_obs')"

*-------------------------------------------------------------------------------
* Within R2 for the knot ranking
*-------------------------------------------------------------------------------
scalar within_r2 = e(r2_within)
di as res "DONE row=`id'  knots=(`k1',`k2',`k3')  within_R2=" %6.4f within_r2

*-------------------------------------------------------------------------------
* Write this result row
*-------------------------------------------------------------------------------
cap file close result_csv
file open result_csv using "`candidate_result_csv'", write replace
file write result_csv "id,k1,k2,k3,r2_within,N_total,N_high,N_low" _n
file close result_csv

local id_csv = string(`id', "%12.0f")
local k1_csv = string(`k1', "%9.2f")
local k2_csv = string(`k2', "%9.2f")
local k3_csv = string(`k3', "%9.2f")
local within_r2_csv = string(within_r2, "%12.8f")
local total_obs_csv = string(`total_obs', "%12.0f")
local high_risk_obs_csv = string(`high_risk_obs', "%12.0f")
local low_risk_obs_csv = string(`low_risk_obs', "%12.0f")

local output_line "`id_csv',`k1_csv',`k2_csv',`k3_csv',`within_r2_csv',`total_obs_csv',`high_risk_obs_csv',`low_risk_obs_csv'"

cap file close result_csv
file open result_csv using "`candidate_result_csv'", write append
file write result_csv "`output_line'" _n
file close result_csv

di as res "Candidate result written: `candidate_result_csv' -> `output_line'"

exit 0
