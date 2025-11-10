# Calculate 30 yr MA of weather
rm(list=ls())
library(gtools)
library(tidyverse)
library(data.table)
library(magrittr)
library(narray)
library(parallel)
library(ncdf4)
library(zoo)
library(glue)
library(Hmisc)
library(testthat)
library(foreign)

extract_climate_data <- function(year, gcm='CCSM4', tas_value='tas', climpath = NULL, tas.path=NULL, is.gcm=T, ncname = '1.0', rcp='rcp85', ...){
    if (is.gcm == T) {
        # load gcm for surrogates pre-rcps
        if (substr(gcm, 1,9)=="surrogate" & year < 2006){
            gcm = substr(gcm, 11, nchar(gcm)-3)
        } 

        if (is.null(climpath)){
            climpath = ifelse(year <=2005, paste0(tas_value,"/historical/",gcm,"/",year), paste0(tas_value,"/",rcp,"/",gcm,"/",year)) 
        }
        if (is.null(tas.path)){
            tas.path = '/shares/gcp/climate/BCSD/hierid/popwt/daily/'
        }
        #open netcdf


        print(paste0(tas.path,climpath,"/1.7.nc4"))



        if (substr(gcm, 1,9)=="surrogate" & year >= 2006){
            ncin = nc_open(paste0(tas.path,climpath,"/1.7.nc4"))
        } 

        else if (gcm=="CCSM4") {
            ncin=nc_open(paste0(tas.path,climpath,"/1.1.nc4"))
        }

        else {
            ncin = nc_open(paste0(tas.path,climpath,"/1.6.nc4"))
        }
        hierid = data.frame(ncvar_get(ncin, "hierid")) #extract hierid
        tas.df = data.frame(ncvar_get(ncin, tas_value)) #extract climate data
        tas.master = data.frame(hierid, tas.df) #put into dataframe
        names(tas.master)[1] = "hierid" #assign variable name for regions
        #reshape tas.master from wide to long
        # master.long = gather(tas.master, dayofyear, temp, X1:X365, factor_key=TRUE)
        check = as.matrix(tas.master[,-1])
        rownames(check) <- tas.master[,1]
        tc = t(check)
        ta = array(tc, dim=c(dim(tc),1,1), dimnames=append(dimnames(tc), c(year, tas_value)))

    } else if (is.gcm == F) {
        climpath = ifelse(is.null(climpath),'/shares/gcp/climate/GHCND/stations/raw/daily/tas/historic/',climpath)
        ncin = nc_open(paste0(climpath,year,'/',ncname,'.nc4'))
        hierid = data.frame(ncvar_get(ncin, "hierid")) #extract hierid
        tas.df = data.frame(ncvar_get(ncin, tas_value)) #extract climate data
        # tas.master = data.frame(hierid, tas.df) #put into dataframe
        # names(tas.master)[1] = "hierid"
        check = t(as.matrix(tas.df))
        rownames(check) <- as.matrix(hierid)
        tc = t(check)
        dimnames(tc)[[1]] <- paste0('X', seq(1,365))
        ta = array(tc, dim=c(dim(tc),1), dimnames=append(dimnames(tc),year))
    }
    nc_close(ncin)
    return(ta)
}

gather_climate_data = function(year, regions, rcp, day.range=NULL, time='annual', gcm ='CCSM4', tas_value='tas', multimodel=F) {

    clim = extract_climate_data(year, rcp=rcp, gcm=gcm, tas_value=tas_value)
    
    if (!is.null(day.range)) {
        doy = c(format(as.Date(paste0("2010","-",day.range[1]),"%Y-%m-%d"),"%j"), format(as.Date(paste0("2010","-",day.range[2]),"%Y-%m-%d"),"%j"))
        clim = clim[paste0('X',seq(doy[1],doy[2])),regions,,drop=F]
    } else { clim = clim[,regions,,,drop=F] }

    if (time == 'annual') { clim = apply(clim, c(2,3), mean) }

    clim_out = array(clim, dim=c(dim(clim),1,1), dimnames=append(dimnames(clim), c(rcp, tas_value)))

    if (multimodel == T) {
        clim_out = array(clim_out, dim=c(dim(clim_out),1), dimnames=append(dimnames(clim_out),gcm))
    }

    message(paste(year, rcp, gcm, tas_value))
    return(clim_out)
}

wrapper2 = function(gcm="CCSM4", rcp='rcp85', tas_value="tasmax"){
    yrs=seq(1950, 2005)
    list_dt = lapply(FUN=gather_climate_data, gcm=gcm, rcp=rcp, tas_value=tas_value, X=yrs)
    dt = as.data.table(list_dt)
    yrs_str = as.character(yrs)
    names(dt) = yrs_str
    dt = rowMeans(dt)
    g = as.numeric(cut2(x=dt, g=3))
    dt = data.table(lrtmax=dt, group=g)
    distribution=dt
    dt = dt[,.(mean_lrtmax=mean(lrtmax)), by=.(group)]
    file <- "/local/shsiang/Dropbox/Global ACP/labor/2_regression/time_use/input/lrtmax_grid.dta"
    haven::write_dta(dt, path=file)
    return(dt)
}

test= wrapper2(gcm="CCSM4")



args = list(time = 'annual')
wrapper = function(gcm, rcp, cores=4) {
    years = seq(1950, 2099)
    
    vect_rcp_map = expand.grid(years = years, rcp = rcp, tas_value=c("tas", "tas-poly-2", "tas-poly-3", "tas-poly-4"))
    rcplist_map = mcmapply(
        FUN=gather_climate_data, 
        year=paste(vect_rcp_map$years), 
        rcp=paste(vect_rcp_map$rcp), 
        gcm = gcm, 
        tas_value=paste(vect_rcp_map$tas_value), 
        MoreArgs=args, SIMPLIFY=F, mc.cores=cores)

    df_map = narray::stack(rcplist_map, along=1)

    df_map = narray::stack(rcplist_map, along=1) %>% 
        narray::map(along=2, function(x) rollmean(x, k=30, fill=NA, align="right"))

    final = df_map %>%
        plyr::adply(c(1,2)) %>%
        rename(region = X1,
            year = X2) %>%
        rename_at(vars(contains('tas')), funs(sub('tas', 'climtas', .))) %>%
        mutate(year = as.numeric(as.character(year))) %>%
        dplyr::filter(year >= min(years) + 29)

    # check for missing values
    expect(!any(is.na(t)), "There are NAs where there shouldn't be!")

    # better to put this on sac probably
    dir.create(glue("/shares/gcp/climate/climtas/{rcp}/{gcm}/"), recursive=TRUE)
    fwrite(final, glue("/shares/gcp/climate/climtas/{rcp}/{gcm}/climtas_30yrMA_hierid.csv"))
    return(glue("Done with {gcm} {rcp}"))
}

# some tests
# t = wrapper("surrogate_MRI-CGCM3_11", "rcp85")
# extract_climate_data(year = 1980, gcm = "surrogate_MRI-CGCM3_11")
models =  c(
    'ACCESS1-0','bcc-csm1-1','BNU-ESM','CanESM2','CCSM4','CESM1-BGC','CNRM-CM5','CSIRO-Mk3-6-0',
    'GFDL-CM3','GFDL-ESM2G','GFDL-ESM2M','IPSL-CM5A-LR','IPSL-CM5A-MR','MIROC-ESM-CHEM','MIROC-ESM',
    'MIROC5','MPI-ESM-LR','MPI-ESM-MR','MRI-CGCM3','inmcm4','NorESM1-M')

surrogates_rcp45 = c('surrogate_GFDL-ESM2G_01','surrogate_GFDL-ESM2G_11','surrogate_MRI-CGCM3_01',
    'surrogate_MRI-CGCM3_06','surrogate_MRI-CGCM3_11','surrogate_GFDL-CM3_89','surrogate_GFDL-CM3_94',
    'surrogate_GFDL-CM3_99','surrogate_CanESM2_89','surrogate_CanESM2_94','surrogate_CanESM2_99')

surrogates_rcp85 = c(surrogates_rcp45, 'surrogate_GFDL-ESM2G_06')

rcp45_spec = expand.grid(models=c(models, surrogates_rcp45), rcps="rcp45")
rcp85_spec = expand.grid(models=c(models, surrogates_rcp85), rcps="rcp85")

spec = rbindlist(
    list(
        expand.grid(models=c(surrogates_rcp45), rcps="rcp45"),
        expand.grid(models=c(surrogates_rcp85), rcps="rcp85"), 
        expand.grid(models=c(models), rcps=c("rcp45", "rcp85"))
        )
    )

mcmapply(wrapper, gcm=paste(spec$models), rcp=paste(spec$rcps), mc.cores=8)

mcmapply(wrapper, gcm=paste(surrogates_rcp85), MoreArgs=list(rcp="rcp85"), mc.cores=6)
mcmapply(wrapper, gcm=paste(surrogates_rcp45), MoreArgs = list(rcp="rcp45"), mc.cores=4)

wrapper(gcm='surrogate_GFDL-ESM2G_06', rcp="rcp85")

mcmapply(wrapper, gcm=models, MoreArgs=list(rcp="rcp45"), mc.cores=6)
mcmapply(wrapper, gcm=rcp85_spec$models, rcp=rcp85_spec$rcps, mc.cores=4)


gather_climate_data(year=2050, rcp="rcp85", tas_value="tas", gcm="CCSM4")
gather_climate_data(year=vect_rcp_map$year[1], rcp="rcp85",tas_value=paste(vect_rcp_map$tas_value[1]))
# convert to dataframe and save


