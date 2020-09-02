# an R script for running labor extractions
# run the following two lines in shell

conda activate risingverse-py27
cd "/home/liruixue/repos/prospectus-tools/gcp/extract"


library(glue)
library(parallel)
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
		glue("--years=[{year}] {basename_command}")
		)

	print(quantiles_command)
	system(quantiles_command)
}


extract_timeseries = function(rcp, ssp, iam, adapt, risk, aggregation=NULL){
	basename <- "combined_uninteracted_spline_empshare_noFE"
	if (adapt == "fulladapt") {
		basename_command <- glue("{basename}{aggregation}-aggregated -{basename}-histclim{aggregation}-aggregated")
	}else if (adapt == "noadapt") {
		basename_command <- glue("{basename}-{adapt}{aggregation}-aggregated")
	}

	quantiles_command = paste0("python -u quantiles.py ",
		"/home/liruixue/repos/labor-code-release-2020/3_projection/",
		"2_extract_projection_outputs/extraction_configs/",
		glue("median_mean_{risk}_unrebased.yml "),
		glue("--only-iam={iam} --only-ssp={ssp} --suffix=_{iam}_{risk}_{adapt}_timeseries "),
		glue("{basename_command}")
		)

	print(quantiles_command)
	system(quantiles_command)
}

extract_timeseries(rcp="rcp45",ssp="SSP3",adapt="fulladapt",risk="highrisk",iam="high",aggregation="-pop-allvars")

extract_map(rcp="rcp45",ssp="SSP2",adapt="fulladapt",year=2020,risk="highrisk",iam="low")

map_args = expand.grid(rcp=c("rcp85","rcp45"),
                       ssp=c("SSP2","SSP3","SSP4"),
                       adapt=c("fulladapt","noadapt"),
                       year=c(2010,2020,2098,2099,2100),
                       risk=c("highrisk","lowrisk","allrisk"),
                       iam=c("high","low")
                       )

mcmapply(extract_map, 
  rcp=map_args$rcp, 
  ssp=map_args$ssp, 
  iam=map_args$iam,
  year=map_args$year, 
  risk=map_args$risk, 
  adapt=map_args$adapt,
  mc.cores = 5)


