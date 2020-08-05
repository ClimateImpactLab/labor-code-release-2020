# Uses output from an energy projection single, in order to get infomation on the loggdpcpc in 2010

library(dplyr)
library(readr)
library(haven)

# old files -- they are missing now??
single.dir = '/shares/gcp/outputs/energy/impacts-blueghost/single-OTHERIND_electricity_FD_FGLS_719_Exclude_all-issues_break2_semi-parametric_TINV_clim_income_spline_GMFD/rcp85/CCSM4/high/SSP3/'
single.file = 'hddcddspline_OTHERIND_electricity-allcalcs-FD_FGLS_inter_climGMFD_Exclude_all-issues_break2_semi-parametric_poly2_OTHERIND_electricity_TINV_clim_income_spline.csv'

# Read in covariates, in order to get climate info

covariates <- read_csv(paste0(single.dir, 
	single.file), skip = 112) 

df =covariates  %>% 
  rename( 'HDD20' = 'climtas-hdd-20', 'CDD20' = 'climtas-cdd-20')%>% 
	 select(year, region, loggdppc, population)

head(df)

df_2010 = df %>% 
	filter(year == 2010) %>%
	mutate(quantile = ntile(loggdppc,3))

summary = df_2010 %>%
	group_by(quantile) %>%
	summarise(
		mean_loggdppc = mean(loggdppc),
		min_loggdppc = min(loggdppc),
		max_loggdppc = max(loggdppc)) %>%
	rename(group = quantile)

file <- "/mnt/CIL_labor/2_regression/time_use/input/loggdppc_2010_grid.dta"
haven::write_dta(summary, path=file)

