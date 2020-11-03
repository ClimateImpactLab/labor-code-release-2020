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
		"uninteracted_main_model-",aggregation, 
		file_type, " -uninteracted_main_model-histclim-",
		aggregation, file_type
		)

	print(quantiles_command)
	system(quantiles_command)
}


for (do_ssp in 1:5) {
	ssp_arg = paste0("SSP", do_ssp)
	get_valuescsv(ssp_arg, "global","pop", "-aggregated")
	get_valuescsv(ssp_arg, "global","wage", "-aggregated")
	get_valuescsv(ssp_arg, "global","gdp", "-aggregated")
}

regions = c(
  "COD.7.29.103", # (1)Kinshasa
  "KEN.4.22.R2947e0197ea9b378", # (2) Nairobi West
  "MMR.14.62.285", # (3)Rangoon, Burma (Yangon (Rangoon))
  "VNM.2.18.Ra5f28dabe4b12dfc", # (4)Hanoi, Vietnam 
  "IND.10.121.371", # (5) Delh
  "CHN.1.14.66", # (6) Suzhou, China
  "PRK.11.170", #(7)Pyongyang, Korea, North
  "PER.15.135.1340",  # (8) Lima, Peru 
  "JPN.22.962", # (9) Kyoto, Japan 
  "AUS.11.Rea19393e048c00bc"
  )


args = expand.grid(ssp=c("SSP3"),
                   aggregation =c("gdp"),
                   region =  regions,
                   file_type = "-levels"
                         )


mcmapply(get_valuescsv, region = args$region, aggregation = args$aggregation, file_type = args$file_type, ssp = args$ssp, mc.cores = 10)

# testing
# test = read_csv(paste0("/shares/gcp/estimation/labor/code_release_int_data/projection_outputs/extracted_data_mc/",
# 	"SSP3-valuescsv_wage_global.csv"))

# display = test %>% filter(rcp == "rcp45", year == "2075") 

# print(display[order(display$value),], n = 1000)


