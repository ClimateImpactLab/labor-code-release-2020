* Ruixue Li, liruixue@uchicago.edu
* convert raw bins to 3c bins with below 0 and above 42 bins

cilpath

do "/home/`c(username)'/repos/labor-code-release-2020/0_subroutines/paths.do"

global final_path "${ROOT_INT_DATA}/regression_ready_data"

global t_version_list tmax
global chn_week_list  chn_prev_week

global variables_list bins_nochn bins_wchn
global data_ll_version_list no_ll_0 

foreach variables in $variables_list {
	foreach t_version in $t_version_list {
		foreach chn_week in $chn_week_list {	
			foreach data_ver in $data_ll_version_list {
				use "$final_path/labor_dataset_`variables'_`t_version'_`chn_week'_`data_ver'.dta", clear

				* rename negative temp bins
				rename `t_version'_bins_nInf_n40C* b1C_0*
				label variable b1C_0 "-Inf to -40C"

				forval b = 1/39 {
					local bin_begin = 41 - `b' 
					local bin_end = `bin_begin' - 1
					rename `t_version'_bins_n`bin_begin'C_n`bin_end'C* b1C_`b'* 
					label variable b1C_`b' "-`bin_begin'C to -`bin_end'C"
				}

				rename `t_version'_bins_n1C_0C* b1C_40*
				label variable b1C_40 "-1C to 0C"


				* rename positive temp bins
				forval b = 0/59 {
					local bin_begin = `b' 
					local bin_end = `bin_begin' + 1
					local bin_n = 41 + `b'
					rename `t_version'_bins_`bin_begin'C_`bin_end'C* b1C_`bin_n'*
					label variable b1C_`bin_n' "`bin_begin'C to `bin_end'C"
				}

				rename `t_version'_bins_60C_Inf* b1C_101*
				label variable b1C_101 "60C to Inf"


				* convert to 3C bins
				gen b3C_0 = b1C_0 + b1C_1 
				gen b3C_34 = b1C_101
				label variable b3C_0 "below 39"
				label variable b3C_34 "above 60"
				forval v = 1/6 {
					gen b3C_0_v`v' = b1C_0_v`v' + b1C_1_v`v' 
					gen b3C_34_v`v' = b1C_101_v`v'
				}

				forval n = 1/33 {
					local n1 = 3 * (`n'-1) + 1
					local n2 = 3 * (`n'-1) + 2
					local n3 = 3 * (`n'-1) + 3	
					gen b3C_`n' = b1C_`n1' + b1C_`n2' + b1C_`n3'
					local lb =  (`n' - 14 ) * 3  
					local ub =  (`n' - 14 ) * 3 + 3
					label variable b3C_`n' "`lb' to `ub'"
					forval v = 1/6 {
						gen b3C_`n'_v`v' = b1C_`n1'_v`v' + b1C_`n2'_v`v' + b1C_`n3'_v`v'
					}
				}

				drop b1C*

				gen below0 = 0
				gen above42 = 0
				forval v = 1/6 {
					gen	below0_v`v' = 0
					gen	above42_v`v' = 0
				}

				forval n = 0/13 {
					replace below0 = below0 + b3C_`n'
					drop b3C_`n'
					forval v = 1/6 {
						replace	below0_v`v' = below0_v`v' + b3C_`n'_v`v'
						drop b3C_`n'_v`v'
					}
				}


				forval n = 28/34 {
					replace	above42 = above42 + b3C_`n'
					drop b3C_`n'
					forval v = 1/6 {
						replace	above42_v`v' = above42_v`v' + b3C_`n'_v`v'
						drop b3C_`n'_v`v'
					}
				}

				drop `t_version'*
			
				save "$final_path/labor_dataset_`variables'_`t_version'_`chn_week'_`data_ver'_0Cto42C_3Cbins.dta", replace
			}
		}
	}
}


