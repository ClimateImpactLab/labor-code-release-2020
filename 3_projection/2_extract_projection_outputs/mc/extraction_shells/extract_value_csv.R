conda activate risingverse-py27
cd "/home/liruixue/repos/prospectus-tools/gcp/extract"
R

library(glue)
library(parallel)
library(tidyverse)
library(dplyr)
# extract dollar values

get_valuescsv <- function(ssp, region, aggregation, file_type){

	quantiles_command = paste0("python -u quantiles.py ",
		"/home/liruixue/repos/labor-code-release-2020/3_projection/",
		"2_extract_projection_outputs/mc/extraction_configs/",
		"damage_function_valuescsv.yml  --only-ssp=", ssp, 
		" --region=", region, " ",
		"--suffix=valuescsv_", aggregation, "_", region, " ", 
		"uninteracted_main_model",aggregation, 
		file_type, " -uninteracted_main_model-histclim",
		aggregation, file_type
		)

	print(quantiles_command)
	system(quantiles_command)
}


for (do_ssp in 4:4) {
	ssp_arg = paste0("SSP", do_ssp)
	# get_valuescsv(ssp_arg, "global","-pop", "-aggregated")
	get_valuescsv(ssp_arg, "global","-wage", "-aggregated")
	# get_valuescsv(ssp_arg, "global","-gdp", "-aggregated")
}


regions = c(
  "NGA.25.510", #  lagos
  "IND.10.121.371", # delhi
  "CHN.2.18.78", # beijing
  "BRA.25.5212.R3fd4ed07b36dfd9c", # sao paulo
  "USA.14.608", # chicago
  "NOR.12.288" # oslo  
  # "BRA.19.3634.Rf31287f7cff5d3a1" # rio
  )

# args = expand.grid(ssp=c("SSP3"),
#                    aggregation =c("-gdp"),
#                    region =  regions,
#                    file_type = "-levels"
#                          )


# mcmapply(get_valuescsv, region = args$region, aggregation = args$aggregation, file_type = args$file_type, ssp = args$ssp, mc.cores = 10)


args = expand.grid(ssp=c("SSP3"),
                   aggregation =c(""),
                   region =  regions,
                   file_type = ""
                         )


mcmapply(get_valuescsv, region = args$region, aggregation = args$aggregation, file_type = args$file_type, ssp = args$ssp, mc.cores = 6)


# testing
# test = read_csv(paste0("/shares/gcp/estimation/labor/code_release_int_data/projection_outputs/extracted_data_mc/",
# 	"SSP3-valuescsv_wage_global.csv"))

# display = test %>% filter(rcp == "rcp45", year == "2075") 

# print(display[order(display$value),], n = 1000)


