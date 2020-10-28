conda activate risingverse-py27
cd "/home/liruixue/repos/prospectus-tools/gcp/extract"
R

library(glue)
library(parallel)
library(tidyverse)
library(dplyr)
# extract dollar values

get_valuescsv <- function(ssp, region, aggregation){

	quantiles_command = paste0("python -u quantiles.py ",
		"/home/liruixue/repos/labor-code-release-2020/3_projection/",
		"2_extract_projection_outputs/mc/extraction_configs/",
		"damage_function_valuescsv.yml  --only-ssp=", ssp, 
		" --region=", region, " ",
		"--suffix=valuescsv_", aggregation, "_", region, " ", 
		"uninteracted_main_model-",aggregation, 
		"-aggregated -uninteracted_main_model-histclim-",
		aggregation, "-aggregated "
		)

	print(quantiles_command)
	system(quantiles_command)
}

for (do_ssp in 3:3) {
	ssp_arg = paste0("SSP", do_ssp)
	get_valuescsv(ssp_arg, "global","pop")
	get_valuescsv(ssp_arg, "global","wage")
	# get_valuescsv(do_ssp, "global","gdp")

}

args = expand.grid(ssp=c("SSP1","SSP2","SSP3","SSP4","SSP5"),
                       aggregation =c("pop","wage","gdp"),
                       region = c("global","SDN.6.16.75.230","USA.14.608")
                       )


mcmapply(get_valuescsv, region = args$region, aggregation = args$aggregation, ssp = args$ssp, mc.cores = 10)

# testing
# test = read_csv(paste0("/shares/gcp/estimation/labor/code_release_int_data/projection_outputs/extracted_data_mc/",
# 	"SSP3-valuescsv_pop_global.csv"))




