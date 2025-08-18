# an R script for running labor extractions
# run the following three lines in shell
conda activate risingverse-py27
cd "/home/liruixue/repos/prospectus-tools/gcp/extract"
R


library(glue)
library(parallel)


extract_map = function(ssp, iam, adapt, year, risk, aggregation="",suffix=""){

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
	if (risk == "allrisk") {
		calculation <- "_rebased"
	} else if (risk == "riskshare") {
		calculation <- "_clipped"
	} else if ((risk == "highrisk") | (risk == "lowrisk")) {
		calculation <- "_unrebased"
	} else if (risk == "allrisk-wrong-rebasing") {
		calculation <- ""
	} 

	quantiles_command = paste0("python -u quantiles.py ",
		"/home/liruixue/repos/labor-code-release-2020/3_projection/",
		"2_extract_projection_outputs/median/extraction_configs/",
		glue("median_mean_{risk}{calculation}.yml "),
		glue("--only-iam={iam} --only-ssp={ssp} --suffix=_{iam}_{risk}_{adapt}{aggregation}{suffix}_{year}_map "),
		glue("--years=[{year}] {basename_command}")
		)

	print(quantiles_command)
	system(quantiles_command)
}


extract_timeseries = function(ssp, iam, column, adapt, model, risk, aggregation="",region="global", suffix=""){


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


	quantiles_command = paste0("python -u quantiles.py ",
		"/home/liruixue/repos/labor-code-release-2020/3_projection/",
		"2_extract_projection_outputs/median/extraction_configs/",
		glue("median_single_gcm_time_series.yml "),
		glue("--only-iam={iam}  --only-models={model} --column={column} --only-ssp={ssp} --region={region} --suffix=_{iam}_{risk}_{adapt}{aggregation}{suffix}_{column}_{region}_{model}_timeseries "),
		glue("{basename_command}")
		)

	print(quantiles_command)
	system(quantiles_command)
}

# tests
# extract_timeseries(ssp="SSP3",adapt="fulladapt",model = "CCSM4", risk="allrisk",iam="high",column="rebased_new", aggregation="-pop")
# extract_timeseries(ssp="SSP3",adapt="fulladapt",model = "CCSM4", risk="allrisk",iam="high",column="rebased", aggregation="-pop")
# extract_timeseries(ssp="SSP3",adapt="incadapt",model = "CCSM4", risk="allrisk",iam="high",column="rebased_new", aggregation="-pop")
# extract_timeseries(ssp="SSP3",adapt="noadapt",model = "CCSM4", risk="allrisk",iam="high",column="rebased_new", aggregation="-pop")


# extract_timeseries(ssp="SSP3",adapt="fulladapt",model = "surrogate_GFDL-CM3_99", risk="allrisk",iam="high",column="rebased_new", aggregation="-pop")
# extract_timeseries(ssp="SSP3",adapt="fulladapt",model = "surrogate_GFDL-CM3_99", risk="allrisk",iam="high",column="rebased", aggregation="-pop")
# extract_timeseries(ssp="SSP3",adapt="incadapt",model = "surrogate_GFDL-CM3_99", risk="allrisk",iam="high",column="rebased_new", aggregation="-pop")
# extract_timeseries(ssp="SSP3",adapt="noadapt",model = "surrogate_GFDL-CM3_99", risk="allrisk",iam="high",column="rebased_new", aggregation="-pop")

extract_timeseries(ssp="SSP3",adapt="fulladapt",model = "GFDL-ESM2G", risk="allrisk",iam="high",column="rebased_new", aggregation="-pop")
extract_timeseries(ssp="SSP3",adapt="fulladapt",model = "GFDL-ESM2G", risk="allrisk",iam="high",column="rebased", aggregation="-pop")
extract_timeseries(ssp="SSP3",adapt="incadapt",model = "GFDL-ESM2G", risk="allrisk",iam="high",column="rebased_new", aggregation="-pop")
extract_timeseries(ssp="SSP3",adapt="noadapt",model = "GFDL-ESM2G", risk="allrisk",iam="high",column="rebased_new", aggregation="-pop")


