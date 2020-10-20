
rm(list=ls())
library(readr)
library(ggplot2)
library(dplyr)
library(glue)
library(data.table)
library(parallel)
# library(pbmcapply)
library(ncdf4)

impacts_root = "/shares/gcp/outputs/labor/impacts-woodwork/labor_mc_aggregate_copy/labor_mc_aggregate/"


ReRebase<- function(nc_file, dir){

	nc = nc_open(glue("{dir}/{nc_file}"), write = TRUE)

	# get the high risk impacts, low risk impacts, risk share, and year and region
	unrebased_high = ncvar_get(nc, "highriskimpacts")
	unrebased_low = ncvar_get(nc, "lowriskimpacts")
	riskshare = ncvar_get(nc,"clip")
	year = ncvar_get(nc, "year")
	region = ncvar_get(nc, "regions")

	# get netcdf4 file dimensions 
	# for adding new variables later
	dim_year = nc$dim[['year']]	
	dim_region = nc$dim[['region']]


	# construct a long dataset in the format of
	# region, yera, highriskimpacts, lowriskimpacts, riskshare
	# so that we can do calculations later 
	dims = list(region, year)
	names(dims) = c("regions","year")

	dimnames(unrebased_high) = dims
	dimnames(unrebased_low) = dims
	dimnames(riskshare) = dims

	rebased_dt = as.data.table(as.table(t(unrebased_high)))
	setnames(rebased_dt,'N',"highriskimpacts")

	rebased_dt[, "lowriskimpacts"] = as.vector(t(unrebased_low))
	rebased_dt[, "riskshare"] = as.vector(t(riskshare))

	
	# compute the rebaser terms for high and low risk impacts
	# only need year 2001 to 2010
	# some MC batches are run with climate data only from 1981 
	# so the output is also from year 1981,
	# while the rest have output from 1980
	# so we need to decide which rows to average depending on the starting year
	if (year[1] == 1981) {
		starting_index = 21
	} else if (year[1] == 1980) {
		starting_index = 20
	}
	ending_index = starting_index + 9

	# compute average by region of those years
	rebaser_low = rebased_dt[, mean(lowriskimpacts[starting_index:ending_index]), by = "regions"]
	rebaser_high = rebased_dt[, mean(highriskimpacts[starting_index:ending_index]), by = "regions"]


	# merge the rebaser back in
	setkey(rebaser_low, regions)
	setkey(rebaser_high, regions)
	setkey(rebased_dt, regions)

	merged = rebaser_low[rebased_dt]
	setnames(merged,'V1',"rebaser_low")
	merged = rebaser_high[merged]
	setnames(merged,'V1',"rebaser_high")


	# compute the correctly rebased column
	merged[, rebased_new := (highriskimpacts-rebaser_high)*riskshare +(1-riskshare)*(lowriskimpacts-rebaser_low)]

	# add that column to the netcdf4 file
	ncvar_rebased_new = ncvar_def(name = "rebased_new", unit = "minutes worked by individual correctly rebased", dim = list(dim_region, dim_year))
	try(nc <- ncvar_add(nc, ncvar_rebased_new), silent = TRUE)

	values <- matrix(unlist(merged[, "rebased_new"]), ncol = length(year), byrow = TRUE)
	ncvar_put(nc, ncvar_rebased_new, values)
	nc_close(nc)

	print(glue("done with {dir}/{nc_file}"))

}


# files to modify
# we don't want to modify the aggregated files 
# so not selecting all nc4 files
# filename_stem = "uninteracted_main_model"
filename_stem = "uninteracted_main_model_w_chn"
filenames = c(glue("{filename_stem}.nc4"),
	glue("{filename_stem}-noadapt.nc4"),
	glue("{filename_stem}-incadapt.nc4"),
	glue("{filename_stem}-histclim.nc4")
	)

# to re-rebase all the mc output
# for (batch_n in 0:14) {
# 	for (file_selector in filenames) {
# 		print(glue("batch {batch_n}"))
# 		working_folder <- glue("{impacts_root}/batch{batch_n}/") 
# 		files <- list.files(working_folder, file_selector, all.files = TRUE, recursive = TRUE)
# 		mcmapply(FUN=ReRebase, nc_file = files, dir = working_folder, mc.cores = 1)
# 	}
# }


# testing on a single
for (file_selector in filenames) {
	working_folder <- "/shares/gcp/outputs/labor/impacts-woodwork/uninteracted_main_model_w_chn_copy"
	files <- list.files(working_folder, file_selector, all.files = TRUE, recursive = TRUE)
	mcmapply(FUN=ReRebase, nc_file = files, dir = working_folder, mc.cores = 1)
}



