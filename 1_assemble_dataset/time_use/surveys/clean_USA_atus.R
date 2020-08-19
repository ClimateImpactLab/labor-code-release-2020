# Replicate cleaning of data from the ATUS
# Author: Simon Greenhill, sgreenhill@uchicago.edu
# Date: 12/4/19

# The end goal (we want this for each country): a person-level dataset for 
# people aged 15-65 that includes: 
# - Date of interview
# - minutes worked
# - minutes ("not worked")
# - risk classification (high or low)
# - age and age**2
# - male (indicator for gender)
# - household size
# - a clear way of merging in further variables as necessary
#     - proposed way of doing this: clean up the whole dataset, then subset at 
#		the very end.

# This dataset will cover: 
# - USA, 2003-2010

# ATUS is split up into 3 different files (with variables I need from them): 
# - atusact: time diary
# - atuscps: household data
# - atusresp: data about respondents
#	- tudiarydate: date of diary day
# 	- tudiaryday: day of week of diary day
#   - trmjind1: industry of main job (major industry, this is the variable used 
#	  previously)
#   - trholiday: flag to indicate a diary day was a holiday
# 	- trnumhou: household size
# - atusrost: household composition
# - atussum: summary of time diary
# 	- trdpftpt: Full time or part time employment status of respondent
#	- tesex: sex
#	- teage: age
#	- t05**: all work-related activities time
# - atuswgts: weights data
# - atuswho: who was with the respondents (don't need this one)

# Identifiers: 
# tucaseid: Unique identifier for the respondent
# tulineno: Identifies an individual in the respondent's household 
# 			(if tulineno==1, the record describes the respondent. 
#			in files that include this information, we will restrict
#			respondents only.)

# Based on the above, I will only clean atussum and atusresp, and the spatial
# data, because those contain all the data we need.
source("/home/liruixue/repos/labor-code-release-2020/0_subroutines/paths.R")
# set up the environment
library(tidyverse)
library(magrittr)
library(glue)
library(data.table)
library(bit64)
library(haven)
library(testthat)
library(arules)
library(parallel)
library(foreign)

cores = detectCores()

####################
# 1. Load raw data #
####################

input = glue("{ROOT_INT_DATA}/surveys/USA_ATUS/raw/")

# clean time diary data
atussum = fread(glue("{input}/atussum_0314/atussum_0314.dat")) %>%
	rename(
		id = TUCASEID,
		empstat = TRDPFTPT, # see atussum_0314.do for employment status information.
		sex = TESEX,
		age = TEAGE
		) %>%
	mutate(
		total_mins = rowSums(select(., starts_with("t", ignore.case=FALSE))),
		mins_worked = rowSums(select(., starts_with("t05"))),
		mins_not_worked = rowSums(select(select(., starts_with("t", ignore.case=FALSE)), -starts_with("t05"))),
		male = ifelse(sex == 1, 1, 0),
		) %>%
	select(id, empstat, sex, age, total_mins, mins_worked, mins_not_worked, male)

expect(
	all(atussum$total_mins == 1440), 
	"Minutes do not add up to 24 hours!")

expect(
	all(atussum$mins_worked + atussum$mins_not_worked == atussum$total_mins), 
	"Worked and not worked minutes do not add up to total!")

# clean respondent data (covariates)
atusresp = fread(glue("{input}/atusresp_0314/atusresp_0314.dat")) %>%
	rename(
		id = TUCASEID,
		date = TUDIARYDATE,
		dow = TUDIARYDAY,
		hhsize = TRNUMHOU,
		is_holiday = TRHOLIDAY
		) %>%
	filter(
		# filter out missing and "other" industry values,
		# as well as miscoded industry values (>13 or <= 0)
		TRMJIND1 <= 13 & TRMJIND1 > 0,
		) %>%
	mutate(
		high_risk = ifelse(TRMJIND1 %in% c(1, 2, 3, 4, 6), 1, 0)
		)


# clean region data
# this requires several steps: 
# 1. obtain a mergeable household id from the ATUS-CPS data
# 2. go to the CPS to get county information.
# 3. Merge full CPS with ATUS-CPS
# 4. Winnow down to cases with usable geographic info

# load and clean ATUS-CPS data
atuscps = fread(glue("{input}/atuscps_0314/atuscps_0314.dat")) %>%
	rename(
		id = TUCASEID,
		hhid = HRHHID,
		hhid2 = HRHHID2,
		hrsersuf = HRSERSUF,
		statefips = GESTFIPS,
		lineno = PULINENO,
		month = HRMONTH,
		year = HRYEAR4
		) %>%
	select(id, hhid, hhid2, statefips, hrsersuf, lineno, month, year) %>%
	mutate(hhid = as.double(hhid)) %>%
	data.table()

#####################################
# 2. Prepare geographic information #
#####################################

# load CPS data to get county information
# CPS data includes:
# - fipscounty (the FIPS county code). This is missing for a large number of cases.
# - cmsacode05
# - cmsacode14
# - smsastat05
# - smsastat14


# this function loads the standardized CPS data and merges it with the atuscps data. There is one file per year 2002-2014.
load_merge_cps = function(year) {
	ds = read_dta(glue("{input}/CEPR_CPS/cepr_org_{year}.dta")) %>%
		mutate(statefips = state) %>% # keep the state FIPS code
		mutate_at( # convert labelled variables into values (in stata-speak, -decode-)
			vars(state, cmsacode05, cmsacode14, smsastat05, smsastat14), 
			as_factor
			) %>%
		mutate_at(
			vars(hhid, hhid2),
			as.numeric
			) %>%
		select(hhid, hhid2, lineno, month, year, state, fipscounty, 
			hrsersuf, starts_with("cmsa"), starts_with("smsa")) %>%
		distinct(hhid, lineno, month, .keep_all=TRUE) %>% # remove duplicates (there are a handful)
		data.table()

	# need to handle different years differently because of changing merge variables.
	# See Appendix K of the ATUS users guide (atususersguide.pdf) for details.
	if (year < 2004) {
		ret = merge(ds[,hhid2:=NULL], atuscps, by=c("hhid", "lineno", "month", "year", "hrsersuf"))
	} else if (year == 2004) {
		# subset data according to how it should be merged, removing the column that will not be used in the merge
		ds_1 = ds[month < 5][,hhid2:=NULL]
		ds_2 = ds[month >= 5][, hrsersuf:=NULL]

		ret_1 = merge(ds_1, atuscps, by=c("hhid", "lineno", "month", "year", "hrsersuf"))
		ret_2 = merge(ds_2, atuscps, by=c("hhid", "lineno", "month", "year", "hhid2"))

		ret = rbind(ret_1, ret_2)
	} else {
		ret = merge(ds[,hrsersuf:=NULL], atuscps, by=c("hhid", "lineno", "month", "year", "hhid2"))
	}

	ret %<>%
		rename(
			cps_year = year, 
			cps_month=month)
	print(glue("Loaded and merged {year}."))
	return(ret)
}

# apply the function and combine the results, then clean up.
cps_raw = mclapply(seq(2002, 2014), load_merge_cps, mc.cores=cores) %>%
	rbindlist(use.names=TRUE) %>%
	mutate(
		fipscounty = ifelse(fipscounty == 0, NA, fipscounty),
		fips = 1000*statefips + fipscounty,
		# the CPS has an outdated FIPS code for Dade County, FL. Replace it.
		# see here for more info: https://www.ddorn.net/data/FIPS_County_Code_Changes.pdf
		fips = ifelse(fips == 12025, 12086, fips)
		) # %>%
	# as.data.table()

# load FIPS code to county name crosswalk
fips_cw = fread(glue("{input}/Crosswalk_Files/fs04ctst.csv")) %>%
	rename(
		fips = FIPS,
		fips_name = `COUNTY/TOWN`) %>%
	select(fips, fips_name) %>%
	distinct(fips, .keep_all=TRUE)

# load SMSA and CMSA to count name crosswalk
# Note that this crosswalk was (seemingly) created by hand by Anthony D'Agostino.
# I (Simon) have not completed a methodical check of it (should I?).
# Changes I've made: 
# - Create a .csv version
# - Add CMSA information for a handful of places that were unmatched in the SMSA and fips data.

print("Warning: Geographic matching is done partially using a lookup table that has not been verified.")
smsa_cw = fread(glue("{input}/Crosswalk_Files/CEPR/CEPR_SMSA_County_Lookup_Clean.csv"))

smsastat05 = smsa_cw %>%
	select(statename, smsastat05_mast, best_county) %>%
	rename(
		state = statename,
		smsastat05 = smsastat05_mast,
		best_county_smsastat05 = best_county
		) %>%
	filter(smsastat05 != "") %>%
	distinct(state, smsastat05, .keep_all=TRUE)

smsastat14 = smsa_cw %>% 
	select(statename, smsastat14_mast, best_county) %>%
	rename(
		state = statename, 
		smsastat14 = smsastat14_mast,
		best_county_smsastat14 = best_county
		) %>%
	filter(smsastat14 != "") %>%
	distinct(smsastat14, state, .keep_all=TRUE)

cmsacode05 = smsa_cw %>%
	select(statename, cmsacode05, best_county) %>%
	rename(
		state = statename,
		best_county_cmsacode05 = best_county
		) %>%
	filter(cmsacode05 != "") %>%
	distinct(cmsacode05, state, .keep_all=TRUE)

cmsacode14 = smsa_cw %>%
	select(statename, cmsacode14, best_county) %>%
	rename(
		state = statename,
		best_county_cmsacode14 = best_county
		) %>%
	filter(cmsacode14 != "") %>%
	distinct(cmsacode14, state, .keep_all=TRUE)

get_master_county_name = function(data) {
	# from a state, county fips code, cmsacodes, and smsastats, get a county
	# name by looking up sequentially through all the crosswalks
	ret = data %>%
		merge(smsastat05, by=c("state", "smsastat05"), all.x=TRUE) %>%
		merge(smsastat14, by=c("state", "smsastat14"), all.x=TRUE) %>%
		merge(cmsacode05, by=c("state", "cmsacode05"), all.x=TRUE) %>%
		merge(cmsacode14, by=c("state", "cmsacode14"), all.x=TRUE) %>%
		merge(fips_cw, by="fips", all.x=TRUE) %>%
		mutate( 
			# create master county name column. 
			# Default to the FIPS county name, then to the SMSA (which are less granular)
			# Note that there are no cases where best_county_smsastat14 and best_county_smsastat05 overlap,
			# so we don't need to evaluate agreement between the two.
			# Same for cmsacode05 and cmsacode 14
			master_county_name = ifelse(
				is.na(fips_name),
				ifelse(
					is.na(best_county_smsastat05),
					ifelse(
						is.na(best_county_smsastat14),
						ifelse(
							is.na(best_county_cmsacode05),
							best_county_cmsacode14,
							best_county_cmsacode05
							),
						best_county_smsastat14),
					best_county_smsastat05),
				fips_name
				)
			)
	return(ret)
}

# create master lookup table
cps_geo = cps_raw %>%
	select(state, fipscounty, cmsacode05, cmsacode14, smsastat14, smsastat05, statefips, fips) %>%
	unique()

# merge in a master county name
cps_geo = merge(cps_geo, get_master_county_name(cps_geo), 
	by=c(
	'state', 'fipscounty', 'smsastat05', 'smsastat14', 'cmsacode05',
	'cmsacode14', 'fips', 'statefips'))

find_nearest_geo = function(pid, hh, maxdiff=365.25*3) {	
	# for individuals that are missing geographic information, match it to 
	# observations of the individual's household in the CPS data, and return 
	# that info if it's the within a specified time window
	tomatch = cps_raw %>%
		filter(hhid==hh) %>%
		as.data.table()

	tomatch[, c('date') := .(paste(cps_year, cps_month, 1, sep="-"))]

	if (nrow(tomatch) %in% c(0, 1)) {
		return(tomatch[0,])
	}

	old_date = tomatch %>% 
		filter(id==pid) %>% 
		pull(date)

	new_dates = tomatch[id != pid & (!is.na(cmsacode05) | !is.na(cmsacode14) | !is.na(smsastat05) | !is.na(smsastat14) | !is.na(smsastat14) | !is.na(fipscounty))]
	setorder(new_dates, date)

	new_date = new_dates[,date][1]
	new_vals = new_dates[1]

	diff = as.Date(new_date) - as.Date(old_date)

	if (as.numeric(abs(diff)) > maxdiff | is.na(diff)) {
		# return NA if we can't get a close enough observation
		return(new_vals[0,])
	} else {
		new_vals %<>%
			get_master_county_name()
		return(new_vals) 
	}
}

# merge new geographic info back into main cps table
# note some hhids will still have missing geographic information.
# This will be addressed as much as possible in section 3 (below).
cps = merge(
	cps_raw, cps_geo, 
	by=c(
		"state", "fipscounty", "fips", "cmsacode05", "cmsacode14", 
		"smsastat14", "smsastat05", "statefips"
		),
	all.x=TRUE
	)

cps_matched = cps %>%
	filter(!is.na(master_county_name))

cps_unmatched = cps %>%
	filter(is.na(master_county_name))

# first thing tomorrow--check this worked, if so can rbind the above and be done.
imputed_geo = mcmapply(
		find_nearest_geo,
		pid=cps_unmatched$id, 
		hh=cps_unmatched$hhid,
		mc.cores=20) %>%
	rbindlist(fill=TRUE) %>%
	select(-date)

cps_all = rbindlist(list(cps_matched, imputed_geo), use.names=TRUE)	

################################
# 3. Merge everything together #
################################

# note that the ATUS is cross-sectional, so the case id is sufficient for linking records.
final = merge(atussum, atusresp, by=c("id")) %>%
	merge(cps, by=c("id")) %>%
	mutate(
		year = as.numeric(substr(date, 1, 4)),
		month = as.numeric(substr(date, 5, 6)),
		day = as.numeric(substr(date, 7, 8))
		) %>%
	select( # remove crosswalk variables that are no longer needed
		-starts_with("best_county"), -fips_name) %>%
	filter( # filter to our desired demographics
		age >= 15 & age <= 65,
		is_holiday != 1,
		mins_worked > 0, # include only people who worked last week
		!is.na(master_county_name),
		year <= 2010,
		) %>%
	rename(
		sample_wgt = TUFNWGTP
		) %>%
	mutate(
		ind_id = group_indices(., id, hhid, lineno, hhid2) 
		) %>%
	select(
		ind_id, state, master_county_name, year, month, day, mins_worked, age, male, hhsize, high_risk, sample_wgt
		) 


fwrite(final, glue("{ROOT_INT_DATA}/surveys/cleaned_country_data/USA_ATUS_time_use.csv"))
write.dta(final, glue("{ROOT_INT_DATA}/surveys/cleaned_country_data/USA_ATUS_time_use.dta"))

location_names = final %>% 
	select(state, master_county_name) %>%
	distinct()
fwrite(location_names, glue("{ROOT_INT_DATA}/surveys/cleaned_country_data/USA_ATUS_location_names.csv"))
