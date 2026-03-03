# Replicate India Time Use Survey (ITUS) cleaning
# Author: Simon Greenhill
# Date: 1/15/20

source("/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/0_subroutines/paths.R")
library(tidyverse)
library(magrittr)
library(glue)
library(data.table)
library(bit64)
library(haven)
library(testthat)
library(arules)
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
    hhsize = B1_q1
  ) %>%
  rename(Key_hhold = Hhold_key) %>%
  dplyr::select(
    Key_hhold, State, District, hhsize
  )

# block 2: individual-level characteristics
b2 = read_dta(glue("{input}/Block-2-Particulars-Household-members-records.dta")) %>%
  data.table() %>%
  rename(
    sex      = B2_c4,
    age      = B2_c5,
    industry = B2_c11,
    ent_stat = B2_c9
  ) %>%
  mutate(
    male = ifelse(sex == 1, 1, 0),
    high_risk_old = ifelse(
      industry < 400 | (industry >= 500 & industry < 600),
      1, 0
    ),
    self_emp = ifelse(ent_stat == 11, 1, 0),
    high_risk = ifelse(
      high_risk_old == 1 | (industry >= 700 & industry < 740),
      1, 0
    )
  ) %>%
  rename(Key_membno = Key_Membno) %>%
  dplyr::select(
    Key_hhold, Key_membno, sex, age, male, high_risk_old, high_risk, self_emp
  ) %>%
  distinct()

# block 3: date information
b3 = read_dta(glue("{input}/Block-3-Time-disposition-selected-days-week-records.dta")) %>%
  dplyr::rename(
    Key_membno          = KEY_MEMBno,
    Key_hhold           = KEY_hhold,
    response_code       = B3_q4b,
    date_normal         = B3_q3_L1_c2,
    date_weekly_variant = B3_q3_L1_c4,
    date_abnormal       = B3_q3_L1_c6,
    sample_wgt          = wgt_combined_dt,
    age_b3              = age
  ) %>%
  dplyr::select(Key_membno, Key_hhold, response_code, date_normal, date_weekly_variant, date_abnormal, age_b3, sample_wgt) %>%
  group_by(Key_membno, Key_hhold, response_code, age_b3) %>%
  summarize(
    date_normal         = max(date_normal),
    date_weekly_variant = max(date_weekly_variant),
    date_abnormal       = max(date_abnormal),
    sample_wgt          = first(sample_wgt)
  ) %>%
  pivot_longer(
    cols      = c(date_normal, date_weekly_variant, date_abnormal),
    names_to  = "date_type",
    values_to = "date"
  ) %>%
  mutate(
    day_type = ifelse(
      date_type == "date_normal", 1,
      ifelse(date_type == "date_weekly_variant", 2, 3)
    )
  ) %>%
  dplyr::select(-date_type) %>%
  filter(date != 0) %>%
  distinct(Key_membno, Key_hhold, date, day_type, .keep_all = TRUE) %>%
  filter(!(date %in% c('290299', '300299'))) %>%
  data.table()

# block 3.5: activity data
b3.5 = read_dta(glue("{input}/Block-3-Item-5-Particulars-activity-selected-days-records.dta")) %>%
  dplyr::rename(
    day_type      = B3_c0a,
    time_spent    = B3_q5_c5,
    activity_code = B3_q5_c7
  ) %>%
  mutate(
    is_work    = ifelse(activity_code <= 329 | activity_code %in% c(751, 892), 1, 0),
    high_risk2 = ifelse(
      activity_code <= 229 | activity_code %in% c(312:319, 326),
      1, 0
    ),
    # Agriculture work: activity codes 111-229 (crop farming, animal husbandry, fishing, forestry)
    # based on NIC-1987 classification
    is_agwork  = ifelse(activity_code <= 229, 1, 0),
    day_type   = as.numeric(day_type)
  ) %>%
  dplyr::select(Key_membno, Key_hhold, day_type, time_spent, activity_code, is_work, high_risk2, is_agwork)

b3_5_raw = read_dta(glue("{input}/Block-3-Item-5-Particulars-activity-selected-days-records.dta"))

# consolidate block 3 to get date information
b3_all = left_join(b3, b3.5, by = c('Key_membno', 'Key_hhold', 'day_type')) %>%
  dplyr::group_by(Key_membno, Key_hhold, date, day_type) %>%
  dplyr::summarize(
    mins_worked    = sum(time_spent[is_work == 1]),
    mins_worked_hr = sum(time_spent[is_work == 1 & high_risk2 == 1]),
    mins_not_worked = sum(time_spent[is_work == 0]),
    total_mins     = sum(time_spent),
    mins_agwork    = sum(time_spent[is_agwork == 1]),  # total minutes in agriculture work activities
    sample_wgt     = first(sample_wgt),
    age_b3         = first(age_b3)
  ) %>%
  filter(total_mins <= 1440) %>%
  data.table()

b3_all$perc_hr   <- ifelse(b3_all$mins_worked == 0, NA, b3_all$mins_worked_hr / b3_all$mins_worked)
b3_all$high_risk2 <- ifelse(b3_all$perc_hr >= 0.5, 1, 0)

expect(
  all(b3_all$total_mins == 1440),
  "Minutes do not add up to 24 hours!")

expect(
  all(b3_all$mins_worked + b3_all$mins_not_worked == b3_all$total_mins),
  "Worked and not worked minutes do not add up to total!")

############################
# 2. Merge blocks together #
############################

all = left_join(b3_all, b2, by = c('Key_membno', 'Key_hhold')) %>%
  left_join(b0.1, by = 'Key_hhold') %>%
  mutate(
    State    = as.numeric(State),
    District = as.numeric(District)
  )

expect(nrow(all) == nrow(b3_all), "Match not 1:1 or m:1!")

#########################################
# Clean and merge location information  #
#########################################

districts = fread(glue("{input}/../ITUS_district_codes.csv"))

states = data.table(
  st_name = c('HARYANA', 'MADHYA PRADESH', 'GUJARAT', 'ORISSA', 'TAMIL NADU', 'MEGHALAYA'),
  State   = seq(1, 6)
)

geo = merge(districts, states, by = 'st_name')

all_geo = left_join(all, geo, by = c('State', 'District')) %>%
  filter(
    age >= 15 & age <= 65,
    mins_worked > 0
  )

final_dataset = all_geo %>%
  dplyr::mutate(
    year   = as.numeric(str_sub(as.character(date), -2, -1)) + 1900,
    month  = as.numeric(str_sub(as.character(date), -4, -3)),
    day    = as.numeric(str_sub(as.character(date), -6, -5)),
    ind_id = group_indices(., Key_membno, Key_hhold)
  ) %>%
  dplyr::select(
    st_name, district_name, year, month, day, ind_id,
    mins_worked, mins_agwork,                           # <-- mins_agwork added here
    age, male, high_risk, high_risk2, self_emp, hhsize, sample_wgt
  ) %>%
  filter(
    year == 1999 | year == 1998,
    month >= 1 & month <= 12,
    day   >= 1 & day   <= 31
  ) %>%
  distinct()

write.csv(final_dataset, glue("{ROOT_INT_DATA}/surveys/cleaned_country_data/IND_ITUS_time_use.csv"))
write.dta(final_dataset, glue("{ROOT_INT_DATA}/surveys/cleaned_country_data/IND_ITUS_time_use.dta"))

location_names = final_dataset %>%
  dplyr::select(st_name, district_name) %>%
  dplyr::distinct(st_name, district_name)

write.csv(location_names, glue("{ROOT_INT_DATA}/surveys/cleaned_country_data/IND_ITUS_location_names.csv"))