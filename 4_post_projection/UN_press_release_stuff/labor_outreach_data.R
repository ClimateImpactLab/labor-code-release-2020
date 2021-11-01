library(glue)
library(R.cache)
library(readr)
library(dplyr)
library(reticulate)
library(parallel)
library(miceadds)
library(haven)
library(ncdf4)
library(data.table)
library(tidyr)

REPO <- "/home/liruixue/repos/"

INPUT_DIR = paste0('/shares/gcp/estimation/labor/code_release_int_data/projection_outputs/outreach/')

# Make sure you are in the risingverse-py27 for this... 
setwd(paste0(REPO))

#' Wrapper that calls get_energy_impacts, transform, reshape and save results
#' @param time_step what years to output ("averaged","all")
#' @param impact_type unit of output ("impacts_mins_worked", "impacts_dollar", "impacts_pct_gdp")
#' @param resolution spatial resolution of output, ("all_IRs", "states", "iso", "global")
#' @param rcp ("rcp45", "rcp85")
#' @param risk_type ("highrisk", "lowrisk", "allrisk")
#' @param stats the statistics to produce, ("mean", "q5", "q17", "q50", "q83", "q95")
#' @param export set to TRUE if want to write output to file
#' @return Data table of processed impacts.
# nishka: this one shouldn't require any change
# nishka: anything that has to do with "risk_type" should be similar to high/low in labor
ProcessImpacts = function(
  time_step,
  impact_type, 
  resolution, 
  rcp=NULL, 
  stats=NULL,
  risk_type = "all",
  export = TRUE,
  ...){
  
  print(glue("{impact_type} {resolution} {rcp} {risk_type} {stats}"))
  # get a df with all impacts and all stats at that resolution
  df = wrap_mapply(
    impact_type = impact_type,
    resolution = resolution,
    rcp = rcp, 
    risk_type = risk_type,
    mc.cores=1,
    mc.silent=FALSE,
    FUN=get_labor_impacts
  ) 
  
  df = select_and_transform(
    df = df, 
    impact_type = impact_type,
    resolution = resolution,
    stats = stats,
  ) 
  
  # browser()

  df = reshape_and_save(
    df = df, 
    stats = stats, 
    resolution = resolution, 
    risk_type = risk_type,
    impact_type = impact_type, 
    time_step = time_step,
    rcp = rcp,
    export = export)
  
  return(df)
  
}


#' convert raw impacts to required impact type and keep only required statistics
#' @param df 
#' @param impact_type unit of output ("impacts_gj", "impacts_kwh", "impacts_pct_gdp")
#' @param resolution spatial resolution of output, ("all_IRs", "states", "iso", "global")
#' @param stats the statistics to produce, ("mean", "q5", "q17", "q50", "q83", "q95")
#' @return Data table of processed impacts.


select_and_transform = function(df, impact_type, resolution, stats, ...) {
  # nishka: the following line may be the only one you need, plus the dollar 2019 conversion
  df_stats = do.call("rbind", df) %>% dplyr::select(year, region, !!stats) 
  if (impact_type == "impacts_mins_worked") {
    return(df_stats)
  } else if (impact_type == "impacts_pct_gdp") {
    # convert from fraction to %
    df_stats = df_stats %>% rename(stats = !!stats) %>%
      dplyr::mutate(stats = - stats * 100) 
    df_stats = rename(df_stats, !!stats:= stats)
    return(df_stats)
  } else if (impact_type == "impacts_dollar") {
    # convert to 2019 dollars
    df_stats = df_stats %>% rename(stats = !!stats) %>%
      dplyr::mutate(stats = stats * 1.273526) 
    df_stats = rename(df_stats, !!stats:= stats)
    return(df_stats)
  }
}


# reshape output and save to file
reshape_and_save = function(df, stats, resolution, impact_type, time_step, rcp, risk_type, export,...) {
  
  rownames(df) <- c()
  if(resolution=="states") 
    df = StatesNames(df)
  
  years_list = list(
    all=NULL,
    averaged=list(
      seq(2020,2039),
      seq(2040,2059),
      seq(2080,2099)))
  
  if (!is.null(years_list[[time_step]]))
    df = YearChunks(df,years_list[[time_step]])
  else
    setnames(df, old='year', new='years')
  
  df = YearsReshape(df)
  
  if(identical(names(df), c("region", as.character(seq(2020, 2099))))) 
    setnames(
      df, 
      as.character(seq(2020,2099)), 
      glue("year_{as.character(seq(2020,2099))}"))
  
  # define a named vector to rename column names
  region_colname = c("Global","state_abbrev","ISO_code","Region_ID")
  names(region_colname) = c("global", "states", "iso", "all_IRs")
  setnames(df, "region", region_colname[resolution])
  
  if (export) {
    fwrite(
      df,
      do.call(
        Path, args = list(impact_type = impact_type, 
                          resolution = resolution,
                          rcp = rcp, 
                          stats = stats, 
                          risk_type = risk_type, 
                          time_step=time_step)))
  }
  
  return(df)
}

# identify which type of files to extract results from
# IR level - "levels.nc4" file, other levels - "aggeregated.nc4" files
# nishka: this one no need to change
get_geo_level = function(resolution) {
  
  geo_level_lookup = list(
    iso="-aggregated", 
    states="-aggregated", 
    all_IRs="-levels", 
    global="-aggregated")
  
  return(geo_level_lookup[[resolution]])
}


# a function to call load.median package and get projection output
# note that to percentage gdp impacts are only applicable for total energy (electricity + other energy)
# nishka: this is where most of the change happens
# replace this function with some calls to load the output of quantiles.py
get_labor_impacts = function(impact_type, risk_type, rcp, resolution,...) {
  
  # set parameters for the load.median function call based on impact_type parameter
  geo_level = get_geo_level(resolution) 
  if (impact_type == "impacts_mins_worked") {
    if (geo_level == "-aggregated") {
      infix = "-pop"
    } else  {
      infix = ""
      geo_level = ""
    }
  } else if (impact_type == "impacts_pct_gdp") {
    infix = "-gdp"
  } else if (impact_type == "impacts_dollar") {
    infix = "-wage"
  } else {
    print("wrong risk_type type")
  }
  
  df = fread(glue("{INPUT_DIR}/SSP3-{rcp}_low_{risk_type}_fulladapt{infix}{geo_level}.csv"))

  if (geo_level == "-aggregated") {  
    # get a list of region codes to filter the data with
    # browser()
    regions = return_region_list(resolution) #is.na(region)
    df = df %>% dplyr::mutate(region = if_else(region == "", "global", region))
    df = df %>% dplyr::filter(region %in% regions) 
  }
  df = df %>% dplyr::filter(year %in% seq(2020, 2099)) 
  return(df)
  
}

#reshapes the data to get region in rows and years in columns
YearsReshape = function(df){
  
  var = names(df)[!(names(df) %in% c('region', 'years'))]
  setnames(df,var,"value")
  df=reshape2:::dcast(df,region + value ~ years, value.var='value')
  setDT(df)
  df[,value:=NULL]
  #super annoying trick
  df=df[,lapply(.SD, function(x) mean(x,na.rm=TRUE)), by=region] 
  return(df)
}

#get two-decades means
YearChunks = function(df,intervals,...){
  
  df = as.data.table(df)
  df[,years:=dplyr:::case_when(year %in% intervals[[1]] ~ 'years_2020_2039',
                               year %in% intervals[[2]] ~ 'years_2040_2059',
                               year %in% intervals[[3]] ~ 'years_2080_2099')][,year:=NULL]
  df=df[!is.na(years)]
  df=df[,lapply(.SD, mean), by=.(region,years)]
  return(df)
}

#directories and files names
Path = function(impact_type, resolution, rcp, stats, risk_type, time_step, suffix='', ...){
  
  # define a named vector to rename folders and files
  geography = c("global","US_states","country_level","impact_regions")
  names(geography) = c("global", "states", "iso", "all_IRs")
  
  dir = glue("/mnt/CIL_labor/outreach/UN/{geography[resolution]}/{rcp}/SSP3/")
  file = glue("unit_{risk_type}_{impact_type}_geography_{geography[resolution]}_years_{time_step}_{rcp}_SSP3_quantiles_{stats}{suffix}.csv")
  
  print(glue('{dir}/{file}'))
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  return(file.path(dir, file))
}


memo.csv = addMemoization(read.csv)

#add US states name to states ID
StatesNames = function(df){
  df=setkey(as.data.table(df),region)
  
  # index the hierarchy.csv file
  check = setkey(as.data.table(setnames(
    memo.csv('/shares/gcp/regions/hierarchy.csv', skip = 31),
    "region.key", "region"))[,.(region, name)],region)
  
  # replace region ID with region names 
  df=check[df][,region:=name][,name:=NULL][]
  return(df)
}

#' Translates key words into list of impact region codes.
#'
#' @param regions Regions, can be IRs or aggregated regions. Also accepts:
#' - all: all ~25k impact regions; 
#' - iso: country-level output; 
#' - global: global outputs; 
#' @return List of IRs or region codes.
return_region_list = function(regions) {
  
  if (length(regions) > 1) {
    return(regions)
  }
  check = memo.csv('/shares/gcp/regions/hierarchy.csv', skip = 31) %>%
    data.frame()
  
  list = check %>%
    dplyr::filter(is_terminal == "True")
  
  if (regions == 'all_IRs'){
    return(list$region.key)
  }
  
  else if (regions == 'iso')
    return(unique(substr(list$region.key, 1, 3)))
  else if (regions == 'states'){
    df = list %>% 
      dplyr::filter(substr(region.key, 1, 3)=="USA") %>%
      dplyr::mutate(region.key = gsub('^([^.]*.[^.]*).*$', '\\1', region.key))
    return(unique(df$region.key))
  }
  else if (regions == 'global')
    return('global')
  else
    return(regions)
}


#' Identifies IRs within a more aggregated region code.
#' @param region_list Vect. of aggregated regions.
#' @return List of IRs associated with each aggregated region.
get_children = function(region_list) {
  
  check = memo.csv('/shares/gcp/regions/hierarchy.csv', skip = 31) %>%
    data.frame()
  
  list = dplyr::filter(check, region.key %in% region_list)$region.key
  
  if ('global' %in% region_list)
    list = c('global', list)
  
  term = check %>%
    dplyr::filter(is_terminal == "True")
  
  substrRight = function(x, n) (substr(x, nchar(x)-n+1, nchar(x)))
  
  child = list()
  for (reg in list) {
    
    regtag = reg
    
    if (reg == 'global') {
      child[['global']] = term$region.key
      next
    }
    
    if (substrRight(reg, 1) != '.')
      reg = paste0(reg, '.')
    
    child[[regtag]] = dplyr::filter(
      term, grepl(reg, region.key, fixed=T))$region.key
  }
  
  return(child)
}
