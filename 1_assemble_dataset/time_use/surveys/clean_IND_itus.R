# Replicate India Time Use Survey (ITUS) cleaning
# Author: Simon Greenhill
# Date: 1/15/20

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
# - India, 1998-1999

# The ITUS is split into "blocks" as follows: 
# (description obtained from ClimateLaborGlobalPaper/Paper/Data/Construction/India/India_ITUS_DataConstructionSummary.docx)
# - Block 0-1: household characteristics
# - Block 2: individual-level characteristics (all individuals, including those for whom time-use data not collected)
# - Block 3: dates for which surveys were conducted
# - Block 3.5: activity-level data for all recorded individuals, organized by time of day and survey-date
# I will clean these blocks individually and then merge them together

# set up the environment
source("/project/cil/home_dirs/egrenier/repos/labor-code-release-2020/0_subroutines/paths.R")

library(tidyverse)
library(magrittr)
library(glue)
library(data.table)
library(bit64)
library(haven)
library(testthat)
#library(arules)
library(parallel)
library(stringr)
library(foreign)

####################
# 1. Load raw data #
####################

input = glue("{ROOT_INT_DATA}/surveys/IND_ITUS/Time_use_survey_1998")

# block 0-1: household characteristics
b0.1 = read_dta(glue("{input}/Block-0-1-Identification-Household-Characteristics-records.dta")) %>%
	data.table() %>%
	rename(
		hhsize = B1_q1 # this one is the same as old data
		) %>%
	rename(Key_hhold = Hhold_key) %>%
  dplyr::select( # select the datat we want and variables needed for merging (come back to this)
		Key_hhold, State, District, hhsize
		)
	# mutate_if(is.labelled, as_factor) %>%
	# data.table()

# block 2: individual-level characteristics
b2 = read_dta(glue("{input}/Block-2-Particulars-Household-members-records.dta")) %>%
	data.table() %>%
	rename(
		sex = B2_c4,
		age = B2_c5, # same as old data
		industry = B2_c11, 
		ent_stat = B2_c9
		) %>%
  mutate(industry = as.numeric(industry)) %>%
  filter(!is.na(industry)) %>%
	mutate(
		male = ifelse(sex == 1, 1, 0), #same as old data
		#age2 = age^2,
		# risk information taken from 1987 National Industrial Classification (NIC-1987) codes:
		# http://mospi.nic.in/classification/national-industrial-classification/national-industrial-classification-1987
		# https://www.dropbox.com/scl/fi/rmk9x6dacdoruqlwelvb8/NIC87_Codes.csv?rlkey=9tg0had5n7lsdo6gsvla974sr&e=1&st=u14hmo39&dl=0 <- if unavailable from india website
		# also create a "high_risk_old" variable which is intended to mimic the way high risk was constructed prviously
		high_risk_old = ifelse(
			industry < 400 | (industry >= 500 & industry < 600),
			1,
			0
			),
		self_emp = ifelse(ent_stat == 11, 1, 0),
		high_risk = ifelse(
			high_risk_old == 1 | (industry >= 700 & industry < 740), # add in transportation
			1,
			0
			),
		high_risk3 = ifelse(
		  industry < 99, 
		  1, 
		  0
		),
		high_risk4 = ifelse(
		  industry < 200 | (industry >= 500 & industry < 600), 
		  1, 
		  0
		),
		manuf = ifelse(
		  high_risk == 1 & high_risk3 == 0,
		  1,
		  0
		),
		manuf2 = ifelse(
		  high_risk == 1 & high_risk4 == 0,
		  1,
		  0
		)
		) %>%
	rename(Key_membno = Key_Membno) %>%
  dplyr::select( # select the datat we want and variables needed for merging (come back to this)
		Key_hhold, Key_membno, sex, age, male, high_risk_old, high_risk, high_risk3, high_risk4, manuf, manuf2, self_emp, age #, age2,
		) %>%
	distinct() # filter out a handful of duplicated obs

# block 3: date information
b3 = read_dta(glue("{input}/Block-3-Time-disposition-selected-days-week-records.dta")) %>%
	dplyr::rename(
		Key_membno = KEY_MEMBno,
		Key_hhold = KEY_hhold,
		response_code = B3_q4b,
		date_normal = B3_q3_L1_c2,
		date_weekly_variant = B3_q3_L1_c4,
		date_abnormal = B3_q3_L1_c6,
		sample_wgt = wgt_combined_dt,
		age_b3 = age
		) %>%
  dplyr::select(Key_membno, Key_hhold, response_code, date_normal, date_weekly_variant, date_abnormal, age_b3, sample_wgt) %>%
	group_by(Key_membno, Key_hhold, response_code, age_b3) %>%
	summarize(
		# in some cases, it seems like there are multiple observations per individual.
		# in some of those observations, the date is recorded as 0, and in others it's recorded as a real date/
		# we consolidate to include only these real dates where they exist.
		date_normal = max(date_normal),
		date_weekly_variant = max(date_weekly_variant),
		date_abnormal = max(date_abnormal),
		sample_wgt = first(sample_wgt)
		) %>%
	pivot_longer(
		cols = c(date_normal, date_weekly_variant, date_abnormal), 
		names_to="date_type", 
		values_to="date"
		) %>%
	mutate( # create a day_type variable with which to merge to block 3.5
		day_type = ifelse(
			date_type == "date_normal",
			1,
			ifelse(
				date_type == "date_weekly_variant",
				2,
				3
				)
			)
		) %>%
  dplyr::select(-date_type) %>%
	filter(date != 0) %>% # we've done what we can to recover correct dates, missing dates are now dropped.
	distinct(Key_membno, Key_hhold, date, day_type, .keep_all=TRUE) %>% # in some cases, an id appears twice. we keep only the first one
	filter( 
		# remove two dates that do not exist: 2/29/1999 and 2/30/1999.
		# this affects only 5 observations
		!(date %in% c('290299', '300299'))) %>%
	data.table()
# ?????? keep only the first one?

duplicated_rows <- duplicated(b3[, .(Key_membno, Key_hhold)]) | 
  duplicated(b3[, .(Key_membno, Key_hhold)], fromLast = TRUE)

# Subset to keep only duplicated rows
b3_duplicates <- b3[duplicated_rows]

# block 3.5: activity data
b3.5 = read_dta(glue("{input}/Block-3-Item-5-Particulars-activity-selected-days-records.dta")) %>%
	dplyr::rename(
		day_type = B3_c0a,
		time_spent = B3_q5_c5,
		activity_code = B3_q5_c7
		) %>%
	mutate(
		is_work = ifelse(activity_code <= 329 | activity_code %in% c(751, 892), 1, 0),
		high_risk2 = ifelse(activity_code <= 229 | activity_code == 312 | activity_code == 313 | activity_code == 314 | activity_code == 315 | activity_code == 316 | activity_code == 317 | activity_code == 318 | activity_code == 319 | activity_code == 326, 1, 0),
		occup_code = ifelse(activity_code %in% c(111:117, 119:127, 129:135, 137, 139:146, 148, 149), 1, 0), # 1: agriculture, 2: manufacturing etc., 3: mining + construction
		occup_code = ifelse(activity_code %in% c(152:156, 159, 165, 221:227, 229, 312:319, 326), 2, occup_code),
		occup_code = ifelse(activity_code %in% c(161:164, 166, 167, 169, 211:217, 219), 3, occup_code),
		day_type = as.numeric(day_type)
		) %>%
  dplyr::select(Key_membno, Key_hhold, day_type, time_spent, activity_code, is_work, high_risk2, occup_code)

b3_5_raw = read_dta(glue("{input}/Block-3-Item-5-Particulars-activity-selected-days-records.dta"))

# consolidate block 3 to get date information
b3_all = left_join(b3, b3.5, by=c('Key_membno', 'Key_hhold', 'day_type')) %>%
	dplyr::group_by(Key_membno, Key_hhold, date, day_type) %>%
	dplyr::summarize(
		mins_worked = sum(time_spent[is_work == 1]),
		mins_worked_hr = sum(time_spent[is_work == 1 & high_risk2 ==1]),
		mins_worked_oc1 = sum(time_spent[is_work == 1 & occup_code ==1]),
		mins_worked_oc2 = sum(time_spent[is_work == 1 & occup_code ==2]),
		mins_worked_oc3 = sum(time_spent[is_work == 1 & occup_code ==3]),
		mins_not_worked = sum(time_spent[is_work == 0]),
		total_mins = sum(time_spent),
		sample_wgt = first(sample_wgt),
		age_b3 = first(age_b3)
		) %>%
	filter(total_mins <= 1440) %>% # filter out the 4 observations where the minutes add up to 2880 (48 hours)
	data.table()

b3_all$perc_hr <- ifelse(b3_all$mins_worked == 0, NA, b3_all$mins_worked_hr/b3_all$mins_worked)
b3_all$perc_oc1 <- ifelse(b3_all$mins_worked == 0, NA, b3_all$mins_worked_oc1/b3_all$mins_worked)
b3_all$perc_oc2 <- ifelse(b3_all$mins_worked == 0, NA, b3_all$mins_worked_oc2/b3_all$mins_worked)
b3_all$perc_oc3 <- ifelse(b3_all$mins_worked == 0, NA, b3_all$mins_worked_oc3/b3_all$mins_worked)

b3_all$high_risk2 <- ifelse(b3_all$perc_hr >= 0.5, 1, 0)
b3_all$occup_code <- ifelse(b3_all$perc_oc1 >= 0.5, 1, 
                            ifelse(b3_all$perc_oc2 >= 0.5, 2,
                                   ifelse(b3_all$perc_oc3 >= 0.5, 3, 0)))

expect(
	all(b3_all$total_mins == 1440), 
	"Minutes do not add up to 24 hours!")

expect(
	all(b3_all$mins_worked + b3_all$mins_not_worked == b3_all$total_mins), 
	"Worked and not worked minutes do not add up to total!")

############################
# 2. Merge blocks together #
############################

all = left_join(b3_all, b2, by=c('Key_membno', 'Key_hhold')) %>%
	left_join(b0.1, by = 'Key_hhold') %>%
	mutate(
		State = as.numeric(State),
		District = as.numeric(District)
		)

expect(nrow(all) == nrow(b3_all), "Match not 1:1 or m:1!")

#########################################
# Clean and  merge location information #
#########################################

districts = fread(glue("{input}/../ITUS_district_codes.csv"))

# manually create lookup table for states based on Documentation/stcodes.txt,
# because districts lookup table lacks state codes
states = data.table(
	st_name = c(
		'HARYANA', 
		'MADHYA PRADESH',
		'GUJARAT',
		'ORISSA',
		'TAMIL NADU',
		'MEGHALAYA'
		),
	State = seq(1, 6)
	)

# merge district codes and state codes
geo = merge(districts, states, by='st_name')

# merge in geo information and filter to what we need
all_geo = left_join(all, geo, by=c('State', 'District')) %>%
	filter(
		age >= 15 & age <= 65,
		mins_worked > 0
		)

final_dataset = all_geo %>% 
	dplyr::mutate(
		year = as.numeric(str_sub(as.character(date), -2,-1)) + 1900,
		month = as.numeric(str_sub(as.character(date), -4,-3)),
		day = as.numeric(str_sub(as.character(date), -6,-5)),
		ind_id = group_indices(., Key_membno, Key_hhold)
		) %>% 
	dplyr::select(
		st_name, district_name, year, month, day, ind_id, mins_worked, age, male, high_risk, high_risk2, high_risk3, high_risk4, manuf, manuf2, occup_code, self_emp, hhsize, sample_wgt
		) %>% 
	filter(
		year == 1999 | year == 1998,
		month >= 1 & month <= 12,
		day >= 1 & day <= 31
		) %>%
	distinct()


head(final_dataset)

write.csv(final_dataset, glue("{ROOT_INT_DATA}/surveys/cleaned_country_data/IND_ITUS_time_use_3sector_occup_codes.csv"))
write.dta(final_dataset, glue("{ROOT_INT_DATA}/surveys/cleaned_country_data/IND_ITUS_time_use_3sector_occup_codes.dta"))

location_names = final_dataset %>%
	dplyr::select(
		st_name, district_name
		) %>%
	dplyr::distinct(
		st_name, district_name
		)

write.csv(location_names, glue("{ROOT_INT_DATA}/surveys/cleaned_country_data/IND_ITUS_location_names.csv"))


