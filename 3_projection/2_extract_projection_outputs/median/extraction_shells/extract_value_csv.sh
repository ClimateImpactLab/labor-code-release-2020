conda activate risingverse-py27
cd "/home/liruixue/repos/prospectus-tools/gcp/extract"
R

library(glue)
library(parallel)
# extract dollar values

for (do_ssp in 1:5) {
	quantiles_command = paste0("python -u quantiles.py ",
		"/home/liruixue/repos/labor-code-release-2020/3_projection/",
		"2_extract_projection_outputs/extraction_configs/",
		"damage_function_valuescsv.yml ",
		"--suffix=_damage_function_valuescsv_wage --only-ssp=SSP", 
		do_ssp, 
		" --region=global ",
		"uninteracted_main_model-wage-aggregated -uninteracted_main_model-histclim-wage-aggregated "
		)

	print(quantiles_command)
	system(quantiles_command)

	# 
	quantiles_command = paste0("python -u quantiles.py ",
		"/home/liruixue/repos/labor-code-release-2020/3_projection/",
		"2_extract_projection_outputs/extraction_configs/",
		"damage_function_valuescsv.yml ",
		"--suffix=_damage_function_valuescsv_popweights --only-ssp=SSP", 
		do_ssp, 
		" --region=global ",
		"uninteracted_main_model-pop-aggregated -uninteracted_main_model-histclim-pop-aggregated "
		)

	print(quantiles_command)
	system(quantiles_command)


	quantiles_command = paste0("python -u quantiles.py ",
		"/home/liruixue/repos/labor-code-release-2020/3_projection/",
		"2_extract_projection_outputs/extraction_configs/",
		"damage_function_valuescsv.yml  --only-ssp=SSP", 
		do_ssp, 
		" --region=global ",
		"--suffix=_damage_function_valuescsv_gdp ",
		"uninteracted_main_model-gdp-aggregated -uninteracted_main_model-histclim-gdp-aggregated "
		)

	print(quantiles_command)
	system(quantiles_command)

}

