# filter out all countries' holidays
# author: Simon Greenhill, sgreenhill@uchicago.edu
# date: 2/27/2020
source("/home/liruixue/repos/labor-code-release-2020/0_subroutines/paths.R")

library(tidyverse)
library(data.table)
library(glue)
library(haven)
library(foreign)
library(parallel)
library(numbers)
library(lubridate)

# cilpath.r:::cilpath()
cores = 10

#######################
# 1. SET UP FUNCTIONS #
#######################
# vectorized version
get_nth_weekday_v = function(years, month, weekday, n) {
	get_nth_weekday = function(month, year, weekday, n) {
		# get the date of the nth weekday of a month on a year
		# (eg. the first monday in february)
		start = as.Date(glue('{year}-{month}-1'))
		if (length(start) != 1) {
			return(NA)
		}

		days = seq(from = start, length.out = days_in_month(start), by='day')

		min = 7 * (n - 1)
		max = 7 * n

		ret = days[
			wday(days, label=TRUE) == weekday & 
			day(days) <= max & 
			day(days) > min
			]
		return(ret)	
	}

	ret = sapply(
		X=years, 
		FUN=get_nth_weekday, 
		month=month, weekday=weekday, n=n) %>%
	as.Date(origin='1970-01-01')

	return(ret)
}

get_last_weekday_v = function(years, month, weekday) {	
	get_last_weekday = function(month, year, weekday) {
		start = as.Date(glue('{year}-{month}-1'))
		if (length(start) != 1) {
			return(NA)
		}

		days = seq(from = start, length.out = days_in_month(start), by='day')

		# get a list of all the dates in the month that fall on the desired 
		# weekday, then return the last one
		ret = days[wday(days, label=TRUE) == weekday]
		return(ret[length(ret)])
	}

	ret = sapply(
		X=years,
		FUN=get_last_weekday,
		month=month, weekday=weekday) %>%
	as.Date(origin='1970-01-01')

	return(ret)
}

get_easter_sunday_v = function(years) {
	get_easter_sunday = function(year) {
		# algorithm from here: http://www.maa.clell.de/StarDate/publ_holidays.html
		a = mod(year, 19)
		b = mod(year, 4)
		c = mod(year, 7)
		d = mod((19 * a + 24), 30)
		e = mod((2 * b + 4 * c + 6 * d + 5), 7)

		day = 22 + d + e
		month = 3

		if (day > 31) {
			day = d + e - 9
			month = 4
		} else if (day == 26 & month == 4) {
			day = 19
		} else if (day == 25 & month == 4 & d == 28 & e == 6 & a > 10) {
			day = 18
		}

		return(as.Date(glue('{year}/{month}/{day}'), format = '%Y/%m/%d'))
	}
	ret = sapply(
		X=years,
		FUN=get_easter_sunday) %>%
		as.Date(origin='1970-01-01')

	return(ret)
}

get_good_friday = function(year) {
	d = get_easter_sunday_v(year) - 2
	return(d)
}

get_easter_monday = function(year) {
	d = get_easter_sunday_v(year) + 1
	return(d)
}

get_ascension_day = function(year) {
	d = get_easter_sunday_v(year) + 39
}

get_pentecostal_monday = function(year) {
	d = get_easter_sunday_v(year) + 50
}

# check for multiple holidays
is_within_week_multi = function(date, holidays) {
	is_within_week = function(date, refdate) {
		if (is.na(refdate)) {
			return(FALSE)
		} else {
			return(date - refdate < 7 & date >= refdate)
		}
	}

	refdates = holidays[holidays$year == year(date), 2:ncol(holidays)]
	values = sapply(X=refdates, is_within_week, date=date)
	if (is.logical(values)) {
		return(any(values))	
	} else {
		stop(glue('{date} failed. Values: {values}'))
	}
	
}

is_holiday_multi = function(date, holidays) {
	is_day = function(date, refdate) {
		if (is.na(refdate)) {
			return(FALSE)
		} else if (date == refdate) {
			return(TRUE)
		} else {
			return(FALSE)
		}
	}

	refdates = holidays[holidays$year == year(date), 2:ncol(holidays)]
	values = sapply(X=refdates, is_day, date=date)
	if (is.logical(values)) {
		return(any(values))	
	} else {
		stop(glue('{date} failed. Values: {values}'))
	}
}

		
is_holiday_country = function(iso, date, res) {
	# function that brings it all together: tells you whether we should drop a
	# given day for a given country, taking into account:
	# - whether the dataset is weekly or daily (for weekly, drop anything
	#   that is within a week of the holiday; for daily, only drop if the holiday
	#   falls on that day)
	# - differing holidays across countries
	# - accounting for the fact that we have already filtered out the US using the
	#   information in the atus data
	if (iso == 'USA') {
		ret = FALSE
	} else if (res == 'daily') {
		ret = is_holiday_multi(date=date, holidays=get(glue('holidays_{iso}')))	
	} else {
		ret = is_within_week_multi(date=date, holidays=get(glue('holidays_{iso}')))	
	}
	
	return(ret)
}

get_years = function(country_code, df=time_use) {
	ret = df[iso==country_code][,year] %>% unique()
	# add in the year before the first year, since we're looking at previous sundays
	ret = c(ret, min(ret) - 1) %>% sort()
	return(ret)
}

####################
# 2. LOAD HOLIDAYS #
####################

# get the full dataset
time_use = glue(
	'{ROOT_INT_DATA}',
	'/temp/all_time_use_pop_merged.dta') %>%
	read_dta() %>%
	data.table()

#######
# BRA #
#######

years_BRA = get_years('BRA')

holidays_BRA = data.frame(year=years_BRA) %>%
  mutate(
    new_year = as.Date(glue('{year}/1/1'), format='%Y/%m/%d'),
    tiradentes = as.Date(glue('{year}/4/21'), format='%Y/%m/%d'),
    labour_day = as.Date(glue('{year}/5/1'), format='%Y/%m/%d'),
    independence_day = as.Date(glue('{year}/9/7'), format='%Y/%m/%d'),
    our_lady_of_aparecida = as.Date(glue('{year}/10/12'), format='%Y/%m/%d'),
    all_souls = as.Date(glue('{year}/11/2'), format='%Y/%m/%d'),
    republic_day = as.Date(glue('{year}/11/15'), format='%Y/%m/%d'),
    christmas = as.Date(glue('{year}/12/25'), format='%Y/%m/%d')
  ) 

#######
# CHN #
#######

# China is complicated and does not fit with out "nth day of kth month" approach
# so we are just hard coding this

years_CHN = get_years('CHN')

holidays_CHN = data.frame(year=years_CHN) %>%
  mutate(
    new_year = as.Date(glue('{year}/1/1'), format='%Y/%m/%d'),
    labor_day1 = as.Date(glue('{year}/5/1'), format='%Y/%m/%d'),
    labor_day2 = ifelse(
      year >1999 & year <= 2007 ,
      as.Date(glue('{year}/5/2'), format='%Y/%m/%d'),
      NA
    ),
    labor_day3 = ifelse(
      year >1999 & year <= 2007 ,
      as.Date(glue('{year}/5/3'), format='%Y/%m/%d'),
      NA
    ),
    national_day1 = as.Date(glue('{year}/10/1'), format='%Y/%m/%d'),
    national_day2 = as.Date(glue('{year}/10/2'), format='%Y/%m/%d'),
    national_day3 = ifelse(
      year >1999 ,
      as.Date(glue('{year}/10/3'), format='%Y/%m/%d'),
      NA
    ),
  	chinese_new_year1 = recode(year,
  	  `1991` = '1991/2/15',
      `1992` = '1992/2/4',
      `1993` = '1993/1/23',
      `1994` = '1994/2/10',
      `1995` = '1995/1/31',
      `1996` = '1996/2/19',
      `1997` = '1997/2/7',
      `1998` = '1998/1/28',
      `1999` = '1999/2/16',
      `2000` = '2000/2/5',
      `2001` = '2001/1/24',
      `2002` = '2002/2/12',
      `2003` = '2003/2/1',
      `2004` = '2004/1/22',
      `2005` = '2005/2/9',
      `2006` = '2006/1/29',
      `2007` = '2007/2/18',
      `2008` = '2008/2/6',
      `2009` = '2009/1/25',
      `2010` = '2010/2/13'),
  	# from 2008 to 2010, the first day is coded as the eve
    chinese_new_year2 = as.Date(chinese_new_year1, origin='1970-1-1') + 1,
    chinese_new_year3 = as.Date(chinese_new_year1, origin='1970-1-1') + 2,
    qing_ming = ifelse(
      year > 2007,
        recode(
          year, 
          `2008` = '2008/4/4',
          `2009` = '2009/4/4',
          `2010` = '2010/4/5',
        ),
      NA
    ),
    duan_wu = ifelse(
      year > 2007,
      recode(
        year, 
        `2008` = '2008/6/8',
        `2009` = '2009/5/28',
        `2010` = '2010/6/16',
      ),
      NA
    ),
    mid_autumn = ifelse(
      year > 2007,
      recode(
        year, 
        `2008` = '2008/9/14',
        `2009` = '2009/10/3',
        `2010` = '2010/9/22',
      ),
      NA
    ),
  ) %>%
  mutate_at(
    # ifelse outputs numerics, convert these back to dates
    vars(labor_day2, labor_day3, national_day3, chinese_new_year1,
    	chinese_new_year2,chinese_new_year3,qing_ming,duan_wu,mid_autumn),
    ~ as.Date(., origin='1970-1-1')
  )

#######
# ESP #
#######

years_ESP = get_years('ESP')
holidays_ESP = data.frame(year=years_ESP) %>%
	mutate(
		new_years = as.Date(glue('{year}/1/1'), format='%Y/%m/%d'),
		kings_day = as.Date(glue('{year}/1/6'), format='%Y/%m/%d'),
		good_friday = get_good_friday(year),
		labor_day = as.Date(glue('{year}/5/1'), format='%Y/%m/%d'),
		ascention = as.Date(glue('{year}/8/15'), format='%Y/%m/%d'),
		national_day = as.Date(glue('{year}/10/12'), format='%Y/%m/%d'),
		all_saints = as.Date(glue('{year}/11/1'), format='%Y/%m/%d'),
		constitution_day = as.Date(glue('{year}/12/6'), format='%Y/%m/%d'),
		immaculate_conception = as.Date(glue('{year}/12/8'), format='%Y/%m/%d'),
		christmas = as.Date(glue('{year}/12/25'), format='%Y/%m/%d')
		)

#######
# FRA #
#######

years_FRA = get_years('FRA')
holidays_FRA = data.frame(year=years_FRA) %>%
	mutate(
		new_years = as.Date(glue('{year}/1/1'), format='%Y/%m/%d'),
		easter_monday = get_easter_monday(year),
		labor_day = as.Date(glue('{year}/5/1'), format='%Y/%m/%d'),
		victory_day = as.Date(glue('{year}/5/8'), format='%Y/%m/%d'),
		ascension_day = get_ascension_day(year),
		pentecostal_monday = get_pentecostal_monday(year),
		bastille_day = as.Date(glue('{year}/7/14'), format='%Y/%m/%d'),
		ascention = as.Date(glue('{year}/8/15'), format='%Y/%m/%d'),
		all_saints = as.Date(glue('{year}/11/1'), format='%Y/%m/%d'),
		armistice = as.Date(glue('{year}/11/11'), format='%Y/%m/%d'),
		christmas = as.Date(glue('{year}/12/25'), format='%Y/%m/%d')
		)

#######
# GBR #
#######

years_GBR = get_years('GBR')
holidays_GBR = data.frame(year=years_GBR) %>%
	mutate(
		new_years = as.Date(glue('{year}/1/1'), format='%Y/%m/%d'),
		new_years_wday = wday(new_years, label=TRUE),
		# if new years falls on a saturday or a sunday, the holiday is celebrated
		# the following monday
		new_years = ifelse(new_years_wday %in% c('Sat', 'Sun'),
			get_nth_weekday_v(month=1, year=year, weekday='Mon', n=1),
			new_years) %>%
			as.Date(origin='1970-1-1'),
		good_friday = get_good_friday(year),
		easter_monday = get_easter_monday(year),
		labor_day = get_nth_weekday_v(month=5, year=year, weekday='Mon', n=1),
		last_mon_may = get_last_weekday_v(month=5, year=year, weekday='Mon'),
		last_mon_aug = get_last_weekday_v(month=8, year=year, weekday='Mon'),
		christmas = as.Date(glue('{year}/12/25'), format='%Y/%m/%d'),
		xmas_wday = wday(christmas, label=TRUE),
		# if christmas falls on a saturday or a sunday, the holiday is celebrated
		# the following monday
		christmas = ifelse(
			xmas_wday == 'Sat',
			as.Date(glue('{year}/12/27'), format='%Y/%m/%d'),
			ifelse(xmas_wday == 'Sun',
				as.Date(glue('{year}/12/28'), format='%Y/%m/%d'),
				christmas
				)
			) %>%
			as.Date(origin='1970-1-1'),
		boxing_day = as.Date(glue('{year}/12/26'), format='%Y/%m/%d')

		) %>%
	select(-new_years_wday, -xmas_wday)


#######
# IND #
#######

years_IND = get_years('IND')
holidays_IND = data.frame(year=years_IND) %>%
  mutate(
    republic_day = as.Date(glue('{year}/1/1'), format='%Y/%m/%d'),
    may_day = as.Date(glue('{year}/5/1'), format='%Y/%m/%d'),
    independence_day = as.Date(glue('{year}/8/15'), format='%Y/%m/%d'),
    Mahatma_Gandhi_Jayanthi = as.Date(glue('{year}/10/2'), format='%Y/%m/%d'),
    christmas = as.Date(glue('{year}/12/25'), format='%Y/%m/%d')
  )

#######
# MEX #
#######

years_MEX = get_years('MEX')
holidays_MEX = data.frame(year=years_MEX) %>%
	mutate(
		new_years = as.Date(glue('{year}/1/1'), format='%Y/%m/%d'),
		constitution = ifelse(
			year > 2005,
			get_nth_weekday_v(month=2, years=year, weekday='Mon', n=1),
			as.Date(glue('{year}/2/5'), format='%Y/%m/%d')
			),
		benito_juarez = ifelse(
			year > 2005,
			get_nth_weekday_v(month=3, years=year, weekday='Mon', n=3),
			as.Date(glue('{year}/3/21'), format='%Y/%m/%d')
			),
		labor = as.Date(glue('{year}/5/1'), format='%Y/%m/%d'),
		independence = as.Date(glue('{year}/9/16'), format='%Y/%m/%d'),
		revolution = ifelse(
			year > 2005,
			get_nth_weekday_v(month=11, years=year, weekday='Mon', n=3),
			as.Date(glue('{year}/11/20'), format='%Y/%m/%d')
			),
		christmas = as.Date(glue('{year}/12/25'), format='%Y/%m/%d')
		) %>%
	mutate_at(
		# ifelse outputs numerics, convert these back to dates
		vars(constitution, benito_juarez, revolution),
		~ as.Date(., origin='1970-1-1')
		) 

#######
# USA #
#######

# Note that for the US, we have already filtered out holidays because the ATUS 
# includes a holiday flag. So we don't need to do anything here.



#########################
# 3. CALCULATE HOLIDAYS #
#########################

resolution = data.frame(
	iso = c('BRA', 'CHN', 'ESP', 'FRA', 'GBR', 'IND', 'MEX', 'USA'),
	res = c('weekly', 'weekly', 'daily', 'daily', 'daily', 'daily', 'weekly', 'daily')
	)

final = time_use %>%
	merge(resolution, by='iso') %>%
	mutate(
		date_to_mark = as.Date(glue('{year}/{month}/{day}', format='%Y/%m/%d')),
		)

final$is_holiday = mcmapply(
	is_holiday_country, 
	iso=final$iso, date=final$date_to_mark, res=final$res,
	mc.cores=cores)


final = final %>%
	select(-res, -date_to_mark)


write.dta(final, glue(
	'{ROOT_INT_DATA}/temp/',
	'all_time_use_holidays_marked.dta'))














