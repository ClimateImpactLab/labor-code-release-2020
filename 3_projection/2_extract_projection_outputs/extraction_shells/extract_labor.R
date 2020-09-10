# an R script for running labor extractions
# run the following two lines in shell

conda activate risingverse-py27
cd "/home/liruixue/repos/prospectus-tools/gcp/extract"


library(glue)
library(parallel)


extract_map = function(ssp, iam, adapt, year, risk, aggregation="",suffix=""){

	basename <- "combined_uninteracted_spline_empshare_noFE"

	# if aggregation is "", no need to add -levels since it's not aggregated files
	if (aggregation != "") {
		aggregation <- paste0(aggregation, "-levels")
	}	

	# do not substract histclim for noadapt
	if (adapt == "incadapt") {
		basename_command <- glue("{basename}-incadapt{aggregation} -{basename}-histclim{aggregation}")
	} else if (adapt == "fulladapt") {
		basename_command <- glue("{basename}{aggregation} -{basename}-histclim{aggregation}")
	} else if (adapt == "noadapt") {
		basename_command <- glue("{basename}-noadapt{aggregation}")
	} else if (adapt == "histclim") {
		basename_command <- glue("{basename}-histclim{aggregation}")
	} else {
		print("wrong specification of adaptation scenario!\n")
	}

	# a suffix that's used to choose the config file name
	if (risk == "allrisk") {
		calculation <- "rebased"
	} else if (risk == "riskshare") {
		calculation <- "clipped"
	} else if ((risk == "highrisk") | (risk == "lowrisk")) {
		calculation <- "unrebased"
	} 

	quantiles_command = paste0("python -u quantiles.py ",
		"/home/liruixue/repos/labor-code-release-2020/3_projection/",
		"2_extract_projection_outputs/extraction_configs/",
		glue("median_mean_{risk}_{calculation}.yml "),
		glue("--only-iam={iam} --only-ssp={ssp} --suffix=_{iam}_{risk}_{adapt}{aggregation}{suffix}_{year}_map "),
		glue("--years=[{year}] {basename_command}")
		)

	print(quantiles_command)
	system(quantiles_command)
}


extract_timeseries = function(ssp, iam, adapt, risk, aggregation="",region="global", suffix=""){


	basename <- "combined_uninteracted_spline_empshare_noFE"

	# if aggregation is "", no need to add -levels since it's not aggregated files
	if (aggregation != "") {
		aggregation <- paste0(aggregation, "-aggregated")
	}	

	# do not substract histclim for noadapt
	if (adapt == "incadapt") {
		basename_command <- glue("{basename}-incadapt{aggregation} -{basename}-histclim{aggregation}")
	} else if (adapt == "fulladapt") {
		basename_command <- glue("{basename}{aggregation} -{basename}-histclim{aggregation}")
	} else if (adapt == "noadapt") {
		basename_command <- glue("{basename}-noadapt{aggregation}")
	} else if (adapt == "histclim") {
		basename_command <- glue("{basename}-histclim{aggregation}")
	} else {
		print("wrong specification of adaptation scenario!\n")
	}

	# a suffix that's used to choose the config file name
	if (risk == "allrisk") {
		calculation <- "rebased"
	} else if (risk == "riskshare") {
		calculation <- "clipped"
	} else if ((risk == "highrisk") | (risk == "lowrisk")) {
		calculation <- "unrebased"
	}


	quantiles_command = paste0("python -u quantiles.py ",
		"/home/liruixue/repos/labor-code-release-2020/3_projection/",
		"2_extract_projection_outputs/extraction_configs/",
		glue("median_mean_{risk}_{calculation}.yml "),
		glue("--only-iam={iam} --only-ssp={ssp} --region=global --suffix=_{iam}_{risk}_{adapt}{aggregation}{suffix}_{region}_timeseries "),
		glue("{basename_command}")
		)

	print(quantiles_command)
	system(quantiles_command)
}

extract_timeseries(ssp="SSP3",adapt="fulladapt",risk="highrisk",iam="high",aggregation="-pop-allvars")

extract_map(ssp="SSP3",adapt="incadapt",year=2099,risk="allrisk",iam="low",aggregation="")

# args = expand.grid(rcp=c("rcp85","rcp45"),
#                        ssp=c("SSP2","SSP3","SSP4"),
#                        adapt=c("fulladapt","noadapt"),
#                        year=c(2010,2020,2098),
#                        # year=c(2100),
#                        risk=c("highrisk","lowrisk","allrisk","riskshare"),
#                        # risk=c("riskshare"),
#                        aggregation=c("","-wage","-gdp","","-pop-allvars"),
#                        iam=c("high","low")
#                        )


args = expand.grid(ssp=c("SSP2","SSP3","SSP4"),
                   adapt=c("incadapt"),
                   year=c(2010,2020,2098),
                   # year=c(2100),
                   risk=c("highrisk","lowrisk","allrisk","riskshare"),
                   # risk=c("riskshare"),
                   aggregation=c("","-pop-allvars"),
                   iam=c("high","low")
                 )

mcmapply(extract_map, 
  ssp=args$ssp, 
  iam=args$iam,
  year=args$year, 
  risk=args$risk, 
  adapt=args$adapt,
  aggregation=args$aggregation,
  # suffix="",
  mc.cores = 5)

mcmapply(extract_timeseries, 
  ssp=args$ssp, 
  iam=args$iam,
  risk=args$risk, 
  aggregation="-pop-allvars",
  adapt=args$adapt,
  region="global",
  suffix="_popweighted_impacts",
  mc.cores = 5)




