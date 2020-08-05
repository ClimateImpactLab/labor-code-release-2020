* List the countries and years we need to generate climate data for
* By: Simon Greenhill, adapted from Tom's migration code
* 9/10/2019

clear all
set more off

cilpath

import delim "$DB/Global ACP/labor/1_preparation/employment_shares/data/required_clim_data.csv", clear

tempfile years
save `years'

* flag data already generated for migration, don't re-generate it
import delim "$DB/Wilkes_InternalMigrationGlobal/internal/Data/Raw/supplements/code_keys/internal_required_clim_data.csv", clear
rename (required_*) (mig_required_*)

merge 1:1 country using `years'

* GMFD ends in 2010
replace required_end = 2010 if required_end >= 2010
* the manually written list of countries here are those that were generated for migration but for which we want a longer time series for use in the employment shares
* regressions.
gen already_generated = (_merge == 3)
replace already_generated = 0 if inlist(country, "Cambodia", "China", "El Salvador", "Malaysia", "Mali", "Pakistan", "Philippines", "Portugal", "Rwanda")
replace already_generated = 0 if country == "Uganda"
drop _merge mig*

* update the metadata
export delim "$DB/Global ACP/labor/1_preparation/employment_shares/data/required_clim_data.csv", replace
