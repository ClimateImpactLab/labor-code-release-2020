# Compare replicated ENOE data to original ENOE data
# Author: Simon Greenhill, sgreenhill@uchicago.edu
# Date: Jan. 29, 2020

# Where I'm currently at (EOD 2/13):
# - Seem to have much better agreement across datasets.
# - My version now has 50% MORE data than the old data. Look into why this is!
# Findings so far: 
# - Temporal extent are similar. There's a little more data in every period in the
#	new data relative to the old. Suggests some kind of diff in the way the datasets
#	are filtered.

library(tidyverse)
library(magrittr)
library(glue)
library(data.table)
library(haven)
library(testthat)
library(lubridate)
library(parallel)
cilpath.r:::cilpath()

cores = detectCores()

old_in = glue('{SAC_SHARES}/estimation/Labor/labor_merge_2019/intermediate_files/')
# new_in = glue('{DB}/Global ACP/labor/replication/1_preparation/time_use/India/')

old = read_dta(glue('{old_in}/labor_time_use_all_countries.dta')) %>%
	filter(iso == "MEX") %>%
	data.table()

new = fread(
	glue(
		'{DB}/Global ACP/labor/replication/1_preparation/time_use/',
		'enoe_replicated.csv')
	)

# see if we can merge anything together
# check = merge(
# 	old, new,
# 	by = c('high_risk', 'age', 'male', 'day', 'month', 'year', 'hhsize'),
# 	)

# what's the distribution of the days of the week in the old data
# all sundays.
old %>% pull(dow_week) %>% summary()

# what about in the new data?
new %>% 
	mutate(
		date = as.Date(glue('{year}-{month}-{day}')),
		dow = weekdays(date)
		) %>%
	group_by(dow) %>%
	summarize(fraction = n()/nrow(new))

quantile(new$mins_worked, c(0.01, 0.05, 0.1, 0.25, 0.5, 0.75, 0.9, 0.95, 0.99))
quantile(old$mins_worked, c(0.01, 0.05, 0.1, 0.25, 0.5, 0.75, 0.9, 0.95, 0.99))
	

# spot check individual observations
# try to find 1000th row of the old data in new data
old[1000]
new %>%
	filter(year == 2010, month == 11, day == 7)
test %>%
	filter(year == 2010, month == 11, day == 7)

# go from hogares data. Can we find it in the new data?
hogares %>% filter(
	CD_A == 14, ENT == 1, CON == 1, V_SEL == 1, N_PRO_VIV == 0, N_ENT == 5,
	N_HOG == 1, H_MUD == 1, UPM == 802, PER == 105) 

new %>% filter(
	CD_A == 14, ENT == 1, CON == 1, V_SEL == 1, N_PRO_VIV == 0, N_ENT == 5,
	N_HOG == 1, H_MUD == 1, UPM == 802, PER == 105)

# can we find an observation in the old data that seems to match? 
# note that we have to go on covariates here
old %>% filter(
	location_id1 == 4, location_id2 == 4, male == 0, age == 31, high_risk == 0,
	hhsize == 4, year == 2005, mins_worked == 1950
	)

# the above is encouraging--we were able to credibly match observations.
# note that the date in the old data is the sunday before.

# let's see how many observations we can merge now. This will be imperfect,
# as sometimes the previous sunday will be in a different month, the location
# name might not match exactly, etc.

old_cw = fread(glue(
	'{DB}/Global ACP/labor/1_preparation/crosswalks/', 
	'timeuse_climate_crosswalk_MEX.csv')) %>%
	rename(
		state_name = NOM_ENT,
		municipality_name = NOM_MUN)

old_geo = old %>% 
	merge(old_cw, 
		by = c('location_id1', 'location_id2'))

# add a previous sunday variable to final, which we can match to the day variable in 
# the old data
new_date_mod = new %>%
	rename(
		interview_day = day, 
		interview_month = month,
		interview_year = year) %>%
	mutate(
		day = day(prev_sunday),
		month = month(prev_sunday),
 		year = year(prev_sunday)) %>%
	data.table()

# better version of the check
check = merge(old_geo, new_date_mod,
	by=c('state_name', 'municipality_name', 'male', 'age', 'age2', 'high_risk', 
		'hhsize', 'year', 'month', 'day', 'sample_weight'),
	all.x=TRUE, all.y=TRUE) %>%
	mutate(diff = mins_worked.x - mins_worked.y)
summary(check$diff)
quantile(check$diff, c(0.01, 0.05, 0.1, 0.25, 0.5, 0.75, 0.9, 0.95, 0.99))

# new version of check that only keeps everything from old geo--this will help
# us dig into any remaining diffs.
check = merge(old_geo, new_date_mod,
	by=c('male', 'age', 'age2', 'high_risk', 
		'year', 'month', 'day', 'sample_weight',
		# remove hhsize from this as they are calculated differently
		'state_name', 'municipality_name' #, 'hhsize'
		),
	all.x=TRUE)

# figure out the regions that are missing in the old data
new_cw = fread(
	glue('{DB}/Pecenco_LaborForceSurveyMexico/Data/Raw/Data/',
	'Claves Entidades Federativas y Municipios PEF 2012 (No accent characters).csv')
	) %>%
	rename(
		state = CLAVE.DE.ENTIDAD.FEDERATIVA,
		municipality = `CLAVE.DE.MUNICIPIO./.DEMARCACIÓN.TERRITORIAL`,
		state_name = NOMBRE.ENTIDAD.FEDERATIVA,
		municipality_name = `NOMBRE.DE.MUNICIPIO./.DEMARCACIÓN.TERRITORIAL`
		) %>%
	select(
		state, state_name, municipality, municipality_name
		)

geo_check = merge(
	old_cw, new_cw,
	by=c('state_name', 'municipality_name'),
	all.x=TRUE, all.y=TRUE
	)

non_missing_geo = geo_check %>%
	filter(!is.na(iso)) %>%
	select(state_name, municipality_name)

# filter the check data to drop any missing geo
check_drop_geo = merge(check, non_missing_geo, 
		by = c('state_name', 'municipality_name'),
		all.x=TRUE)

# look at sample of unmatched cases in old data
unmatched_old = check_drop_geo %>%
	filter(is.na(id.y)) %>%
	mutate(prev_sunday = as.Date(glue('{year}-{month}-{day}'), format='%Y-%m-%d'))

nrow(unmatched_old)
# 260k

# how many of these are holidays?
# use holiday calculator from replicate_enoe.R
unmatched_old %<>%
	mutate(is_holiday = mcmapply(
		is_within_week_multi, prev_sunday,
		MoreArgs=list(holidays=holidays), mc.cores=cores)) %>%
	filter(is_holiday == FALSE)
nrow(unmatched_old)
# this filters out 244774 obs, leaving us with 5905 to match

# now look at some random observations to see if we can find patterns
unmatched_old %>% sample_n(1)

# old id 2752664
unmatched_old %>% filter(id.x == 2752664)
new %>% filter(state_name == "Tabasco", municipality_name == "Centro",
	male == 0, age == 41, year == 2009, mins_worked == 1810, year == 2009)
# new id 2131962

##############################################################################
# Below is old code used for diagnostics that lead to untangling of previous #
# differences.																 #
##############################################################################

# # old id 2892102
# unmatched_old %>% filter(id.x == 2892102)
# new %>% filter(state_name == "Tamaulipas", municipality_name == 'Nuevo Laredo',
# 	mins_worked == 2250, year == 2005)
# # new id 620812 (?)
# new %>% filter(id == 620812)
# # seems like another high risk issue: industry 3 coded as low risk in old data

# # old id 3037617
# new %>% filter(state_name == 'Veracruz de Ignacio de la Llave', 
# 	municipality_name == 'Veracruz', male == 0, age == 40, year == 2008, 
# 	sample_weight == 86
# 	)
# # new id 1256273
# # problem here was that previous sunday was not properly taking into account
# # that the previous sunday for a day that was a sunday should be the week before,
# # not that same day. This is fixed now.

# # old id 925981
# old_geo %>% filter(id == 925981)
# check_drop_geo %>% filter(id.x == 925981)
# new %>% filter(state_name == 'Durango', municipality_name == 'Durango', 
# 	sample_weight == 83, age == 43, year == 2006)

# # new id 551289 (?)
# new %>% filter(id == 551289)
# # this is because the old data classified transportation as low risk, while
# # we classify as high risk.

# # old id =31329
# old_geo %>% filter(id == 31329)
# unmatched_old %>% filter(id.x == 31329)
# outcome_uf %>% filter(id == 1433759)
# new %>% filter(state_name == 'Aguascalientes', municipality_name == 'Aguascalientes',
# 	high_risk == 0, age==21, year == 2008, sample_weight ==101)
# # new id: 1433759
# new %>% filter(id == 1433759)
# # this was because the old data does not filter out unknown industry info. 
# # how many does this affect?
# # nrow for correct final data: 2949750
# # nrow when we keep the incorrect industry info: 3277103
# # so the diff is 327353
# # more than compensating the remaining problematic observations
# # as a last check, let's remove the new regions from this
# # Ok, so we are now down to 120926 in unmatched old.

# # look at old id == 1806697
# old_geo %>% filter(id == 1806697)
# new %>% filter(state_name == 'Nayarit', municipality_name == 'Tepic', male == 1,
# 	age == 28, high_risk == 0, hhsize == 6, year == 2007, sample_weight == 40)
# # looks like id 543964 in the new data
# # this is unmatched because of a diff in hh size. Where could that be coming from?
# # hhsize is calculated differently in the old data. 


# # let's look into old id == 2149684
# old_geo %>% filter(id == 2149684)
# new %>% filter(state_name == "Puebla", municipality_name == "Puebla", male == 0, 
# 	age == 30, high_risk == 1, hhsize == 4) # , sample_weight == 195)

# possible_new_ids = sociodemo %>% 
# 	filter(age == 30, state == 21, municipality == 114, male == 0, 
# 		sample_weight == 195, high_risk == 1) %>%
# 	pull(id)

# # new id for this seems to be 678621
# outcome %>% filter(id %in% possible_new_ids & year == 2010)
# # problem is that the municipality name is different. This turned out to be a 
# # strings as factors problem in the new data cleaning. It i snow fixed. 



# # this is fairly encouraging--now dig into big diffs
# check %>% filter(diff < -600) %>% sample_n(5)

# # try to find observations in the old data that are unmatched in teh new--what 
# # are these obs?
# check %>% filter(is.na(id.y)) %>% sample_n(5)

# old_geo %>% filter(id == 1817228)
# new %>% filter(municipality_name == 'Tepic', state_name == 'Nayarit', male == 1,
# 	age %in% c(42, 43), high_risk == 1, hhsize == 5, year %in% c(2009, 2010))

# old_geo %>% filter(id == 137118)
# new %>% filter(municipality_name == 'Tijuana', age == 23, hhsize==2, male == 1,
# 	year == 2010)
# sociodemo %>% filter(sex == 1, age == 23, sample_weight == 206, ENT == 2, PER == 110)
# new %>% filter(id == 723737)
# new %>% filter(id == 771854)
# # the below is clearly the same as id 137118 in old_geo
# # but old geo has tow observations of this person. Why?
# # after fixing to include the basic data, we're good to go!
# new %>% filter(id == 715726) 
# sociodemo %>% filter(id == 715726)
# outcome_unfiltered[id == 715726]

# next step in checking (2/14/20): Why are there more observations in the replicated
# data now? Inspect observations in replicated that do not appear in old
# check %>% filter(is.na(id.x)) %>% sample_n(5)
# let's look into new id 274305
# new %>% filter(id == 274305)
# old_geo %>% filter(state_name == 'Guerrero') %>% pull(municipality_name) %>% unique()
# # municipality "Acapulco de Juárez" does not appear in the old data.

# # are other location also missing? Let's look at some more
# old_geo %>% filter(state_name == 'Chihuahua') %>% pull(municipality_name) %>% unique() %>% sort()
# # the entire state of Yucatán seems to be missing!
# old_geo %>% filter(state_name == 'Yucatán') %>% pull(municipality_name) %>% unique()
# old_geo %>% filter(state_name == 'Sinaloa') %>% pull(municipality_name) %>% unique()

# # it seems there's a pattern here--some municipalities and in some cases whole
# # states are missing from the old data. Let's look into why this is.
# # seems this missingness is not a problem in the old data taken from Final in the DB. 
# # Why does stuff get dropped?
