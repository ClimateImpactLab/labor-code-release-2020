# Downscale PWT according to shares in Gennaioli et al. 
# Process outlined in this note: https://www.overleaf.com/2269162439pjtsymvjtdjq.
# See also: https://gitlab.com/ClimateImpactLab/Impacts/post-projection-tools/tree/master/income

# Author: Simon Greenhill, sgreenhill@uchicago.edu
# Created: 10/3/2019

# Set up
remove(list=ls())
library(tidyverse)
library(tidyr)
library(glue)
library(haven)
library(stringr)
library(data.table)

cilpath.r:::cilpath()
lab = glue("{DB}/Global ACP/labor/")
mig = glue("{DB}/Wilkes_InternalMigrationGlobal/internal/Data/Intermediate/population/")
code = glue("{REPO}/post-projection-tools/income/")
source(glue("{code}/downscale_function.R"))

# need to think about what to do about places that have 2 population matches and 2 corresponding gdps.
# want to be able to use gdp for these places
d = fread(glue("{lab}/1_preparation/covariates/income/income_pop_merged.csv")) %>%
	data.frame() %>%
	filter(!(year < 1990 & iso == "GBR")) %>% # filter out pre-1990 UK data, because we do not have adm1 level population for it
	mutate_at(vars(-iso, -contains("admin_name"), -contains("adm_name")),
		as.numeric) %>%
	mutate( # combine places that have matched pop and gdp
		double_match = ifelse(!is.na(gdppc_adm1_infill_2) & !is.na(pop_tot2),
			1, 0),
		half_match = ifelse((!is.na(gdppc_adm1_infill_2) & is.na(pop_tot2))| (!is.na(pop_tot2) & is.na(gdppc_adm1_infill_2)),
			1, 0),
		gdppc_adm1_infill_1 = ifelse(double_match == 1, (gdppc_adm1_infill_1*pop_tot1 + gdppc_adm1_infill_2*pop_tot2)/(pop_tot1 + pop_tot2), gdppc_adm1_infill_1),
		population1 = ifelse(double_match == 1, pop_tot1 + pop_tot2, pop_tot1),
		gdppc_adm1_infill_2 = ifelse(double_match == 1, NA, gdppc_adm1_2),
		population2  = ifelse(double_match == 1, NA, pop_tot2),
		getal_admin_name1 = ifelse(double_match == 1, 
			glue("{getal_admin_name1}, {getal_admin_name2}"), 
			ifelse(half_match == 1, "missing", getal_admin_name1)),
		getal_admin_name2 = ifelse(double_match == 1, NA, 
			ifelse(half_match == 1, NA, getal_admin_name2))
		) %>%
	dplyr::select(-double_match)

# reshape and collapse 
long = d %>%
	tidyr::gather(key, value, -year, -iso, -location_id1, -admin_name, -match_id) %>%
	tidyr::extract(key, c("field", "number"), "(.+\\D)(\\d$)") %>% 
	tidyr::spread(field, value) %>%
	rename_at(.vars = vars(ends_with("_")),
            .funs = list(~ gsub("_$", "", .))) %>%
	dplyr::select(-number)

col = long %>%
	filter(!is.na(getal_admin_name) & !is.na(admin_name)) %>%
	mutate_at(vars(population, gdppc_adm0_infill, gdppc_adm1_infill, gdppc_adm0_PWT),
		as.numeric) %>%
	# mutate(m_count = ifelse(is.na(gdppc_adm1_infill), 0, 1)) %>%
	group_by(year, iso, getal_admin_name) %>%
	summarize(
		pop = mean(population, na.rm = TRUE), 
		gdppc_adm0_infill = mean(gdppc_adm0_infill, na.rm = TRUE), 
		gdppc_adm0_PWT = mean(gdppc_adm0_PWT, na.rm = TRUE),
		gdppc_adm1_infill = mean(gdppc_adm1_infill, na.rm = TRUE),
		missing = max(ifelse(getal_admin_name == "missing" | admin_name == "missing" | is.na(pop), 1, 0), na.rm=TRUE),
		) %>%
	# unique() %>%
	# summarize()
	ungroup() %>%
	data.frame() %>%
	mutate(m_count = 1) # we don't have problematic m:1 gennaioli-labor matches in this dataset, so we don't have to worry about this

# get country level populations and merge in
# use World Bank data for this, as our data are not comprehensive within a country
country_pop = read_csv(glue("{mig}/world_bank_pop_data.csv"), skip=4) %>%
	data.frame() %>%
	dplyr::select(-Country.Name, -Indicator.Name, -Indicator.Code, -X64) %>%
	rename(iso = Country.Code) %>%
	gather(key = year, value=population, -iso) %>%
	mutate(year = as.numeric(substr(year, 2, 5))) %>%
	rename(adm0_pop = population)

# get crosswalk between getal admin names and location_id1
cw = long %>% 
	dplyr::select(iso, location_id1, getal_admin_name) %>%
	filter(!is.na(getal_admin_name) & !is.na(location_id1)) %>%
	unique()

# perform the downscaling
prepped = col %>%
	left_join(country_pop, by=c("iso", "year")) 

downscaled = downscale(ds=prepped, cntry_id=quo(iso)) %>%
	right_join(cw, by=c("iso", "getal_admin_name")) %>%
	dplyr::select(year, iso, location_id1, getal_admin_name, gdppc_adm0_PWT, gdppc_adm1_PWT_downscaled, pop, adm0_pop) %>%
	dplyr::filter(getal_admin_name != "")

write_csv(downscaled, glue("{lab}/1_preparation/covariates/income/income_downscaled.csv"))