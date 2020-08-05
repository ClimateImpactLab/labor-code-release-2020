# Compare replicated ITUS data to original ITUS data
# Author: Simon Greenhill, sgreenhill@uchicago.edu
# Date: Jan. 21, 2020

rm(list=ls())
library(tidyverse)
library(magrittr)
library(glue)
library(data.table)
library(haven)
library(testthat)
cilpath.r:::cilpath()

old_in = glue('{SAC_SHARES}/estimation/Labor/labor_merge_2019/intermediate_files/')
new_in = glue('{DB}/Global ACP/labor/replication/1_preparation/time_use/India/')

old = read_dta(glue('{old_in}/labor_time_use_all_countries.dta')) %>%
	filter(iso == "IND") %>%
	mutate(
		mins_worked = mins_worked / sqrt(7)
		) %>%
	data.table()


old = read_dta(glue('/shares/gcp/estimation/Labor/labor_merge_2019/intermediate_files/labor_time_use_all_countries.dta')) %>%
	filter(iso == "IND") %>%
	mutate(
		mins_worked = mins_worked / sqrt(7)
		) %>%
	data.table()


new = read_csv('/shares/gcp/estimation/labor/time_use_data/intermediate/CHN_CHNS_time_use_location_names.csv') %>%
	data.table()

