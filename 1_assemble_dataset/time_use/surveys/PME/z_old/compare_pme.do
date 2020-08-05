global data_folder /shares/gcp/estimation/Labor/replication_data/time_use/brazil/


use "$data_folder/cleaned/cleaned_pmeall_1.dta", clear
use "$data_folder/cleaned/cleaned_pme_all_lodown.dta", clear



use "/shares/gcp/estimation/Labor/labor_merge_2019/for_regression/country_specific_polynomials/labor_dataset_BRA_dec2019.dta", clear
count
* to match to 1st record in lodown
drop pre* poly* *dd*  adj* *tile clust* *gdp* _merge
tab month year
tab day if year == 2003 & month == 5
gen interview_date = date
keep if year == 2003 & month == 5 & day == 25
save tempold, replace

list if male == 0 & age == 47 & mins_worked == 2700 & hhsize == 2 & year == 2002 & location_id1 == 47 & month == 3

list if male == 0 & age == 47 & mins_worked == 2700 & hhsize == 2 & year == 2002 & location_id1 == 47 & month == 4


list if male == 0 & age == 47 & mins_worked == 2700 & hhsize == 2 & survey_year == 2002 & metropolitan_region == 33 & survey_month == 4


use "$data_folder/cleaned/cleaned_lodown_newcode.dta", clear
count
tab month year
tab day if year == 2003 & month == 5
keep if year == 2003 & month == 5 & day == 25
save tempnew, replace

use tempnew, clear
drop _merge
merge n:n mins_worked male age hhsize interview_date using tempold 
* 4,479,182
list if male == 0 & age == 47 & mins_worked == 2700 & hhsize == 2 & year == 2002 & metropolitan_region ==33 & month == 3








*********


use "$data_folder/cleaned/cleaned_lodown_oldcode.dta", clear
count
rename V035 metropolitan_region
* 4,480,133
list if sex == 0 & age == 47 & total_work == 2700 & hhsize == 2 & year == 2002 & metropolitan_region ==33 & month == 3
list if sex == 0 & age == 47 & total_work == 2700 & hhsize == 2 & year == 2002 & metropolitan_region ==33 & month == 4

use "$data_folder/cleaned/cleaned_lodown_newcode.dta", clear
count



use "$data_folder/cleaned/cleaned_olddata_newcode.dta", clear
count
* 4,478,126
list if male == 0 & age == 47 & mins_worked == 2700 & hhsize == 2 & year == 2002 & metropolitan_region ==33 & month == 3

drop _merge
merge 1:1 panel hhd_survey_number rotational_group male age mins_worked hhsize survey_year metropolitan_region survey_month interview_date control_number hhd_selection_number using "$data_folder/cleaned/cleaned_lodown_newcode.dta"


use "$data_folder/cleaned/cleaned_olddata_oldcode.dta", clear
count
* 4,479,080
rename V035 metropolitan_region
list if sex == 0 & age == 47 & total_work == 2700 & hhsize == 2 & year == 2002 & metropolitan_region ==33 & month == 3
