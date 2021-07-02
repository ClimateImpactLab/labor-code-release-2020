library(yaml)
library(parallel)
library(glue)
library(skimr)
library(yaml)
library(dplyr)
library(parallel)
REPO <- "/home/repos/liruixue"
source(paste0(REPO,"/post-projection-tools/nc_tools/misc_nc.R"))

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
	files <- files[!grepl(pattern='aggregated', x=files)]	
	files <- files[!grepl(pattern='levels', x=files)]	
	files <- files[ifelse(isFALSE(start_at), 1, start_at):ifelse(isFALSE(end_at), length(files), end_at)]

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

#' Flexible version of base:::Reduce().
#' @param f binary function
#' @param X second parameter of the function. Will iterate over that one. 
#' @param init initial value of the first parameter. 
FlexReduce <- function(f, X, init){

	for (x in X){
		init <- f(init,x) 
	}
	return(init)
}



IterateExclude <- function(characters, patterns){

	for(p in patterns){
		characters <- characters[!grepl(p, characters)]
	}

	return(characters)
}


#' @return character vector. crop names. 
AllCrop <- function(){
	return(c('cassava','sorghum', 'soy', 'rice','corn','wheat_spring', 'wheat_winter'))
}

#' @param targetyaml character. full path to a 'pvals.yml' file. 
#' @param seed_name character. If you want the csvv seed, should be the name of the csvv which is the base name of netcdf files. If you want the histclim seed, should be 'histclim'.
#' @param seednumber logical. If TRUE, simply returns the seed as a number, if FALSE, will return a list with one element named 'targetyaml' that's a vector of two elements,
#' the seed in itself and the path to the pvals.yml file (the targetdir).
#' @return seed for the given target yaml file if latter exists and contains this seed, otherwise return NA.  
GetSeed <- function(targetyaml, seed_name, seednumber=TRUE){

	seed_type <- 'seed-csvv'
	if(seed_name=='histclim') seed_type <- 'seed-yearorder'

	if(!file.exists(targetyaml)){
		message(paste0('yml file does not exist in ', targetyaml, ' . returning NA.'))
		return(NA)
	}

	file = yaml.load_file(targetyaml, handlers=list("int"=function(x) { as.numeric(x) } ))

	if (! seed_name %in% names(file)){
		message(paste0('entry in yml file does not exist for ', targetyaml, ' . returning NA.'))
		return(NA)
	} 
	if (! seed_type %in% names(file[[seed_name]])){
		message(paste0('seed missing in ', targetyaml, ' . returning NA.'))
		return(NA)
	}
	if (seednumber) {
		return(file[[seed_name]][[seed_type]])
	} else {
		targetyaml = gsub('/pvals.yml', '', targetyaml)
		files<-list('targetyaml' = c(file[[seed_name]][[seed_type]], targetyaml))
		return(files)
	}

}

#' @param paths character vector. one or more full paths to the root of a projection run containing pvals.yml files. 
#' @param drop list of character vectors. If not empty, should have the length of `paths` and each element should be character vector containing 
#' character patterns to filter the target directories to use. 
#' @param keep_only list of character vectors. Equivalent to the opposite of `drop`. 
#' @param na_rm logical. remove NA seeds ?
#' @param processes integer. 
#' @param seed_name character vector. See GetSeed(). 
#' 
#' A simple run on one montecarlo using 60 processes
#' GetSeedApplyOnPaths(paths='/shares/gcp/outputs/agriculture/impacts-mealy/montecarlo-corn-140521',
#'                     seed_name='corn-160221',
#'                     processes=60)
#'
#'
#' Same but subsetting models

# ' @return a list. It has as many elements as there are in the `paths` argument. Each element is a list itself, containing four elements : 
#' (1) vector of seeds, each identified by the name of the target directory, (2) number of seeds, (3) the number of unique seeds (4) the number of NA values among that. 
#' (1)-(3) are affected by `na_rm`.  
GetSeedApplyOnPaths <- function(paths, drop=list(), keep_only=list(), na_rm=FALSE, processes=30, seed_name){

	out <- list()
	for (i in 1:length(paths)){
		p <- paths[i]
	    s <- seed_name[i]
		out[[p]] <- list()
		files <- list.files(path=p,  pattern='pvals.yml', full.names=TRUE, recursive=TRUE)
		if(length(drop)>0){
			message('dropping requested target dirs')
			files <- FlexReduce(function(characters, pattern) characters[!grepl(pattern, characters)], drop[[i]], files)
		}
		if(length(keep_only)>0){
			message('keeping only requested target dirs')
			files <- FlexReduce(function(characters, pattern) characters[grepl(pattern, characters)], keep_only[[i]], files)			
		}
		seeds <- mcmapply(targetyaml=files, FUN=GetSeed, MoreArgs=list(seed_name=s), mc.cores=processes)
		isna <- which(is.na(seeds))		
		if(na_rm){
			message('removing NAs')
			if(length(isna)>0) seeds <- seeds[-isna]
		}
		out[[p]][['seeds']] <- seeds
		out[[p]][['number of seeds']] <- length(seeds)
		out[[p]][['number of unique seeds']] <- length(unique(seeds))
		out[[p]][['number of NA seeds']] <- length(isna)

	}

	return(out)
}


d = GetSeedApplyOnPaths(paths='/shares/gcp/outputs/labor/impacts-woodwork/mc_correct_rebasing_for_integration',
                     seed_name='uninteracted_main_model',
                     processes=40,na_rm=FALSE)

names(d$"/shares/gcp/outputs/labor/impacts-woodwork/mc_correct_rebasing_for_integration"$"seeds"[1])


list = d$"/shares/gcp/outputs/labor/impacts-woodwork/mc_correct_rebasing_for_integration"$"seeds"
df = as.data.frame(list)
library(data.table)
setDT(df, keep.rownames = TRUE)
df$dup = duplicated(df[,2])

library(stringr)
df_dup = df %>% filter(dup) %>% 
			mutate(rn = str_replace(rn, "/pvals.yml","")) %>%
			select(rn) %>% rename(paths = rn)

# for (i in df_dup$paths) {
# 	print(i)
# 	# unlink(i)
# }


# save missing seeds and remove those directories
list = d$"/shares/gcp/outputs/labor/impacts-woodwork/mc_correct_rebasing_for_integration"$"seeds"
df = as.data.frame(list)
df = df %>% filter(is.na(list))
setDT(df, keep.rownames = TRUE)
library(stringr)
df_NA = df %>% 
			mutate(rn = str_replace(rn, "/pvals.yml","")) %>%
			select(rn) %>% rename(paths = rn)
library(tidyverse)
write_csv(df_NA, "/shares/gcp/outputs/labor/impacts-woodwork/mc_correct_rebasing_for_integration/NA_seeds_4th_batch.csv")

for (i in df_NA$paths) {
	print(i)
	# i_NA = str_replace(i, "mc_correct_rebasing_for_integration",
	# 	"mc_correct_rebasing_for_integration_NA_3rd_batch")
	# dir.create(i_NA, recursive = TRUE)
	# file.copy(i, i_NA, recursive=TRUE)
	# unlink(i, recursive = TRUE)
}


# df_NA_new = read_csv("/shares/gcp/outputs/labor/impacts-woodwork/mc_correct_rebasing_for_integration/NA_seeds_2nd_batch.csv")
# df_NA_old = read_csv("/shares/gcp/outputs/labor/impacts-woodwork/mc_correct_rebasing_for_integration/NA_seeds.csv")



