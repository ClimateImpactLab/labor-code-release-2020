# Compare replicated MTUS data to original MTUS data
# Author: Simon Greenhill, sgreenhill@uchicago.edu
# Date: Dec. 17, 2019

rm(list=ls())
library(tidyverse)
library(magrittr)
library(glue)
library(data.table)
library(haven)
library(testthat)
cilpath.r:::cilpath()

old_in = glue("/shares/gcp/estimation/Labor/labor_merge_2019/for_regression/country_specific_polynomials")
new_in = glue("{DB}/Global ACP/labor/replication/1_preparation/time_use/EU")

# will proceed one country at a time, because main dataset is easier to subset by country.
old = read_dta(glue("{old_in}/labor_dataset_EU_dec2019.dta")) %>%
	data.table() %>%
	select( # select only the variables we can actually compare against (the ones that appear in the newly cleaned version)
		iso, location_id1, location_id2, id, index, day, month, year, mins_worked, high_risk, age, age2, male, hhsize) %>%
	arrange(year, month, day, age, male, hhsize)

new = fread(glue("{new_in}/mtus_replicated.csv")) %>%
	select(-day) %>%
	rename(day = cday)


# pull 100 random rows from old dataset, find matching rows in new dataset, compare minutes worked values
sample_rows = sample(1:nrow(old), 100)

check = old %>%
	merge(new, by=c("iso"="iso", "day", "year", "month", "high_risk", "age", "male", "hhsize")) %>%
	mutate(diff = mins_worked.x - mins_worked.y)

summary(check$mins_worked.x - check$mins_worked.y)
nrow(check)

# plot distributions of old and new mins worked


#########
# SPAIN #
#########

old_esp = read_dta(glue("{old_in}/labor_dataset_EU_dec2019.dta")) %>%
	filter(iso == "ESP") %>%
	data.table() %>%
	select( # select only the variables we can actually compare against (the ones that appear in the newly cleaned version)
		location_id1, location_id2, id, index, day, month, year, mins_worked, high_risk, age, age2, male, hhsize) %>%
	arrange(year, month, day, age, male, hhsize)

new_esp = fread(glue("{new_in}/mtus_replicated.csv")) %>%
	filter(iso == "ESP") %>%
	arrange(year, month, cday, age, male, hhsize)

	

# investigate distribution of NAs in years that appear in old data vs years that don't.
# years in old data: 2002, 2003
# years in new data: same as above, plus 2009, 2010
new_esp %>% 
	group_by(occup, year) %>%
	summarize(n = n()) %>%
	mutate(share = n / sum(n)) %>%
	data.frame()

##########
# FRANCE #
##########

old_fra = old %>% 
	filter(iso == "FRA")

new_fra = fread(glue("{new_in}/mtus_replicated.csv")) %>%
	filter(iso == "FRA") %>%
	arrange(year, month, day, age, male, hhsize)

new_fra %>%
	g

######
# UK #
######

new_gbr = fread(glue("{new_in}/mtus_replicated.csv")) %>%
	filter(iso == "GBR") %>%
	arrange(year, month, day, age, male, hhsize)

# investigate distribution of NAs in years that appear in old data vs years that don't.
# years in old data: 1983, 1984, 1987, 1995, 2000, 2001
# years in new data: same as above, plus 1974, 1975
new_gbr %>% 
	group_by(occup, year) %>%
	summarize(n = n()) %>%
	mutate(share = n / sum(n)) %>%
	data.frame()

new_gbr %>% 
	filter(!(year %in% c(1974, 1975))) %>%
	group_by(occup, year) %>%
	summarize(n = n()) %>%
	mutate(share = n / sum(n)) %>%
	data.frame()


















