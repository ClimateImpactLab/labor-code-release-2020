#Hit command+k+1 to fold functions. Better to read ! 
#Below functions are commented out tons of examples of arguments to run. Don't read. 

source("~/repos/labor-code-release-2020/0_subroutines/paths.R")

setup <- function(){

  #clean environment
  rm(list = ls())


  list.of.packages <- c("tictoc","parallel","reshape2", "data.table", "readstata13", "plyr", "dplyr", "gridExtra", "grid", "foreign", "tidyr", "glue") #Put the name of your packages in strings here
  new.packages <- list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]
  if(length(new.packages)) install.packages(new.packages, repos = "http://cran.us.r-project.org")

  invisible(lapply(list.of.packages, library, character.only = TRUE))

  cilpath.r:::cilpath()

  message(glue("date the code was ran : {Sys.Date()}"))
  message(glue("time the code was ran : {Sys.time()}"))

  tic()

  }


setup()


paths <- function(ctry, admin_level){


	config_path = glue("{DIR_EXT_DATA}/climate/config/{ctry}")

	output_path = glue("{ROOT_INT_DATA}/climate/raw/{ctry}/{admin_level}")

	  if(dir.exists(output_path)==FALSE){
	    dir.create(output_path, recursive=TRUE)
	  }


  return(list(config_path=config_path))

 }


args_for_weights = function(climate_source_list, countries_list, admin_list){

	args = expand.grid(climate_source=climate_source_list, country=countries_list, admin_level=admin_list)

	return(args)
}

args_for_aggregate = function(climate_source_list, countries_list, admin_list, level, var_list){

	trans_list = glue("{var_list}_aggregation_{level}")

	args = expand.grid(climate_source=climate_source_list, country=countries_list, admin_level=admin_list, transf=trans_list)

	return(args)
}


do_weights = function(country, climate_source, admin_level){

	message(glue("getting pixel weights for {country} from {climate_source} data at admin level {admin_level}"))

	paths = paths(ctry=country, admin_level=admin_level)

	code = glue("{ROOT_REPO}/climate_data_aggregation/gis/intersect_zonalstats_par.py")

	config = glue("{paths$config_path}/gis_{country}_{climate_source}_{admin_level}.txt")

	command = glue("python {code} {config}")

	system(command)

}

do_aggregate = function(country, climate_source, admin_level, transf){

	message(glue("aggregating for {country} from {climate_source} data at admin level {admin_level} for transformation {transf}"))

	paths = paths(ctry=country, admin_level=admin_level)

	code = glue("{ROOT_REPO}/climate_data_aggregation/aggregation/merge_transform_average.py")

	config = glue("{paths$config_path}/{transf}_{country}_{climate_source}_{admin_level}.txt")

	command = glue("python {code} {config}")

	system(command)
}

######### generate weights

# args_weights = args_for_weights(climate_source_list = "GMFD",
# 	countries_list = "CHN",
# 	admin_list = "adm3"
# )

# mcmapply(FUN=do_weights, country=args_weights$country, climate_source=args_weights$climate_source, admin_level=args_weights$admin_level, mc.cores=1)


# args_weights = args_for_weights(climate_source_list = "GMFD",
# 	countries_list =c("BRA", "IND", "USA", "MEX"),
# 	admin_list = "adm2"
# )

# mcmapply(FUN=do_weights, country=args_weights$country, climate_source=args_weights$climate_source, admin_level=args_weights$admin_level, mc.cores=4)


# args_weights = args_for_weights(climate_source_list = "GMFD",
# 	countries_list =c("FRA","GBR","ESP","BRA", "IND", "USA", "MEX","CHN"),
# 	admin_list = "adm1"
# )

# mcmapply(FUN=do_weights, country=args_weights$country, climate_source=args_weights$climate_source, admin_level=args_weights$admin_level, mc.cores=8)




# WORLD adm0 weights
# args_weights = args_for_weights(climate_source_list = "GMFD",
# 	countries_list =c("WORLD"),
# 	admin_list = "adm0"
# )

# mcmapply(FUN=do_weights, country=args_weights$country, climate_source=args_weights$climate_source, admin_level=args_weights$admin_level, mc.cores=1)



######### below is the latest time we generated climate data for all countries ############
# all_variables <- c(
# 	"prcp_poly",
# 	"tmax_rcspline_nochn_3kn",
# 	"tavg_rcspline_wchn_3kn",
# 	"tmax_poly",
# 	"tmax_bin"
# )

all_variables <- c(
	"prcp_poly",
	"tmax_rcspline_nochn_3kn",
	"tavg_rcspline_wchn_3kn",
	"tmax_poly"
)



args_aggregate = args_for_aggregate(climate_source_list = "GMFD",
	countries_list = c("BRA", "IND", "USA", "MEX"),
	admin_list = "adm2",
	level = "daily",
	var_list = all_variables
)


mcmapply(FUN=do_aggregate, country=args_aggregate$country, climate_source=args_aggregate$climate_source, admin_level=args_aggregate$admin_level,
transf=args_aggregate$transf, mc.cores=2)


args_aggregate = args_for_aggregate(climate_source_list = "GMFD",
	countries_list = c("FRA","GBR","ESP"),
	admin_list = "adm1",
	level = "daily",
	var_list = all_variables
)

mcmapply(FUN=do_aggregate, country=args_aggregate$country, climate_source=args_aggregate$climate_source, admin_level=args_aggregate$admin_level,
transf=args_aggregate$transf, mc.cores=2)


args_aggregate = args_for_aggregate(climate_source_list = "GMFD",
	countries_list = "CHN",
	admin_list = "adm3",
	level = "daily",
	var_list = all_variables
)

mcmapply(FUN=do_aggregate, country=args_aggregate$country, climate_source=args_aggregate$climate_source, admin_level=args_aggregate$admin_level,
transf=args_aggregate$transf, mc.cores=1)


# long run climate
args_aggregate = args_for_aggregate(climate_source_list = "GMFD",
	countries_list = c("BRA", "IND", "USA", "MEX", "FRA","GBR","ESP","CHN"),
	admin_list = "adm1",
	level = "yearly",
	var_list = "lrtmax"
)

mcmapply(FUN=do_aggregate, country=args_aggregate$country, climate_source=args_aggregate$climate_source, admin_level=args_aggregate$admin_level,
transf=args_aggregate$transf, mc.cores=1)


args_aggregate = args_for_aggregate(climate_source_list = "GMFD",
	countries_list = c("WORLD"),
	admin_list = "adm0",
	level = "yearly",
	var_list = "lrtmax"
)

mcmapply(FUN=do_aggregate, country=args_aggregate$country, climate_source=args_aggregate$climate_source, admin_level=args_aggregate$admin_level,
transf=args_aggregate$transf, mc.cores=1)














message(glue("date the code finished to run : {Sys.Date()}"))
message(glue("time the code finished to run : {Sys.time()}"))
toc()





