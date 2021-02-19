
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
out = glue("/mnt/CIL_labor/3_projection/impact_checks/clipping_lrclim")


# calculating difference in the clipped vs unclipped riskshare and exporting the result to a csv to use for map
# change folder name to test_lrt_k for lrt^k projection
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
	dplyr::select(region, year.x, value) %>%
  rename(year = year.x) %>%
  write_csv(glue("{out}/riskshare.csv"))

# calculating difference in the clipped vs unclipped impacts and exporting the result to a csv to use for map
# change folder name to test_lrt_k for lrt^k projection
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
  dplyr::select(region, year.x, value) %>%
  rename(year = year.x) %>%
  write_csv(glue("{out}/impacts.csv"))


# obataining the regions that lie within the 1/99 LRT and exporting the result to a csv to use for map
LRT = read_csv(glue("{out}/1_99_LRT.csv")) %>%
	data.frame() %>%
	dplyr::select(region, year, climtas)

lrt_riskshare = LRT %>%
	left_join(uc_riskshare, by = "region") %>%
	dplyr::select(region, year.y, unclipped) %>%
	rename(value = unclipped, year = year.y) %>%
	write_csv(glue("{out}/lrt_riskshare.csv"))

lrt_impacts = LRT %>%
	left_join(uc_impacts, by = "region") %>%
	dplyr::select(region, year.y, unclipped) %>%
	rename(value = unclipped, year = year.y) %>%
	write_csv(glue("{out}/lrt_impacts.csv"))


# diagnostics:

# checking mean of difference by country
 riskshare %>% 
    group_by(gr= substr(region, 1, 3)) %>%
    summarise(mean= mean(value)) %>% 
    print(n = 300)

# checking mean of difference by country
 impacts %>% 
    group_by(gr= substr(region, 1, 3)) %>%
    summarise(mean= mean(value)) %>% 
    print(n = 300)

# distribution of difference in impacts and and riskshare. _z stands for zeroes

impacts_z = impacts %>% # 133 obs
	filter(value == 0)
riskshare_z = riskshare %>% # 185 obs
	filter(value == 0)
zeroes = riskshare_z %>%
	left_join(impacts_z, by = "region") # 52 NA from impacts
zeroes %>% count(is.na(value.y))


impacts_z1 = impacts %>% # 2427 obs
	filter(value >= -0.01 & value <= 0.01)
riskshare_z1 = riskshare %>% # 3182 obs
	filter(value >= -0.01 & value <= 0.01)
zeroes1 = riskshare_z1 %>%
	left_join(impacts_z1, by = "region")
zeroes1 %>% count(is.na(value.y)) # 1694 observations between riskshare and impacts don't match


impacts_z2 = impacts %>% # 369 obs
	filter(value >= -0.001 & value <= 0.001)
riskshare_z2 = riskshare %>% # 289 obs
	filter(value >= -0.001 & value <= 0.001)
zeroes2 = riskshare_z2 %>%
	left_join(impacts_z2, by = "region")
zeroes2 %>% count(is.na(value.y)) # 125 observations don't match


impacts_z3 = impacts %>% # 155 obs
	filter(value >= -0.0001 & value <= 0.0001)
riskshare_z3 = riskshare %>% # 193 obs
	filter(value >= -0.0001 & value <= 0.0001)
zeroes3 = riskshare_z3 %>%
	left_join(impacts_z3, by = "region")
zeroes3 %>% count(is.na(value.y)) # 58 observations don't match


impacts_z4 = impacts %>% # 138 obs
	filter(value >= -0.00001 & value <= 0.00001)
riskshare_z4 = riskshare %>% # 187 obs
	filter(value >= -0.00001 & value <= 0.00001)
zeroes4 = riskshare_z4 %>%
	left_join(impacts_z4, by = "region")
zeroes4 %>% count(is.na(value.y)) # 53 observations don't match


impacts_z5 = impacts %>% # 8378 obs
	filter(value >= -0.05 & value <= 0.05)
riskshare_z5 = riskshare %>% # 12425 obs
	filter(value >= -0.05 & value <= 0.05)
zeroes5 = riskshare_z5 %>%
	left_join(impacts_z5, by = "region")
zeroes5 %>% count(is.na(value.y)) # 5179 don't match


#  the highest absolute value difference between clipped and unclipped risk shares in regions inside 1/99 temperature 
lrt_risk = LRT %>%
	left_join(riskshare, by = "region") %>%
	select(region, year.y, value) %>%
	rename(year = year.y)

lrt_risk %>%
	filter(value == max(abs(value)))
#           region year     value
# 1 CHN.11.102.717 2099 0.4597552


# change code from here
diff = read_csv(glue("{out}/diff_riskshare_outside_1_99.csv")) %>% data.frame()

diff %>% filter(value == max(value))
diff %>% filter(value == min(value))

out = read_csv(glue("{out}/outside_1_99_LRT.csv")) %>% data.frame()

out %>%
	filter(climtas <= 0.64) %>%
	summarise(max = max(climtas)) #0.6279102

out %>% 
	filter(climtas >= 0.62 & climtas <= 0.64)
#   region year   climtas
# 1  MNG.9 2099 0.6279102

out %>%
	filter(climtas >= 29.01) %>%
	summarise(max = min(climtas))

out %>% 
	filter(climtas >= 29.01 & climtas <= 29.011)
#            region year  climtas
# 1 IND.33.519.2087 2099 29.01049


# # extra code, to check summary of multiple dfs at once
# L <- list(impacts_z, impacts_z1, impacts_z2, riskshare_z, riskshare_z1, riskshare_z2)
# ll = map(L, summary)
# ll

# count(zeroes2$region == zeroes3$region) 
# setdiff(zeroes2$region, zeroes3$region)


