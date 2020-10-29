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
		"-levels -uninteracted_main_model-histclim-",
		aggregation, "-levels "
		)

	print(quantiles_command)
	system(quantiles_command)
}

get_valuescsv("SSP3", "global","pop")

for (do_ssp in 3:3) {
	ssp_arg = paste0("SSP", do_ssp)
	get_valuescsv(ssp_arg, "global","pop")
	get_valuescsv(ssp_arg, "global","wage")
	get_valuescsv(ssp_arg, "global","gdp")
}

args = expand.grid(ssp=c("SSP3"),
	# ssp=c("SSP1","SSP2","SSP3","SSP4","SSP5"),
                       aggregation =c("wage"),
                       region = c("SDN.6.16.75.230")
                       )
get_valuescsv("SSP3", "SDN.6.16.75.230","wage")


mcmapply(get_valuescsv, region = args$region, aggregation = args$aggregation, ssp = args$ssp, mc.cores = 10)

# testing
test = read_csv(paste0("/shares/gcp/estimation/labor/code_release_int_data/projection_outputs/extracted_data_mc/",
	"SSP3-valuescsv_pop_global.csv"))

test = test %>% filter(rcp == "rcp45", year == "2075") 

print(test[order(test$value),], n = 1000)


