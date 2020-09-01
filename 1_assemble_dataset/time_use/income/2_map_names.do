* This program maps admin1 names from the labor dataset to adm1 names in Gennaioli et al. and EU income data,
* which I will use to downscale PWT country-level income data. 

* Author: Simon Greenhill, sgreenhill@uchicago.edu
* Date: 10/2/2019
* Updated 2/29/2020 to work with replicated labor dataset.
* For orginal version, see gcp-labor/1_preparation/income/map_names.do

clear all
set more off 
pause off
cap ssc install reclink

do "/home/`c(username)'/repos/labor-code-release-2020/0_subroutines/setup_paths_stata.do"

****************************
* 1. set up tools and data *
****************************

* modify reclink so it doesn't drop unmatched observations
cap program drop better_reclink
program better_reclink
	args country ds1 ds2 idmaster idusing
	di "`country'"

	use `ds1', clear
	keep if iso  == "`country'"
	reclink iso admin_name using `ds2', idmaster(`idmaster') idusing(`idusing') gen(score_getal) minscore(0.6) required(iso)
	drop _merge
	preserve
		use `ds2', clear
		keep if iso == "`country'"
		drop iso
		rename admin_name Uadmin_name
		tempfile temp
		save `temp'
	restore

	merge m:1 Uadmin_name using `temp', nogen
	duplicates tag getal_id, gen(dup_getal)
	format %24s admin_name Uadmin_name
end

* combine all the crosswalks into one
loc isos "BRA" "CHN" "ESP" "FRA" "GBR" "IND" "MEX" "USA"

foreach iso in "`isos'" {
	qui import delim "${DIR_EXT_DATA}/crosswalks/shapefile_to_timeuse_crosswalk_`iso'.csv", clear
	
	if "`iso'" == "GBR" {
		rename admin_name name_1
	}
	if "`iso'" == "MEX" {
		rename state_name name_1
	}
	if "`iso'" == "BRA" {
		rename name_1_adm1 name_1
	}
	keep iso adm0_id name_1 adm1_id
	qui duplicates drop

	rename name_1 admin_name

	cap confirm file `cw'
	if _rc == 0 & iso != "`BRA'" {
		qui append using `cw'
		tempfile cw
		qui save `cw'
	}
	else {
		tempfile cw
		qui save `cw'
	}	
}

use `cw', clear

keep iso
duplicates drop

tempfile countnames
save `countnames'

* load getal data and subset to countries we want
use "${DIR_EXT_DATA}/misc/pwt_income_adm1.dta", clear
keep region countrycode
rename countrycode iso
duplicates drop

merge m:1 iso using `countnames', keep(3) nogen

* for European countries, keep only the NUTS coded data
keep if regexm(region, "[A-Z][A-Z][0-9]") | !inlist(iso, "FRA", "ESP")
keep if regexm(region, "[A-Z][A-Z][A-Z]") | !inlist(iso, "GBR")

rename region admin_name
egen getal_id = group(iso admin_name)

drop if mi(getal_id)

tempfile insample
save `insample'

* load population data and subset to countries we want
use "${DIR_EXT_DATA}/misc/adm2_pop_mortality.dta", clear

* NOTE: Missing a few years of China data here. Interpolate (linearly in-sample, log out of sample)
egen adm2_id_unique = group(iso adm1_id adm2_id)
drop if mi(adm2_id_unique)
xtset adm2_id_unique year
tsfill

foreach v in iso adm1_id adm2_id adm1 adm2 {
	by adm2_id_unique: replace `v' = `v'[1] 
}

* append a blank dataset with China 1989 and 1990 observations, since we need those.
* An alternative way of doing this would be -tsfill, full-, but that produces a bunch of 
* extra observations I don't want to deal with.
preserve
	keep if iso == "CHN"
	drop year population
	duplicates drop
	expand 2

	gen year = .
	gen population = .
	sort adm2_id_unique
	by adm2_id_unique: replace year = 1989 if _n == 1
	by adm2_id_unique: replace year = 1990 if _n == 2

	tempfile chn_append
	save `chn_append'
restore

append using `chn_append'

sort adm2_id_unique year
* linear interpolation in sample
by adm2_id_unique: ipolate population year, gen(population_interpolated)
* log extrapolation out of sample
gen log_pop = log(population)
by adm2_id_unique: ipolate log_pop year, gen(log_population_extrapolated) epolate
replace population_interpolated = exp(log_population_extrapolated) if mi(population_interpolated)

replace population = population_interpolated

keep iso adm1 adm1_id adm2_id year population

collapse (sum) population, by(iso adm1_id adm1 year)
replace adm1 = adm1_id if missing(adm1)
egen id = group(iso adm1)

rename adm1 admin_name

tempfile pop
save `pop'

drop year population
duplicates drop

tempfile pop_names
save `pop_names'

******************************************************************
* 2. Match G et al regions to population regions in mort dataset *
******************************************************************

* Brazil
better_reclink "BRA" `insample' `pop_names' getal_id id

gen Uadmin_name2 = ""
gen Uadmin_name3 = ""
gen Uadmin_name4 = ""
gen Uadmin_name5 = ""

replace Uadmin_name = "pará" if admin_name == "ParÃ¡ and AmapÃ¡"
replace Uadmin_name2 = "amapá" if admin_name == "ParÃ¡ and AmapÃ¡"

replace Uadmin_name = "amazonas" if admin_name == "Amazonas, MG, MG do Sul, RondÃ´nia, Roraima"
replace Uadmin_name2 = "mato grosso" if admin_name == "Amazonas, MG, MG do Sul, RondÃ´nia, Roraima"
replace Uadmin_name3 = "mato grosso do sul" if admin_name == "Amazonas, MG, MG do Sul, RondÃ´nia, Roraima"
replace Uadmin_name4 = "rondônia" if admin_name == "Amazonas, MG, MG do Sul, RondÃ´nia, Roraima"
replace Uadmin_name5 = "roraima" if admin_name == "Amazonas, MG, MG do Sul, RondÃ´nia, Roraima"

replace Uadmin_name = "goiás" if admin_name == "GoiÃ¡s, DF, Tocantins"
replace Uadmin_name2 = "distrito federal" if admin_name == "GoiÃ¡s, DF, Tocantins"
replace Uadmin_name3 = "tocantins" if admin_name == "GoiÃ¡s, DF, Tocantins"

drop if mi(getal_id)
replace iso = "BRA" if mi(iso)

tempfile BRA
save `BRA'

* China
better_reclink "CHN" `insample' `pop_names' getal_id id

gen Uadmin_name2 = ""
gen Uadmin_name3 = ""
replace Uadmin_name2 = "Chongqing" if admin_name == "Sichuan w/ Chongqing"
replace Uadmin_name2 = "Hainan" if admin_name == "Guangdong w/ Hainan"
replace Uadmin_name2 = "Neimenggu" if admin_name == "Gansu w/ Inner Mongolia & Ningxia"
replace Uadmin_name3 = "Ningxia" if admin_name == "Gansu w/ Inner Mongolia & Ningxia"

drop if mi(getal_id)

tempfile CHN
save `CHN'

* France
better_reclink "FRA" `insample' `pop_names' getal_id id

* match to NUTS codes
forval i=2(1)6 {
	gen Uadmin_name`i' = ""
}

replace Uadmin_name = "Ile-de-France" if admin_name == "FR1"

replace Uadmin_name = "Champagne-Ardenne" if admin_name == "FR2"
replace Uadmin_name2 = "Picardie" if admin_name == "FR2"
replace Uadmin_name3 = "Haute-Normandie" if admin_name == "FR2"
replace Uadmin_name4 = "Centre" if admin_name == "FR2"
replace Uadmin_name5 = "Basse-Normandie" if admin_name == "FR2"
replace Uadmin_name6 = "Bourgogne" if admin_name == "FR2"

replace Uadmin_name = "Nord-Pas-de-Calais" if admin_name == "FR3"

replace Uadmin_name = "Lorraine" if admin_name == "FR4"
replace Uadmin_name2 = "Alsace" if admin_name == "FR4"
replace Uadmin_name3 = "Franche-Comté" if admin_name == "FR4"

replace Uadmin_name = "Pays de la Loire" if admin_name == "FR5"
replace Uadmin_name2 = "Bretagne" if admin_name == "FR5"
replace Uadmin_name3 = "Poitou-Charentes" if admin_name == "FR5"

replace Uadmin_name = "Aquitaine" if admin_name == "FR6"
replace Uadmin_name2 = "Limousin" if admin_name == "FR6"
replace Uadmin_name3 = "Midi-Pyrénées" if admin_name == "FR6"

replace Uadmin_name = "Auvergne" if admin_name == "FR7"
replace Uadmin_name2 = "Rhône-Alpes" if admin_name == "FR7"

replace Uadmin_name = "Languedoc-Roussillon" if admin_name == "FR8"
replace Uadmin_name2 = "Provence-Alpes-Côte d'Azur" if admin_name == "FR8"
replace Uadmin_name3 = "Corse" if admin_name == "FR8"

drop if mi(getal_id)
replace iso = "FRA" if mi(iso)

tempfile FRA
save `FRA'

* India
better_reclink "IND" `insample' `pop_names' getal_id id

replace Uadmin_name = "" if !inlist(admin_name, "Gujarat", "Haryana", "Madhya Pradesh", "Meghalaya", "Orissa", "Tamil Nadu")
drop if mi(admin_name)
replace iso = "IND" if mi(iso)

tempfile IND
save `IND'

* Mexico
better_reclink "MEX" `insample' `pop_names' getal_id id

replace iso = "MEX" if mi(iso)

tempfile MEX
save `MEX'

* Spain
better_reclink "ESP" `insample' `pop_names' getal_id id

replace iso = "ESP" if mi(iso)

tempfile ESP
save `ESP'

* United Kingdom
better_reclink "GBR" `insample' `pop_names' getal_id id


replace iso = "GBR" if mi(iso)

tempfile GBR
save `GBR'

* United States
better_reclink "USA" `insample' `pop_names' getal_id id

replace iso = "USA" if mi(iso)

tempfile USA
save `USA'

* merge together results
use `countnames', clear
levelsof iso, local(countries)

use `USA', clear
drop if _n > 0

tempfile all
save `all'

foreach c in `countries' {
	di "`c'"

	use ``c'', clear

	if "`c'" == "BRA" {
		loc min=2002
		loc max=2010
	}
	if "`c'" == "CHN" {
		loc min = 1989
		loc max = 2011
	}
	if "`c'" == "ESP" {
		loc min=2002
		loc max=2003
	}
	if "`c'" == "FRA" {
		loc min=1998
		loc max=1999
	}
	if "`c'" == "GBR" {
		loc min=1983
		loc max=2001
	}
	if "`c'" == "IND" {
		loc min=1998
		loc max=1999
	}
	if "`c'" == "MEX" {
		loc min=2005
		loc max=2010
	}
	if "`c'" == "USA" {
		loc min=2003
		loc max=2010
	}

	loc range=`max' - `min' + 1
	expand `range', gen(dup)

	sort admin_name Uadmin_name
	by admin_name Uadmin_name: gen counter = _n

	qui gen year = `min' + counter - 1

	qui drop dup counter
	order iso year

	qui append using `all'
	qui save `all', replace
}

drop score_getal dup_getal getal_id Uiso

* loop over the additional names, merging in relevant pop data
replace Uadmin_name = "missing" if Uadmin_name == ""
replace admin_name = Uadmin_name if admin_name == ""
rename Uadmin_name Uadmin_name1

forval j=1(1)6 {
	preserve
		use `pop', clear
		rename admin_name Uadmin_name`j'
		rename population population`j'
		tempfile tomerge
		save `tomerge'
	restore

	merge m:1 iso Uadmin_name`j' year using `tomerge', keep(1 3) nogen
	rename Uadmin_name`j' pop_admin_name`j'
}

egen pop_tot = rowtotal(population*)
drop population*
egen pop_adm_name = concat(pop_admin_name*), punct(" ")
drop pop_admin_name*


tempfile main
save `main'

************************************************
* 3. clean countries for labor (one at a time) *
************************************************

* Brazil
better_reclink "BRA" `cw' `insample' adm1_id getal_id

drop if inlist(Uadmin_name, "Rio Grande do Sul", "SÃ£o Paulo") & mi(adm1_id)
replace iso = "BRA" if mi(iso)

tempfile BRA
save `BRA'

* China
better_reclink "CHN" `cw' `insample' adm1_id getal_id

replace iso = "CHN" if mi(iso)

tempfile CHN
save `CHN'

* France
better_reclink "FRA" `cw' `insample' adm1_id getal_id

* match to NUTS codes
replace Uadmin_name = "FR1" if regexm(admin_name, "le-de-France")
replace Uadmin_name = "FR2" if inlist(admin_name, "Champagne-Ardenne", "Picardie", "Haute-Normandie", "Centre", "Basse-Normandie", "Bourgogne")
replace Uadmin_name = "FR3" if inlist(admin_name, "Nord-Pas-de-Calais")
replace Uadmin_name = "FR4" if inlist(admin_name, "Lorraine", "Alsace") 
replace Uadmin_name = "FR4" if regexm(admin_name, "Franche-Comt")
replace Uadmin_name = "FR5" if inlist(admin_name, "Pays de la Loire", "Bretagne", "Poitou-Charentes")
replace Uadmin_name = "FR6" if inlist(admin_name, "Aquitaine", "Limousin")
replace Uadmin_name = "FR6" if regexm(admin_name, "Midi-Pyr")
replace Uadmin_name = "FR7" if inlist(admin_name, "Auvergne")
replace Uadmin_name = "FR7" if regexm(admin_name, "ne-Alpes$")
replace Uadmin_name = "FR8" if inlist(admin_name, "Languedoc-Roussillon", "Corse")
replace Uadmin_name = "FR8" if regexm(admin_name, "Provence-Alpes-C")

drop if mi(adm1_id)
replace iso = "FRA" if mi(iso)

tempfile FRA
save `FRA'

* India
better_reclink "IND" `cw' `insample' adm1_id getal_id

replace iso = "IND" if mi(iso)
tempfile IND
save `IND'

* Mexico
better_reclink "MEX" `cw' `insample' adm1_id getal_id
* a perfect match!
tempfile MEX
save `MEX'

* Spain
better_reclink "ESP" `cw' `insample' adm1_id getal_id

* match to NUTS codes
* North West: Galicia, Asturias, Cantabria
replace Uadmin_name = "ES1" if inlist(admin_name, "Principado de Asturias", "Cantabria", "Galicia")
* North East: Basque Community, Navarre, La Rioja, Aragon
replace Uadmin_name = "ES2" if inlist(admin_name, "Comunidad Foral de Navarra", "La Rioja")
replace Uadmin_name = "ES2" if regexm(admin_name, "Vasco") | regexm(admin_name, "Arag")
* Community of Madrid:	Community of Madrid
replace Uadmin_name = "ES3" if (admin_name == "Comunidad de Madrid")
* Centro
replace Uadmin_name = "ES4" if inlist(admin_name, "Castilla-La Mancha", "Extremadura")
replace Uadmin_name = "ES4" if regexm(admin_name, "Castilla y Le")

* East:	Catalonia, Valencian Community, Balearic Islands
replace Uadmin_name = "ES5" if inlist(admin_name, "Comunidad Valenciana", "Islas Baleares")
replace Uadmin_name = "ES5" if regexm(admin_name, "Catalu")

* South: Andalusia, Region of Murcia, Ceuta, Melilla
replace Uadmin_name = "ES6" if inlist(admin_name, "Ceuta y Melilla")
replace Uadmin_name = "ES6" if regexm(admin_name, "Andaluc") | regexm(admin_name, "Murcia")

* Canary Islands	Canary Islands
replace Uadmin_name = "ES7" if inlist(admin_name, "Islas Canarias")

drop if mi(adm1_id)
replace iso = "ESP" if mi(iso)

tempfile ESP
save `ESP'

* United Kingdom
* come back to this
better_reclink "GBR" `cw' `insample' adm1_id getal_id

* match to NUTS codes
gen Uadmin_name2 = ""
replace Uadmin_name = "UKC" if admin_name == "North East"
replace Uadmin_name = "UKE" if admin_name == "Yorkshire and the Humber"
replace Uadmin_name = "UKF" if admin_name == "East Midlands"
replace Uadmin_name = "UKG" if admin_name == "West Midlands"
replace Uadmin_name = "UKH" if admin_name == "East of England"
replace Uadmin_name = "UKI" if admin_name == "South East and London"
replace Uadmin_name2 = "UKJ" if admin_name == "South East and London"
replace Uadmin_name = "UKK" if admin_name == "South West"
replace Uadmin_name = "UKL" if admin_name == "Wales"
replace Uadmin_name = "UKM" if admin_name == "Scotland"
replace Uadmin_name = "UKN" if admin_name == "Northern Ireland"

drop if mi(adm1_id)
replace iso = "GBR" if mi(iso)

tempfile GBR
save `GBR'

* United States
better_reclink "USA" `cw' `insample' adm1_id getal_id

replace iso = "USA" if mi(iso)
tempfile USA
save `USA'

use `countnames', clear
levelsof iso, local(countries)

use `USA', clear
drop if _n > 0

tempfile all
save `all'

* expand each dataset by number of years we need; append all countries
foreach c in `countries' {
	di "`c'"

	use ``c'', clear

	if "`c'" == "BRA" {
		loc min=2002
		loc max=2010
	}
	if "`c'" == "CHN" {
		loc min = 1989
		loc max = 2011
	}
	if "`c'" == "ESP" {
		loc min=2002
		loc max=2003
	}
	if "`c'" == "FRA" {
		loc min=1998
		loc max=1999
	}
	if "`c'" == "GBR" {
		loc min=1983
		loc max=2001
	}
	if "`c'" == "IND" {
		loc min=1998
		loc max=1999
	}
	if "`c'" == "MEX" {
		loc min=2005
		loc max=2010
	}
	if "`c'" == "USA" {
		loc min=2003
		loc max=2010
	}

	loc range=`max' - `min' + 1
	expand `range', gen(dup)

	sort admin_name Uadmin_name
	by admin_name Uadmin_name: gen counter = _n

	qui gen year = `min' + counter - 1

	qui drop dup counter
	order iso year

	qui append using `all'
	qui save `all', replace	
}

* clean up
drop score_getal dup_getal getal_id Uiso

*****************************
* 4. Merge together results *
*****************************

* Loop over the different potential getal additional names, merging in the relevant income information
replace Uadmin_name = "missing" if Uadmin_name == ""
rename Uadmin_name Uadmin_name1

replace admin_name = "missing" if admin_name == ""

forvalues j  = 1(1)2 {
	preserve
		use "${DIR_EXT_DATA}/misc/pwt_income_adm1.dta", clear
		rename (region *gdppc*) (Uadmin_name`j' *gdppc*_`j')
		rename countrycode iso

		keep iso year Uadmin_name`j' *gdp* 

		tempfile pwt 
		save `pwt', replace
	restore

	merge m:1 iso Uadmin_name`j' year using `pwt', keep(1 3) nogen
	rename Uadmin_name`j' getal_admin_name`j'

	* merge in pop data
	preserve
		use `main', clear

		rename (pop_tot pop_adm_name admin_name) (pop_tot`j' pop_adm_name`j' getal_admin_name`j')

		drop id adm1_id

		tempfile pop_merge
		save `pop_merge'
	restore

	merge m:1 iso getal_admin_name`j' year using `pop_merge', keep(1 3) nogen
	replace pop_tot`j' = . if pop_tot`j' == 0
}

* rename population population1
* drop gdppcstate country

* make a new grouping id var
egen match_id = group(iso admin_name getal_admin_name* pop_adm_name*), missing

export delimited using "${DIR_EXT_DATA}/misc/income_pop_merged.csv", replace
