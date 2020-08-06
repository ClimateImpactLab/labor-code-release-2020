# Replicate Encuesta Nacional de Ocupacion y Empleo (ENOE), Mexico cleaning
# Author: Simon Greenhill
# Date: 1/29/2020

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
# - Mexico, 2005-2013

# Note that we need to be careful about type conversion for this data. 
# Most strings seem to be internally stored as factors, so converting to character 
# first avoids incorrect conversion we also set stringsAsFactors=FALSE in an abundance
# of caution. see this SO post for more information: 
# https://stackoverflow.com/questions/6917518/r-as-numeric-function-not-returning-correct-from-data-frame

library(tidyverse)
library(magrittr)
library(glue)
library(data.table)
library(foreign)
library(parallel)
library(testthat)
library(lubridate)
library(sf)
library(foreign)
cilpath.r:::cilpath()

# how much of the server do you want to take up?
# remember to consider memory constraints!
cores = detectCores()

####################
# 1. Load raw data #
####################

input = glue('/local/shsiang/Dropbox/GCP/WORKSHOP_STUDENT_FOLDERS/Pecenco_LaborForceSurveyMexico/Data/Raw/Data/')

# unzip all the zipped files
files_2004 = list.files(
	glue('{input}/1987-2004/'), 
	full.names=TRUE)

files_2014 = list.files(
	glue('{input}/2005-2014/'), 
	full.names=TRUE,
	recursive=TRUE)

# there's some non-zipped files in these directories, skip over them
unzip_if_zip = function(file) {
	ext = substr(file, nchar(file)-3, nchar(file))
	if (ext == '.zip') {
		unzip(file, exdir = glue('{dirname(file)}/unzipped/'))
		return(glue('{file} unzipped.'))
	} else {
		return(glue('{file} not a .zip. Skipped.'))
	}
}

mclapply(c(files_2004, files_2014), unzip_if_zip, mc.cores=cores)

read_format_dbf = function(path) {
	# read a dbf and format the column names to bind the files together
	# The ENOE includes two types of files (básico and ampliado), which
	# have different variable names for the time worked variable. In the
	# básico files, the time worked variables are prefixed with P5B, whereas
	# in the ampliado they are prefixed with P5C.
	# This function reads in a dbf and modifies the filenames for easier
	# rbinding
	data = read.dbf(path)
	names(data) = gsub(
		pattern = 'P5[BC]_', 
		replacement = 'time_worked_', 
		names(data)
		)
	return(data)
}

# read and combine files of a given type
read_data = function(type) {
	# paths are idiosyncratic, need to input them manually for each case
	if (type %in% c('eneu', 'hog', 'may', 'MAY', 'men', 'MEN')) {
		subdir = '1987-2004'
	} else {
		subdir = '2005-2014'
		if (type == 'hogt') {
			subdir = glue('{subdir}/HogaresEntrevistados')
		} else if (type == 'coe1t') {
			subdir = glue(
				'{subdir}/',
				'Variables_del_cuestionario_de_ocupacion_y_empleo_I')
		} else if (type == 'coe2t') {
			subdir = glue(
				'{subdir}/',
				'Variables_del_cuestionario_de_ocupacion_y_empleo_II')
		} else if (type == 'sdemt') {
			subdir = glue('{subdir}/VariablesSociodemograficas')

		} else if (type == 'vivt') {
			subdir = glue('{subdir}/ViviendasLevantadas')
		} else {
			stop('Type not recognized')
		}
	}
	
	dir = glue('{input}/{subdir}/unzipped/')

	# read each of the types of files
	all_files = list.files(dir, full.names=TRUE)
	files = all_files[grep(glue('*{type}*'), all_files)]

	data = mclapply(files, read_format_dbf, mc.cores=cores)
	ret = rbindlist(data, use.names=TRUE, fill=TRUE)
	rm(data)
	return(ret)
}

#################################
# 2. Process data by year group #
#################################

# the files are in various different formats across years, 
# we'll have to process group individually.

# For now, we'll only process 2005 and on, though it seems like it could be
# possible to use earlier data as well.

# The following tables have the data we need: 
# - HOGARES (hogt): date
# - SOCIODEMOGRAFICO (sdemt): age, sex, industry, 
# - Cuestonario Ampliado (coe1t): hrs worked
# - VIVIENDA (vivt): household size

# 2.1. Process data for from the SOCIODEMOGRAFICO (sdemt) table
sociodemo = read_data('sdemt') %>%
	rename(
		municipality = MUN,
		sex = SEX,
		age = EDA,
		industry = SCIAN,
		sample_wgt = FAC
		) %>%
	mutate_at(
		vars(age, industry, CD_A, ENT, CON, V_SEL, N_PRO_VIV, N_ENT, N_HOG, 
			N_REN, H_MUD, UPM, PER, sample_wgt, municipality),
		~ as.numeric(as.character(.), stringsAsFactors=FALSE)
		) %>%
	filter(
		# filter out miscoded, unknown, and other industry info
		!(industry %in% c(19, 21)),
		industry >= 1 & industry <= 20
		) %>%
	mutate(
		# keep two copies -- ENT is needed for merging
		state = ENT,
		male = ifelse(sex == '1', 1, 0),
		# high risk: agriculture and fishing (1), mining (2), electricity, water
		# and gas generation (3), construction (4), manufacturing (5),
		# transportation (8)
		high_risk = ifelse(industry %in% c(1, 2, 3, 4, 5, 8), 1, 0),
		# create an ID variable--first step of this is to get an identifier for
		# that tracks each round of the five-round panel
		# see ENOEROtación de panel y CONSECUTIVO.pdf for information about this
		consecutivo = 77 - N_ENT + floor(PER/100) + (mod(PER, 100) - 5)*4,
		) %>%
	as.data.table() %>% # switch to data.table for speed
	.[,id := .GRP, by=c('consecutivo', 'CD_A', 'ENT', 'CON', 'V_SEL', 'N_HOG', 'N_REN', 'H_MUD')] %>%
	select(
		id, CD_A, ENT, CON, V_SEL, N_PRO_VIV, N_ENT, N_HOG, N_REN, H_MUD, UPM, PER,
		municipality, state, sex, age, industry, sample_wgt, 
		male, high_risk
		) %>%
	data.table()

# 2.2. Process data for HOGARES (hogt) table
hogares = read_data('hogt') %>%
	filter(
		# keep only completed interviews
		R_DEF == '00'
		) %>%
	mutate_at(
		vars(CD_A, ENT, CON, V_SEL, N_PRO_VIV, N_ENT, N_HOG, H_MUD, UPM, PER,
			D_DIA, D_MES, D_ANIO),
		~ as.numeric(as.character(.), stringsAsFactors=FALSE)
		) %>%
	rename(
		day = D_DIA,
		month = D_MES,
		year = D_ANIO
		) %>%
	select(
		CD_A, ENT, CON, V_SEL, N_PRO_VIV, N_ENT, N_HOG, H_MUD, UPM, PER,
		day, month, year
		) %>%
	data.table()

# 2.3. Process data for VIVIENDA (vivt) table
vivienda = read_data('vivt') %>%
	rename(
		hhsize = P1
		) %>%
	mutate_at(
		vars(CD_A, ENT, CON, V_SEL, N_PRO_VIV, N_ENT, UPM, hhsize),
		~ as.numeric(as.character(.), stringsAsFactors=FALSE)
		) %>%
	select(
		CD_A, ENT, CON, V_SEL, N_PRO_VIV, N_ENT, UPM, hhsize
		) %>%
	data.table()

# 2.4. Process data for Cuestonarios Ampliado and Basico (coe1t)
# be careful here--this takes around 200GB mem
# can scale this down by modifying cores at the top of the script
ca = read_data('coe1t') %>% 
	mutate_at(
		vars(
			starts_with('time_worked'), 
			CD_A, ENT, CON, V_SEL, N_HOG, H_MUD, N_PRO_VIV, N_ENT, N_REN, UPM, 
			PER),
		~ as.numeric(as.character(.), stringsAsFactors=FALSE)
		) %>%
	mutate_at(
		# convert missings and miscoded hours data to actual NAs, 
		# then convert to minutes
		vars(starts_with('time_worked_H')),
		~ ifelse(
			. %in% c(98, 99) | . < 0 | . > 24, 
			NA, 
			. * 60)
		) %>%
	mutate_at(
		# convert miscoded minutes data to NAs
		vars(starts_with('time_worked_M')),
		~ ifelse(
			. < 0 | . > 59,
			NA,
			.
			)
		) %>%
	select(-time_worked_TDIA, -P5C) %>%
	rename(
		hrs_worked = time_worked_THRS
		) %>%
	mutate(
		# replace non-response with actual NAs
		hrs_worked = ifelse(hrs_worked == 999, NA, hrs_worked),
		mins_worked = rowSums(select(., starts_with('time_worked')), na.rm=TRUE),
		) %>%
	select(
		CD_A, ENT, CON, V_SEL, N_HOG, H_MUD, N_PRO_VIV, N_ENT, N_REN, UPM, PER,
		hrs_worked, mins_worked
		) %>%
	data.table()

# Note that the "hours worked" (weekly hours reported as a total by the interviewee) 
# and "minutes worked" (calculated from the daily hours and minutes reported 
# day by day by the interviewee) differ in some cases. We choose the minutes worked
# variable on the assumption that individual daily recalls will be more accurate
# than the weekly recall.


############################
# 3. Merge tables together #
############################

outcome = merge(
	sociodemo, hogares, 
	by=c('CD_A', 'ENT', 'CON', 'V_SEL', 'N_HOG', 'H_MUD', 'N_PRO_VIV', 'N_ENT',
		'UPM', 'PER')
	) %>%
	merge(
		vivienda,
		by=c('CD_A', 'ENT', 'CON', 'V_SEL', 'N_PRO_VIV', 'N_ENT', 'UPM')
		) %>%
	merge(
		ca,
		by=c('CD_A', 'ENT', 'CON', 'V_SEL', 'N_HOG', 'H_MUD', 'N_PRO_VIV', 
			'N_ENT', 'N_REN', 'UPM', 'PER')
		) %>%
	mutate(
		year = year + 2000,
		date = as.Date(glue('{year}/{month}/{day}')),
		prev_sunday = as.Date(
			ifelse(
				wday(date, label=TRUE) == 'Sun',
				floor_date(date, 'week', week_start = 7) - 7,
				floor_date(date, 'week', week_start = 7)),
			origin = '1970-01-01')
		
		) %>%
	as.data.table() %>% # switch to data.table for speed
	# filter to our specifications
	.[age >= 15 & age <= 65] %>%
	.[mins_worked > 0] %>%
	.[year <= 2010]

###############################
# 4. MERGE IN GEOGRAPHIC DATA #
###############################

# keep only distinct obs
enoe_geo = outcome %>% 
	select(state, municipality) %>%
	unique()

# note that this is done preserving accents, as accented characters seem to be
# correctly parsed in both the csv and the shapefile



enoe_cw = fread(
	glue('/local/shsiang/Dropbox/GCP/WORKSHOP_STUDENT_FOLDERS/Pecenco_LaborForceSurveyMexico/Data/Raw/Data/',
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

enoe_geo = merge(enoe_geo, enoe_cw, by=c('state', 'municipality'), all.x=TRUE)

shp = st_read(
	dsn = glue('/shares/gcp//climate/_spatial_data/MEX/'),
	layer = 'national_municipal'
	) %>%
	as.data.table() %>%
	select(NOM_ENT, NOM_MUN, CVEGEO) %>%
	rename(
		state_name = NOM_ENT,
		municipality_name = NOM_MUN
		)

cw = merge(enoe_geo, shp, by=c('state_name', 'municipality_name'), all.x=TRUE)

# now merge in the outcome data 	
final = outcome %>%
	merge(cw, by=c('state', 'municipality'), all.x=TRUE) %>%
	rename(
		ind_id = id
		) %>% 
	select(
		ind_id, state_name, municipality_name, 
		prev_sunday, mins_worked, male, age, high_risk, hhsize, 
		sample_wgt
		) %>% 
	mutate(
		year = year(prev_sunday),
		month = month(prev_sunday),
		day = day(prev_sunday)
		) %>%
	select(
		-prev_sunday)

#fwrite(
#	final, 
#	glue('{DB}/Global ACP/labor/replication/1_preparation/time_use/',
#		'enoe_replicated.csv')
#	)

fwrite(final, "/shares/gcp/estimation/labor/time_use_data/intermediate/MEX_ENOE_time_use.csv")
write.dta(final, "/shares/gcp/estimation/labor/time_use_data/intermediate/MEX_ENOE_time_use.dta")

location_names = final %>% 
	select(state_name, municipality_name) %>%
	distinct()
fwrite(location_names, "/shares/gcp/estimation/labor/time_use_data/intermediate/MEX_ENOE_time_use_location_names.csv")


