# This script takes the raw IPUMS shapefiles and simplifies them for faster plotting 
# (adapted from code originally written for migration)
# Author: Simon Greenhill, sgreenhill@uchicago.edu
# Date: 4/11/2019

remove(list = ls())
library(tidyverse)
library(maptools)
library(sf)
library(glue)
library(mapview)
library(haven)
library(cilpath.r)

cilpath.r:::cilpath()

laborDB = glue("{DB}/labor/")

adm_lev = "adm1"
geo_lev = "geolev1"
shp_lev = quo(GEOLEVEL1) # quo function allows  for evaluation in dplyr functions below. 
shp_dir = glue("{laborDB}/1_preparation/IPUMS/shp")
shploc = glue("{shp_dir}/world_{geo_lev}_2019/")
shpname = glue("world_{geo_lev}_2019")

# get list of countries used in labor
countries = glue("{laborDB}/1_preparation/IPUMS/data/required_clim_data.csv") %>%
	read_csv() %>%
	pull(country) %>%
	gsub(pattern="_", replacement=" ") %>%
  	str_to_title()

# simplify the geolev1 file
shp_geolev1 = st_read(dsn = shploc, layer = shpname) %>%
  filter(!(grepl("99$|98$", GEOLEVEL1) & GEOLEVEL1 != 192099) & GEOLEVEL1 != 231017) %>%
  mutate(CNTRY_NAME = as.character(CNTRY_NAME), 
      CNTRY_NAME = ifelse(CNTRY_NAME == "Kyrghzstan", "Kyrgyz Republic", CNTRY_NAME), 
      CNTRY_NAME = ifelse(CNTRY_NAME == "Lao People's Democratic Republic", "Laos", CNTRY_NAME)) %>%
  st_transform(crs="+proj=robin +lon_0=0 +x_0=0 +y_0=0 +ellps=WGS84 +datum=WGS84 +units=m +no_defs") %>%
  filter(CNTRY_NAME %in% countries & !st_is_empty(.)) %>% # subset to only the countries we actually need this information for
  st_simplify() %>% # get rid of fine detail 
  st_cast("MULTIPOLYGON") %>% # cast all polygons as multipolygons so they can be easily decluttered 
  st_cast("POLYGON") %>% # remove small islands and other clutter 
  mutate(area=as.numeric(st_area(.))) %>% # compute area of each polygon
  filter(area > 10^8) %>% # get rid of small areas
  group_by(CNTRY_NAME, ADMIN_NAME, CNTRY_CODE, GEOLEVEL1, BPL_CODE) %>%
  st_buffer(0) %>% # avoids an error due to intersecting polygons 
  summarize()

dir.create(glue("{shploc}/simplified"))
shp_geolev1 %>% 
	st_write(dsn=glue("{shploc}/simplified/"), 
		     layer=glue("world_geolev1_simplified"), 
		     driver="ESRI Shapefile", 
		     delete_dsn = TRUE)