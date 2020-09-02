# an R script for running labor extractions
# run the following two lines in shell

conda activate risingverse-py27
cd "/home/liruixue/repos/prospectus-tools/gcp/extract"


library(glue)
rcps = c("rcp45","rcp85")
ssps = c("ssp2","ssp3","ssp4")
risk = c("highrisk","lowrisk","allrisk")
adapt = c("noadapt","fulladapt")


extract_map = function(rcp, ssp, iam, adapt, year, risk, aggregation=NULL){

	basename <- "combined_uninteracted_spline_empshare_noFE"
	if (adapt == "fulladapt") {
		basename_command <- glue("{basename} -{basename}-histclim")
	}else if (adapt == "noadapt") {
		basename_command <- glue("{basename}-{adapt}")
	}

	quantiles_command = paste0("python -u quantiles.py ",
		"/home/liruixue/repos/labor-code-release-2020/3_projection/",
		"2_extract_projection_outputs/extraction_configs/",
		glue("median_mean_{risk}_unrebased.yml "),
		glue("--only-iam={iam} --only-ssp={ssp} --suffix=_{iam}_{risk}_{adapt}_{year}_map "),
		glue("years={year} basename -${basename}-histclim")
		)

	print(quantiles_command)
	system(quantiles_command)
}
extract_map(rcp="rcp45",ssp="SSP3",adapt="noadapt",year=2020,risk="highrisk",iam="high")


extract_timeseries = function(rcp, ssp, iam, adapt, year, risk, aggregation=NULL){
	basename <- "combined_uninteracted_spline_empshare_noFE"
	if (adapt == "fulladapt") {
		basename_command <- glue("{basename}-aggregated -{basename}-histclim-aggregated")
	}else if (adapt == "noadapt") {
		basename_command <- glue("{basename}-{adapt}-aggregated")
	}

	quantiles_command = paste0("python -u quantiles.py ",
		"/home/liruixue/repos/labor-code-release-2020/3_projection/",
		"2_extract_projection_outputs/extraction_configs/",
		glue("median_mean_{risk}_unrebased.yml "),
		glue("--only-iam={iam} --only-ssp={ssp} --suffix=_{iam}_{risk}_{adapt}_timeseries "),
		glue("years={year} {basename_command}")
		)

	print(quantiles_command)
	# system(quantiles_command)
}

extract_timeseries(rcp="rcp45",ssp="SSP3",adapt="noadapt",year=2020,risk="highrisk",iam="high")



