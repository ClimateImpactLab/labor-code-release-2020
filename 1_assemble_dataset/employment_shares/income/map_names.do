* create mapping from La Porta income data adm1 names to IPUMS adm1 names
* By: Simon Greenhill, sgreenhill@uchicago.edu (adapted from code by Tom)
* Date: 9/13/2019

* A note about characters with diacritics: 
* String matching a replacing when some characters have diacritics (accents or other markings) on them is a pain.
* I'm dealing with this using regular expressions: Instead of typing an accented character in the code (which will
* not be reliably understood by different OSes, versions, etc.), I match all the other letters in the word, and 
* allow for a wildcard where the accent is. Note that this can fail if a word you don't want to match is identical
* to the one you want to match except for its diacritic markings (this happens in Poland's case, 
* so I revert to just using the accented characters).

clear all
set more off
set varabbrev off
cap set processors 12
set maxvar 32767
pause on

cilpath
global lab "$OUTPUT/CIL_labor/"
global mig "$OUTPUT/CIL_Migration/"
global Inc_DATA "$OUTPUT/Global_ACP//MORTALITY/Replication_2018/2_Data"

****************************
* 1. set up tools and data *
****************************

* modify reclink so it doesn't drop unmatched observations
cap program drop better_reclink
program better_reclink
	args country insample
	di "`country'"
	insheet using "$lab/1_preparation/employment_shares/data/shp/world_geolev1_2019/geolev1_names.csv", clear
	rename cntry_name country
	keep if country  == "`country'"
	reclink country admin_name using `insample', ///
		 idmaster(geolevel1) idusing(getal_id) gen(score_getal) minscore(0.6) required(country)
	drop _merge
	preserve
		use `insample', clear
		keep if country == "`country'"
		drop country
		rename admin_name Uadmin_name
		tempfile temp
		save `temp'
	restore

	merge m:1 Uadmin_name using `temp', nogen
	duplicates tag getal_id, gen(dup_getal)
	format %24s admin_name Uadmin_name
end

* get list of countries in IPUMS labor data
insheet using "$lab/1_preparation/employment_shares/data/required_clim_data.csv", clear
keep country
tempfile countnames
save `countnames', replace

* clean up the getal names
import delimited "$Inc_DATA/Raw/Income/LaPorta/Gennaioli2014_full.csv", clear

keep country region
duplicates drop

replace country = "Egypt" if country == "Egypt, Arab Rep."
replace country = "Iran" if country == "Iran (Islamic Republic of)"
replace country = "Kyrghzstan" if country == "Kyrgyzstan"
replace country = "Lao People's Democratic Republic" if country == "Lao People's DR"
replace country = "Palestine" if country == "State of Palestine"
replace country = "Sudan" if country == "Sudan (Former)"
replace country = "Tanzania" if country == "U.R. of Tanzania: Mainland"
rename region admin_name

* add countries that are missing entirely
local N = _N + 2
set obs `N'
replace country = "Papua New Guinea" if _n == _N - 1
replace country = "South Sudan" if _n == _N

merge m:1 country using `countnames', keep(3) nogen

* Generate a unique identifier for admin - country pairs
egen getal_id = group(country admin_name)
sort getal_id
replace getal_id = _n if getal_id == .

tempfile insample
save `insample'

**************************************
* 2. clean countries (one at a time) *
**************************************

* Argentina
better_reclink "Argentina" `insample'

replace Uadmin_name = "Ciudad de Bs. As." if admin_name == "City of Buenos Aires" 

drop if geolevel1 == .

tempfile Argentina
save `Argentina'

* Armenia
better_reclink "Armenia" `insample'

drop if geolevel1 == .

tempfile Armenia
save `Armenia'

* Austria
better_reclink "Austria" `insample'

replace Uadmin_name = "AT1" if inlist(admin_name, "Burgenland", "Wien")
replace Uadmin_name = "AT1" if regexm(admin_name, "Nieder.+sterreich")
replace Uadmin_name = "AT2" if inlist(admin_name, "Steiermark")
replace Uadmin_name = "AT2" if regexm(admin_name, "K.+rnten")
replace Uadmin_name = "AT3" if inlist(admin_name, "Salzburg", "Tirol", "Vorarlberg")
replace Uadmin_name = "AT3" if regexm(admin_name, "Ober.+sterreich")

drop if geolevel1 == .

tempfile Austria
save `Austria'

* Belarus (unmatched in G et al.)
better_reclink "Belarus" `insample'

tempfile Belarus
save `Belarus'

* Benin
better_reclink "Benin" `insample'

tempfile Benin
save `Benin'

* Bolivia
better_reclink "Bolivia" `insample'

tempfile Bolivia
save `Bolivia'

* Botswana (unmatched in G et al.)
better_reclink "Botswana" `insample'

tempfile Botswana
save `Botswana'

* Brazil
better_reclink "Brazil" `insample'

replace Uadmin_name = "Amazonas, MG, MG do Sul, RondÃ´nia, Roraima" if ///
	(admin_name == "Amazonas" | admin_name == "Rondonia" | admin_name == "Mato Grosso do Sul, Mato Grosso" ///
	| admin_name == "Roraima" )
replace Uadmin_name = "GoiÃ¡s, DF, Tocantins" if admin_name == "Distrito Federal"
replace Uadmin_name = "ParÃ¡ and AmapÃ¡" if (admin_name == "Pará" | ///
	admin_name == "Amapá")

drop if geolevel1 ==.

tempfile Brazil
save `Brazil'

* Burkina Faso (unmatched in  G et al.)
better_reclink "Burkina Faso" `insample'

tempfile Burkina Faso
save `Burkina Faso'

* Cambodia (unmatched in G et al.)
better_reclink "Cambodia" `insample'

tempfile Cambodia
save `Cambodia'

* Cameroon (unmatched in G et al.)
better_reclink "Cameroon" `insample'

tempfile Cameroon
save `Cameroon'

* Canada
better_reclink "Canada" `insample'

gen Uadmin_name2 = ""
replace Uadmin_name2 = "Yukon Territory, Northwest Territories, and Nunavut" if admin_name == "Yukon, Prince Edward Island"
drop if geolevel1 == .

tempfile Canada
save `Canada'

* Chile 
better_reclink "Chile" `insample'

replace Uadmin_name = "Antofagasta" if (admin_name == "Antofagasta" | ///
	admin_name == "El Loa" | admin_name == "Tocopilla")

replace Uadmin_name = "Atacama" if (admin_name == "Copiapó" | ///
	admin_name == "Chañaral" | admin_name == "Huasco" )

replace Uadmin_name = "AisÃ©n del General Carlos IbÃ¡Ã±ez del Campo" if ( /// 
	admin_name == "Aisén, General Carrera, Palena" | admin_name == "Coihaique" | /// 
	admin_name == "Ma. Esperanza, Capitán Prat")

replace Uadmin_name = "BiobÃ­o" if (admin_name == "Ñuble" | ///
	admin_name == "Bío Bío" | admin_name == "Concepción")

replace Uadmin_name = "Los Lagos" if (admin_name == "Osorno" | ///
	admin_name == "Chiloé" | admin_name == "Llanquihue" | admin_name =="Valdivia" )

replace Uadmin_name = "Maule" if (admin_name == "Curicó" | admin_name == "Talca" ///
	| admin_name == "Cauquenes" | admin_name == "Linares")

replace Uadmin_name = "Libertador General Bernardo O'Higgins" if (admin_name == "Cachapoal" ///
	| admin_name == "Cardenal Caro" | admin_name == "Colchagua")

replace Uadmin_name = "RegiÃ³n Metropolitana de Santiago" if (admin_name == "Chacabuco" | ///
	admin_name == "Cordillera" | admin_name == "Maipo" | admin_name == "Melipilla" | ///
	admin_name == "Santiago" | admin_name == "Talagante")

replace Uadmin_name = "TarapacÃ¡" if (admin_name == "Iquique" )

replace Uadmin_name = "ValparaÃ­so" if (admin_name == "San Felipe de Aconcagüa" | ///
	admin_name == "Los Andes" | admin_name == "San Antonio" | admin_name == "Petorca" ///
	| admin_name == "Valparaíso, Isla de Pascua" | admin_name == "Quillota")


drop if geolevel1 == .

tempfile Chile
save `Chile'

* China
better_reclink "China" `insample'

replace Uadmin_name = "Gansu w/ Inner Mongolia & Ningxia" if (admin_name == "Ningxia" | admin_name == "Inner Mongolia" | admin_name == "Gansu")

drop if mi(geolevel1)

tempfile China
save `China'

* Colombia
better_reclink "Colombia" `insample'

foreach v in "2" "3" {
	gen Uadmin_name`v' = ""
}

* For when one admin name is assigned to multiple getal admin regions 
replace Uadmin_name = "Bogota" if admin_name == "Bogotá D.C., Cundinamarca"
replace Uadmin_name2 = "Cundinamarca" if admin_name == "Bogotá D.C., Cundinamarca"

replace Uadmin_name2 = "Quindio" if admin_name == "Caldas, Quindío, Risaralda"
replace Uadmin_name3 = "Risaralda" if admin_name == "Caldas, Quindío, Risaralda"

replace Uadmin_name = "Cesar" if admin_name == "Cesar, Norte De Santander, Magdalena"
replace Uadmin_name2 = "Magdalena" if admin_name == "Cesar, Norte De Santander, Magdalena"

replace Uadmin_name = "Sucre" if admin_name == "Bolívar, Sucre"

replace Uadmin_name = "Nuevos Departamentos" if (admin_name == "Arauca" ///
	| admin_name == "Amazonas, Guaviare, Vaupés, Vichada, Guainía" | admin_name == "Putumayo" | ///
	admin_name == "Archipiélago De San Andrés Y Providencia" )

drop if geolevel1 == .

tempfile Colombia
save `Colombia'

* Costa Rica (unmatched in G et al.)
better_reclink "Costa Rica" `insample'

tempfile Costa Rica
save `Costa Rica'

* Cuba (unmatched in G et al.)
better_reclink "Cuba" `insample'

tempfile Cuba
save `Cuba'

* Dominican Republic (unmatched in G et al)
better_reclink "Dominican Republic" `insample'

tempfile Dominican Republic
save `Dominican Republic'

* Ecuador
better_reclink "Ecuador" `insample'

foreach v in "2" "3" "4" "5" "6" "7" {
	gen Uadmin_name`v' = ""
}

loc x "Cañar, Esmeraldas, Guayas, Manabí, Manga del Cura [Disputed canton], Pichincha, El Piedrero [Disputed canton], Los Ríos, Santa Elena, Santo Domingo de las Tsáchilas, Galápagos"
replace Uadmin_name = "CaÃ±ar" if admin_name == "`x'"
replace Uadmin_name2 = "Esmeraldas" if admin_name == "`x'"
replace Uadmin_name3 = "Galapagos" if admin_name == "`x'"
replace Uadmin_name4 = "Guayas" if admin_name == "`x'"
replace Uadmin_name5 = "Los Rios" if admin_name == "`x'"
replace Uadmin_name6 = "Manabi" if admin_name == "`x'"
replace Uadmin_name7 = "Pichincha" if admin_name == "`x'"

replace Uadmin_name = "Imbabura" if admin_name == "Imbabura, Las Golondrinas [Disputed canton]"

replace Uadmin_name2 = "Sucumbios" if admin_name == "Napo, Orellana, Sucumbíos"

drop if geolevel1 == .

tempfile Ecuador
save `Ecuador'

* Egypt
better_reclink "Egypt" `insample'
foreach v in "2" "3"  {
	gen Uadmin_name`v' = ""
}

replace Uadmin_name2 = "Behera" if admin_name == "Menoufia, Behera"

replace Uadmin_name = "Cairo" if admin_name == "Giza, 6th October City, Cairo, Helwan"
replace Uadmin_name2 = "Giza" if admin_name == "Giza, 6th October City, Cairo, Helwan"
replace Uadmin_name = "Beni Suef" if admin_name == "Bani Swif"

drop if geolevel1 ==.

tempfile Egypt
save `Egypt'

* El Salvador
better_reclink "El Salvador" `insample'

tempfile El Salvador
save `El Salvador'

* Ethiopia (unmatched in G et al.)
better_reclink "Ethiopia" `insample'

tempfile Ethiopia
save `Ethiopia'

* Fiji (unmatched in G et al.)
better_reclink "Fiji" `insample'

tempfile Fiji
save `Fiji'

* France
better_reclink "France" `insample'

replace Uadmin_name = "FR1" if regexm(admin_name, ".+le-de-France")
replace Uadmin_name = "FR2" if inlist(admin_name, "Champagne-Ardenne", "Picardy", "Upper Normandy", "Centre", "Lower Normandy", "Burgundy")
replace Uadmin_name = "FR3" if inlist(admin_name, "North Pas-de-Calais")
replace Uadmin_name = "FR4" if inlist(admin_name, "Lorraine", "Alsace")
replace Uadmin_name = "FR4" if regexm(admin_name, "Franche-Comt.+")
replace Uadmin_name = "FR5" if inlist(admin_name, "Loire Valley", "Brittany", "Poitou-Charentes")
replace Uadmin_name = "FR6" if inlist(admin_name, "Aquitaine", "Limousin")
replace Uadmin_name = "FR6" if regexm(admin_name, "Midi-Pyr.+n.+es")
replace Uadmin_name = "FR7" if inlist(admin_name, "Auvergne")
replace Uadmin_name = "FR7" if regexm(admin_name, "Rh.+ne-Alpes")
replace Uadmin_name = "FR8" if inlist(admin_name, "Languedoc-Roussillon", "Provence-Alpes-Riviera", "Corsica")
replace Uadmin_name = "FR9" if inlist(admin_name, "Guadeloupe", "Martinique", "French Guyana")
replace Uadmin_name = "FR9" if regexm(admin_name, "R.+union Island")

drop if mi(geolevel1)

tempfile France
save `France'

* Germany
better_reclink "Germany" `insample'

replace Uadmin_name = "DE1" if regexm(admin_name, "Baden-W.+rttemberg")
replace Uadmin_name = "DE2" if admin_name == "Bayern"
replace Uadmin_name = "DE3" if inlist(admin_name, "East Berlin", "West Berlin")
replace Uadmin_name = "DE4" if admin_name == "Brandenburg"
replace Uadmin_name = "DE5" if admin_name == "Bremen"
replace Uadmin_name = "DE6" if admin_name == "Hamburg"
replace Uadmin_name = "DE7" if admin_name == "Hessen"
replace Uadmin_name = "DE8" if admin_name == "Mecklenburg-West Pomerania"
replace Uadmin_name = "DE9" if admin_name == "Niedersachsen"
replace Uadmin_name = "DEA" if admin_name == "Nordrhein-Westfalen"
replace Uadmin_name = "DEB" if admin_name == "Rheinland-Pfalz"
replace Uadmin_name = "DEC" if admin_name == "Saarland"
replace Uadmin_name = "DED" if admin_name == "Saxony"
replace Uadmin_name = "DEE" if admin_name == "Saxony-Anhalt"
replace Uadmin_name = "DEF" if admin_name == "Schleswig-Holstein"
replace Uadmin_name = "DEG" if admin_name == "Thuringia"

drop if mi(geolevel1)

tempfile Germany
save `Germany'

* Ghana (unmatched in G et al.)
better_reclink "Ghana" `insample'

tempfile Ghana
save `Ghana'

* Greece
better_reclink "Greece" `insample'
sort admin_name

* Attica
replace Uadmin_name = "EL3" if (admin_name == "Prefecture of Athens" | ///
	admin_name == "Prefecture of East Attiki" | admin_name == "Prefecture of Pireas" ///
	| admin_name == "Prefecture of West Attiki" )

* Nisia Aigaiou Kriti:	North Aegean, South Aegean, Crete
replace Uadmin_name = "EL4" if (admin_name == "Chania" | ///
	admin_name == "Chios" | admin_name == "Dodekanissos" | ///
	admin_name == "Iraklio" | admin_name == "Kyklades" | ///
	admin_name == "Lassithi" | admin_name == "Lesvos" | ///
	admin_name == "Rethymno" | admin_name == "Samos" | )

* Voreia Ellada: Eastern Macedonia and Thrace, Central Macedonia, Western Macedonia, Epirus
replace Uadmin_name = "EL5" if (admin_name == "Imathia" | ///
	admin_name == "Arta" | admin_name == "Chalkidiki" | ////
	admin_name == "Drama" |admin_name == "Evros" | ///
	admin_name == "Florina" | admin_name == "Grevena" | ///
	admin_name == "Imathia" | admin_name == "Ioannina" | ///
	admin_name == "Kastoria" | admin_name == "Kavala" | ///
	admin_name == "Kilkis" | admin_name == "Kozani" | ///
	admin_name == "Pella" | admin_name == "Pieria" | ///
	admin_name == "Preveza" | admin_name == "Rodopi" | ///
	admin_name == "Serres" | admin_name == "Thesprotia" | ///
	admin_name == "Thessaloniki" | admin_name == "Xanthi" )

* Kentriki Ellada	Thessaly, Ionian Islands, Western Greece, Central Greece, Peloponnese
replace Uadmin_name = "EL6" if (admin_name == "Achaia" | admin_name== "Argolida" ///
	| admin_name == "Thessaloniki" | admin_name == "Arkadia" | ///
	admin_name == "Etolia and Akarnania" | admin_name == "Evia" ///
	| admin_name == "Evrytania" | admin_name == "Fokida" | ///
	admin_name == "Phthiotis" | admin_name == "Ilia" | ///
	admin_name == "Karditsa" | admin_name == "Kefallinia" | /// 
	admin_name == "Kerkyra" | admin_name == "Korinthia" | ///
	admin_name == "Lakonia" | admin_name == "Larissa" | ///
	admin_name == "Lefkada" | admin_name == "Magnissia" | ///
	admin_name == "Messinia" | admin_name == "Trikala" | /// 
	admin_name == "Viotia" | admin_name == "Zakynthos"  | ///
	admin_name == "Fthiotida")
drop if geolevel1 == .

tempfile Greece
save `Greece'

* Guatemala
better_reclink "Guatemala" `insample'

tempfile Guatemala
save `Guatemala'

* Haiti (unmatched in G et al.)
better_reclink "Haiti" `insample'

tempfile Haiti
save `Haiti'

* Honduras
better_reclink "Honduras" `insample'

tempfile Honduras
save `Honduras'

* India
better_reclink "India" `insample'

replace Uadmin_name = "Assam w/ Mizoram" if admin_name == "Mizoram"

tempfile India
save `India'

* Indonesia
better_reclink "Indonesia" `insample'

replace Uadmin_name = "W. Kalimantan" if admin_name == "Kalimantan Barat"
replace Uadmin_name = "S. Kalimantan" if admin_name == "Kalimantan Selatan"
replace Uadmin_name = "C. Kalimantan" if admin_name == "Kalimantan Tengah"
replace Uadmin_name = "E. Kalimantan" if admin_name == "Kalimantan Timur"

replace Uadmin_name = "W. Nusa Tenggara" if admin_name == "Nusa Tenggara Barat"
replace Uadmin_name = "E. Nusa Tenggara" if admin_name == "Nusa Tenggara Timur"

replace Uadmin_name = "C. Sulawesi" if admin_name == "Sulawesi Tengah"
replace Uadmin_name = "S.E. Sulawesi" if admin_name == "Sulawesi Tenggara"
replace Uadmin_name = "N. Sulawesi" if admin_name == "Gorontalo, Sulawesi Utara"

replace Uadmin_name = "W. Sumatra" if admin_name == "Sumatera Barat"

replace Uadmin_name = "Aceh" if admin_name == "Nanggroe Aceh Darussalam"

replace Uadmin_name = "C. Java" if admin_name == "Jawa Tengah"
replace Uadmin_name = "E. Java" if admin_name == "Jawa Timur"
replace Uadmin_name = "W. Java" if admin_name == "Banten, Jawa Barat"


replace Uadmin_name = "N. Sumatra" if admin_name == "Sumatera Utara"

drop if geolevel1 == .
duplicates drop Uadmin_name admin_name, force

tempfile Indonesia
save `Indonesia'

* Iran (unmatched in G et al.)
better_reclink "Iran" `insample'

tempfile Iran
save `Iran'

* Iraq (unmatched in G et al.)
better_reclink "Iraq" `insample'

tempfile Iraq
save `Iraq'

* Ireland
better_reclink "Ireland" `insample'

replace Uadmin_name = "IE0" // Ireland only has 1 NUTS1 region

drop if geolevel1 == .

tempfile Ireland
save `Ireland'

* Israel (Unmatched in G et al.)
better_reclink "Israel" `insample'

tempfile Israel
save `Israel'

* Italy
better_reclink "Italy" `insample'

replace Uadmin_name = "ITC" if inlist(admin_name, "Piemonte, Valle d'Aosta", "Lombardia", "Liguria")
replace Uadmin_name = "ITF" if inlist(admin_name, "Abruzzo", "Molise", "Campania", "Puglia", "Basilicata", "Calabria")
replace Uadmin_name = "ITG" if inlist(admin_name, "Sicilia", "Sardegna")
* note: Marche is in ITI. I am choosing to include it in ITH rather than leaving it unmatched because there are not NUTS regions left unmatched, and the downscaling system will thus assign in a GDP of ~0.
replace Uadmin_name = "ITH" if inlist(admin_name, "Trentino alto Adige", "Veneto", "Friuli Venezia Giulia", "Emilia Romagna, Marche")
replace Uadmin_name = "ITI" if inlist(admin_name, "Toscana", "Umbria", "Lazio")

drop if geolevel1 == .

tempfile Italy
save `Italy'

* Jamaica (unmatched in G et al.)
better_reclink "Jamaica" `insample'

tempfile Jamaica
save `Jamaica'

* Jordan (unmatched in G et al.)
better_reclink "Jordan" `insample'

replace Uadmin_name = "Maâan" if admin_name == "Ma'an"

drop if mi(geolevel1)

tempfile Jordan
save `Jordan'

* Kenya
better_reclink "Kenya" `insample'

replace Uadmin_name = "Northeast., East., Rift Valley" if admin_name == "Eastern"

tempfile Kenya
save `Kenya'

* Kyrgyz Republic (unmatched in G et al.)
better_reclink "Kyrghzstan" `insample'

replace country = "Kyrgyz Republic"

tempfile Kyrgyz Republic
save `Kyrgyz'

* Laos (unmatched in G et al.)
better_reclink "Lao People's Democratic Republic" `insample'

qui replace country = "Laos"

tempfile Laos
save `Laos'

* Lesotho
better_reclink "Lesotho" `insample'

replace Uadmin_name = "Leribe, Maseru, Mokhot., QN, TT" if inlist(admin_name, "Qacha's Nek", "Maseru", "Thaba-Tseka", "Mokhotlong")

tempfile Lesotho
save `Lesotho'

* Liberia (unmatched in G et al.)
better_reclink "Liberia" `insample'

tempfile Liberia
save `Liberia'

* Malawi (unmatched in G et al.)
better_reclink "Malawi" `insample'

tempfile Malawi
save `Malawi'

* Malaysia
better_reclink "Malaysia" `insample'

replace Uadmin_name = "Kedah and Perlis" if admin_name == "Perlis"

tempfile Malaysia
save `Malaysia'

* Mali (unmatched in G et al.)
better_reclink "Mali" `insample'

tempfile Mali
save `Mali'

* Mexico
better_reclink "Mexico" `insample'

tempfile Mexico
save `Mexico'

* Mongolia (unmatched in G et al.)
better_reclink "Mongolia" `insample'

replace Uadmin_name = "Tuv" if admin_name == "Tov"
replace Uadmin_name = "Umnugobi" if admin_name == "Omnogovi"
replace Uadmin_name = "Khubusgul" if admin_name == "Khovsgol"

drop if mi(geolevel1)

tempfile Mongolia
save `Mongolia'

* Morocco
better_reclink "Morocco" `insample'

replace Uadmin_name = "" if regexm(admin_name, "Tanger-T.+touan")
replace Uadmin_name = "Tansift" if admin_name == "Marrakech-Tensift-Al Haouz"
replace Uadmin_name = "Eastern" if admin_name == "Oriental"

drop if mi(geolevel1)

tempfile Morocco
save `Morocco'

* Mozambique
better_reclink "Mozambique" `insample'

tempfile Mozambique
save `Mozambique'

* Nepal
better_reclink "Nepal" `insample'

replace Uadmin_name = "Eastern" if inlist(admin_name, "Mechi", "Koshi", "Sagarmatha")
replace Uadmin_name = "Far-west" if inlist(admin_name, "Mahakali", "Seti")
replace Uadmin_name = "Mid-west" if inlist(admin_name, "Karnali", "Bheri", "Rapti")
replace Uadmin_name = "Western" if inlist(admin_name, "Dhawalagiri", "Gandaki", "Lumbini")
replace Uadmin_name = "Central" if inlist(admin_name, "Janakpur", "Bagmati", "Narayani")

drop if mi(geolevel1)

tempfile Nepal
save `Nepal'

* Nicaragua
better_reclink "Nicaragua" `insample'
 
replace Uadmin_name = "PacÃ­fico Norte" if inlist(admin_name, "Chinandega", "Estelí, León")
replace Uadmin_name = "PacÃ­fico Central" if inlist(admin_name, "Managua, Masaya", "Carazo", "Granada") 
replace Uadmin_name = "PacÃ­fico Sur" if admin_name == "Rivas"

drop if geolevel1 ==.

tempfile Nicaragua
save `Nicaragua'

* Nigeria
better_reclink "Nigeria" `insample'

replace Uadmin_name = "North East" if inlist(admin_name, "Adamawa", "Bauchi", "Borno", "Gombe", "Taraba", "Yobe")
replace Uadmin_name = "North West" if inlist(admin_name, "Jigawa", "Kaduna", "Kano", "Katsina", "Kebbi", "Sokoto", "Zamfara")
replace Uadmin_name = "South East" if inlist(admin_name, "Abia", "Anambra", "Ebonyi", "Enugu", "Imo")
replace Uadmin_name = "South West" if inlist(admin_name, "Ekiti", "Lagos", "Ogun", "Ondo", "Osun", "Oyo")

drop if mi(geolevel1)

tempfile Nigeria
save `Nigeria'

* Pakistan
better_reclink "Pakistan" `insample'

replace Uadmin_name = "NWFP" if admin_name == "North-West Frontier Province"

drop if mi(geolevel1)

tempfile Pakistan
save `Pakistan'

* Palestine (unmatched in G et al.)
better_reclink "Palestine" `insample'

tempfile Palestine
save `Palestine'

* Panama
better_reclink "Panama" `insample'

replace Uadmin_name = "ColÃ³n" if admin_name == "Colón, Comarca Kuna Yala (San Blas)"
replace Uadmin_name = "DariÃ©n" if admin_name == "Comarca Emberá, Darién"

gen Uadmin_name2 = ""
replace Uadmin_name2 = "ChiriquÃ­" if admin_name == "Bocas de Toro, Chiriquí, Comarca Ngäbe Buglé, Veraguas"

gen Uadmin_name3 = ""
replace Uadmin_name3 = "Veraguas" if admin_name == "Bocas de Toro, Chiriquí, Comarca Ngäbe Buglé, Veraguas"

drop if geolevel1 == .

tempfile Panama
save `Panama'

* Papua New Guinea (unmatched in G et al.)
better_reclink "Papua New Guinea" `insample'

tempfile Papua New Guinea
save `Papua New Guinea'

* Paraguay
better_reclink "Paraguay" `insample'

gen Uadmin_name2 = ""
replace Uadmin_name2 = "BoquerÃ³n" if admin_name == "Alto Paraguay, Boquerón, Presidente Hayes"

gen Uadmin_name3 = ""
replace Uadmin_name3 = "Presidente Hayes" if admin_name == "Alto Paraguay, Boquerón, Presidente Hayes"

replace Uadmin_name2 = "CanindeyÃº" if admin_name == "Caaguazú, Canindeyú, Alto Paraná"
replace Uadmin_name3 = "Alto ParanÃ¡" if admin_name == "Caaguazú, Canindeyú, Alto Paraná"

drop if mi(geolevel1)

tempfile Paraguay
save `Paraguay'

* Peru
better_reclink "Peru" `insample'

tempfile Peru
save `Peru'

* Philippines
better_reclink "Philippines" `insample'

sort admin_name

replace Uadmin_name = "Cagayan Valley, Cordillera, Illogos" if (admin_name==  "Abra" | ///
	admin_name == "Ifugao" | admin_name == "Ilocos Norte" | admin_name == "Ilocos Sur" | ///
	admin_name == "Kalinga-Apayao, Apayo, Kalinga" | admin_name == "La Union" ///
	| admin_name == "Mountain Province" | admin_name == "Nueva Vizcaya" ///
	| admin_name == "Pangasinan" | admin_name == "Quirino" | admin_name == "Cagayan, Batanes")


replace Uadmin_name = "Mindanao" if (admin_name == "Agusan del norte" | ///
	admin_name == "Agusan del sur" | admin_name == "Bukidnon" | ///
	admin_name == "Camiguin" | admin_name == "Cotabato (North Cotabato)" | ///
	admin_name == "Davao (Davao del Norte)" | admin_name == "Lanao del Norte" | ///
	admin_name == "Lanao del Sur" | admin_name == "Basilan, City Of Isabela" | ///
	admin_name == "Maguindanao, Cotabato City" | admin_name == "Misamis Occidental" ///
	| admin_name == "Misamis Oriental" | admin_name == "South Cotabato, Sarangani" ///
	| admin_name == "Sultan Kudarat" | admin_name == "Sulu"  /// 
	| admin_name == "Surigao Del Norte, Dinagat islands" | admin_name== "Surigao del Sur" ///
	| admin_name == "Tawi-Tawi" | admin_name == "Zamboanga Norte" ///
	| admin_name == "Zamboanga del Sur, Zamboanga Sibugay")


replace Uadmin_name = "Tagalog, Luzon, W. Visayas" if (admin_name == "Aklan" | /// 
	admin_name == "Albay" | admin_name == "Antique" | admin_name == "Aurora" | ///
	admin_name == "Bataan" | admin_name == "Batangas" | admin_name == "Benguet" | ///
	admin_name == "Bulacan" | admin_name == "Cavite" | admin_name == "Davao Oriental" | ///
	admin_name == "Davao del Sur" | admin_name == "Iloilo, Guimaras" | admin_name == "Isabela" /// 
	| admin_name == "Laguna" | admin_name == "Marinduque" | admin_name == "Negros Occidental" ///
	| admin_name == "Nueva Ecija" | admin_name == "Occidental Mindoro" | admin_name == "Oriental Mindoro" ///
	| admin_name == "Palawan" | admin_name == "Quezon" | admin_name == "Rizal" ///
	| admin_name == "Romblon" | admin_name == "Tarlac" | admin_name == "Zambales" | ///
	admin_name == "Pampanga")


replace Uadmin_name = "Central Visayas" if (admin_name == "Bohol" | admin_name == "Cebu" | ///
	admin_name ==  "Negros Oriental" | admin_name == "Siquijor"   ///
	)

replace Uadmin_name = "Bicol Region" if (admin_name == "Camarines Sur" | ///
	admin_name == "Camarines norte" | admin_name == "Capiz" | admin_name == "Catanduanes" /// 
	| admin_name == "Masbate" | admin_name == "Sorsogon" )

replace Uadmin_name = "Eastern Visayas" if (admin_name == "Eastern Samar" | /// 
	admin_name == "Leyte, Biliran" | admin_name == "Northern Samar" | ///
	admin_name == "Samar (Western Samar)" | admin_name == "Southern Leyte")

replace Uadmin_name = "Metro Manila" if (admin_name == "Manila" | admin_name == "Manila Metro, 2nd District" ///
	| admin_name == "Manila Metro, 3rd District" | admin_name == "Manila Metro, 4th District")

drop if geolevel1 == .

tempfile Philippines
save `Philippines'

* Poland
better_reclink "Poland" `insample'

replace Uadmin_name = "PL1" if regexm(admin_name, ".+dzkie")
replace Uadmin_name = "PL1" if admin_name == "Mazowieckie"

replace Uadmin_name = "PL2" if regexm(admin_name, "Ma.+opolskie")
replace Uadmin_name = "PL2" if regexm(admin_name, "Śl.+skie")

replace Uadmin_name = "PL3" if inlist(admin_name, "Lubelskie", "Podkarpackie", "Podlaskie")
replace Uadmin_name = "PL3" if regexm(admin_name, ".+wi.+tokrzyskie")

replace Uadmin_name = "PL4" if inlist(admin_name, "Wielkopolskie", "Zachodniopomorskie", "Lubuskie")

replace Uadmin_name = "PL5" if regexm(admin_name, "Dolno.+l.+skie")
replace Uadmin_name = "PL5" if admin_name == "Opolskie"

replace Uadmin_name = "PL6" if inlist(admin_name, "Kujawsko pomorskie", "Pomorskie")
replace Uadmin_name = "PL6" if regexm(admin_name, "Warmi.+sko mazurskie")

drop if geolevel1 == .

tempfile Poland
save `Poland'

* Portugal
better_reclink "Portugal" `insample'

* Mainland Portugal	Norte, Algarve, Centro, Lisbon, Alentejo
replace Uadmin_name = "PT1" if (admin_name == "Algarve" | ///
	admin_name == "Alto Trás-os-Montes" | admin_name == "Ave" | ///
	admin_name == "Baixo Mondego" | admin_name == "Baixo Vouga" | ///
	admin_name == "Cávado" | admin_name == "Douro" | ///
	admin_name == "Dão-Lafões" | admin_name == "Entre Douro e Vouga" | ///
	admin_name == "Grande Lisboa" | admin_name == "Grande Porto" | ///
	admin_name == "Lezíria do Tejo" | admin_name == "Minho-Lima" | ///
	admin_name == "Médio Tejo" | admin_name == "Oeste" | ///
	admin_name == "Other Alentejo" | admin_name == "Other Center" ///
	| admin_name == "Península de Setúbal" | admin_name == "Pinhal Litoral" | ///
	admin_name == "Tamega")

* Azores
replace Uadmin_name = "PT2" if (admin_name == "Região Autónoma dos Açores")

* Madeira
replace Uadmin_name = "PT3" if (admin_name == "Região Autónoma da Madeira")

drop if geolevel1 == .

tempfile Portugal
save `Portugal'

* Puerto Rico (unmatched in G et al.)
better_reclink "Puerto Rico" `insample'

tempfile Puerto Rico
save `Puerto Rico'

* Romania
better_reclink "Romania" `insample'

* Nord-Vest, Centru
replace Uadmin_name = "RO1" if (admin_name == "Alba" | ///
	admin_name == "Bihor" | admin_name == "Bistrita Nasaud" | ///
	admin_name == "Brasov" | admin_name == "Cluj" | ///
	admin_name == "Covasna" | admin_name == "Harghita" | ///
	admin_name == "Maramures" | admin_name == "Mures" | ///
	admin_name == "Salaj" | admin_name == "Satu Mare" | ///
	admin_name == "Sibiu" )

* Nord-Est, Sud-Est
replace Uadmin_name = "RO2" if (admin_name == "Bacau" | ///
	admin_name == "Botosani" | admin_name == "Braila" | ///
	admin_name == "Buzau" | admin_name == "Constanta" | ///
	admin_name == "Galati" | admin_name == "Lasi" | ///
	admin_name == "Neamt" | admin_name == "Suceava" | ///
	admin_name == "Tulcea" | admin_name == "Vaslui" | ///
	admin_name == "Vrancea" )

* Sud – Muntenia, București – Ilfov
replace Uadmin_name = "RO3" if (admin_name == "Arges" | ///
	admin_name == "Bucharest Sector 1 to 6" | ///
	admin_name == "Calarasi, Giurgiu, Ialomita, Ilfov" | ///
	admin_name == "Dimbovita" | admin_name == "Prahova" | ///
	admin_name == "Teleorman" )

* Sud-Vest Oltenia, Vest
replace Uadmin_name = "RO4" if (admin_name == "Arad" | ///
	admin_name == "Caras Severin" | admin_name == "Dolj" | ///
	admin_name == "Gorj" | admin_name == "Hunedoara" | ///
	admin_name == "Mehedinti" | admin_name == "Olt" | ///
	admin_name == "Timis" | admin_name == "Vâlcea" )

drop if geolevel1 == .

tempfile Romania
save `Romania'

* Rwanda (unmatched in G et al.)
better_reclink "Rwanda" `insample'

tempfile Rwanda
save `Rwanda'

* Saint Lucia (unmatched in G et al.)
better_reclink "Saint Lucia" `insample'

tempfile Saint Lucia
save `Saint Lucia'

* Senegal (unmatched in G et al.)
better_reclink "Senegal" `insample'

tempfile Senegal
save `Senegal'

* Sierra Leone (unmatched in G et al.)
better_reclink "Sierra Leone" `insample'

tempfile Sierra Leone
save `Sierra Leone'

* Slovenia
better_reclink  "Slovenia" `insample'

replace Uadmin_name = "SI0"

drop if mi(geolevel1)

tempfile Slovenia
save `Slovenia'

* South Africa
better_reclink "South Africa" `insample'

replace Uadmin_name = "Transvaal" if admin_name == "Gauteng, Limpopo, Mpumalanga, North West, Northern Cape"

drop if mi(geolevel1)

tempfile ZAF
save `ZAF'

* South Sudan (unmatched in G et al.)
better_reclink "South Sudan" `insample'

tempfile South Sudan
save `South Sudan'

* Spain
better_reclink "Spain" `insample'

sort admin_name
* North West: Galicia, Asturias, Cantabria
replace Uadmin_name = "ES1" if (admin_name == "Cantabria" | ///
	admin_name == "Galicia" | admin_name == "Principado de Asturias")

* North East: Basque Community, Navarre, La Rioja, Aragon
replace Uadmin_name = "ES2" if (admin_name == "Aragón" | ///
	admin_name == "Comunidad Foral de Navarra" | ///
	admin_name == "La Rioja" | admin_name == "País Vasco" | ///
	)

* Community of Madrid:	Community of Madrid
replace Uadmin_name = "ES3" if (admin_name == "Comunidad de Madrid")

* Centre: Castile and León, Castile-La Mancha, Extremadura
replace Uadmin_name = "ES4" if (admin_name == "Castilla y León" | ///
	admin_name == "Castilla-La Mancha" | ///
	admin_name == "Extremadura" )


* East:	Catalonia, Valencian Community, Balearic Islands
replace Uadmin_name = "ES5" if (admin_name == "Cataluña" | ///
	admin_name == "Illes Balears" | admin_name == "Comunidad Valenciana")

* South: Andalusia, Region of Murcia, Ceuta, Melilla
replace Uadmin_name = "ES6" if (admin_name == "Andalucía" | ///
	admin_name == "Ciudad Autónoma de Ceuta" | admin_name == "Ciudad Autónoma de Melilla" | ///
	admin_name == "Región de Murcia")

* Canary Islands	Canary Islands
replace Uadmin_name = "ES7" if (admin_name == "Canarias")

drop if geolevel1 == .

tempfile Spain
save `Spain'

* Sudan (unmatched in G et al.)
better_reclink "Sudan" `insample'

tempfile Sudan
save `Sudan'

* Switzerland
better_reclink "Switzerland" `insample'

replace Uadmin_name = "Appenzell A&I Rh." if admin_name == "Outer and Inner Rhodes"
replace Uadmin_name = "Tessin" if admin_name == "Ticino"
replace Uadmin_name = "Neuenburg" if admin_name == "Neuchatel"
replace Uadmin_name = "Waadt" if admin_name == "Vaud"
replace Uadmin_name = "Wallis" if admin_name == "Valais"
replace Uadmin_name = "Bern w/ Jura" if admin_name == "Jura"

drop if mi(geolevel1)

tempfile Switzerland
save `Switzerland'

* Tanzania
better_reclink "Tanzania" `insample'

replace Uadmin_name = "Kagera" if admin_name == "Geita, Kagera, Mwanza, Shinyanga, Simiyu"

gen Uadmin_name2 = ""
replace Uadmin_name2 = "Mwanza" if admin_name == "Geita, Kagera, Mwanza, Shinyanga, Simiyu"

gen Uadmin_name3 = ""
replace Uadmin_name3 = "Shinyanga" if admin_name == "Geita, Kagera, Mwanza, Shinyanga, Simiyu"

drop if mi(geolevel1)

tempfile Tanzania
save `Tanzania'

* Thailand
better_reclink "Thailand" `insample'
gen Uadmin_name2 = ""
replace Uadmin_name2 = "Chumphon" if admin_name == "Ranong, Chumphon"
replace Uadmin_name2 = "Krabi" if admin_name == "Krabi, Surat Thani"
replace Uadmin_name2 = "Phayao" if admin_name == "Phayao, Chiang Rai"
replace Uadmin_name2 = "Yasothon" if admin_name == "Ubon Ratchathani, Yasothon, Amnat Charoen"

drop if geolevel1 == .

tempfile Thailand
save `Thailand'

* Togo (unmatched in G et al.)
better_reclink "Togo" `insample'

tempfile Togo
save `Togo'

* trinidad and tobago (unmatched in G et al.)
better_reclink "Trinidad and Tobago" `insample'

tempfile Trinidad and Tobago
save `Trinidad and Tobago'

* Turkey (unmatched in G et al.)
better_reclink "Turkey" `insample'

replace Uadmin_name = "Bolu and Duzce" if regexm(admin_name, "D.+zce, Bolu")
replace Uadmin_name = "Gumushane" if regexm(admin_name, "G.+m.+shane, Bayburt")

drop if mi(geolevel1)

tempfile Turkey
save `Turkey'

* Uganda (unmatched in G et al.)
better_reclink "Uganda" `insample'

tempfile Uganda
save `Uganda'

* United Kingdom
better_reclink "United Kingdom" `insample'

replace Uadmin_name = "UKC" if admin_name == "North East"
replace Uadmin_name = "UKD" if admin_name == "North West"
replace Uadmin_name = "UKE" if admin_name == "Yorkshire and the Humber"
replace Uadmin_name = "UKF" if admin_name == "East Midlands"
replace Uadmin_name = "UKG" if admin_name == "West Midlands"
replace Uadmin_name = "UKH" if admin_name == "East of England"
replace Uadmin_name = "UKI" if admin_name == "London"
replace Uadmin_name = "UKJ" if admin_name == "South East"
replace Uadmin_name = "UKK" if admin_name == "South West"
replace Uadmin_name = "UKL" if admin_name == "Wales"
replace Uadmin_name = "UKM" if admin_name == "Scotland"
replace Uadmin_name = "UKN" if admin_name == "Northern Ireland"

drop if mi(geolevel1)

tempfile United Kingdom
save `United Kingdom'

* United States
better_reclink "United States" `insample'

tempfile USA
save `USA'

* Uruguay
better_reclink "Uruguay" `insample'

tempfile Uruguay
save `Uruguay'

* Venezuela
better_reclink "Venezuela" `insample'

replace Uadmin_name = "Estado FalcÃ³n" if regexm(admin_name, "Falc.+n")
replace Uadmin_name = "Estado Lara" if admin_name == "Lara"
replace Uadmin_name = "Estado Nueva Esparta" if admin_name == "Nueva Esparta, Federal Dependencies"

gen Uadmin_name2 = ""
replace Uadmin_name2 = "Estado MÃ©rida" if regexm(admin_name, "Barinas, M.+rida")

drop if mi(geolevel1)

tempfile Venezuela
save `Venezuela'

* Vietnam
better_reclink "Vietnam" `insample'

replace Uadmin_name = "Hanoi / Ha Tay" if admin_name == "ha noi, Hoa Binh, Phu Tho, Vinh Phuc"

gen Uadmin_name2 = ""
replace Uadmin_name2 = "Son La" if admin_name == "Dien Bien, Lai Chau, Lao Cai, Son La, Yen Bai"
replace Uadmin_name2 = "Cao Bang" if admin_name == "Bac Kan, Cao Bang, Thai Nguyen"

drop if mi(geolevel1)

tempfile Vietnam
save `Vietnam'

* Zambia
better_reclink "Zambia" `insample'

tempfile Zambia
save `Zambia'

* Guinea (unmatched in G et al.)
* Note this is done last because doing it before Papua New Guinea leads us to lose the tempfile.
better_reclink "Guinea" `insample'

tempfile Guinea
save `Guinea'

*****************************
* 3. Merge together results *
*****************************

use `countnames', clear
levelsof country, local(countries)

use `Zimbabwe', clear
drop if _n > 0

tempfile all
save `all'

* expand and append all countries
foreach c in `countries' {
	di "`c'"
	if "`c'" == "South Africa" {
		loc c ZAF
	}
	else if "`c'" == "United States" {
		loc c USA
	}
	else if "`c'" == "Kyrgyz Republic" {
		loc c Kyrgyz
	}
	cap confirm file ``c''
	if _rc != 0 {
		di "----skipping `c' (no tempfile)----"
	}
	else {
		qui insheet using "$lab/1_preparation/employment_shares/data/required_clim_data.csv", clear
		
		* max of the income data is 2014, so cut off here
		qui replace required_end = 2014 if required_end > 2014

		qui merge 1:m country using ``c'', keep(3) nogen

		qui gen yearspan = required_end - required_start
		qui sum yearspan, meanonly
		local range = `r(min)' + 1
		qui expand `range', gen(dup)
		sort admin_name
		bysort admin_name: gen counter = _n
		qui gen year = required_start + counter - 1

		qui drop required* dup yearspan counter
		order country year

		qui append using `all'

		qui save `all', replace
	}
}

* Clean up
* Get rid of variables we don't need
drop score_getal dup_getal getal_id Ucountry

* drop geolev1s that indicate missings
drop if ((mod(geolevel1, 100) == 99 | mod(geolevel1, 100) == 98 | mod(geolevel1, 100) == 88) & geolevel1 != 192099)

* Return to country names used in IPUMS data
/* replace country = "Laos" if country == "Lao People's Democratic Republic"
replace country = "Kyrgyz Republic" if country == "Kyrghzstan" */

* Loop over the different potential getal additional names, merging in the relevant income information
replace Uadmin_name = "missing" if Uadmin_name == ""
rename Uadmin_name Uadmin_name1

forvalues j  = 1/7 {
	preserve
		use "$mig/internal/Data/Intermediate/income/adm1_cleaning/pwt_income_adm1.dta", clear
		rename (region *gdppc*) (Uadmin_name`j' *gdppc*_`j')

		replace country = "Egypt" if country == "Egypt, Arab Rep."
		replace country = "Iran" if country == "Iran (Islamic Republic of)"
		replace country = "Kyrgyz Republic" if country == "Kyrgyzstan"
		replace country = "Laos" if country == "Lao People's DR"
		replace country = "Palestine" if country == "State of Palestine"
		replace country = "Sudan" if country == "Sudan (Former)"
		replace country = "Tanzania" if country == "U.R. of Tanzania: Mainland"

		keep country year Uadmin_name`j' *gdp* 

		tempfile pwt 
		save `pwt', replace 
	restore

	merge m:1 country Uadmin_name`j' year using `pwt', gen(z`j')
	keep if z`j' != 2
	drop z`j'
	rename Uadmin_name`j' getal_admin_name`j'
}

pause

* merge in pop data 
tempfile main
save `main'

import delim using "$lab/1_preparation/employment_shares/data/adm1_empshares.csv", clear
keep year geolev1 country_str geolev1_pop
rename geolev1 geolevel1
rename country_str country
drop if ((mod(geolevel1, 100) == 99 | mod(geolevel1, 100) == 98 | mod(geolevel1, 100) == 88) & geolevel1 != 192099)
drop if year > 2014

merge 1:1 geolevel1 year country using `main', assert(2 3) nogen

pause

* Germany is split into East and West in IPUMS, but not in PWT. I think this means we need to drop it.
drop if country == "Germany"

drop if mi(geolev1_pop)
drop max_year min_year cntry_code bpl_code

export delimited using "$lab/1_preparation/employment_shares/data/income/income_pop_merged.csv", replace
