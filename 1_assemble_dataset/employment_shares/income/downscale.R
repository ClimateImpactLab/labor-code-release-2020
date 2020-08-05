# Downscale PWT according to shares in Gennaioli et al. 
# Process: outlined in this note: https://www.overleaf.com/2269162439pjtsymvjtdjq.
# See also: https://gitlab.com/ClimateImpactLab/Impacts/post-projection-tools/tree/master/income

# Author: Simon Greenhill, sgreenhill@uchicago.edu
# Created: 9/18/2019

# Set up
remove(list=ls())
library(tidyverse)
library(tidyr)
library(glue)
library(haven)
library(stringr)
library(cilpath.r)

cilpath.r:::cilpath()
lab = glue("{DB}/Global ACP/labor/")
code = glue("{REPO}/post-projection-tools/income/")
source(glue("{code}/downscale_function.R"))

d = read.csv(glue("{lab}/1_preparation/employment_shares/data/income/income_pop_merged.csv"))

# reshape and collapse 
long = d %>% 
	tidyr::gather(key, value, -year, -country, -geolevel1, -geolev1_pop, -admin_name) %>%
	tidyr::extract(key, c("field", "number"), "(.+\\D)(\\d$)") %>% 
	tidyr::spread(field, value) %>%
	rename_at(.vars = vars(ends_with("_")),
            .funs = list(~ gsub("_$", "", .)))

col = long %>%
	dplyr::select(-contains("rescaled"), -contains("13br"), -number) %>%
	mutate_at(
		c("gdppc_adm0_infill", "gdppc_adm0_PWT", "gdppc_adm1_infill"), 
		as.numeric) %>%
	mutate(m_count = ifelse(is.na(gdppc_adm1_infill), 0, 1)) %>% 
	group_by(year, country, geolevel1) %>%
	summarize(
		pop = mean(geolev1_pop, na.rm = TRUE), 
		gdppc_adm0_infill = mean(gdppc_adm0_infill, na.rm = TRUE), 
		gdppc_adm0_PWT = mean(gdppc_adm0_PWT, na.rm = TRUE),
		gdppc_adm1_infill = sum(gdppc_adm1_infill, na.rm = TRUE), # note there is an (obviously incorrect) assumption here--that any getal regions mapped to multiple IPUMS regions have equal population		
		missing = max(ifelse(getal_admin_name == "missing", 1, 0)),
		m_count = sum(m_count)
		)

# get list of countries that are entirely unmatched in G et al.
countries = col %>% 
	group_by(country) %>%
	summarize(missings = mean(missing)) %>%
	filter(missings == 1) %>%
	pull(country)

# get country level populations and merge in
country_pop = d %>% 
	dplyr::select(country, geolevel1, geolev1_pop, year) %>%
	distinct() %>%
	group_by(country, year) %>%
	summarize(adm0_pop = sum(geolev1_pop, na.rm=TRUE))

prepped = col %>%
	left_join(country_pop, by=c("country", "year"))

#######################
# perform downscaling #
#######################
downscaled = downscale(ds=prepped, cntry_id=quo(country)) %>%
	mutate(
		gdppc_adm1_PWT_downscaled = ifelse(
			geolevel1 %in% c(356026, 356031) |
				country %in% countries |
				(country == "vietnam" & year < 1990),
			gdppc_adm0_PWT,
			gdppc_adm1_PWT_downscaled
			)
		)

# weirdness: some countries have negative downscaled values when they didn't in migration. 
# need to figure out why this is? (Canada and Honduras)
final = downscaled %>% 
	dplyr::select(year, country, geolevel1, gdppc_adm0_PWT, gdp_adm0_PWT, gdppc_adm1_PWT_downscaled, pop)

write_csv(final, path = glue("{lab}/1_preparation/employment_shares/data/income/income_downscaled.csv"))
