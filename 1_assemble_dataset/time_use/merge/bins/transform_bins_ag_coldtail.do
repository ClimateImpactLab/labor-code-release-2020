
/***************************************************************************************************
Purpose
-------
Re-bin temperature exposure/count variables from the raw 1°C bins  into 3°C bins,
 with an additional collapsed cold tail.

Outputs
-------
Two saved datasets: for collapsed cold tail below 9°C and below 12°C


Based on: 
----------
original do file transform_bins.do by Ruixue Li (liruixue@uchicago.edu)

Adapted by: 
----------
Marine de Franciosi (mdefranciosi@uchicago.edu)

***************************************************************************************************/


do "/project/cil/home_dirs/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"
global final_path "${ROOT_INT_DATA}/regression_ready_data"

global t_version_list tmax
global chn_week_list  chn_prev_week
global variables_list bins_nochn
global data_ll_version_list no_ll_0

foreach variables in $variables_list {
    foreach t_version in $t_version_list {
        foreach chn_week in $chn_week_list {
            foreach data_ver in $data_ll_version_list {

                use "$final_path/labor_dataset_`variables'_`t_version'_`chn_week'_`data_ver'.dta", clear

                /******************************************************************
                 1) Rename raw bins into b1C_0 ... b1C_101 (same as original)
                ******************************************************************/

                * negative tail (-Inf to -40)
                rename `t_version'_bins_nInf_n40C* b1C_0*
                label variable b1C_0 "-Inf to -40C"

                * -40 to -1
                forval b = 1/39 {
                    local bin_begin = 41 - `b'
                    local bin_end   = `bin_begin' - 1
                    rename `t_version'_bins_n`bin_begin'C_n`bin_end'C* b1C_`b'*
                    label variable b1C_`b' "-`bin_begin'C to -`bin_end'C"
                }

                * -1 to 0
                rename `t_version'_bins_n1C_0C* b1C_40*
                label variable b1C_40 "-1C to 0C"

                * 0 to 60
                forval b = 0/59 {
                    local bin_begin = `b'
                    local bin_end   = `bin_begin' + 1
                    local bin_n     = 41 + `b'
                    rename `t_version'_bins_`bin_begin'C_`bin_end'C* b1C_`bin_n'*
                    label variable b1C_`bin_n' "`bin_begin'C to `bin_end'C"
                }

                * 60 to Inf
                rename `t_version'_bins_60C_Inf* b1C_101*
                label variable b1C_101 "60C to Inf"


                /******************************************************************
                 2) Build + save two versions (coldcut = 9 and 12)
                    - cold tail: <= coldcut
                    - regular 3C bins: coldcut..42 by 3 (e.g. 9-12,12-15,...,39-42)
                    - upper tail: >= 42
                ******************************************************************/

                foreach coldcut in 9 12 {

                    local uppercut 42

                    * Mapping: b1C_(41+t) is the 1C bin [t, t+1)
                    local below_last_idx  = 41 + `coldcut' - 1   // last 1C index included in <= coldcut tail
                    local above_first_idx = 41 + `uppercut'      // first 1C index included in >= uppercut tail

                    * --- cold tail: <= coldcut ---
                    gen below`coldcut' = 0
                    forval v = 1/6 {
                        gen below`coldcut'_v`v' = 0
                    }

                    forval i = 0/`below_last_idx' {
                        replace below`coldcut' = below`coldcut' + b1C_`i'
                        forval v = 1/6 {
                            replace below`coldcut'_v`v' = below`coldcut'_v`v' + b1C_`i'_v`v'
                        }
                    }
                    label variable below`coldcut' "`coldcut'C and below"


                    * --- regular 3C bins starting at coldcut up to 42 ---
                    * creates vars like b3C_9 (meaning 9 to 12), b3C_12 (12 to 15), ...
                    forval lb = `coldcut'(3)`=`uppercut'-3' {
                        local ub = `lb' + 3

                        gen b3C_`lb' = 0
                        forval v = 1/6 {
                            gen b3C_`lb'_v`v' = 0
                        }

                        * add the three 1C bins: [lb,lb+1) + [lb+1,lb+2) + [lb+2,lb+3)
                        forval k = 0/2 {
                            local t   = `lb' + `k'
                            local idx = 41 + `t'
                            replace b3C_`lb' = b3C_`lb' + b1C_`idx'
                            forval v = 1/6 {
                                replace b3C_`lb'_v`v' = b3C_`lb'_v`v' + b1C_`idx'_v`v'
                            }
                        }

                        label variable b3C_`lb' "`lb'C to `ub'C"
                    }


                    * --- upper tail: >= 42C ---
                    gen above42 = 0
                    forval v = 1/6 {
                        gen above42_v`v' = 0
                    }

                    * sum b1C indices for 42-43 up through 59-60 (idx 100), plus 60-Inf (idx 101)
                    forval i = `above_first_idx'/101 {
                        replace above42 = above42 + b1C_`i'
                        forval v = 1/6 {
                            replace above42_v`v' = above42_v`v' + b1C_`i'_v`v'
                        }
                    }
                    label variable above42 "42C and above"


                    * --- save a version for this coldcut ---
                    preserve
                        drop b1C*
                        save "$final_path/labor_dataset_`variables'_`t_version'_`chn_week'_`data_ver'_coldle`coldcut'_3Cbins_`coldcut'to42_plusTails.dta", replace
                    restore


                    * --- cleanup ---
                    capture drop below`coldcut' below`coldcut'_v*
                    forval lb = `coldcut'(3)`=`uppercut'-3' {
                        capture drop b3C_`lb' b3C_`lb'_v*
                    }
                    capture drop above42 above42_v*

                }

            }
        }
    }
}
