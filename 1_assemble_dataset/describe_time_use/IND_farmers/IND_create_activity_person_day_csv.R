

source("/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/0_subroutines/paths.R")
library(tidyverse)
library(magrittr)
library(glue)
library(data.table)
library(bit64)
library(haven)
library(testthat)
library(parallel)
library(stringr)
library(foreign)

####################
# 1. Load raw data #
####################

input = glue("{ROOT_INT_DATA}/surveys/IND_ITUS/Time_use_survey_1998")

# ---- Block 0-1: Household characteristics ----
b0.1 = read_dta(glue("{input}/Block-0-1-Identification-Household-Characteristics-records.dta")) %>%
  data.table() %>%
  rename(
    hhsize    = B1_q1,
    Key_hhold = Hhold_key
  ) %>%
  dplyr::select(Key_hhold, State, District, hhsize)

# ---- Block 2: Individual-level characteristics ----
b2 = read_dta(glue("{input}/Block-2-Particulars-Household-members-records.dta")) %>%
  data.table() %>%
  rename(
    sex      = B2_c4,
    age      = B2_c5,
    industry = B2_c11,
    ent_stat = B2_c9
  ) %>%
  mutate(
    male         = ifelse(sex == 1, 1, 0),
    # High-risk classification based on NIC-1987 codes
    # Agriculture, mining, construction, etc. are considered high-risk
    high_risk_old = ifelse(
      industry < 400 | (industry >= 500 & industry < 600),
      1, 0
    ),
    self_emp = ifelse(ent_stat == 11, 1, 0),
    # Extend high_risk_old to also include transportation (700-739)
    high_risk = ifelse(
      high_risk_old == 1 | (industry >= 700 & industry < 740),
      1, 0
    )
  ) %>%
  rename(Key_membno = Key_Membno) %>%
  dplyr::select(Key_hhold, Key_membno, sex, age, male, high_risk_old, high_risk, self_emp) %>%
  distinct() %>%# remove a handful of duplicated observations
  filter(high_risk == 1)


# ---- Block 3: Date information ----
# Each individual has up to 3 survey dates: normal, weekly-variant, abnormal day
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
    # Where multiple obs exist per individual, take the real (non-zero) date
    date_normal         = max(date_normal),
    date_weekly_variant = max(date_weekly_variant),
    date_abnormal       = max(date_abnormal),
    sample_wgt          = first(sample_wgt)
  ) %>%
  # Reshape to long so each row is one (person, day_type) combination
  pivot_longer(
    cols      = c(date_normal, date_weekly_variant, date_abnormal),
    names_to  = "date_type",
    values_to = "date"
  ) %>%
  mutate(
    # day_type is used to merge with Block 3.5 activity records
    day_type = case_when(
      date_type == "date_normal"         ~ 1,
      date_type == "date_weekly_variant" ~ 2,
      date_type == "date_abnormal"       ~ 3
    )
  ) %>%
  dplyr::select(-date_type) %>%
  filter(date != 0) %>%                                               # drop missing dates
  distinct(Key_membno, Key_hhold, date, day_type, .keep_all = TRUE) %>% # keep first if duplicate
  filter(!(date %in% c('290299', '300299'))) %>%                     # remove non-existent dates Feb 29/30
  data.table()

# ---- Block 3.5: Activity-level records ----
# This block is the core of the activity-person-day dataset.
# Each row is one activity episode (person x day_type x activity).
b3.5 = read_dta(glue("{input}/Block-3-Item-5-Particulars-activity-selected-days-records.dta")) %>%
  dplyr::rename(
    day_type      = B3_c0a,
    time_spent    = B3_q5_c5,   # duration of this activity in minutes
    activity_code = B3_q5_c7    # activity classification code
  ) %>%
  mutate(
    # Work activities: codes <= 329 (SNA production) or specific codes 751, 892
    is_work    = ifelse(activity_code <= 329 | activity_code %in% c(751, 892), 1, 0),
    # High-risk work activities: outdoor/physical production activities
    high_risk2 = ifelse(
      activity_code <= 229 |
        activity_code %in% c(312:319, 326),
      1, 0
    ),
    day_type   = as.numeric(day_type)
  ) %>%
  dplyr::select(Key_membno, Key_hhold, day_type, time_spent, activity_code, is_work, high_risk2)

##############################################
# 2. Merge blocks to activity-person-day level
##############################################

# Join Block 3 (dates) with Block 3.5 (activities) on person + day_type
# Result: each row = one activity episode for one person on one calendar date
activity_person_day = left_join(b3, b3.5, by = c('Key_membno', 'Key_hhold', 'day_type'))

# Sanity check: total minutes per person-day should not exceed 1440 (24 hours)
person_day_totals = activity_person_day %>%
  group_by(Key_membno, Key_hhold, date, day_type) %>%
  summarize(total_mins = sum(time_spent, na.rm = TRUE)) %>%
  ungroup()

bad_ids = person_day_totals %>% filter(total_mins > 1440) %>%
  dplyr::select(Key_membno, Key_hhold, date, day_type)

# Remove person-days where total minutes exceed 24 hours
activity_person_day = activity_person_day %>%
  anti_join(bad_ids, by = c('Key_membno', 'Key_hhold', 'date', 'day_type'))

# Merge in individual characteristics (Block 2) and household characteristics (Block 0-1)
activity_person_day = activity_person_day %>%
  left_join(b2,   by = c('Key_membno', 'Key_hhold')) %>%
  left_join(b0.1, by = 'Key_hhold') %>%
  mutate(
    State    = as.numeric(State),
    District = as.numeric(District)
  )

#########################################
# 3. Merge geographic information
#########################################

districts = fread(glue("{input}/../ITUS_district_codes.csv"))

states = data.table(
  st_name = c('HARYANA', 'MADHYA PRADESH', 'GUJARAT', 'ORISSA', 'TAMIL NADU', 'MEGHALAYA'),
  State   = seq(1, 6)
)

geo = merge(districts, states, by = 'st_name')

activity_person_day = left_join(activity_person_day, geo, by = c('State', 'District'))

##################################################
# 4. Filter, parse dates, and finalize variables
##################################################

final_dataset = activity_person_day %>%
  filter(
    age >= 15 & age <= 65   # working-age population only
  ) %>%
  mutate(
    # Parse 6-digit date string (DDMMYY) into separate year/month/day columns
    year   = as.numeric(str_sub(as.character(date), -2, -1)) + 1900,
    month  = as.numeric(str_sub(as.character(date), -4, -3)),
    day    = as.numeric(str_sub(as.character(date), -6, -5)),
    # Unique individual identifier
    ind_id = group_indices(., Key_membno, Key_hhold)
  ) %>%
  filter(
    year  %in% c(1998, 1999),
    month >= 1  & month <= 12,
    day   >= 1  & day   <= 31
  ) %>%
  dplyr::select(
    # Geographic identifiers
    st_name, district_name,
    # Date
    year, month, day,
    # Person identifier
    ind_id,
    # Core activity variables (one row per activity episode)
    activity_code,   # activity classification code
    time_spent,      # duration of this activity in minutes  <-- key variable
    is_work,         # 1 if this is a work activity
    high_risk2,      # 1 if this is a high-risk work activity
    # Individual characteristics
    age, male, high_risk, self_emp,
    # Household characteristics
    hhsize,
    # Survey weight
    sample_wgt
  ) %>%
  distinct()

####################
# 5. Save output
####################

write.csv(
  final_dataset,
  glue("{ROOT_INT_DATA}/surveys/cleaned_country_data/IND_farmers_activities/IND_ITUS_activity_person_day_ag_worker.csv"),
  row.names = FALSE
)

write.dta(
  final_dataset,
  glue("{ROOT_INT_DATA}/surveys/cleaned_country_data/IND_farmers_activities/IND_ITUS_activity_person_day_ag_worker.dta")
)