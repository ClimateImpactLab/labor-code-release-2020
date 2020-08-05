clear
set matsize 3000
set more off
set maxvar 20000

local DATAPATH "/shares/gcp/estimation/Labor/Labor_merge"


cilpath
******************************************
******************************************
******************************************
* first clean old raw data using old code
******************************************
******************************************
******************************************

global data_folder /shares/gcp/estimation/Labor/replication_data/time_use/brazil/
*use "$DB/GCP/WORKSHOP_STUDENT_FOLDERS/Baker_LaborForceSurveyBrazil/Data/Final/pmeall_1.dta", clear
use "`DATAPATH'/BRA/pmeall_1.dta"
*15,499,605 observations

gen employed=1 if V401==1
replace employed=0 if V401==2
replace employed=1 if V403==1
* 2,060,700 missing employed

rename V035 metropolitan_region

gen total_work=VD28*60
* (8,575,351 missing values generated)
drop if VD28 <= 0
* 0 obs deleted
*drop if employed==.
*2,060,700 observations deleted)
*drop if employed==2

drop if VD28==.
*6,514,651 observations deleted
* drop if VD28 > 100
* 4857 deleted 4977
** extensive margin
gen worked_this_week = 1 if V401==1
replace worked_this_week=0 if V401==0

* 6,924,254 obs left

cap drop highrisk
cap drop lowrisk

gen highrisk=1 if V408A==1 | V408A==2 | V408A==5 | V408A==10 | V408A==11 | V408A==12 | V408A==13 | V408A==14 | V408A==15 | V408A==16 | V408A==17 | V408A==20 | V408A==21 | V408A==24 | V408A==25 | V408A==26 | V408A==45
replace highrisk=1 if V408A >= 28 & V408A <=36 

replace highrisk=0 if highrisk != 1
replace highrisk=. if V408A==.


* sex, where male==1
gen sex=0 if V203==2
replace sex=1 if V203==1

*age (NB// drop if age <15 or >65)
gen age=V234 
drop if V234 < 15 | V234 > 65 
* 143,225 observations deleted
gen age_2=age^2


* hh size

* Summary Statistics
gen hhsize=.
replace hhsize= V209 if V209 <31



drop if total_work == 0
* 139,625 deleted
drop if total_work == .
drop if year<2002

drop if year>2010
* if don't drop > 2010, we'll get 6,636,547 obs
* this will give us 4475272 obs


egen hhid2=group(V040 V050 V060)
egen id=group(hhid2 V204 V214 V224 V203)
sort id year month
by id: gen n=_n
replace id=. if n >=9
* 5404 missing
* 5,551,248


rename V204 day_of_birth
rename V214 month_of_birth
rename V224 year_of_birth
rename V070 survey_month
rename V075 survey_year 
rename V055 survey_week 


drop V*

save "$data_folder/cleaned/cleaned_olddata_oldcode.dta", replace


******************************************
******************************************
******************************************
* then clean new raw data using old code
******************************************
******************************************
******************************************

********************************************
*import delimited using "$data_folder/pme_all_lodown.csv", clear
*save "$data_folder/pme_all_lodown.dta", replace
use "$data_folder/pme_all_lodown.dta", clear

rename vd* VD*

rename v* V*
rename *a *A

gen employed=1 if V401==1
*(9,320,538 missing values generated)
replace employed=0 if V401==2
replace employed=1 if V403==1
* 2,060,700 missing employed


gen total_work=VD28*60
* (9,120,422 missing values generated)
drop if VD28 <= 0
* 0 obs deleted
*drop if employed==.
*(2,165,807 observations deleted)

*drop if employed==2

drop if VD28==.
*(6,954,615 observations deleted)
*drop if VD28 > 100
* 4857 deleted 4977
** extensive margin
gen worked_this_week = 1 if V401==1
replace worked_this_week=0 if V401==0

* 6,924,254 obs left

cap drop highrisk
cap drop lowrisk

gen highrisk=1 if V408A==1 | V408A==2 | V408A==5 | V408A==10 | V408A==11 | V408A==12 | V408A==13 | V408A==14 | V408A==15 | V408A==16 | V408A==17 | V408A==20 | V408A==21 | V408A==24 | V408A==25 | V408A==26 | V408A==45
replace highrisk=1 if V408A >= 28 & V408A <=36 

replace highrisk=0 if highrisk != 1
replace highrisk=. if V408A==.


* sex, where male==1
gen sex=0 if V203==2
replace sex=1 if V203==1

*age (NB// drop if age <15 or >65)
gen age=V234 
drop if V234 < 15 | V234 > 65 
* 143,225 observations deleted
gen age_2=age^2


* hh size

* Summary Statistics
gen hhsize=.
replace hhsize= V209 if V209 <31



* generate survey date
rename V070 month
rename V075 year 
rename V055 week 
rename V035 metropolitan_region

drop if total_work == 0
* 139,625 deleted
drop if total_work == .
drop if year<2002

drop if year>2010
* if don't drop > 2010, we'll get 6,636,547 obs
* this will give us 4475272 obs


egen hhid2=group(V040 V050 V060)
egen id=group(hhid2 V204 V214 V224 V203)
sort id year month
by id: gen n=_n
replace id=. if n >=9
* 5404 missing
* 5,551,248


rename V204 day_of_birth
rename V214 month_of_birth
rename V224 year_of_birth
rename V070 survey_month
rename V075 survey_year 
rename V055 survey_week 

drop V*

save "$data_folder/cleaned/cleaned_lodown_oldcode.dta", replace

