#==============================================================================#
# Combine Labor Sectors

# Author: Elliot Grenier (egrenier@uchicago.edu)
# Date created: 4 February 2025
# Last modified: 4 February 2025

# This script combines high and low worker risk sectors using high risk worker
# shares generated in the projection system.
# 
# To run: change scenario and run
#==============================================================================#

# Combine labor sectors
library(data.table)
library(dplyr)
library(stringr)
library(glue)

# Paths and globals
source('/project/cil/home_dirs/egrenier/repos/regional_scc/0_programs/paths.R')

# Change scenario here
gcm = 'CCSM4'
rcp = 'rcp85'
ssp = 'SSP3'
iam = 'low'
year = 2099

# Load in data
alpha = fread(glue("{DB}/deltabeta/input/empshare/empshare_{gcm}-{rcp}-{ssp}-{iam}.csv")) %>% filter(year == !!year) %>% select(-year)

# Get impacts for both sectors
beta_low = fread(glue("{DB}/deltabeta/output/labor/response-low/{gcm}-{rcp}-{ssp}-{iam}-delta_beta-all_regions-{year}-labor-low-rebased.csv")) # note to change year if not doing 2099
beta_high = fread(glue("{DB}/deltabeta/output/labor/response-high/{gcm}-{rcp}-{ssp}-{iam}-delta_beta-all_regions-{year}-labor-high-rebased.csv"))

# Join high and low sector impacts and high risk employment shares
beta = left_join(beta_high, beta_low, join_by('hierid', 'bin')) %>%  rename_with(~ str_replace(.x, "\\.x$", "_high") %>% str_replace("\\.y$", "_low")) %>% select(-sector_high, -sector_low)
beta = left_join(beta, alpha)

# Calculate final effect
final = beta %>%
  mutate(effect_fa = (highriskshare_FA*effect_y_rb_high + (1-highriskshare_FA)*effect_y_rb_low) - (highriskshare_IA*effect_by_rb_high + (1-highriskshare_IA)*effect_by_rb_low)) %>%
  #mutate(effect_fa_alt = highriskshare_FA*effect_fa_high + (1-highriskshare_FA)*effect_fa_low + (highriskshare_FA - highriskshare_IA)*(effect_by_rb_high - effect_by_rb_low)) %>%
  select(hierid, bin, effect_fa) #, effect_fa_alt)

df = final %>% mutate(day = effect_fa/365)
# Save out data
dir.create(paste0(DB, "/deltabeta/output/labor/response-combined/"))
write.csv(final, file = glue("{DB}/deltabeta/output/labor/response-combined/{gcm}-{rcp}-{ssp}-{iam}-delta_beta-all_regions-{year}-labor-combined-rebased.csv"), row.names=FALSE)
