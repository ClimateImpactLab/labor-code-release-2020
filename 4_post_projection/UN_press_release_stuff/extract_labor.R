# an R script for running labor extractions
# run the following three lines in shell
conda activate risingverse-py27
cd "/home/nsharma/repos/prospectus-tools/gcp/extract"
R


library(glue)
library(parallel)


extract_levels = function(ssp, iam, adapt, risk, aggregation="", suffix=""){

	basename <- "uninteracted_main_model"

	# if aggregation is "", no need to add -levels since it's not aggregated files
	if (aggregation != "") {
		aggregation <- paste0(aggregation, "-levels")
	}	

	# do not substract histclim for noadapt
	if (adapt == "incadapt") {
		if (risk != "riskshare") {
			basename_command <- glue("{basename}-incadapt{aggregation} -{basename}-histclim{aggregation}")
		} else {
			basename_command <- glue("{basename}-incadapt{aggregation}")
		}
	} else if (adapt == "fulladapt") {
		if (risk != "riskshare") {
			basename_command <- glue("{basename}{aggregation} -{basename}-histclim{aggregation}")
		} else {
			basename_command <- glue("{basename}{aggregation}")
		}
	} else if (adapt == "noadapt") {
		basename_command <- glue("{basename}-noadapt{aggregation}")
	} else if (adapt == "histclim") {
		basename_command <- glue("{basename}-histclim{aggregation}")
	} else {
		print("wrong specification of adaptation scenario!\n")
	}

	# a suffix that's used to choose the config file name
	if ((risk == "allrisk") | (risk == "highrisk") | (risk == "lowrisk")) {
		calculation <- "rebased"
	} else if (risk == "riskshare") {
		calculation <- "clipped"
	}

	quantiles_command1 = paste0("python -u quantiles.py ",
		"/home/nsharma/repos/labor-code-release-2020/4_post_projection/",
		"UN_press_release_stuff/extraction_configs/",
		glue("mean_{risk}_{calculation}.yml "),
		glue("--only-iam={iam} --only-ssp={ssp} --suffix=_{iam}_{risk}_{adapt}{aggregation}{suffix}-yearsets "),
		glue("--yearsets=yes {basename_command}")
		)

	print(quantiles_command1)
	system(quantiles_command1)
	
	quantiles_command2 = paste0("python -u quantiles.py ",
		"/home/nsharma/repos/labor-code-release-2020/4_post_projection/",
		"UN_press_release_stuff/extraction_configs/",
		glue("mean_{risk}_{calculation}.yml "),
		glue("--only-iam={iam} --only-ssp={ssp} --suffix=_{iam}_{risk}_{adapt}{aggregation}{suffix} "),
		glue("{basename_command}")
		)

	print(quantiles_command2)
	system(quantiles_command2)
}


# gdp aggregation and pop weights

args = expand.grid(
	ssp=c("SSP3"),
	adapt=c("fulladapt","incadapt","noadapt","histclim"),
	risk=c("highrisk","lowrisk"),
	# risk="allrisk",
	aggregation=c("-gdp"),
	iam=c("low")
	 )

mcmapply(extract_levels, 
  ssp=args$ssp, 
  iam=args$iam,
  risk=args$risk, 
  adapt=args$adapt,
  aggregation=args$aggregation,
  mc.cores = 40)

# mcmapply(extract_levels, 
#   ssp=args$ssp, 
#   iam=args$iam,
#   yearlist=args$yearlist, 
#   risk=args$risk, 
#   adapt=args$adapt,
#   aggregation=args$aggregation,
#   mc.cores = 40)


extract_agg = function(ssp, iam, adapt, risk, aggregation="", suffix=""){


	basename <- "uninteracted_main_model"

	# if aggregation is "", no need to add -levels since it's not aggregated files
	if (aggregation != "") {
		aggregation <- paste0(aggregation, "-aggregated")
	} else {
		return()
	}	

	# do not substract histclim for noadapt
	if (adapt == "incadapt") {
		if (risk != "riskshare") {
			basename_command <- glue("{basename}-incadapt{aggregation} -{basename}-histclim{aggregation}")
		} else {
			basename_command <- glue("{basename}-incadapt{aggregation}")
		}
	} else if (adapt == "fulladapt") {
		if (risk != "riskshare") {
			basename_command <- glue("{basename}{aggregation} -{basename}-histclim{aggregation}")
		} else {
			basename_command <- glue("{basename}{aggregation}")
		}
	} else if (adapt == "noadapt") {
		basename_command <- glue("{basename}-noadapt{aggregation}")
	} else if (adapt == "histclim") {
		basename_command <- glue("{basename}-histclim{aggregation}")
	} else {
		print("wrong specification of adaptation scenario!\n")
	}

	# a suffix that's used to choose the config file name
	if ((risk == "allrisk") | (risk == "highrisk") | (risk == "lowrisk")) {
		calculation <- "rebased"
	} else if (risk == "riskshare") {
		calculation <- "clipped"
	}



	quantiles_command = paste0("python -u quantiles.py ",
		"/home/nsharma/repos/labor-code-release-2020/4_post_projection/",
		"UN_press_release_stuff/extraction_configs/",
		glue("mean_{risk}_{calculation}.yml "),
		glue("--only-iam={iam} --only-ssp={ssp} --suffix=_{iam}_{risk}_{adapt}{aggregation}{suffix} "),
		glue("{basename_command}")
		)

	print(quantiles_command)
	system(quantiles_command)
}

# time series

args = expand.grid(
	ssp=c("SSP3"),
	adapt=c("fulladapt","incadapt","noadapt","histclim"),
	risk=c("highrisk","lowrisk"),
	# risk="allrisk",
	aggregation=c("-gdp"),
	iam=c("low")
	 )

mcmapply(extract_agg, 
  ssp=args$ssp, 
  iam=args$iam,
  risk=args$risk, 
  aggregation=args$aggregation,
  adapt=args$adapt,
  mc.cores = 40)



