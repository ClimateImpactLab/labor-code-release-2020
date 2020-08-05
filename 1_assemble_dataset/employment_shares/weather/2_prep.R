# Prep for climate data generation by generating the folder structure and populating it with shapefiles
# Author: Simon Greenhill, adapted from Tom's migration code
# 9/10/2019

rm(list=ls())
library(dplyr)
library(sf)
library(glue)
cilpath.r:::cilpath()

dir = glue("{SHARES}/estimation/labor/")
laborDB = glue("{DB}/Global ACP/labor/")

# create the directories this will go to
dir.create(glue("{dir}//IPUMS/1_raw"), recursive = TRUE)
raw = glue("{dir}/employment_shares_data/climate_data/1_raw")

# list = read.csv(glue("{laborDB}/1_preparation/IPUMS/data/required_clim_data.csv")) %>%
# 	filter(already_generated == 0)
# re-running for only the countries where we do not have sufficient climate data to calculate
# 30 year MA in climate for final census.
# The reason we did not have enough data for this previously was because we re-used already-
# generated climate data from the migration sector, which was in many cases generated for
# fewer years than required by the full IPUMS employment shares dataset.
list = list(country=c('Cambodia', 'China', 'El Salvador', 'Malaysia', 'Mali', 'Philippines', 'Portugal',
         'Rwanda', 'Uganda'))

# load the world shapefile
# note that these are the shapefiles from the migration DB (they are the same)
shp_dir = glue("{laborDB}/1_preparation/employment_shares/data/shp/")
shp_sf = st_read(glue("{shp_dir}/world_geolev1_2019/world_geolev1_2019.shp"), stringsAsFactors = FALSE) %>%
	# IPUMS shapefiles include some places that don't exist (these are placeholders for unknowns). 
	# We drop these. Everything that ends in 99 or 98 is a missing; but one region (Isla de La Juventud, Cuba)
	# ends in 99 and is not a missing.
	# we also filter out 231017, which is an unmapped "special region" of Ethiopia.
	filter(!(grepl("99$|98$", GEOLEVEL1) & GEOLEVEL1 != 192099) & GEOLEVEL1 != 231017) %>%
	mutate(CNTRY_NAME = ifelse(CNTRY_NAME == "Kyrghzstan", "Kyrgyz Republic", CNTRY_NAME), 
		CNTRY_NAME = ifelse(CNTRY_NAME == "Lao People's Democratic Republic", "Laos", CNTRY_NAME))

# loop through each of the countries, generating a folder and the relevant shapefile, for adm1 level data
for (i in list$country) {
	i = as.character(i)
	# Filter the world shapefile to the country we are looping through
	shp = filter(shp_sf, CNTRY_NAME == i)

	# Get rid of annoying spaces that might be bad for the file structure
	i = gsub(" ","_",i)

	# Create a directory for the country - adm unit and shapefile
	dir.create(glue("{raw}/{i}_adm1/shapefile"), recursive = TRUE)

	# Save this shapefile in the relevant folder
	st_write(shp, glue("{raw}/{i}_adm1/shapefile/{i}_adm1_shp.shp"), delete_dsn = TRUE)
}
