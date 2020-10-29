# this is the wrong one, 
# the correct one is extract_value_csv.sh
conda activate risingverse-py27
cd "/home/liruixue/repos/prospectus-tools/gcp/extract"
R

library(glue)
library(parallel)

quantiles_command = paste0("python -u quantiles.py ",
	"/home/liruixue/repos/labor-code-release-2020/3_projection/",
	"2_extract_projection_outputs/mc/extraction_configs/",
	"damage_function_valuescsv.yml ",
	"--suffix=_damage_function_valuescsv_global --region=global ",
	"uninteracted_main_model-wage-aggregated -uninteracted_main_model-histclim-wage-aggregated "
	)

print(quantiles_command)
system(quantiles_command)


