# Prepare code release covariates data
# Note - this code should be run from the risingverse (python 3)

# This code moves some of our projection results from our usual location on our servers 
# and Dropbox/Synology to the code release data storage 

rm(list = ls())
library(readr)
library(dplyr)
library(reticulate)
library(haven)
library(tidyr)
cilpath.r:::cilpath()


setwd(paste0(REPO,"/labor-code-release-2020/"))

output = '/shares/gcp/estimation/labor/code_release_int_data/projection_outputs/covariates/'


# Source a python code that lets us load SSP data directly from the SSPs
# Make sure you are in the risingverse conda environment for this... 
projection.packages <- paste0(REPO,"/labor-code-release-2020/3_projection/packages_programs_inputs/")
source_python(paste0(projection.packages, "future_gdp_pop_data.py"))

pop = get_pop() 

# Get population and gdp values: 
inf = paste0("/mnt/Global_ACP/MORTALITY", 
	"/Replication_2018/3_Output/7_valuation/1_values/adjustments/vsl_adjustments.dta")
con_df = read_dta(inf) 
conversion_value = con_df$inf_adj[1]

############################################################
# 5 Get data needed for income decile plot 

# 2012
gdppc = get_gdppc_all_regions('high', 'SSP3') %>%
	mutate(gdppc = gdppc * conversion_value) 

df = gdppc %>% 
	dplyr::filter(year == 2012)

# Get 2012 population projections
pop12 = pop %>% 
	dplyr::filter(ssp == "SSP3") %>%
	dplyr::filter(year == 2010) %>% 
	dplyr::select(region, pop)

df = left_join(df, pop12, by = "region") %>% 
	dplyr::select(region, year, gdppc, pop)

write_csv(df, paste0(output,
	'SSP3-high-IR_level-gdppc-pop-2012.csv'))


# 2099

# Population values are every 5 years. We use flat interpolation (a step function)
# in between. So the 2099 population is assigned to the value we have in 2095. 

pop99 = pop %>% 
	dplyr::filter(ssp == "SSP3") %>%
	dplyr::filter(year == 2095) %>% 
	dplyr::select(region, pop) %>%
	rename(pop99 = pop)

gdppc99 = gdppc %>% 
	dplyr::filter(year == 2099) %>%
	rename(gdppc99 = gdppc)

covs = left_join(pop99, gdppc99, by = "region") %>%
	dplyr::select(region, pop99, gdppc99) %>%
	mutate(gdp99 = gdppc99 *pop99)

write_csv(covs, paste0(output, 
	'SSP3-high-IR_level-gdppc_pop-2099.csv'))


