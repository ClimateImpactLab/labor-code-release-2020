REPO <- "/home/liruixue/repos"
library(yaml)
library(parallel)
library(glue)
library(skimr)
source(paste0(REPO,"/post-projection-tools/nc_tools/misc_nc.R"))
library(glue)

#' reads a specific netcdf file containing impacts, in a specific target directory, and performs checks of the values contained in it. 
#' @param spec a list of named single characters describing a target directory, as returned by DecomposeTargetDir() defined in this code. 
#' @param impacts.var a character. the name of the impact variable on which to perform checks.
#' @param years_search a numeric vector of size 2 : the first and last year defining the sequence of years one expects to see in the data. 
#' 
#' @return a data table -- 9 or 10 columns  (batch),rcp, gcm, iam, ssp, adapt, type , obs, regions, years -- 4 rows for 4 different types (Inf, NaN, 0 and missing).
#' If the netcdf file was not readable, {type , obs, regions, years} are filled with "can't open" strings.
ReadAndCheck <- function(spec, impacts.var, years_search){

	list2env(spec, environment())

	if ('batch' %in% names(spec)) {
		spec_DT <- data.table(batch=batch, rcp=rcp, gcm=climate_model, iam=iam, ssp=ssp, adapt=adapt)
		file_path <- file.path(impacts.folder, batch, rcp, climate_model, iam, ssp, impacts.file)
	} else {
		spec_DT <- data.table(rcp=rcp, gcm=climate_model, iam=iam, ssp=ssp, adapt=adapt)
		file_path <- file.path(impacts.folder, rcp, climate_model, iam, ssp, impacts.file)		
	}

	DT <- try(nc_to_DT(nc_file=file_path, impact_var=impacts.var))


	if (is.data.table(DT)){
		DT <- DT[year %in% years_search]

		infDT <- DT[is.infinite(get(impacts.var))]
		nanDT <- DT[is.nan(get(impacts.var))]
		zeroDT <- DT[get(impacts.var)==0]

		shouldbe_DT <- as.data.table(expand.grid(region=fread('/shares/gcp/regions/hierarchy.csv')[is_terminal==TRUE][[1]], year=years_search, stringsAsFactors = FALSE))
		setkey(shouldbe_DT, region, year)

		infDT <- data.table(type='inf', obs=nrow(infDT), regions=length(unique(infDT[, region])), years=length(unique(infDT[,year])))
		nanDT <- data.table(type='nan', obs=nrow(nanDT), regions=length(unique(nanDT[, region])), years=length(unique(nanDT[,year])))
		zeroDT <- data.table(type='zero', obs=nrow(zeroDT), regions=length(unique(zeroDT[, region])), years=length(unique(zeroDT[,year])))

		missing_obs <- nrow(shouldbe_DT)-nrow(DT)
		missing_regions=length(unique(shouldbe_DT[,region]))-length(unique(DT[,region]))
		missing_years=length(unique(shouldbe_DT[,year]))-length(unique(DT[,year]))
		missDT <- data.table(type='missing', obs=missing_obs, regions=missing_regions, years=missing_years)
		

		out <- cbind(spec_DT[rep(1,4),], rbind(infDT, nanDT, zeroDT, missDT))

	} else {

		errorDT <- data.table(type="can't open", obs="can't open", regions="can't open", years="can't open")
		out <- cbind(spec_DT, errorDT)

	}
	

	return(out)
}

#' reads a full set of projection target directories produced by a projection run, and returns a 
#' data table containing checks for each nc4 file of the type 'adapt' in this projection run. 
#' 
#' @param impacts.folder a character. The full path of the folder containing the target directory. Example : '/shares/gcp/outputs/agriculture/impacts-mealy/cassava-median-010120'. 
#' @param impacts.var a character. The impact variable contained in netcdfs on which to perform checks. For example, 'rebased'.
#' @param threads an integer. Number of cores to parallelize over. Each netcdf file will be assigned to a unique core. 
#' @param output_dir a character. The directory where to save the csv containing the checks.
#' @param base a character. The base name of an impact netcdf. 
#' @param output_title a character. It will be appended to the csv name and should be ideally the last folder of the projection directory, for example 'csvv-median-010120'.
#' 
#' @return the data table containing the checks for each selected nc4 file in the projection directory.   
ApplyReadAndCheck <- function(impacts.folder, base, impacts.var, years_search=seq(1981,2097), threads=1, output_dir, output_title, start_at=FALSE, end_at=FALSE){


	files <- list.files(path=impacts.folder, pattern='.nc4', all.files = TRUE, recursive = TRUE)
	files <- grep(pattern=base, x=files, value=TRUE)
	# files <- files[grepl(pattern='aggregated', x=files)]	
	files <- files[grepl(pattern='levels', x=files)]	
	files <- files[ifelse(isFALSE(start_at), 1, start_at):ifelse(isFALSE(end_at), length(files), end_at)]

	# browser()
	specs <- mapply(FUN=DecomposeTargetDir, target_dir=files, MoreArgs = list(impacts.folder=impacts.folder, base=base), SIMPLIFY = FALSE)
	
	if (threads>1){

		checks <- mcmapply(FUN=ReadAndCheck, spec=specs, MoreArgs=list(impacts.var=impacts.var, years_search=years_search), SIMPLIFY=FALSE, mc.cores=threads, mc.preschedule=TRUE)

	} else if (threads==1){

		checks <- mapply(FUN=ReadAndCheck, spec=specs, MoreArgs=list(impacts.var=impacts.var, years_search=years_search), SIMPLIFY=FALSE)

	} else {

		stop('invalid number of threads')

	}
	
	out <- rbindlist(checks)

	fwrite(out, file.path(output_dir, glue('checks_{output_title}.csv')))

	return(out)
}


ApplyReadAndCheck(impacts.folder = "/shares/gcp/outputs/labor/impacts-woodwork/mc_correct_rebasing_for_integration/", 
	base = "uninteracted_main_model", 
	impacts.var = "rebased", 
	years_search=seq(1981,2099), 
	threads=70, 
	output_dir = "/shares/gcp/outputs/labor/impacts-woodwork/mc_correct_rebasing_for_integration/", 
	output_title = "mc_aggregated", 
	start_at=FALSE, 
	end_at=FALSE)

library(tidyverse)
d = read_csv("/shares/gcp/outputs/labor/impacts-woodwork/mc_correct_rebasing_for_integration/checks_mc.csv")
d = d %>% filter(obs > 0)

d = read_csv("/shares/gcp/outputs/labor/impacts-woodwork/mc_correct_rebasing_for_integration/checks_mc_aggregated.csv")
d = d %>% filter(obs > 0)

d = read_csv("/shares/gcp/outputs/labor/impacts-woodwork/mc_correct_rebasing_for_integration/checks_mc_levels.csv")
d = d %>% filter(obs > 0)


import xarray as xr
import pandas as pd
d = xr.open_dataset("uninteracted_main_model-noadapt-wage-aggregated.nc4").to_dataframe().reset_index()
d[d.rebased == 0]
d[pd.isnull(d.rebased)]
d[pd.isna(d.rebased)]













