library(data.table)
library(ncdf4)
library(parallel)
library(glue)
library(dplyr)



#' reads a netcdf file and converts it into a data.frame or a data.table. 
#' @param nc_file character. The full path to the netcdf file, including '.nc4'. 
#' @param impact_var character. The name of the variable containing the values to pull out of the netcdf. 
#' @param dimvars a list of named characters. The characters are the names of the dimension in 
#' the netcdf, and their names will be used as column name in the data.table.
#' @param to.data.frame logical. If TRUE, returns a data.frame. 
#' @param print.nc logical. If TRUE, prints the description of the netcdf. 
#' 
#' @return a data frame or a data table with (length(dimvars) + 1) columns. 
nc_to_DT <- function(nc_file, impact_var, dimvars=list(region='regions', year='year'), to.data.frame=TRUE, print.nc=FALSE){

	nc = nc_open(nc_file)
	if(print.nc) print(nc)
	value = ncvar_get(nc, impact_var)
	dims = lapply(FUN=function(x) c(ncvar_get(nc, x)), X=dimvars)
	names(dims) = names(dimvars)
	if(!identical(unname(sapply(dims, length)),dim(value))) stop(glue("ordering of specified dim vars is not same as ordering for {impact_var}. Please correct."))
	dimnames(value) = dims
	done = as.data.table(as.table(t(value)))
	if('year' %in% unlist(dimvars)) done[,year:=as.integer(year)]
	setnames(done,'N',impact_var)
	setkeyv(done, names(dimvars))
	done[]
	if(to.data.frame) done <- as.data.frame(done) 
	return(done)

}

#' reads a specific netcdf file containing impacts, in a specific target directory, and performs checks of the values contained in it. 
#' @param spec a list of named single characters : impacts.folder, rcp, climate_model, iam, ssp, impacts.file.  Latter including '.nc4'. 
#' @param impacts.var a character. the name of the impact variable on which to perform checks.
#' @param years_search a numeric vector of size 2 : the first and last year defining the set of years one expects to see in the data. 
#' 
#' @return a data table -- 8 columns  rcp, gcm, iam, ssp, type , obs, regions, years -- 4 rows for 4 different types (Inf, NaN, 0 and missing)
ReadAndCheck <- function(spec, impacts.var, years_search){

	list2env(spec, environment())

	DT <- nc_to_DT(nc_file=file.path(impacts.folder, rcp, climate_model, iam, ssp, impacts.file), impact_var=impacts.var, to.data.frame=FALSE)

	DT <- DT[year %in% years_search]

	infDT <- DT[is.infinite(get(impacts.var))]
	nanDT <- DT[is.nan(get(impacts.var))]
	zeroDT <- DT[get(impacts.var)==0]
	shouldbe_DT <- as.data.table(expand.grid(region=fread('/shares/gcp/regions/hierarchy.csv')[is_terminal==TRUE][[1]], year=years_search, stringsAsFactors = FALSE))

	infDT <- data.table(rcp=rcp, gcm=climate_model, iam=iam, ssp=ssp, type='inf', 
		obs=nrow(infDT), regions=length(unique(infDT[, region])), years=length(unique(infDT[,year])))


	nanDT <- data.table(rcp=rcp, gcm=climate_model, iam=iam, ssp=ssp, type='nan',
		obs=nrow(nanDT), regions=length(unique(nanDT[, region])), years=length(unique(nanDT[,year])))

	zeroDT <- data.table(rcp=rcp, gcm=climate_model, iam=iam, ssp=ssp, type='zero',
		obs=nrow(zeroDT), regions=length(unique(zeroDT[, region])), years=length(unique(zeroDT[,year])))

	missing_obs <- nrow(shouldbe_DT)-nrow(DT)

	missDT <- data.table(rcp=rcp, gcm=climate_model, iam=iam, ssp=ssp, type='missing',
		obs=missing_obs, regions=length(unique(shouldbe_DT[!(region %in% DT[,region]),region])), years=length(unique(shouldbe_DT[!(year %in% DT[,year]),year])))
	
	out <- rbind(infDT, nanDT, zeroDT, missDT)

	return(out)
}


#' reads a single projection target directory and returns a list defining the scenarios represented by this target directory.
#' 
#' @param target_dir a character.  The path of a target directory, starting from the rcp scenarios. For example : 'rcp45/CCSM4/high/SSP3/myfile.nc4'
#' @param impacts.folder a character. The full path of the folder containing the target directory. Example : '/shares/gcp/outputs/agriculture/impacts-mealy/cassava-median-010120'. 

#' @return a list of 6 named charactes : impacts.folder, impacts.file, rcp, climate_model, iam, ssp. 
DecomposeTargetDir <- function(impacts.folder, target_dir){

	rcp <- gsub("/..*", "", target_dir)
	target_dir <- gsub(paste0(rcp, "/"), "", target_dir)
	climate_model <- gsub("/..*", "", target_dir)
	target_dir <- gsub(paste0(climate_model, "/"), "", target_dir)
	iam <- gsub("/..*", "", target_dir)
	target_dir <- gsub(paste0(iam, "/"), "", target_dir)
	ssp <- gsub("/..*", "", target_dir)
	impacts.file <- gsub(paste0(ssp, "/"), "", target_dir)

	return(list(impacts.folder=impacts.folder, impacts.file=impacts.file, rcp=rcp, climate_model=climate_model, iam=iam, ssp=ssp))

} 





#' reads a full set of projection target directories produced by a projection run, and returns a 
#' data table containing checks for each nc4 file of the type 'adapt' in this projection run. 
#' 
#' @param impacts.folder a character. The full path of the folder containing the target directory. Example : '/shares/gcp/outputs/agriculture/impacts-mealy/cassava-median-010120'. 
#' @param adapt a character. It should uniquely identify a unique netcdf in a target directory. It can (and should) be of the regex type. 
#' @param impacts.var a character. The impact variable contained in netcdfs on which to perform checks. For example, 'rebased'.
#' @param threads an integer. Number of cores to parallelize over. Each netcdf file will be assigned to a unique core. 
#' @param output_dir a character. The directory where to save the csv containing the checks.
#' @param output_title a character. It will be appended to the csv name and should be ideally the last folder of the projection directory, for example 'csvv-median-010120'.
#' 
#' @return the data table containing the checks for each selected nc4 file in the projection directory.   
ApplyReadAndCheck <- function(impacts.folder, adapt='*-incadapt.nc4', impacts.var, years_search=seq(1981,2098), threads=30, output_dir, output_title){


	files <- list.files(impacts.folder, adapt, all.files = TRUE, recursive = TRUE)
	specs <- mapply(FUN=DecomposeTargetDir, target_dir=files, MoreArgs = list(impacts.folder=impacts.folder), SIMPLIFY = FALSE)
	checks <- mcmapply(FUN=ReadAndCheck, spec=specs, MoreArgs=list(impacts.var=impacts.var, years_search=years_search), SIMPLIFY=FALSE, mc.cores=threads)

	out <- rbindlist(checks)

	# fwrite(out, file.path(output_dir, glue('checks_{output_title}.csv')))
	fwrite(out %>% dplyr::filter(obs > 0), file.path(output_dir, glue('issues_{output_title}.csv')))


	return(out)
}


#' converts an intuitive definition of an adaptation scenario to the suffix of impacts nc4 files.  
#' @param adapt character. 'fulladapt', 'incadapt', 'noadapt', 'histclim'
#' 
#' @return a character, belonging to the set of suffixes that exist for nc4 files : c("", "-incadapt", "-noadapt","-histclim")
nc_adapt_to_suf <- function(adapt){
	
	sufs = c(fulladapt="", incadapt="-incadapt", noadapt="-noadapt",histclim="-histclim")

	return(sufs[[adapt]])

}


for (batch_n in 6:7) {
	batch <- glue("batch{batch_n}")
	impacts.folder <- glue("/shares/gcp/outputs/labor/impacts-woodwork/labor_mc_202009/{batch}")
	impacts.var <- "rebased"
	output_dir <- "/shares/gcp/outputs/labor/impacts-woodwork/labor_mc_202009/"
	output_title <- batch
	results = ApplyReadAndCheck(impacts.folder, adapt='uninteracted_main_model.nc4', impacts.var, years_search=seq(1981,2098), threads=60, output_dir, output_title)
	print(glue("batch{batch_n}"))
	print(results %>% dplyr::filter(obs > 0))
}



