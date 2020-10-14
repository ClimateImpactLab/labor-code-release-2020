rm(list=ls())
library(tidyverse)
library(glue)
library(cilpath.r)
library(lfe)
library(sf)
library(rgdal)
library(testthat)
library(grid)
library(gridExtra)
cilpath.r:::cilpath()
lab = glue("/mnt/CIL_Migration")
out = glue("{lab}/2_regressions/ipums/figures/full_sample")
migDB = glue("{DB}/Wilkes_InternalMigrationGlobal")
# source Trin's mapping utility
source(glue("~/repos/post-projection-tools/mapping/mapping.R"))
# load data and clean it up a little
dat = read_csv(glue("/mnt/CIL_labor/1_preparation/employment_shares/data/emp_inc_clim_merged.csv")) %>%
	# drop places that don't exist
	filter(geolev1 != 1 &
		(!(mod(geolev1, 100) %in% c(98, 99) & geolev1 != 192099))) %>%
	filter(!is.na(total_pop)) %>% # filter to census years only
	filter(year <= 2010) # drop years we don't have clim data for (GMFD only goes to 2010)