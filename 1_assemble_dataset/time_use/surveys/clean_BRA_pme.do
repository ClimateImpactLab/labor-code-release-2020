* this code cleans 

cilpath
global data_folder /shares/gcp/estimation/Labor/replication_data/time_use/brazil/
use "$data_folder/pme_all_lodown.dta", clear

count
* 16,508,681 obs

* mins_worked
gen mins_worked = vd28 * 60 
* (9,120,422 missing values generated)
drop if !(mins_worked > 0)
* (150,228 observations deleted)
drop if missing(mins_worked)
* (9,120,422 observations deleted)



* age
rename v234 age
drop if age < 15 | age > 65
*(151,259 observations deleted)

* male
rename v203 male
* no missing
replace male = 0 if male == 2


* hhsize
rename v209 hhsize 

* high_risk
rename v408a economic_activity
gen high_risk = 0
replace high_risk = 1 if economic_activity >= 1 & economic_activity <= 21
replace high_risk = 1 if economic_activity >= 23 & economic_activity <= 45
replace high_risk = 1 if inlist(economic_activity, 60,61,62,92)
drop if economic_activity == 0
drop if missing(economic_activity)


* region
rename v035 metropolitan_region
* values:
* 26 = Recife
* 29 = Salvador
* 31 = Belo Horizonte
* 33 = Rio de Janeiro
* 35 = São Paulo
* 41 = Curitiba
* 43 = Porto Alegre



* household identifiers
rename v040 control_number
rename v050 hhd_selection_number
rename v060 panel
rename v063 rotational_group
rename v072 hhd_survey_number
* this number is not unique for each person
rename v201 resident_identifier


egen hhd_id = group(metropolitan_region control_number hhd_selection_number panel rotational_group)
* new id is same as id in old dataset

* there's no individual identifier in the dataset 
rename v204 day_of_birth
rename v214 month_of_birth
rename v224 year_of_birth
egen ind_id = group(hhd_id day_of_birth month_of_birth year_of_birth male)



* generate survey date
rename v070 survey_month
rename v075 survey_year 
rename v055 survey_week 

* reference week: sat - sun preceding the week set to interview for the household
* each month of the survey has 4 reference weeks
* reference date: the date of the last day of the reference week
* PME is a panel survey, in which each household is interviewed 8 times over a 16-months period 
* (the household is surveyed for 4 consecutive months, out for 8, and then returns for another 4 months of interviews)

tempfile temp
save `temp', replace


* the following chunk of code generates the date of the sunday at the beginning of the reference week
* first we find what are the weeks 
keep survey_year survey_month survey_week
duplicates drop

* find 1st day of month and its day of week
gen day1 = mdy(survey_month, 1, survey_year)
gen day1_dow = dow(day1)

* find date of 1st sunday of each month
gen sunday1 = day1
replace sunday1 = day1 + (7 - day1_dow) if day1_dow != 0

* find date of the 2nd, 3rd, 4th sundays
gen sunday2 = sunday1 + 7
gen sunday3 = sunday1 + 7 * 2
gen sunday4 = sunday1 + 7 * 3

* count number of days before 1st sunday
gen days_month_start = 0
replace days_month_start = (7 - day1_dow) if day1_dow != 0 

* count number of days after 4th sunday
gen days_month_end = 0
replace days_month_end = 31 - (sunday4 - day1) if inlist(survey_month, 1,3,5,7,8,10,12)
replace days_month_end = 30 - (sunday4 - day1) if inlist(survey_month, 4,6,9,11)
replace days_month_end = 29 - (sunday4 - day1) if survey_month == 2 & inlist(survey_year, 2004, 2008, 2012)
replace days_month_end = 28 - (sunday4 - day1) if survey_month == 2 & (!inlist(survey_year, 2004, 2008, 2012))

* if there's 1 week or more left at the end of the month, take that week plus the 3 weeks from 1st sunday to 4th sunday
drop if days_month_start == days_month_end
gen take_first_week = 1 if days_month_start > days_month_end
gen interview_date4 = sunday4 + 7 if take_first_week != 1 
gen interview_date3 = sunday4 if take_first_week != 1
gen interview_date2 = sunday3 if take_first_week != 1
gen interview_date1 = sunday2 if take_first_week != 1


* if there's more days before the first sunday than after the last sunday, take the first week
forval i = 1/4{
	replace interview_date`i' = sunday`i' if take_first_week == 1
}


* generate the date variable
gen sunday_endofweek = 0

forval i = 1/4 {
	replace sunday_endofweek = interview_date`i' if survey_week == `i'
}

format interview_date* sunday* day1 %tdDDMonCCYY

keep survey_year survey_month survey_week sunday_endofweek 

merge 1:n survey_year survey_month survey_week using `temp'

rename v211 statistical_weight_no_adjusting
* This variable has 6 integers and 1 decimal separated by a dot
* (person's stastitical weight corrected for non-occured interviews without adjusting for population projection)
*    Variable |        Obs        Mean    Std. Dev.       Min        Max
*-------------+---------------------------------------------------------
*        v211 |  7,086,772    414.0406    246.0739         19     4101.9

rename v215 statistical_weight_adjusted
gen sample_wgt = statistical_weight_adjusted
* This variable has 6 integers and 1 decimal separated by a dot
* (person's stastitical weight corrected for non-occured interviews adjusting for population projection - used for indexes calculations)

*    Variable |        Obs        Mean    Std. Dev.       Min        Max
*-------------+---------------------------------------------------------
*        v215 |  7,086,772    473.2924     281.812       20.6       5367
drop v*

gen saturday_endofweek = sunday_endofweek - 1
gen year = year(saturday_endofweek)
gen month = month(saturday_endofweek)
gen day = day(saturday_endofweek)
drop if year < 2002 | year > 2010

keep metropolitan_region ind_id year month day mins_worked age male high_risk hhsize sample_wgt

save "/shares/gcp/estimation/labor/time_use_data/intermediate/BRA_PME_time_use.dta", replace

use "/shares/gcp/estimation/labor/time_use_data/intermediate/BRA_PME_time_use.dta", clear

export delimited using "/shares/gcp/estimation/labor/time_use_data/intermediate/BRA_PME_time_use.csv", replace
