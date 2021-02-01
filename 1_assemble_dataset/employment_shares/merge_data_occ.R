# made a few changes in the merge_data.R script. besides changing the file paths to /mnt/CIL_labor
# and /shares/gcp, I had to change the 'clim' file name. It is now GMFD_adm1_internal.csv, earlier it 
# was GMFD_adm1_internal_new.csv. Assuming they are the same and running the following code to include
# industry-wise shares to run the risk share regressions again by occupation. 


# Merge together IPUMS employment share data, LR Tavg data, and income data. 
rm(list = ls())
library(tidyverse)
library(glue)
library(cilpath.r)
library(zoo)
library(countrycode)

cilpath.r:::cilpath()

lab = glue("/mnt/CIL_labor/1_preparation/employment_shares/data")

# load empshares
emp = read_csv(glue("{lab}/adm1_empshares.csv")) %>%
	select(year, geolev1, geolev1_pop,total_pop, ind_highrisk_share, ind_highrisk_share_no50, industry_share10, industry_share20, industry_share30, industry_share50, ind_highrisk_share, ind_highrisk_share_no50)

# load income
inc = read_csv(glue("{lab}/income/income_downscaled_bartlett.csv"))

popop = read_csv(glue("{lab}/popop/popop_geolev1.csv")) %>%
	filter(!is.na(GEOLEVEL1)) %>%
	mutate(GEOLEVEL1 = as.numeric(GEOLEVEL1)) %>%
	select(GEOLEVEL1, popop) %>%
	data.frame()

# wrappers for functions so they can be called from within mutate_at
MA_30yr = function(x) {
	return(rollmean(x, k=30, fill=NA, align="right") / 365.25)
}

MA_15yr = function(x) {
	return(rollmean(x, k=15, fill=NA, align="right") / 365.25)
}

# load clim and calculate 30-year moving avgs
clim = read_csv(glue("/shares/gcp/estimation/labor/employment_shares_data/climate_data/2_intermediate/GMFD_adm1_internal.csv")) %>%
	group_by(geolevel1, year) %>%
	select(-month) %>%
	summarize_all(sum) %>%
	ungroup() %>%
	group_by(geolevel1) %>%
	mutate_at(vars(ends_with("pop")), 
		list(MA_30yr = MA_30yr, MA_15yr = MA_15yr)) %>%
	ungroup() %>%
	data.frame()

# merge the three datasets
all = full_join(emp, inc, by=c("geolev1"="geolevel1", "year")) %>%
	full_join(clim, by=c("geolev1"="geolevel1", "year")) %>%
	left_join(popop, by=c("geolev1"="GEOLEVEL1")) %>%
	data.frame()

# add continent indentifiers
all$continent = countrycode(sourcevar = all$country, origin = "country.name", destination = "continent")

# lump Fiji (the only country we have in Oceania) in with Asia
all %<>%
	mutate(
		continent = ifelse(country == "Fiji", "Asia", continent)
		) %>%
	filter(!is.na(country)) # filter out missing country (this is unusable West/East Germany data)

# save
write_csv(all, glue("{lab}/emp_inc_clim_merged_occ.csv"))
