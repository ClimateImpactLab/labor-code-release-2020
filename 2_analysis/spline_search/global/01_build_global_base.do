*-------------------------------------------------------------------------------
* 01_build_global_base.do
*-------------------------------------------------------------------------------
* PURPOSE
*   Build the common global base used for the spline knot search
*
*   This script starts from the holiday-dropped time-use dataset since it's the last 
* 	intermediate dataset before the splines terms are calculated at pixel level before
* 	climate aggregation. 
*
* STEPS
*   1. Load the holiday-dropped time-use dataset 
*   2. Merge daily temperature powers, precipitation terms, and long-run temperature
*   3. Rebuild the weights and cluster variables used by the search regressions
*   4. Save the base dataset used by the global and regional searches
*
* INPUT
*   Holiday-dropped time-use sample and country-level climate files
*
* OUTPUTS
*   Global base file with temperature polynomials and all the regression variables
*-------------------------------------------------------------------------------

version 16.1
clear all
set more off

*-------------------------------------------------------------------------------
* PATHS
*-------------------------------------------------------------------------------

run "/project/cil/home_dirs/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"

local temp_dir "${ROOT_INT_DATA}/temp"
local regression_data_dir "${ROOT_INT_DATA}/regression_ready_data"
cap mkdir "`regression_data_dir'"
local ISOS "USA GBR FRA ESP IND BRA MEX"

*-------------------------------------------------------------------------------
* Helper programs
*-------------------------------------------------------------------------------

* Return the climate admin level used for each country
capture program drop _adm_level_for_iso
program define _adm_level_for_iso, rclass
    syntax , iso(string)

    if inlist("`iso'","GBR","FRA","ESP") {
        return local adm "adm1"
    }
    else if inlist("`iso'","USA","MEX","IND","BRA") {
        return local adm "adm2"
    }
    else {
        di as error "Unsupported iso: `iso'"
        exit 198
    }
end


* Build six lag terms for daily countries using the weekday rule
capture program drop _make_day_slots
program define _make_day_slots
    syntax varlist

    quietly {
        foreach v of local varlist {
            forvalues i = 1/6 {
                local j = 7 - `i'
                gen double `v'_v`i' = F`j'.`v'
                replace `v'_v`i' = L`i'.`v' if dow(date) >= `i'
            }
        }
    }
end


* Rebuild group weights and representative-unit weights
capture program drop create_risk_weights
program define create_risk_weights

    syntax varname, base_weight(varname) [suffix(string)]

    local group_var `varlist'

    if "`suffix'" == "" {
        local suffix ""
    }

    * Group shares within country
    bysort iso `group_var': gen double `group_var'_prop = _N
    by iso: replace `group_var'_prop = `group_var'_prop / _N

    * Reweight so the group totals match their sample shares
    gen double risk_adj_sample_wgt`suffix' = `base_weight' * `group_var'_prop

    bysort `group_var': egen double `group_var'_sum = total(risk_adj_sample_wgt`suffix')

    gen double total_`group_var'_share = _N
    bysort `group_var': replace total_`group_var'_share = _N / total_`group_var'_share

    replace risk_adj_sample_wgt`suffix' = ///
        risk_adj_sample_wgt`suffix' / `group_var'_sum * total_`group_var'_share

    drop total_`group_var'_share `group_var'_prop `group_var'_sum

    * Representative-unit weights
    gegen rep_unit_tot_wgt`suffix' = total(risk_adj_sample_wgt`suffix'), by(rep_unit)
    gen double rep_unit_sample_wgt`suffix' = ///
        risk_adj_sample_wgt`suffix' / rep_unit_tot_wgt`suffix'

    gegen test_sum`suffix' = total(rep_unit_sample_wgt`suffix'), by(rep_unit)

    * Representative-unit-year weights
    gegen rep_unit_year_tot_wgt`suffix' = total(risk_adj_sample_wgt`suffix'), by(rep_unit year)
    gen double rep_unit_year_sample_wgt`suffix' = ///
        risk_adj_sample_wgt`suffix' / rep_unit_year_tot_wgt`suffix'

    gegen test_sum_2`suffix' = total(rep_unit_year_sample_wgt`suffix'), by(rep_unit year)

    count if (round(test_sum`suffix') != 1) | (round(test_sum_2`suffix') != 1)

    if `r(N)' != 0 {
        di as error "Sample weights for `group_var' do not add to 1"
    }
    else {
        di as result "Sample weights for `group_var' correctly generated"
        drop rep_unit_tot_wgt`suffix' rep_unit_year_tot_wgt`suffix' ///
             test_sum`suffix' test_sum_2`suffix'
    }

end


*-------------------------------------------------------------------------------
* 1) Load survey base 
*-------------------------------------------------------------------------------

confirm file "`temp_dir'/all_time_use_pop_merged_reweighted_clustered_holidays_dropped.dta"

use "`temp_dir'/all_time_use_pop_merged_reweighted_clustered_holidays_dropped.dta", clear

drop if iso == "CHN"

capture confirm variable date
if _rc {
    confirm variable year
    confirm variable month
    confirm variable day
    gen int date = mdy(month, day, year)
}

format date %td

capture confirm variable year
if _rc gen int year = year(date)

capture confirm variable month
if _rc gen byte month = month(date)

capture confirm variable day
if _rc gen byte day = day(date)

* Variables used later in the fixed effects
cap drop week_fe
gen week_fe = week(date)

cap drop dow_week
gen byte dow_week = dow(date)
replace dow_week = 8 if inlist(iso, "BRA", "MEX")

tempfile survey_base
save "`survey_base'", replace


*-------------------------------------------------------------------------------
* 2) Build one country slice at a time and append
*-------------------------------------------------------------------------------

tempfile global_base
clear
save "`global_base'", emptyok replace

foreach iso of local ISOS {

    di as txt "Processing ISO: `iso'"

    quietly _adm_level_for_iso, iso("`iso'")
    local ADM = r(adm)

*-------------------------------------------------------------------------------
    * Keep daily temperature powers as-is; spline terms are added later
*-------------------------------------------------------------------------------

    use "${ROOT_INT_DATA}/climate/final/`iso'/`ADM'/GMFD_`iso'_tmax_polynomials_`ADM'.dta", clear

    gen int date = mdy(month, day, year)
    format date %td

    tsset `ADM'_id date

    keep `ADM'_id date tmax_p1 tmax_p2 tmax_p3

    tempfile tmax_poly
    save "`tmax_poly'", replace


*-------------------------------------------------------------------------------
    * Build precipitation exposure and six lag terms
*-------------------------------------------------------------------------------

    use "${ROOT_INT_DATA}/climate/final/`iso'/`ADM'/GMFD_`iso'_prcp_`ADM'.dta", clear

    gen int date = mdy(month, day, year)
    format date %td

    tsset `ADM'_id date

    capture confirm variable prcp_p1
    if !_rc {
        rename prcp_p1 precip_p1

        capture confirm variable prcp_p2
        if !_rc rename prcp_p2 precip_p2
    }

    gen byte __daily = !inlist("`iso'", "BRA", "MEX")

    if __daily {
        foreach v of varlist precip_p1 precip_p2 {
            capture confirm variable `v'
            if _rc continue

            replace `v' = `v' * sqrt(7)
        }

        local pvars "precip_p1"

        capture confirm variable precip_p2
        if !_rc local pvars "`pvars' precip_p2"

        _make_day_slots `pvars'
    }
    else {
        foreach v of varlist precip_p1 precip_p2 {
            capture confirm variable `v'
            if _rc continue

            gen double w_`v' = `v'

            forvalues i = 1/6 {
                gen double `v'_l`i' = L`i'.`v'
                replace w_`v' = w_`v' + `v'_l`i'
            }

            replace `v' = w_`v'

            forvalues i = 1/6 {
                gen double `v'_v`i' = `v'
            }

            drop w_`v' `v'_l?
        }
    }

    drop __daily

    local KEEP_P "`ADM'_id date precip_p1 precip_p1_v*"

    capture confirm variable precip_p2
    if !_rc local KEEP_P "`KEEP_P' precip_p2 precip_p2_v*"

    keep `KEEP_P'

    tempfile precip_terms
    save "`precip_terms'", replace


*-------------------------------------------------------------------------------
    * Long-run temperature
    * USA/GBR/FRA use WORLD adm0 values, others use country adm1 values
*-------------------------------------------------------------------------------

    tempfile long_run_temp

    if inlist("`iso'", "USA", "GBR", "FRA") {
        use "${ROOT_INT_DATA}/climate/final/WORLD/adm0/GMFD_WORLD_long_run_adm0.dta", clear

        capture confirm variable ISO
        if !_rc rename ISO iso

        keep iso lr_tmax_p1

        save "`long_run_temp'", replace
    }
    else {
        use "${ROOT_INT_DATA}/climate/final/`iso'/adm1/GMFD_`iso'_long_run_adm1.dta", clear

        keep adm1_id lr_tmax_p1

        save "`long_run_temp'", replace
    }


*-------------------------------------------------------------------------------
    * Merge the climate terms into the country survey slice
*-------------------------------------------------------------------------------

    use "`survey_base'", clear
    keep if iso == "`iso'"

    merge m:1 `ADM'_id date using "`tmax_poly'", nogen keep(3)
    merge m:1 `ADM'_id date using "`precip_terms'", nogen keep(3)

    if inlist("`iso'", "USA", "GBR", "FRA") {
        merge m:1 iso using "`long_run_temp'", nogen keep(3)
    }
    else {
        merge m:1 adm1_id using "`long_run_temp'", nogen keep(3)
    }

    cap drop daily_ctry
    gen byte daily_ctry = !inlist(iso, "BRA", "MEX")

    cap drop __pid
    gen long __pid = .
    replace __pid = adm1_id if inlist(iso, "FRA", "GBR", "ESP")
    replace __pid = adm2_id if inlist(iso, "USA", "MEX", "IND", "BRA")

    cap drop real_temperature
    gen double real_temperature = tmax_p1

    append using "`global_base'"
    save "`global_base'", replace
}


*-------------------------------------------------------------------------------
* 3) Rebuild weights and clusters
*-------------------------------------------------------------------------------

use "`global_base'", clear

foreach v in risk_prop risk_sum risk_adj_sample_wgt total_risk_share ///
            risk_adj_sample_wgt_equal ///
            risk_adj_sample_wgt_old risk_adj_sample_wgt_sector ///
            rep_unit rep_unit_sample_wgt rep_unit_year_sample_wgt ///
            rep_unit_sample_wgt_old rep_unit_year_sample_wgt_old ///
            rep_unit_sample_wgt_sector rep_unit_year_sample_wgt_sector {
    cap drop `v'
}

* Representative unit used for weights
gen rep_unit = adm1_id
replace rep_unit = adm0_id if inlist(iso, "USA", "GBR", "FRA")

* Risk and sector weights
create_risk_weights high_risk, base_weight(pop_adj_sample_wgt)

capture confirm variable high_risk_old
if !_rc {
    create_risk_weights high_risk_old, base_weight(pop_adj_sample_wgt) suffix(_old)
}
else {
    di as txt "NOTE: high_risk_old not found, skipping _old weights"
}

capture confirm variable sector
if !_rc {
    create_risk_weights sector, base_weight(pop_adj_sample_wgt) suffix(_sector)
}
else {
    di as txt "NOTE: sector not found; skipping _sector weights"
}

* Monthly country and adm1 clusters
cap drop cluster_adm0yymm
cap drop cluster_adm1yymm

egen cluster_adm0yymm = group(iso month year)
egen cluster_adm1yymm = group(adm1_id month year)


*-------------------------------------------------------------------------------
* 4) Save the global base
*-------------------------------------------------------------------------------

order iso date year month day ///
      adm0_id adm1_id adm2_id ///
      mins_worked high_risk high_risk_old sector real_temperature ///
      age age2 male hhsize log_gdp_pc_adm1 ///
      tmax_p1 tmax_p2 tmax_p3 ///
      precip_p1 precip_p2 precip_p1_v* precip_p2_v* lr_tmax_p1 ///
      sample_wgt adj_sample_wgt pop_adj_sample_wgt ///
      risk_adj_sample_wgt risk_adj_sample_wgt_old risk_adj_sample_wgt_sector ///
      rep_unit rep_unit_sample_wgt rep_unit_year_sample_wgt ///
      rep_unit_sample_wgt_old rep_unit_year_sample_wgt_old ///
      rep_unit_sample_wgt_sector rep_unit_year_sample_wgt_sector ///
      dow_week week_fe cluster_adm0yymm cluster_adm1yymm adm0_pop ///
      daily_ctry __pid

compress

save "`regression_data_dir'/global_base_polys_tmax_nochn_no_ll_0_MASTER.dta", replace
save "`regression_data_dir'/global_base_final.dta", replace

di as res "Saved: `regression_data_dir'/global_base_polys_tmax_nochn_no_ll_0_MASTER.dta"
di as res "Saved: `regression_data_dir'/global_base_final.dta"
