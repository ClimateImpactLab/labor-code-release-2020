clear all

****************************************************
* 0) PATHS (AS PROVIDED)
****************************************************
* CSVs
local csv_ind "/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/output/rf/uninteracted_reg_comlohi/uninteracted_reg_comlohi_table_values_2026_272841.csv"
local csv_occ "/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/output/rf/uninteracted_reg_comlohi/uninteracted_reg_comlohi_table_values_2026_272841_occup2.csv"
local csv_io  "/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/output/rf/uninteracted_reg_comlohi/uninteracted_reg_comlohi_table_values_2026_272841_oi.csv"

* ster files (by-risk)
local ster_ind "/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/output/ster/uninteracted_reg_comlohi/uninteracted_reg_by_risk_2026_272841.ster"
local ster_occ "/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/output/ster/uninteracted_reg_comlohi/uninteracted_reg_by_risk_2026_272841_occup2.ster"
local ster_io  "/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/output/ster/uninteracted_reg_comlohi/uninteracted_reg_by_risk_2026_272841_oi.ster"

* output tex
local out_dir "/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/output/tables"
cap mkdir "`out_dir'"
local out_tex "`out_dir'/weekly_minutes_272841.tex"

****************************************************
* 1) READ CSVs
****************************************************
tempfile ind occ io

* -------- industry
import delimited using "`csv_ind'", clear varnames(1)
destring temp ref yhat_low se_low yhat_high se_high, replace
keep temp ref yhat_low se_low yhat_high se_high
rename yhat_low  b_low_ind
rename se_low    se_low_ind
rename yhat_high b_high_ind
rename se_high   se_high_ind
sort temp ref
save `ind', replace

* -------- occupation
import delimited using "`csv_occ'", clear varnames(1)
destring temp ref yhat_low se_low yhat_high se_high, replace
keep temp ref yhat_low se_low yhat_high se_high
rename yhat_low  b_low_occ
rename se_low    se_low_occ
rename yhat_high b_high_occ
rename se_high   se_high_occ
sort temp ref
save `occ', replace

* -------- industry & occupation
import delimited using "`csv_io'", clear varnames(1)
destring temp ref yhat_low se_low yhat_high se_high, replace
keep temp ref yhat_low se_low yhat_high se_high
rename yhat_low  b_low_io
rename se_low    se_low_io
rename yhat_high b_high_io
rename se_high   se_high_io
sort temp ref
save `io', replace

****************************************************
* 2) MERGE + ORDER
****************************************************
use `ind', clear
merge 1:1 temp ref using `occ', nogen
merge 1:1 temp ref using `io',  nogen

* temps in your table
keep if inlist(temp, 45, 40, 35, 30, 27, 10, 5, 0, -5, -10)
gsort -temp

****************************************************
* 3) ADD SIGNIFICANCE STARS + FORMAT (1 decimal)
*    p = 2*Normal(-abs(b/se))
****************************************************
capture program drop _mkstars
program define _mkstars
    syntax varname(numeric) , SE(varname) GEN(name)

    tempvar tstat pval
    gen double `tstat' = `varlist' / `se'
    gen double `pval'  = 2*normal(-abs(`tstat'))

    gen str3 `gen' = cond(missing(`pval'),"", ///
                    cond(`pval'<0.01,"***", ///
                    cond(`pval'<0.05,"**",  ///
                    cond(`pval'<0.10,"*",   ""))))
end

* stars for each coefficient cell
_mkstars b_low_ind,  se(se_low_ind)   gen(star_low_ind)
_mkstars b_low_occ,  se(se_low_occ)   gen(star_low_occ)
_mkstars b_low_io,   se(se_low_io)    gen(star_low_io)

_mkstars b_high_ind, se(se_high_ind)  gen(star_high_ind)
_mkstars b_high_occ, se(se_high_occ)  gen(star_high_occ)
_mkstars b_high_io,  se(se_high_io)   gen(star_high_io)

* formatted strings (coef + stars) and SE in parentheses
foreach v in b_low_ind b_low_occ b_low_io b_high_ind b_high_occ b_high_io {
    gen str25 s_`v' = strtrim(string(`v', "%9.1f"))
}

replace s_b_low_ind  = s_b_low_ind  + star_low_ind
replace s_b_low_occ  = s_b_low_occ  + star_low_occ
replace s_b_low_io   = s_b_low_io   + star_low_io
replace s_b_high_ind = s_b_high_ind + star_high_ind
replace s_b_high_occ = s_b_high_occ + star_high_occ
replace s_b_high_io  = s_b_high_io  + star_high_io

foreach v in se_low_ind se_low_occ se_low_io se_high_ind se_high_occ se_high_io {
    gen str25 s_`v' = strtrim(string(`v', "%9.1f"))
}

****************************************************
* 4) EXTRACT Adj R2 and group-specific N from .ster
****************************************************
capture program drop _get_stats_by_risk
program define _get_stats_by_risk, rclass
    args sterpath

    estimates clear
    quietly estimates use "`sterpath'"

    return scalar r2a = e(r2_a)
    return scalar N_total = e(N)

    local found_low  0
    local found_high 0

    foreach nm in low_N N_low lowrisk_N N_lowrisk lo_N risk1_N {
        capture local tmp = e(`nm')
        if (_rc==0) {
            return scalar N_low = e(`nm')
            local found_low 1
            continue, break
        }
    }
    foreach nm in high_N N_high highrisk_N N_highrisk hi_N risk2_N {
        capture local tmp = e(`nm')
        if (_rc==0) {
            return scalar N_high = e(`nm')
            local found_high 1
            continue, break
        }
    }

    if (`found_low'==0)  return scalar N_low  = .
    if (`found_high'==0) return scalar N_high = .
end

* industry stats
quietly _get_stats_by_risk "`ster_ind'"
local r2_ind    : display %4.2f r(r2a)
local Nlow_ind  : display %15.0fc r(N_low)
local Nhigh_ind : display %15.0fc r(N_high)
local Ntot_ind  : display %15.0fc r(N_total)

* occupation stats
quietly _get_stats_by_risk "`ster_occ'"
local r2_occ    : display %4.2f r(r2a)
local Nlow_occ  : display %15.0fc r(N_low)
local Nhigh_occ : display %15.0fc r(N_high)
local Ntot_occ  : display %15.0fc r(N_total)

* ind&occ stats
quietly _get_stats_by_risk "`ster_io'"
local r2_io     : display %4.2f r(r2a)
local Nlow_io   : display %15.0fc r(N_low)
local Nhigh_io  : display %15.0fc r(N_high)
local Ntot_io   : display %15.0fc r(N_total)

* warn if group-specific N not found
if ("`Nlow_ind'"==".") | ("`Nhigh_ind'"==".") | ///
   ("`Nlow_occ'"==".") | ("`Nhigh_occ'"==".") | ///
   ("`Nlow_io'"==".")  | ("`Nhigh_io'"==".") {
    di as error "WARNING: Could not find low/high N inside one or more .ster files."
    di as error "Tried e(low_N), e(N_low), e(lowrisk_N), e(risk1_N) and similarly for high."
    di as error "Totals available: ind=`Ntot_ind', occ=`Ntot_occ', io=`Ntot_io'."
    di as error "Fix: in regression code before saving .ster: estadd scalar low_N=... and high_N=..."
}

****************************************************
* 5) WRITE LaTeX TABULAR
****************************************************
file open fh using "`out_tex'", write replace text

file write fh "\begin{tabular}{@{}l *{6}{>{\centering\arraybackslash}p{2.05cm}} @{}}" _n
file write fh "\toprule" _n
file write fh "\toprule" _n
file write fh "& \multicolumn{6}{c}{Weekly Minutes worked per worker} \\" _n
file write fh "\cmidrule(lr){2-7}" _n
file write fh "& \multicolumn{3}{c}{Low-risk workers} & \multicolumn{3}{c}{High-risk workers} \\" _n
file write fh "\cmidrule(lr){2-4}\cmidrule(lr){5-7}" _n
file write fh "\multirow{2}{*}{Daily maximum temperature} & Industry & Occupation & Industry \& Occupation & Industry & Occupation & Industry \& Occupation \\" _n
file write fh "& & & & & & \\" _n
file write fh "\midrule" _n

quietly count
local Nobs = r(N)

local templist 45 40 35 27 30 10 5 0 -5 -10

foreach t of local templist {

    * ---- Baseline temperature (not in CSV) ----
    if (`t' == 27) {
        file write fh "$27^{\circ}$ & -- & -- & -- & -- & -- & -- \\" _n
        file write fh " & -- & -- & -- & -- & -- & -- \\" _n
    }
    else {
        * find the row in CSV corresponding to this temperature
        quietly count if temp == `t'
        if (r(N) != 1) {
            di as error "ERROR: temp=`t' not uniquely found in CSV"
            exit 459
        }

        quietly {
            preserve
            keep if temp == `t'
        }

        * coefficient row
        file write fh "$`t'^{\circ}$ & " ///
            "`=s_b_low_ind[1]' & `=s_b_low_occ[1]' & `=s_b_low_io[1]' & " ///
            "`=s_b_high_ind[1]' & `=s_b_high_occ[1]' & `=s_b_high_io[1]' \\" _n

        * SE row
        file write fh " & " ///
            "(`=s_se_low_ind[1]') & (`=s_se_low_occ[1]') & (`=s_se_low_io[1]') & " ///
            "(`=s_se_high_ind[1]') & (`=s_se_high_occ[1]') & (`=s_se_high_io[1]') \\" _n

        restore
    }
}

file write fh "\midrule" _n
file write fh "Adj \$R\$-squared & `r2_ind' & `r2_occ' & `r2_io' & `r2_ind' & `r2_occ' & `r2_io' \\" _n
file write fh "\$N\$ & `Nlow_ind' & `Nlow_occ' & `Nlow_io' & `Nhigh_ind' & `Nhigh_occ' & `Nhigh_io' \\" _n
file write fh "\bottomrule" _n
file write fh "\bottomrule" _n
file write fh "\end{tabular}" _n

file close fh
di as result "DONE: LaTeX table written to `out_tex'"
