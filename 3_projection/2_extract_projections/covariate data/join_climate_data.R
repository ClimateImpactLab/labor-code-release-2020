# load packages
packages = c("ggplot2", "dplyr", "magrittr", "readr", "RColorBrewer",
             "glue", "scales", "parallel"
)
message(" ---- loading packages ---- ")
invisible(lapply(packages, function(pkg) {
  suppressPackageStartupMessages(library(pkg, character.only = TRUE))
}))
rm(packages)

# read paths
USER = Sys.getenv("USER")
source(glue("/project/cil/home_dirs/{USER}/repos/labor-code-release-2020/0_subroutines/paths.R"))

# read population and gdppc data 
high_iam <- read_csv(glue('{ROOT_INT_DATA}/projection_outputs/covariates',
                          '/pop_gdppc_2015_2099.csv'))
high_iam <- high_iam %>%
  mutate(loggdppc = log(gdppc)) # calculate log GDPpc

# read allcalcs for climate data
allcalcs_clim <- read_csv(glue('{ROOT_INT_DATA}/projection_outputs/covariates',
                               '/single-allcalcs-uninteracted_main_model.csv'), skip = 31) %>%
  filter(`year...2` == 2015 | `year...2` == 2099) %>%
  select(`year...2`, region, climtas)

# combine the data
cov_deciles <- inner_join(high_iam, allcalcs_clim, by = c("region", "year" = "year...2"))

cov_deciles <- cov_deciles %>%
  rename(population = pop) %>%
  select(year, region, population, gdppc, loggdppc, climtas)

# output the data
write_csv(cov_deciles, glue('{ROOT_INT_DATA}/projection_outputs/covariates',
                            '/SSP3-rcp85-high_covariates_decile_plots.csv'))
