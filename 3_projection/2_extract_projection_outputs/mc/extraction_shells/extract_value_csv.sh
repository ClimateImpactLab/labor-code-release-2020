conda activate risingverse-py27
cd "/home/liruixue/repos/prospectus-tools/gcp/extract"
R

library(glue)
library(parallel)
# extract dollar values

for (do_ssp in 1:5) {
	quantiles_command = paste0("python -u quantiles.py ",
		"/home/liruixue/repos/labor-code-release-2020/3_projection/",
		"2_extract_projection_outputs/mc/extraction_configs/",
		"damage_function_valuescsv.yml ",
		"--suffix=_damage_function_valuescsv_wage --only-ssp=SSP", 
		do_ssp, 
		" --region=global ",
		"combined_uninteracted_spline_empshare_noFE-wage-aggregated -combined_uninteracted_spline_empshare_noFE-histclim-wage-aggregated "
		)

	print(quantiles_command)
	system(quantiles_command)

	# 
	quantiles_command = paste0("python -u quantiles.py ",
		"/home/liruixue/repos/labor-code-release-2020/3_projection/",
		"2_extract_projection_outputs/mc/extraction_configs/",
		"damage_function_valuescsv.yml ",
		"--suffix=_damage_function_valuescsv_popweights --only-ssp=SSP", 
		do_ssp, 
		" --region=global ",
		"combined_uninteracted_spline_empshare_noFE-pop-allvars-aggregated -combined_uninteracted_spline_empshare_noFE-histclim-pop-allvars-aggregated "
		)

	print(quantiles_command)
	system(quantiles_command)


	quantiles_command = paste0("python -u quantiles.py ",
		"/home/liruixue/repos/labor-code-release-2020/3_projection/",
		"2_extract_projection_outputs/mc/extraction_configs/",
		"damage_function_valuescsv.yml  --only-ssp=SSP", 
		do_ssp, 
		" --region=global ",
		"--suffix=_damage_function_valuescsv_gdp ",
		"combined_uninteracted_spline_empshare_noFE-gdp-aggregated -combined_uninteracted_spline_empshare_noFE-histclim-gdp-aggregated "
		)

	print(quantiles_command)
	system(quantiles_command)

}

