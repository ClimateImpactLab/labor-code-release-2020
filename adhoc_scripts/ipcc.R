# energy numbers for IPCC AR6
# ISO level electricity and other energy impacts in 2099 for RCP85 SSP3 
# for all African countries in GJ. 
# Please include the average change for electricity and other energy 
# across all ISOs in Africa (should be straight out of James' aggregated files, 
# which aggregate into an "Africa" region - let me know if you have questions).
# ISO level total % of GDP impacts in 2099 for RCP85 SSP3, 
# summed across fuel types, for all African countries. 
# Please also include the Africa average from the aggregated files.
# Same as the above for labor -- both high risk and low risk minutes lost, 
# and the total measured in % of GDP.



rm(list = ls())
source("~/repos/labor-code-release-2020/0_subroutines/paths.R")
source("~/repos/post-projection-tools/mapping/imgcat.R") #this redefines the way ggplot plots. 
library(glue)
library(parallel)
# Load in the required packages, installing them if necessary 
if(!require("pacman")){install.packages(("pacman"))}
pacman::p_load(ggplot2, 
               dplyr,
               readr, 
               DescTools,
               RColorBrewer)

source(glue("{DIR_REPO_LABOR}/4_post_projection/0_utils/time_series.R"))

extracted_data_dir = "/shares/gcp/estimation/labor/code_release_int_data/projection_outputs/extracted_data"
output_dir = "/shares/gcp/estimation/labor/code_release_int_data/projection_outputs/ipcc"

# impacts

command = paste0("python -u /home/liruixue/repos/prospectus-tools/gcp/extract/quantiles.py ",
	"/home/liruixue/repos/labor-code-release-2020/3_projection/",
	"2_extract_projection_outputs/extraction_configs/",
	"median_mean_highrisk_unrebased.yml ",
	"--only-iam=high --only-ssp=SSP3 --suffix=_high_highrisk_fulladapt-pop-aggregated_ipcc ",
	"combined_uninteracted_spline_empshare_noFE -combined_uninteracted_spline_empshare_noFE-histclim"
	)
system(command)



command = paste0("python -u /home/liruixue/repos/prospectus-tools/gcp/extract/quantiles.py ",
	"/home/liruixue/repos/labor-code-release-2020/3_projection/",
	"2_extract_projection_outputs/extraction_configs/",
	"median_mean_lowrisk_unrebased.yml ",
	"--only-iam=high --only-ssp=SSP3 --suffix=_high_lowrisk_fulladapt-pop-aggregated_ipcc ",
	"combined_uninteracted_spline_empshare_noFE -combined_uninteracted_spline_empshare_noFE-histclim"
	)
system(command)


# 
command = paste0("python -u /home/liruixue/repos/prospectus-tools/gcp/extract/quantiles.py ",
	"/home/liruixue/repos/labor-code-release-2020/3_projection/",
	"2_extract_projection_outputs/extraction_configs/",
	"median_mean_riskshare_clipped.yml ",
	"--only-iam=high --only-ssp=SSP3 --suffix=_high_riskshare_fulladapt-pop-aggregated_ipcc ",
	"combined_uninteracted_spline_empshare_noFE -combined_uninteracted_spline_empshare_noFE-histclim"
	)
system(command)


# 
command = paste0("python -u /home/liruixue/repos/prospectus-tools/gcp/extract/quantiles.py ",
	"/home/liruixue/repos/labor-code-release-2020/3_projection/",
	"2_extract_projection_outputs/extraction_configs/",
	"median_mean_allrisk_rebased.yml ",
	"--only-iam=high --only-ssp=SSP3 --suffix=_high_riskshare_fulladapt_ipcc ",
	"combined_uninteracted_spline_empshare_noFE -combined_uninteracted_spline_empshare_noFE-histclim"
	)
system(command)

high_min = read_csv(paste0(extracted_data_dir,
					"/SSP3-rcp85_high_highrisk_fulladapt-pop-aggregated_ipcc.csv"))


low_min = read_csv(paste0(extracted_data_dir,
					"/SSP3-rcp85_high_lowrisk_fulladapt-pop-aggregated_ipcc.csv"))

share = read_csv(paste0(extracted_data_dir,
					"/SSP3-rcp85_high_riskshare_fulladapt-pop-aggregated_ipcc.csv"))


command = paste0("python -u /home/liruixue/repos/prospectus-tools/gcp/extract/quantiles.py ",
	"/home/liruixue/repos/labor-code-release-2020/3_projection/",
	"2_extract_projection_outputs/extraction_configs/",
	"median_mean_riskshare_clipped.yml ",
	"--only-iam=high --only-ssp=SSP3 --suffix=_high_riskshare_fulladapt-pop-aggregated_ipcc ",
	"combined_uninteracted_spline_empshare_noFE -combined_uninteracted_spline_empshare_noFE-histclim"
	)
system(command)





command = paste0("python -u /home/liruixue/repos/prospectus-tools/gcp/extract/quantiles.py ",
	"/home/liruixue/repos/labor-code-release-2020/3_projection/",
	"2_extract_projection_outputs/extraction_configs/",
	"median_mean_allrisk_rebased.yml ",
	"--only-iam=high --only-ssp=SSP3 --suffix=_high_allrisk_fulladapt-gdp-levels_ipcc ",
	"combined_uninteracted_spline_empshare_noFE-gdp-levels -combined_uninteracted_spline_empshare_noFE-histclim-gdp-levels"
	)

system(command)


high_pct = read_csv("")

low_pct = read_csv("")









