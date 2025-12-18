#==============================================================================#
# Combine Mortality Age Groups
#
# Author: Elliot Grenier (egrenier@uchicago.edu)
# Date created: 4 February 2025
# Last modified: 4 February 2025
#
# This script combines all mortality age groups by population share for a given scenario.
# 
# To run: change scenario and run
#==============================================================================#

# Combine labor sectors
library(data.table)
library(dplyr)
library(tidyr)
library(glue)

# 0. Paths and globals ----
source('/project/cil/home_dirs/egrenier/repos/regional-scc/utils/paths.R')

# Change scenario here
gcm = 'CCSM4'
rcp = 'rcp45'
ssp = 'SSP2'
iam = 'low'
year = 2099

# 1. Load in data ----
popwt = fread(glue('{DB}/deltabeta/input/covariates/econ_clim-{gcm}-{rcp}-{ssp}-{iam}.csv'))
popwt[year == !!year, .(region, share_young, share_older, share_oldest)]

# Define age groups and get all impacts
age_group = c("young", "older", "oldest")

# Get impacts for all age groups and bind rows together
impact = data.frame()
for (age in age_group){
  
  df = fread(glue("{DB}/deltabeta/output/mortality/response-{age}/{gcm}-{rcp}-{ssp}-{iam}-delta_beta-all_regions-{year}-mortality-{age}-rebased.csv")) %>% mutate(agegroup = age)
  
  impact = rbind(impact, df)
  
  rm(df)
}

# Pivot wider and join with age group weights
# NOTE: Don't be worried about NA values. These are in regions with 0 pop. We do not plot these.
#       In regional_scc/0_programs/utils.R a function exists which contains all of these regions
impact = impact %>% pivot_wider(names_from = agegroup, values_from = effect_fa)
final = left_join(impact, popwt) %>% mutate(effect_fa = young*young_share + older*older_share + oldest*oldest_share) %>% select(hierid, bin, effect_fa)

# Save
dir.create(glue("{DB}/deltabeta/output/mortality/response-combined/"))
write.csv(final, glue("{DB}/deltabeta/output/mortality/response-combined/{gcm}-{rcp}-{ssp}-{iam}-delta_beta-all_regions-{year}-mortality-combined-rebased.csv"))
  