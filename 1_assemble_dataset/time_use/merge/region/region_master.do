*-------------------------------------------------------------------------------
* region_master.do
*-------------------------------------------------------------------------------
* PURPOSE
*   Build the region-specific regression-ready datasets used for the regional
*   regressions
*
* STEPS
*   1. Load the holiday-dropped time-use sample
*   2. Keep the countries in each region
*   3. Merge the region-specific spline terms and climate controls
*   4. Match the same daily/weekly exposure timing used in master.do
*   5. Save one regression-ready dataset per region
*
* INPUTS
*   Holiday-dropped time-use data
*   Region-specific spline terms, precip, and long-run temp files
*
* REGION KNOT FOLDERS
*   After the region knot search, spline terms were calculated at the pixel
*   level for the chosen knots, then aggregated to admin units in the final_* folders
*   EuropeUS: final_14_20_28
*   LatinAmerica: final_26_29_34
*   SouthAsia: final_28_33_41
*
* OUTPUTS
*   Region datasets are saved under:
*   ${ROOT_INT_DATA}/regression_ready_data/region_datasets/
*-------------------------------------------------------------------------------

version 16.1
clear all
set more off
set rmsg on
set trace off

*-------------------------------------------------------------------------------
* Setup
*-------------------------------------------------------------------------------
run "/project/cil/home_dirs/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"

local time_use_base "${ROOT_INT_DATA}/temp/all_time_use_pop_merged_reweighted_clustered_holidays_dropped.dta"

local climate_root "${ROOT_INT_DATA}/climate"
local output_dir "${ROOT_INT_DATA}/regression_ready_data/region_datasets"

cap mkdir "`output_dir'"

*-------------------------------------------------------------------------------
* Helper programs
*-------------------------------------------------------------------------------

* Daily surveys: build six lag terms
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

* Weekly surveys: sum the last seven days and repeat across six lag terms
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

* Use the same spline names across region climate files
cap program drop _detect_and_keep_spline_terms
program define _detect_and_keep_spline_terms
    syntax , iso(string)
    quietly {

        * GBR special case
        cap confirm variable tmax_rcspl_14_20_28_3kn_t0
        if !_rc & "`iso'"=="GBR" {
            cap drop tmax_rcspl_3kn_t0_raw tmax_rcspl_3kn_t1_raw
            gen double tmax_rcspl_3kn_t0_raw = tmax_rcspl_14_20_28_3kn_t0
            gen double tmax_rcspl_3kn_t1_raw = tmax_rcspl_14_20_28_3kn_t1

            keep adm_id year month day date tmax_rcspl_3kn_t0_raw tmax_rcspl_3kn_t1_raw
        }
        else {
            ds tmax_rcspline_3kn_*_term0
            local t0 : word 1 of `r(varlist)'
            ds tmax_rcspline_3kn_*_term1
            local t1 : word 1 of `r(varlist)'

            cap drop tmax_rcspl_3kn_t0_raw tmax_rcspl_3kn_t1_raw
            gen double tmax_rcspl_3kn_t0_raw = `t0'
            gen double tmax_rcspl_3kn_t1_raw = `t1'

            keep adm_id year month day date tmax_rcspl_3kn_t0_raw tmax_rcspl_3kn_t1_raw
        }
    }
end

*-------------------------------------------------------------------------------
* Regions
*-------------------------------------------------------------------------------
local regions "EuropeUS LatinAmerica SouthAsia"

foreach region of local regions {

    di as txt "Building region dataset: `region'"

    local country_list ""
    local climate_folder ""

    if "`region'"=="EuropeUS" {
        local country_list "FRA GBR ESP USA"
        local climate_folder "final_14_20_28"
    }
    else if "`region'"=="LatinAmerica" {
        local country_list "BRA MEX"
        local climate_folder "final_26_29_34"
    }
    else if "`region'"=="SouthAsia" {
        local country_list "IND"
        local climate_folder "final_28_33_41"
    }

    local region_climate_root "`climate_root'/`climate_folder'"

    *-------------------------------------------------------------------------------
    * Load survey base and keep region countries
    *-------------------------------------------------------------------------------
    use "`time_use_base'", clear

    gen byte __keep = 0
    foreach country of local country_list {
        replace __keep = 1 if iso=="`country'"
    }
    keep if __keep==1
    drop __keep

    * Make date if needed
    capture confirm variable date
    if _rc {
        capture confirm variable year
        capture confirm variable month
        capture confirm variable day
        gen int date = mdy(month,day,year)
    }
    format date %td

    cap confirm variable year
    if _rc gen int year = year(date)
    cap confirm variable month
    if _rc gen byte month = month(date)
    cap confirm variable day
    if _rc gen byte day = day(date)

    * Keep worked survey rows
    cap confirm variable mins_worked
    if !_rc keep if mins_worked>0

    tempfile survey_region
    save "`survey_region'", replace

    *-------------------------------------------------------------------------------
    * Build region dataset by country
    *-------------------------------------------------------------------------------
    tempfile region_stack
    clear
    save "`region_stack'", emptyok replace

    foreach iso_code of local country_list {

        di as txt "    -> ISO `iso_code'"

        use "`survey_region'", clear
        keep if iso=="`iso_code'"
        if _N==0 {
            di as txt "       (no observations in base for `iso_code'; skip)"
            continue
        }

        local adm_level "adm2"
        if inlist("`iso_code'","FRA","GBR","ESP") local adm_level "adm1"

        * Common key for climate merges
        gen long adm_id = `adm_level'_id

        tempfile survey_slice
        save "`survey_slice'", replace

        *-------------------------------------------------------------------------------
        * Merge region-specific spline terms
        *-------------------------------------------------------------------------------
        tempfile spline_terms
        local spline_file "`region_climate_root'/`iso_code'/`adm_level'/GMFD_`iso_code'_tmax_splines_nochn_`adm_level'.dta"
        use "`spline_file'", clear

        capture confirm variable date
        if _rc gen int date = mdy(month,day,year)
        format date %td

        rename `adm_level'_id adm_id

        duplicates drop adm_id date, force
        tsset adm_id date

        _detect_and_keep_spline_terms, iso("`iso_code'")

        gen byte __weekly = inlist("`iso_code'","BRA","MEX")
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

        keep adm_id date tmax_rcspl_3kn_t0 tmax_rcspl_3kn_t1 ///
             tmax_rcspl_3kn_t0_v* tmax_rcspl_3kn_t1_v*
        save "`spline_terms'", replace

        *-------------------------------------------------------------------------------
        * Merge temperature polynomial controls
        *-------------------------------------------------------------------------------
        tempfile tmax_poly_terms
        local tmax_poly_file "`region_climate_root'/`iso_code'/`adm_level'/GMFD_`iso_code'_tmax_polynomials_`adm_level'.dta"
        use "`tmax_poly_file'", clear

        capture confirm variable date
        if _rc gen int date = mdy(month,day,year)
        format date %td

        rename `adm_level'_id adm_id

        duplicates drop adm_id date, force
        tsset adm_id date

        cap confirm variable tmax_poly_1
        if !_rc {
            cap drop tmax_p1 tmax_p2 tmax_p3 tmax_p4
            gen double tmax_p1 = tmax_poly_1
            gen double tmax_p2 = tmax_poly_2
            gen double tmax_p3 = tmax_poly_3
            gen double tmax_p4 = tmax_poly_4
        }

        * Match the daily/weekly timing used in master.do
        gen byte __weekly = inlist("`iso_code'","BRA","MEX")
        if __weekly {
            _weekly_sum_and_repeat tmax_p1 tmax_p2 tmax_p3 tmax_p4
        }
        else {
            replace tmax_p1 = tmax_p1*sqrt(7)
            replace tmax_p2 = tmax_p2*sqrt(7)
            replace tmax_p3 = tmax_p3*sqrt(7)
            replace tmax_p4 = tmax_p4*sqrt(7)
            _mk_dayslots_panel tmax_p1 tmax_p2 tmax_p3 tmax_p4
        }
        drop __weekly

        keep adm_id date tmax_p1 tmax_p2 tmax_p3 tmax_p4 ///
             tmax_p1_v* tmax_p2_v* tmax_p3_v* tmax_p4_v*
        save "`tmax_poly_terms'", replace

        *-------------------------------------------------------------------------------
        * Merge precipitation controls
        *-------------------------------------------------------------------------------
        tempfile precip_terms
        local precip_file "`region_climate_root'/`iso_code'/`adm_level'/GMFD_`iso_code'_prcp_`adm_level'.dta"
        use "`precip_file'", clear

        capture confirm variable date
        if _rc gen int date = mdy(month,day,year)
        format date %td

        rename `adm_level'_id adm_id

        duplicates drop adm_id date, force
        tsset adm_id date

        capture confirm variable prcp_p1
        if !_rc {
            rename prcp_p1 precip_p1
            capture confirm variable prcp_p2
            if !_rc rename prcp_p2 precip_p2
        }

        gen byte __weekly = inlist("`iso_code'","BRA","MEX")
        if __weekly {
            _weekly_sum_and_repeat precip_p1
            capture confirm variable precip_p2
            if !_rc _weekly_sum_and_repeat precip_p2
        }
        else {
            replace precip_p1 = precip_p1*sqrt(7)
            capture confirm variable precip_p2
            if !_rc replace precip_p2 = precip_p2*sqrt(7)
            _mk_dayslots_panel precip_p1
            capture confirm variable precip_p2
            if !_rc _mk_dayslots_panel precip_p2
        }
        drop __weekly

        keep adm_id date precip_p1 precip_p2 precip_p1_v* precip_p2_v*
        save "`precip_terms'", replace

        *-------------------------------------------------------------------------------
        * Merge long-run temperature
        *-------------------------------------------------------------------------------
        tempfile long_run_temp
        local long_run_merge_key ""

        if inlist("`iso_code'","USA","GBR","FRA") {

            use "${ROOT_INT_DATA}/climate/final_27_28_41/WORLD/adm0/GMFD_WORLD_long_run_adm0.dta", clear

            cap confirm variable iso
            if _rc {
                cap confirm variable ISO
                if !_rc rename ISO iso
                else rename adm0_id iso
            }

            capture confirm string variable iso
            if _rc tostring iso, replace

            keep iso lr_tmax_p1
            save "`long_run_temp'", replace
            local long_run_merge_key "iso"
        }
        else {

            local long_run_file "`region_climate_root'/`iso_code'/adm1/GMFD_`iso_code'_long_run_adm1.dta"
            use "`long_run_file'", clear

            cap confirm variable lr_tmax_p1
            if _rc {
                rename tmax_poly_1 lr_tmax_p1
            }

            keep adm1_id lr_tmax_p1
            duplicates drop adm1_id, force
            save "`long_run_temp'", replace
            local long_run_merge_key "adm1"
        }

        *-------------------------------------------------------------------------------
        * Merge climate variables into survey rows
        *-------------------------------------------------------------------------------
        use "`survey_slice'", clear

        merge m:1 adm_id date using "`spline_terms'",    nogen keep(3)
        merge m:1 adm_id date using "`tmax_poly_terms'", nogen keep(3)
        merge m:1 adm_id date using "`precip_terms'",    nogen keep(3)

        if "`long_run_merge_key'"=="adm1" {
            merge m:1 adm1_id using "`long_run_temp'", nogen keep(3)
        }
        else if "`long_run_merge_key'"=="iso" {
            merge m:1 iso using "`long_run_temp'", nogen keep(3)
        }

        append using "`region_stack'"
        save "`region_stack'", replace
    }

    *-------------------------------------------------------------------------------
    * Load full region stack
    *-------------------------------------------------------------------------------
    use "`region_stack'", clear

    *-------------------------------------------------------------------------------
    * Create fixed-effect variables used by the regressions
    *-------------------------------------------------------------------------------
    cap drop week_fe
    gen int week_fe = week(date)

    *-------------------------------------------------------------------------------
    * Check day-of-week variable
    *-------------------------------------------------------------------------------
    capture confirm variable dow_week
    if _rc {
        gen byte dow_week = dow(date)
        replace dow_week = 8 if inlist(iso,"BRA","MEX")   // weekly surveys use one shared value
    }

    *-------------------------------------------------------------------------------
    * Save region dataset
    *-------------------------------------------------------------------------------
    compress
    local output_file "`output_dir'/labor_dataset_region_`region'.dta"
    save "`output_file'", replace
    di as result "Saved: `output_file'"
}

di as result "All region datasets built successfully."
