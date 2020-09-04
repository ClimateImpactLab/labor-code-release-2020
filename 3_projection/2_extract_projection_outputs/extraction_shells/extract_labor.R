# an R script for running labor extractions
# run the following two lines in shell

conda activate risingverse-py27
cd "/home/liruixue/repos/prospectus-tools/gcp/extract"


library(glue)
library(parallel)


extract_map = function(rcp, ssp, iam, adapt, year, risk, aggregation="",suffix=""){

	basename <- "combined_uninteracted_spline_empshare_noFE"
	if (adapt == "fulladapt") {
		basename_command <- glue("{basename} -{basename}-histclim")
	}else if (adapt == "noadapt") {
		basename_command <- glue("{basename}-{adapt}")
	}

	if (risk == "allrisk") {
		rebased <- "rebased"
	} else if (risk == "riskshare") {
		rebased <- "clipped"
	} else {
		rebased <- "unrebased"
	}
	# browser()

	quantiles_command = paste0("python -u quantiles.py ",
		"/home/liruixue/repos/labor-code-release-2020/3_projection/",
		"2_extract_projection_outputs/extraction_configs/",
		glue("median_mean_{risk}_{rebased}.yml "),
		glue("--only-iam={iam} --only-ssp={ssp} --suffix=_{iam}_{risk}_{adapt}{aggregation}{suffix}_{year}_map "),
		glue("--years=[{year}] {basename_command}")
		)

	print(quantiles_command)
	system(quantiles_command)
}


extract_timeseries = function(rcp, ssp, iam, adapt, risk, aggregation="",region="global", suffix=""){
	basename <- "combined_uninteracted_spline_empshare_noFE"
	if (adapt == "fulladapt") {
		basename_command <- glue("{basename}{aggregation}-aggregated -{basename}-histclim{aggregation}-aggregated")
	}else if (adapt == "noadapt") {
		basename_command <- glue("{basename}-{adapt}{aggregation}-aggregated")
	}

	if (risk == "allrisk") {
		rebased <- "rebased"
	} else if (risk == "riskshare") {
		rebased <- "clipped"
	} else {
		rebased <- "unrebased"
	}

	quantiles_command = paste0("python -u quantiles.py ",
		"/home/liruixue/repos/labor-code-release-2020/3_projection/",
		"2_extract_projection_outputs/extraction_configs/",
		glue("median_mean_{risk}_{rebased}.yml "),
		glue("--only-iam={iam} --only-ssp={ssp} --region=global --suffix=_{iam}_{risk}_{adapt}{aggregation}{suffix}_{region}_timeseries "),
		glue("{basename_command}")
		)

	print(quantiles_command)
	system(quantiles_command)
}

extract_timeseries(rcp="rcp45",ssp="SSP3",adapt="fulladapt",risk="highrisk",iam="high",aggregation="-pop-allvars")

extract_map(rcp="rcp45",ssp="SSP2",adapt="fulladapt",year=2020,risk="highrisk",iam="low",aggregatio="-gdp")

args = expand.grid(rcp=c("rcp85","rcp45"),
                       ssp=c("SSP2","SSP3","SSP4"),
                       adapt=c("fulladapt","noadapt"),
                       year=c(2010,2020,2098),
                       # year=c(2100),
                       risk=c("highrisk","lowrisk","allrisk","riskshare"),
                       # risk=c("riskshare"),
                       aggregation=c("","-wage","-gdp","","-pop-allvars"),
                       iam=c("high","low")
                       )

mcmapply(extract_map, 
  rcp=args$rcp, 
  ssp=args$ssp, 
  iam=args$iam,
  year=args$year, 
  risk=args$risk, 
  adapt=args$adapt,
  aggregation=args$aggregation,
  # suffix="",
  mc.cores = 40)

mcmapply(extract_timeseries, 
  rcp=args$rcp, 
  ssp=args$ssp, 
  iam=args$iam,
  risk=args$risk, 
  aggregation="-pop-allvars",
  adapt=args$adapt,
  region="global",
  suffix="_popweighted_impacts",
  mc.cores = 5)




