
rm(list=ls()) # to clear workspace

library(tidyverse)
library(glue)
library(cilpath.r)
library(lfe)
library(sf)
library(rgdal)
library(testthat)
library(grid)
library(gridExtra)
library(numbers)

lab = glue("/shares/gcp/outputs/labor/impacts-woodwork")
dir = glue("uninteracted_splines_27_37_39_by_risk_empshare_noFE_YearlyAverageDay/rcp85/CCSM4/high/SSP3/csv")
out = glue("/mnt/CIL_labor/3_projection/impact_checks")

c_riskshare = read_csv(glue("{lab}/main_model_flat_edges_single_copy/{dir}/labor-climtasmaxclip-clip.csv")) %>% 
	rename(clipped = value) %>%
	filter(year == 2099)

uc_riskshare = read_csv(glue("{lab}/test_rcc_copy1/{dir}/uninteracted_main_model-clip.csv")) %>% 
	rename(unclipped = value)%>%
	filter(year == 2099)

riskshare = c_riskshare %>%
	left_join(uc_riskshare, by= "region") %>% 
	mutate (value = clipped - unclipped) %>% 
	data.frame() %>%
  select(region, year.x, value) %>%
  rename(year = year.x) %>%
  write_csv(glue("{out}/riskshare.csv"))

# checking mean of difference by country
 riskshare %>% 
    group_by(gr= substr(region, 1, 3)) %>%
    summarise(mean= mean(value)) %>% 
    print(n = 300)


c_impacts = read_csv(glue("{lab}/main_model_flat_edges_single_copy/{dir}/labor-climtasmaxclip-rebased_new.csv")) %>% 
	rename(clipped = value)%>%
	filter(year == 2099)

uc_impacts = read_csv(glue("{lab}/test_rcc_copy1/{dir}/uninteracted_main_model-rebased_new.csv")) %>% 
	rename(unclipped = value)%>%
	filter(year == 2099)

impacts = c_impacts %>%
	left_join(uc_impacts, by= "region") %>% 
	mutate (value = clipped - unclipped) %>%
	data.frame()%>%
  select(region, year.x, value) %>%
  rename(year = year.x) %>%
  write_csv(glue("{out}/impacts.csv"))

# checking mean of difference by country
 impacts %>% 
    group_by(gr= substr(region, 1, 3)) %>%
    summarise(mean= mean(value)) %>% 
    print(n = 300)
