conda activate risingverse-py27
cd "/home/liruixue/repos/prospectus-tools/gcp/extract"
R

library(glue)
library(parallel)

quantiles_command = paste0("python -u quantiles.py ",
	"/home/liruixue/repos/labor-code-release-2020/3_projection/",
	"2_extract_projection_outputs/extraction_configs/",
	"damage_function_valuescsv.yml ",
	"--suffix=_damage_function_valuescsv_global --region=global ",
	"combined_uninteracted_spline_empshare_noFE-wage-aggregated -combined_uninteracted_spline_empshare_noFE-histclim-wage-aggregated "
	)

print(quantiles_command)
system(quantiles_command)


