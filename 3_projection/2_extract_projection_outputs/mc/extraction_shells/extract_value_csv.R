conda activate risingverse-py27
cd "/home/liruixue/repos/prospectus-tools/gcp/extract"
R

library(glue)
library(parallel)
# extract dollar values

get_valuescsv <- function(ssp, region, aggregation){
	quantiles_command = paste0("python -u quantiles.py ",
		"/home/liruixue/repos/labor-code-release-2020/3_projection/",
		"2_extract_projection_outputs/mc/extraction_configs/",
		"damage_function_valuescsv.yml  --only-ssp=", ssp, 
		" --region=", region, " ",
		"--suffix=_valuescsv_", aggregation, " ",
		"combined_uninteracted_spline_empshare_noFE-",aggregation, 
		"-aggregated -combined_uninteracted_spline_empshare_noFE-histclim-",
		aggregation, "-aggregated "
		)

	print(quantiles_command)
	system(quantiles_command)
}

for (do_ssp in 1:5) {
	get_valuescsv(do_ssp, "global","pop")
	get_valuescsv(do_ssp, "global","wage")
	get_valuescsv(do_ssp, "global","gdp")

}

args = expand.grid(ssp=c("SSP1","SSP2","SSP3","SSP4","SSP5"),
                       aggregation =c("pop","wage","gdp"),
                       region = c("global","SDN.6.16.75.230","USA.14.608")
                       )


mcmapply(get_valuescsv, region = args$region, aggregation = args$aggregation, ssp = args$ssp, mc.cores = 10)

