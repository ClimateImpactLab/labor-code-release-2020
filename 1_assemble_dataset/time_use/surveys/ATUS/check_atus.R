# Compare replicated ATUS data to original ATUS data
# Author: Simon Greenhill, sgreenhill@uchicago.edu
# Date: Jan. 13, 2020

rm(list=ls())
library(tidyverse)
library(magrittr)
library(glue)
library(data.table)
library(haven)
library(testthat)
cilpath.r:::cilpath()

old_in = glue('{SAC_SHARES}/estimation/Labor/labor_merge_2019/intermediate_files/')
new_in = glue("{DB}/Global ACP/labor/replication/1_preparation/time_use/USA/")

old = read_dta(glue('{old_in}/labor_time_use_all_countries.dta')) %>%
	filter(iso == 'USA') %>%
	select(
		-lgdppc, -pop, -gdppc_adm1_pwt_downscaled, - country, -date, 
		-dow_week) %>%
	mutate(mins_worked = mins_worked/sqrt(7)) %>%
	data.table() # %>%

new = fread(glue('{new_in}/atus_replicated.csv')) %>%
	mutate(
		year = as.numeric(substr(date, 1, 4)),
		month = as.numeric(substr(date, 5, 6)),
		day = as.numeric(substr(date, 7, 8)),
		id = as.double(id)
		) %>%
	select(-date, -empstat)

check = merge(
	old, 
	new,
	by=c('id', 'age', 'age2', 'male', 'hhsize', 'iso', 'day', 'month', 
		'high_risk', 'year'),
	all.x=TRUE, all.y=TRUE) %>%
	mutate(
		diff = mins_worked.x - mins_worked.y,
		sample_weight_diff = weight - sample_weight
		)

summary(check$sample_weight_diff)

# do sample weights line up?

# see which ids are unmatched in the old data
unmatched_ids_old = check %>%
	filter(is.na(master_county_name)) %>%
	pull(id)

# do any of these ids exist in the new data?
new %>%
	filter(id %in% unmatched_ids_old)
# answer: nope. This means they are filtered out due to the new geographic
# matching (check this)

# merge in to cps_unmatched (an object from replicate_atus.R)
unmatched_check = merge(
	data.frame(id=unmatched_ids_old), 
	cps_unmatched, 
	by = 'id',
	all.x = TRUE)

# 5258 of the unmatched ids are because of the geographic mismatch.
unmatched_check %>% filter(!is.na(state)) %>% nrow()

remainder = unmatched_check %>% 
	filter(is.na(state)) %>% pull(id) %>%
	as.character() %>% as.numeric()

# look into the remaining ids
remainder_df = old %>% filter(id %in% remainder)
nrow(remainder_df)


# Check out id 20030100015890
# atussum %>% filter(id == 20030100015890)
# atusresp %>% filter(id == 20030100015890)
# atusresp_unfiltered %>% filter(id == 20030100015890)
# this turned out to be a holiday

# Check out id 20091009090692
# atussum %>% filter(id == 20091009090692)
# atusresp %>% filter(id == 20091009090692)
# atuscps %>% filter(id == 20091009090692)
# cps %>% filter(id == 20091009090692)

# t = load_merge_cps(2009)
# this turned out to be because I was filtering 
# out non-respondent data in atucps

# check out id 20030504030523
# new %>% filter(id == 20030504030523)
# atussum %>% filter(id == 20030504030523)
# atusresp %>% filter(id == 20030504030523)
# this was because I filtered out industry == 12. 
# Change this

# check out id 20030807030819
new %>% filter(id == 20030807030819)
atussum %>% filter(id == 20030807030819)
atusresp %>% filter(id == 20030807030819)
atuscps %>% filter(id == 20030807030819)
cps_raw %>% filter(id == 20030807030819)

# now check on unmatched ids in the new data
unmatched_ids_new = check %>%
	filter(
		is.na(sample_weight)
		) %>%
	pull(id)

old %>% 
	filter(id %in% unmatched_ids_new) %>%
	head()
# again, no ids appear here.

new %>%
	filter(id %in% unmatched_ids_new) %>%
	filter(year <= 2010) %>%
	nrow()
# only 4 ids are pre-2010 here. This is good news--these seem to be small idio-
# syncrasies.
