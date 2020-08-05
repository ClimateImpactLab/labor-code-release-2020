# Prepare China time use data from China Health and Nutrition Study (CHNS)
# Author: Simon Greenhill, sgreenhill@uchicago.edu
# Date: 11/26/2019

rm(list=ls())
library(tidyverse)
library(haven)
library(data.table)
library(glue)
library(magrittr)
library(testthat)
cilpath.r:::cilpath()

input = glue("{DB}/Global ACP/labor/1_preparation/time_use/china/CHNSRawData/")
output = glue("{DB}/Global ACP/labor/1_preparation/time_use/china/")

select_vars = function(df) {
	# function to select only the columns we want
	return(df %>% 
		select(colnames(df)[nchar(colnames(df)) > 7 | colnames(df) %in% c("idind", "hhid", "wave")]))
}

# load in time use data
time = read_dta(glue("{input}/original/wages_01.dta")) %>%
	rename(
		hrs_worked_last_week = c7, 
		province = t1
		) %>%
	select_vars() %>%
	select(-wage89_imp) %>%
	data.frame()

# load in occupation data
occ = read_dta(glue("{input}/original/jobs_00.dta")) %>%
	rename(
		is_working = b2,
		primary_job = b4,
		primary_job_hrs_per_week = b8,
		primary_job_position = b9,
		has_secondary_job = b9a,
		secondary_job_hrs_per_week = b13
		) %>%
	select_vars() %>%
	data.frame()


# gender and birthdate 
cov = read_dta(glue("{input}/original/mast_pub_01.dta")) %>%
	mutate(
		male = ifelse(gender == 1, 1, 0)) %>%
	select(idind, gender, male, west_dob_y) %>%
	data.frame()

# interview date and age
date = read_dta(glue("{input}/original/surveys_pub_01.dta")) %>%
	rename(
		interview_date = t7) %>%
	select(idind, hhid, wave, age, interview_date) %>%
	data.frame()

# household size
hhsize = read_dta(glue("{input}/original/hhinc_pub_00.dta")) %>%
	select(hhid, wave, hhsize) %>%
	data.frame()

# community id
commid = read_dta(glue("{input}/original/asset_00.dta")) %>%
	select("wave", "hhid", "commid")

# merge all of the above together
# merging on individual id, hh id 
comb = Reduce(function(x,y) full_join(x, y, by=c("idind", "hhid", "wave")), list(time, occ, date))

# merge in variables identified by individual id only
comb %<>% left_join(cov, by="idind")

# merge in variables identified by hhid and wave only
comb %<>% left_join(hhsize, by=c("hhid", "wave"))

# merge in community id
comb %<>% left_join(commid, by=c("hhid", "wave"))

# clean up dataset: 
# 1. subset to workers only
# 2. classify high risk employment. there are several ways of doing this. Possible high-risk occupations include:
#		a. clearly high-risk: 5 (farmer, fisherman, hunter), 9 (ordinary solider, policeman), 10 (driver)
#		b. possibly high-risk: 6 (skilled worker, for example foreman, craftsman), 7 (non-skilled worker, eg a day laborer)
# Make two versions of the high_risk classification, one with only (a) and one with both (a) and (b).
# 3. Convert hours worked to minutes worked
final = comb %>%
	filter(is_working == 1) %>%
	mutate(
		mins_worked = hrs_worked_last_week * 60,
		high_risk = ifelse(primary_job %in% c(5, 9, 10, 6, 7), 1, 0),
		age2 = age^2
		)

# will want to write a few automated checks for final data.
# for example: 
# does age + dob = interview date?
expect(all(abs(as.numeric(final$west_dob_y) + as.numeric(final$age) - as.numeric(substr(final$interview_date, 1, 4))) <= 1, na.rm=TRUE),
	"Year of birth + age not within 1 interview year")

expect(all(substr(final$hhid, 1, 6) == final$commid, na.rm=TRUE), "hhids and commids don't match up")

# write out
fwrite(final, glue("{output}/chn_time_use.csv"))

###############
# DIAGNOSTICS #
###############

# check out missings
# is occupation missing for people who are working?
final %>% 
	mutate(missing = ifelse(is.na(primary_job), 1, 0)) %>% 
	group_by(wave, province) %>% 
	summarize(
		missing_share = sum(missing) / n(),
		observations = n()) %>%
	data.frame()


# what is distribution of missing for hrs worked data?
final %>% 
	mutate(missing = ifelse(is.na(hrs_worked_last_week), 1, 0)) %>% 
	group_by(wave, province) %>% 
	summarize(
		missing_share = sum(missing) / n(),
		observations = n()) %>%
	data.frame()
