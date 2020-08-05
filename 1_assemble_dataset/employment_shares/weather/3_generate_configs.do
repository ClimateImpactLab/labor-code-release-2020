* Generate the config files we need for our climate data
* Author: Simon Greenhill, adapted from Tom's migration code
* Date: 9/10/2019

clear all
set more off
macro drop _all

cilpath
loc GIT $REPO/gcp-labor/1_preparation/employment_shares/data_cleaning/weather/config/

* Set parameters
local sys = "sacagawea" //running system
local gap = 5 //For BEST, generating 10-years data per output file is OK for the Sacagawea system, but for smaller grid GMFD data aggregation, take gap=5. 
local path "/shares/gcp/estimation/labor/employment_shares_data/climate_data/1_raw"
local weight "'popwt'"
loc clim "GMFD"
local GMFD_parm "'prcp', 'tavg'"
local transforms "'poly': 4"

import delim using "$DB/Global ACP/labor/1_preparation/employment_shares/data/required_clim_data.csv", clear
replace country = subinstr(country, " ","_",.)


replace required_end = 2010 if required_end > 2010
replace required_start = 1948 if required_start < 1948
local parameters "`GMFD_parm'"

levelsof country, local(countries)

*********************************
* 1. Write the gis config files *
*********************************

** set directory to store the files**
cd `GIT'/1_gis
loc adm 1 // can generalize this to loop over adm levels if we want adm2 data as well

foreach shp in `countries' {
	file open txt using "gis_`clim'_`shp'_adm`adm'.txt", write replace
		
	file write txt "{" _n
	file write txt "    'run_location': '`sys''," _n
	file write txt "    'n_jobs': 12," _n
	file write txt "    'verbose': 2," _n
	
	//Specify clim dataset
	file write txt "    'clim': '`clim''," _n
	
	//Location of the shapefile under directory "path" 
	file write txt "    'shapefile_location': '`path'/`shp'_adm`adm'/shapefile'," _n

	//Name of the shapefile
	file write txt "    'shapefile_name': '`shp'_adm`adm'_shp'," _n
	file write txt "    'shp_id': '`shp'_adm`adm''," _n
	
	file write txt "    'numeric_id_fields': []," _n
	file write txt "    'string_id_fields': ['GEOLEVEL`adm'']," _n
	
	//Pop weighted
    file write txt "    'weightlist': ['pop']," _n
	file write txt "    'use_existing_segment_shp': False," _n
	file write txt "    'filter_ocean_pixels': False," _n
    file write txt "    'keep_features': None," _n
    file write txt "    'drop_features': None" _n
	
	file write txt "}" _n
	file close txt	
}

*****************************************************
* 2. Write the merge transform average config files *
*****************************************************

** set directory to store the files**
cd "`GIT'/2_aggregation"

foreach shp in `countries' {
	di "`shp'"
	file open txt using "aggregation_`clim'_`shp'_adm`adm'.txt", write replace

	// Find the year required year start and year end for the country-adm unit we are looping through
	sum required_start if country == "`shp'"
	local y0 = r(mean)
	sum required_end if country == "`shp'"
	local y1 = r(mean)
	
	file write txt "{" _n
	file write txt "    'run_location': '`sys''," _n
				
	//Input file from the GIS step and output directory of the final csv 
	file write txt "    'input_file': '`path'/`shp'_adm`adm'/shapefile/segment_weights/`shp'_adm`adm'_shp_`clim'_grid_segment_weights_area_pop.csv'," _n 
	file write txt "    'output_dir': '`path'/`shp'_adm`adm'/climate'," _n
			
	file write txt "    'region_columns': ['GEOLEVEL`adm'']," _n
	file write txt "    'group_by_column': None," _n
	file write txt "    'weight_columns': [`weight']," _n
	file write txt "    'climate_source': ['`clim'']," _n
	
	file write txt "    'parameters': [`parameters']," _n
	file write txt "    'transforms': {`transforms'}," _n
	
	// not sure about this one!!
	file write txt "    'collapse_as': 'sum'," _n
	file write txt "    'collapse_to': 'month'," _n
	
	file write txt "    'year_block_size': `gap'," _n
	file write txt "    'first_year': `y0'," _n
	file write txt "    'last_year': `y1'" _n
	
	file write txt "}" _n
	file close txt
}
