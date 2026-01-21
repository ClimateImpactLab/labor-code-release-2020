#------------------------------------------------------------------------------------------
# Labor Delta Beta Wrapper Script (adapted from https://gitlab.com/ClimateImpactLab/Impacts/gcp-labor/-/blob/master/3_projection/deltabetas/double_delta_beta.R)

# Author: Elliot Grenier (egrenier@uchicago.edu)
# Date Created: Jan 27 2025
# Last Modified: Feb 10 2025

# Description:
#
#   This script uses the yellow purple package found here: 
#   https://gitlab.com/ClimateImpactLab/Impacts/post-projection-tools/-/blob/master/response_function/yellow_purple_package.R
#   to run delta betas for all regions to get changes in minutes worked as a result of
#   of climate change by risk sector for three bins: Total, Days <20C, Days>20C.
#   Delta-beta is an approximation of the projection system. We are using the results
#   produced here to create plots (scatter, blob) illustrating the distribution
#   of damages across future climate and and current socio-economics.
#
#'  [note]:
#'      we discovered in late January 2025 that to get a combined sector in the 
#'      delta-betas, we needed to rebase the "current" 2015 and "future" 2099 impacts 
#'      from a baseline year. You can't just use the same base year though because the
#'      terms will cancel out and we go back to a no-rebasing scenario (ask Ashwin
#'      to show you the math if you're curious). The janky solution we came up with was to 
#'      rebase one (i.e. future) from 2004 and the other (i.e. current) from 2006. 
#'      This super roughly approximates the rebasing procedure in the actual projection system.
#------------------------------------------------------------------------------------------

# Load packages ------------------------------
if(!require("pacman")){install.packages(("pacman"))}
pacman::p_load(ggplot2, 
               dplyr,
               readr)
library(glue)

# Load in yellow purple and labor curve function 
source('/project/cil/home_dirs/egrenier/repos/labor-code-release-2020/0_subroutines/paths.R')
REPO=ROOT_REPO # this is to make yp package paths consistent with labor repo. 
source(glue("{DIR_REPO_POST_PROJ}/response_function/yellow_purple_package.R"))
source(glue("{DIR_REPO_LABOR}/3_projection/3_diagnostics/deltabeta/get_curve_labor.R"))

# Delta beta functions -----------------------


# Function for getting the delta beta table! Note - this is for an uninteracted model, as it doesn't subtract a histclim
# this is a decent approximation in the uninteracted case, where there isn't an effect of the changing covariates in the 2001-2010 period.
    
# This function is pretty much lifted directly from Dylan's delta beta code. I've just simplified it a bit to 
# make sure we are only saving the outputs needed to do this particular task. 
#   .................................

delta_beta_labor <- function(region, curve_ds, binclim, sector, year, base_year, year1, year2, rebase = T, rnd.digits = 2, 
                             drop_zero_bins = F, rel.20 = T, full_db = F, bin=NULL, ...) {
  
  dims = dimnames(binclim)[[1]]

  effect_2004 = curve_ds[dims,paste0(year),region]*binclim[dims,paste(year1),]
  effect_2006 = curve_ds[dims,paste0(year),region]*binclim[dims,paste(year2),]
  FA_effect_y = curve_ds[dims,paste0(year),region]*binclim[dims,paste(year),]
  NA_effect_by = curve_ds[dims,paste0(year),region]*binclim[dims,paste(base_year),]
  
  if (rebase == T){
    FA_effect_y_rb = FA_effect_y - effect_2004
    NA_effect_by_rb = NA_effect_by - effect_2006
  }
  
  if (is.null(bin)) {
    diff = mean(diff(as.numeric(dimnames(binclim)[[1]])))/2
    bin = paste0('(',as.numeric(dimnames(binclim)[[1]])-diff,',',as.numeric(dimnames(binclim)[[1]])+diff,']')		
  }
  
  # uncomment and add a comma after NA_effect_by_rb to see what's happening under the hood
  # in the rebasing procedure.
  deltabeta = data.frame( list(
    bin=bin,
    T_y = binclim[dims,paste(year),],
    T_by = binclim[dims,paste(base_year),],
    T_diff = binclim[dims,paste(year),] - binclim[dims,paste(base_year),],
    beta_fa = curve_ds[dims,paste0(year),region],
    effect_2004 = effect_2004,
    effect_2006 = effect_2006,
    FA_effect_y = FA_effect_y,
    NA_effect_by = NA_effect_by,
    effect_fa = FA_effect_y_rb - NA_effect_by_rb, # sector specific effect
    effect_na = FA_effect_y - effect_2006,
    effect_by_rb = NA_effect_by_rb
  ) , stringsAsFactors=F
  )
  
  # rounding
  deltabeta[,colnames(deltabeta)[grepl('T_',colnames(deltabeta))]] = round(deltabeta[,colnames(deltabeta)[grepl('T_',colnames(deltabeta))]], digits = 0 )
  deltabeta[,colnames(deltabeta)[grepl('beta_',colnames(deltabeta))]] = round(deltabeta[,colnames(deltabeta)[grepl('beta_',colnames(deltabeta))]], digits = rnd.digits )
  deltabeta[,colnames(deltabeta)[grepl('effect_',colnames(deltabeta))]] = round(deltabeta[,colnames(deltabeta)[grepl('effect_',colnames(deltabeta))]], digits = rnd.digits )

  under20 = round( apply(deltabeta[which(as.numeric(rownames(deltabeta)) < 20),(ncol(deltabeta)-10):ncol(deltabeta)],2,sum), digits = 2)
  over20 = round( apply(deltabeta[which(as.numeric(rownames(deltabeta)) > 20),(ncol(deltabeta)-10):ncol(deltabeta)],2,sum), digits = 2)
  total = round( apply(deltabeta[,(ncol(deltabeta)-10):ncol(deltabeta)],2,sum), digits = 2)
  
  if (drop_zero_bins == T) {
    deltabeta = dplyr::filter(deltabeta,(T_y > 0 | T_by > 0 | T_y < 0 | T_by < 0))
  }
  if (rel.20==T) {
    df = bind_rows(under20, over20, total) %>% 
      data.frame(bin=as.character(c('Total <20C', 'Total >20C', 'Total')), stringsAsFactors=F)
    
  } else {
    df = bind_rows( total) %>% 
      data.frame(bin=as.character(c('Total')), stringsAsFactors=F) 
  }
  
  # full db gives us mortality by 1 degree temp bin
  if (full_db == TRUE){
    
    db_table = bind_rows(deltabeta,df) %>%
      mutate_all(as.character) %>%
      mutate_all(~ if_else(is.na(.x),'',.x))  %>% 
      mutate(hierid = region,
             sector = sector)
    
  } else {
    
    db_table = df %>% mutate(hierid = region,
                             sector = sector)
    
  }
  

  # For debugging
  # db_table = bind_rows(deltabeta,df)%>% mutate(hierid = region,
  #                                              sector = sector)
  
  return(db_table)
}

# Function for loading a DB table for a given specification, region, and year
# Note; the func input is sourced from the get_curve_labor.R script, and is the labor response function you 
# want to run. Make sure it's up to date! 
get_db_table = function(region, csvv, clim, sector, args, covars_df=NULL) {
  
  for(i in 1:length(args)) {
    assign(x=names(args)[i], value=args[[i]])
  }
  
  message(region)
  
  all_years = sort(c(year, base_year, year1, year2))
  
  # this is just for the interacted case (not the main model, need to load.covariates first)
  if(!is.null(covars_df)){
    covars=get.covariates(covars=covars_df, region=region, 
                          years=year, covar.names=c("climtasmax", "loggdppc"), list.names=NULL, ...) 
  }else{
    covars=NULL
  }
  
  message("Binning climate...")
  binclim = mapply_bin_clim(regions=region, years=all_years, clim=clim, 
                            TT_lower_bound = TT_lower_bound, TT_upper_bound = TT_upper_bound, TT_step = TT_step)

  # Get the full adapt beta, for each point in temp distribution
  # Only one response function in labor for each sector. 
  message('drawing response function...')
  curve_ds = mapply_curve(regions=region,years=year, base_year=base_year, csvv=csvv, covars=covars_df, func = func, sector = sector, 
                          TT_lower_bound = TT_lower_bound, TT_upper_bound = TT_upper_bound, TT_step = TT_step)
  
  message("got the curve")
  df = delta_beta_labor(region=region, curve_ds=curve_ds, binclim=binclim, sector=sector,
                        year=year, base_year=base_year, year1=year1, year2=year2, 
                        rnd.digits=5, drop_zero_bins=F, rel.20=T, full_db=full_db, bin=NULL)
  
  return(df)
}

# Loop over a list of regions, and then bind them into one list, return list of results
get_all_db_tables = function(region_list, sector, args) {
  
  for(i in 1:length(args)) {
    assign(x=names(args)[i], value=args[[i]])
  }

  all_years = sort(c(year, base_year, year1, year2))
  clim_df = mapply_extract_climate_data(years=all_years, tas_value=tas_value, ncname=ncname, 
                                        gcm=gcm, rcp=rcp)
 
  message('loading csvv...')
  if (!is.null(csvv.name)){
    csvv = read.csvv(filepath = paste0(csvv.dir,csvv.name))
  } else { 
    message('warning: csvv empty')
    csvv = NULL 
  }
  
  df = lapply(region_list, get_db_table, csvv=csvv, clim=clim_df, sector, args) %>%
    rbindlist()

  return(df)
}

save_sector_output = function(df, sector, ssp, iam, rcp, gcm, year, out, rebased=T){
  
  # Create directory if it doesn't exist already
  file_outputwd = paste0(out, "response-", sector,"/")
  dir.create(file_outputwd)
  slug = ifelse(rebased==T, "-rebased", '')
  # Save out file
  output_file = paste0(file_outputwd, glue("{gcm}-{rcp}-{ssp}-{iam}"),"-delta_beta-all_regions-", year, "-labor-", sector, slug, ".csv")
  write.csv(df, output_file, row.names=FALSE)
  
}

