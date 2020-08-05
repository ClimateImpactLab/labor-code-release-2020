* Shell out the python commands for intersect and GIS
* Author: Simon Greenhill, from Tom's migration code
* Date: 9/10/2019

clear all
set more off
macro drop _all
cap log close 
parallel initialize 12, f

cilpath
loc laborDB "$DB/Global ACP/labor/"
loc GIT $REPO/gcp-labor/1_preparation/employment_shares/data_cleaning/weather/config/
loc path $SHARES/estimation/labor/employment_shares_data/climate_data/1_raw

import delim using "`laborDB'/1_preparation/employment_shares/data/required_clim_data.csv"
* keep if already_generated == 0
replace country = subinstr(country, " ","_",.)
drop if required_end < 1948

levelsof country, local(countries)

loc clim "GMFD" // could generalize to loop over GMFD and BEST if desired
loc adm 1
loc test_mode 1 // toggle this to run for one (or a few) country only
if `test_mode' == 1 {
    loc countries "El_Salvador"
}
else { // write a log if not in test mode
    local date = subinstr(c(current_date), " ", "_", .)
    log using $REPO/gcp-labor/1_Cleaning/IPUMS/weather/log/4_`date'.log, replace text
}

foreach shp in `countries' {
	di "----intersect: `shp'----"
	cap confirm file `path'/`shp'_adm`adm'/shapefile/segment_weights/`shp'_adm`adm'_shp_`clim'_grid_segment_weights_area_pop.csv
	if _rc != 0 { // only run if appropriate segment weights not created
		cap mkdir `path'/`shp'_adm`adm'/clim
		shell python ~/climate_data_aggregation/gis/intersect_zonalstats_par.py `GIT'/1_gis/gis_`clim'_`shp'_adm`adm'.txt
	}

	di "----aggregate: `shp'----"
	shell python ~/climate_data_aggregation/aggregation/merge_transform_average.py `GIT'/2_aggregation/aggregation_`clim'_`shp'_adm`adm'.txt
}
