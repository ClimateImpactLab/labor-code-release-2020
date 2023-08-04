# Replicate cleaning of data from the Mutlinational Time Use Study (MTUS)
# Author: Simon Greenhill, sgreenhill@uchicago.edu
# Date: 12/4/19

# Start with an outline of what needs to be done, then fill out the details.
# This should eventually be turned into a readme describing the replication process. 

# The end goal (we want this for each country): a person-level dataset for people aged 15-65 that includes: 
# - Date of interview
# - minutes worked
# - minutes ("not worked")
# - risk classification (high or low)
# - age and age**2
# - male (indicator for gender)
# - household size
# - a clear way of merging in further variables as necessary
#     - proposed way of doing this: clean up the whole dataset, then subset at the very end.

# This dataset will cover: 
# - Spain, 2002-03
# - France, 1998-99
# - Great Britain, 1983-84, 1987, 1995, 2000, 2001

# Code(s) proceed as follows: 
# 1. Load raw data
# 2. Merge in geographic information
# 3. Merge in date information (from episode file)
# 4. Subset and create variables for estimating dataset

# Future code will: 
# 1. Implement this replication for each country
# 2. Append all country data together 
# 	 (ideally, we could write a master script that functionalizes each cleaning script, 
#     allowing us to specify the variables we want in the estimating dataset without having
#	  to edit a bunch fo scripts manually.)
# 3. Write sanity checks for the combined data (eg, daily hours add up to 24, ages in reasonable range)

# set up the environment
source("~/repos/labor-code-release-2020/0_subroutines/paths.R")
library(tidyverse)
library(magrittr)
library(glue)
library(data.table)
library(haven)
library(testthat)
library(foreign)
#cilpath.r:::cilpath()

input = glue("{ROOT_INT_DATA}/surveys/WEU_MTUS/raw_data/")

####################
# 1. Load raw data #
####################

adult = fread(glue("{input}/MTUS-adult-aggregate.csv"))
child = fread(glue("{input}/MTUS-child-aggregate.csv"))

comb = rbind(adult, child) 

# diagnostics 

######################################
# 2. Merge in geographic information #
######################################

gbr = read_dta(glue("{input}/SupplementaryData/region-race-uk.dta")) %>%
	data.frame() %>%
	zap_labels() %>%
	dplyr::select(-ethnic, -id) %>%
	distinct() # drop duplicates

fra = read_dta(glue("{input}/SupplementaryData/region-race-fra1998.dta")) %>%
	data.frame() %>%
	zap_labels() %>%
  dplyr::select(-ethnic) %>%
	distinct() # drop duplicates

esp = read_dta(glue("{input}/SupplementaryData/region-race-spa.dta")) %>%
	data.frame() %>%
	zap_labels() %>%
  dplyr::select(-ethnic) %>%
	distinct() # drop duplicates

# merge by country, then rbind

gbr_comb = comb %>%
  filter(countrya == 37) %>%
  mutate(iso = "GBR") 

gbr_comb$persid <- as.double(gbr_comb$persid)

gbr_comb = gbr_comb %>%
  merge(gbr, all.x=FALSE, by=c("countrya", "survey", "hldid", "persid"))

fra_comb = comb %>%
  filter(countrya == 12) %>%
  mutate(iso = "FRA") 

fra_comb$hldid <- as.double(fra_comb$hldid)

fra_comb =  fra_comb %>%
  merge(fra, all.x=FALSE, by=c("countrya", "survey", "swave", "msamp", "hldid", "persid"))

# !!!!! all.x changed from TRUE to FALSE, no effect on france, but elimited some obs for spain
esp_comb = comb %>%
	filter(countrya == 34) %>%
	mutate(iso = "ESP") %>%
	merge(esp, all.x=FALSE, by=c("countrya", "survey", "swave", "msamp", "hldid", "persid")) %>%
	# no region information prior to 2002 or in 2008, so we can't use those years.
	filter(year >= 2002 & year != 2008)


comb_geo = rbindlist(list(gbr_comb, fra_comb, esp_comb), use.names=TRUE)

# need to do checks on the merges here. Seem to be some NAs--need to decide whether merge should be less strict to avoid this.

# will need to merge the region ids with a shapefile (what is that shapefile?)

################################
# 3. Merge in date information #
################################

# merge in date information, which is available only in the "episode" file
ep_adult = fread(glue("{input}/MTUS-adult-episode.csv"))
ep_child = fread(glue("{input}/MTUS-child-episode.csv"))

ep = rbind(ep_adult, ep_child)   %>%
  dplyr::select(countrya, survey, swave, msamp, hldid, persid, id, day, cday, month, year) %>%
	mutate(
		id = ifelse(id > 13 & id == persid, 1, id)
		)%>%
	distinct()
	
# !!!!! all.x changed from true to false
# removed "id"
comb_all = comb_geo %>%
	merge(ep, all = FALSE, by=c("countrya", "survey", "swave", "msamp", "hldid", "persid", "year","month","day"))

#########################################################
# 4. Subset and create variables for estimating dataset #
#########################################################


comb_all[comb_all < 0] <- NA

final = comb_all %>%
	filter(
		badcase == 0, # filter to include only data that are not flagged as bad. Only about 3% of data flagged as bad. 
		age >= 15 & age <= 65, # filter to our desired age range
		cday > 0 & !is.na(cday), # filter out dates that are either not reported or unmatched
		occup > 0 & !is.na(occup), # filter out unreported or unmatched occupations
		!is.na(region), # filter out missing regions
		propwt != 0
		) %>%
	mutate( 
		# create the variables that will be used in the estimating dataset
		mins_worked = rowSums(dplyr::select(., main7, main8, main9, main10, main11, main12, main13, main14), na.rm=TRUE),
		total_mins = rowSums(dplyr::select(., starts_with("main")), na.rm=TRUE),
		mins_not_worked = total_mins - mins_worked,
		high_risk = ifelse(occup %in% c(12, 13), 1, 0),
		high_risk2 = ifelse(occup %in% c(10, 12, 13), 1, 0),
		self_emp = ifelse(occup ==14, 1, 0),
		male = ifelse(sex == 1, 1, 0),
		) %>%
	rename(
		hhsize = hhldsize
		) %>%
	filter(
	 	mins_worked > 0 # include only people who have worked in last week
		)
	
#write some unit tests here: minutes add up, to all worked, all worked == 24 hrs
expect(all(final$total_mins == 1440), "Minutes do not add up to 24 hours!")
expect(all(final$mins_worked + final$mins_not_worked == final$total_mins, na.rm=TRUE), "Worked and not worked do not add up to 24 hours!")

# need to add a region name column here that will allow for matching with shapefiles
final = final %>% 
  dplyr::select( # select the variables we want to write out into the estimating dataset
		iso, countrya, survey, hldid, persid, swave, msamp, cday, month, year, mins_worked, high_risk,  high_risk2, self_emp, age, male, hhsize, propwt, region
		) %>% 
	mutate(
		ind_id = group_indices(., countrya, survey, swave, msamp, hldid, persid)
		) %>%
	rename(
		day = cday,
		sample_wgt = propwt,
		region_code = region
		) %>% 
  dplyr::select(
		iso, region_code, ind_id, year, month, day, mins_worked, high_risk, high_risk2, self_emp, age, male, hhsize, sample_wgt
		)

final_gbr = final %>% 
	filter(
		iso == "GBR") %>% 
  dplyr::select(
		-iso)

final_fra = final %>% 
	filter(
		iso == "FRA") %>% 
  dplyr::select(
		-iso)

final_esp = final %>% 
	filter(
		iso == "ESP") %>% 
  dplyr::select(
		-iso)


fwrite(final, glue("{ROOT_INT_DATA}/surveys/cleaned_country_data/WEU_MTUS_time_use_SE.csv"))
write.dta(final, glue("{ROOT_INT_DATA}/surveys/cleaned_country_data/WEU_MTUS_time_use_SE.dta"))
fwrite(final_gbr, glue("{ROOT_INT_DATA}/surveys/cleaned_country_data/GBR_MTUS_time_use_SE.csv"))
fwrite(final_fra, glue("{ROOT_INT_DATA}/surveys/cleaned_country_data/FRA_MTUS_time_use_SE.csv"))
fwrite(final_esp, glue("{ROOT_INT_DATA}/surveys/cleaned_country_data/ESP_MTUS_time_use_SE.csv"))
write.dta(final_gbr, glue("{ROOT_INT_DATA}/surveys/cleaned_country_data/GBR_MTUS_time_use_SE.dta"))
write.dta(final_fra, glue("{ROOT_INT_DATA}/surveys/cleaned_country_data/FRA_MTUS_time_use_SE.dta"))
write.dta(final_esp, glue("{ROOT_INT_DATA}/surveys/cleaned_country_data/ESP_MTUS_time_use_SE.dta"))


final  = final %>%
  dplyr::select( # select the variables we want to write out into the estimating dataset
		iso, region_code
		) %>%
	distinct()


fwrite(final, glue("{ROOT_INT_DATA}/surveys/cleaned_country_data/WEU_MTUS_location_names.csv"))



