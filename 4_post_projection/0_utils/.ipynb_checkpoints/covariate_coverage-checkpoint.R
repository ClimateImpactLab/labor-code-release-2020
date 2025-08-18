# FUNCTIONS

#' Translates key words into list of impact region codes.
#'
#' @param regions Regions, can be IRs or aggregated regions. Also accepts:
#' - all: all ~25k impact regions; 
#' - iso: country-level output; 
#' - global: global outputs; 
#' @return List of IRs or region codes.

return_region_list = function(regions) {

    check = read.csv(glue('{DB}/hierarchy.csv')) %>%
        data.frame()

    list = check %>%
        dplyr::filter(is_terminal)

    if (length(regions) > 1)
        return(regions)

    if (regions == 'all')
        return(list$region.key)
    else if (regions == 'iso')
        return(unique(substr(list$region.key, 1, 3)))
    # else if (regions == 'states'){
    #     df = list %>% 
    #         dplyr::filter(substr(region.key, 1, 3)=="USA") %>%
    #         dplyr::mutate(region.key = gsub('^([^.]*.[^.]*).*$', '\\1', region.key))
    #     return(unique(df$region.key))
    # }
    else if (regions == 'global')
        return('')
    else
        return(regions)

}


#' Checks spatial resolution of regions as defined by impact region definitions.
#' 
#' Determines whether input region is an impact region or a more aggregated 
#' region. 
#'
#' @param region_list vector of IRs, ISOs, or regional codes in between.
#' @return List containing region codes at ir_level or aggregated resolutions.

check_resolution = function(region_list) {

    out = list()

    check = read.csv(glue('{DB}/hierarchy.csv')) %>% #change this path after Rae replies
        data.frame()

    list = check %>%
        dplyr::filter(region.key %in% region_list)

    if (nrow(list)==0 & !('' %in% region_list))
        stop('Region not found!')

    if (any(list$is_terminal))
        out[['ir_level']] = dplyr::filter(list, is_terminal)$region.key
    if (any(!(list$is_terminal)))
        out[['aggregated']] = dplyr::filter(list, !(is_terminal))$region.key
    if ('' %in% region_list)
        out[['aggregated']] = c(out[['aggregated']], '')


    return(out)
}


#' Identifies IRs within a more aggregated region code.
#'
#' @param region_list Vect. of aggregated regions.
#' @return List of IRs associated with each aggregated region.
get_children = function(region_list) {

    check = read.csv(glue('{DB}/hierarchy.csv')) %>%
        data.frame()

    list = dplyr::filter(check, region.key %in% region_list)$region.key

    if ('' %in% region_list)
        list = c('', list)

    term = check %>%
        dplyr::filter(is_terminal)

    substrRight = function(x, n) (substr(x, nchar(x)-n+1, nchar(x)))

    child = list()
    for (reg in list) {

        regtag = reg

        if (reg == '') {
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


#' Converts Netcdf variable into an R ndarray with
#' named dimensions. 
#'
#' @param var Variable in Netcdf.
#' @param ncin Netcdf.
#' @return ndarray with named dimensions.
nc4_to_array = function(var, ncin) {

    dims = c()
    dim_list = list()
    for (i in seq(1, length(ncin$var[[var]][['dim']]))) {
        d = ncin$var[[var]][['dim']][[i]][['vals']]
        dims = c(dims, length(d))
        dim_list[[i]] = d
    }

    out_array = ncvar_get(ncin, var)
    out = array(
        out_array,
        dim=dims,
        dimnames=dim_list)

    return(out)
}


#' Converts economic data nc4 into workable dataframe. Primarily a 
#' helper function for `get_econvar`.
#' 
#' @param nc4_dir Directory to nc4 containing economic variables.
#' @param varlist list of variables to extract from nc4. Includes:
#' 'pop', 'gdp', 'gdppc'
#' @return Dataframe containing nc4 .
open_econvar_nc4 = function(nc4_dir, varlist=c('pop', 'gdp', 'gdppc')) {

    ncin=nc_open(nc4_dir)
    args = list(ncin=ncin)
    dflist = wrap_mapply(var=varlist, FUN=nc4_to_array, MoreArgs=args)

    lambda = function(array, name) {
        df = data.table(data.table::melt(array))
        names(df) =  c('year', 'region', 'model', name) 
        return(df) 
    }

    df = mapply(dflist, names(dflist), FUN=lambda, SIMPLIFY=FALSE)
    nc_close(ncin)
    return(Reduce(merge,df))
}


#' Extracts population and income data from SSP projections.
#' 
#' Inputs
#' ------
#' `data/2_projection/2_econ_vars/SSP*.nc4` - Netcdf files containing age-specific
#' and total population, GDP, and GDP per capita vaariables for each SSP/IAM
#' combination at the impact region level. This function extracts economic
#' variables from these datasets based upon various parameters defining the desired
#' output. When needed, values for aggregated regions are produced by calculating
#' the total across child impact regions and re-calculating per capita income.
#' 
#' Outputs
#' -------
#' Dataframe containing projected economic variables conistsent with input parameters.
#' 
#' Parameters/Return
#' -----------------
#' @param units pop, gdp, or gdppc (2019$). Also extracts age-specific pop:
#' (pop0to4, pop5to64, pop65plus)
#' @param regions Regions, can be IRs or aggregated regions. Also accepts:
#' - all: all ~25k impact regions; 
#' - iso: country-level output; 
#' - global: global outputs
#' @param ssp SSP scenario (SSP1-5)
#' @param iam Economic modelling scenario (low, high)
#' @param year_list List of years to extract between 2020 and 2099.
#' @param input_dir Directory containing socioecon data (note default)
#' @param scale_variable Can be used to scale output, e.g. millions of dollars
#'
#' @return Dataframe containing projected values.
get_econvar = function(
    units='pop', 
    regions='all', 
    ssp='SSP3', 
    iam='high', 
    year_list=seq(2020,2099), 
    input_dir=EV_INPUT_DEFAULT, 
    scale_variable=1,
    as.DT=FALSE ) {

    # Parse inputs to determine list of regions
    region_list = return_region_list(regions)
    resolution_list = check_resolution(region_list)
    scale_func = function(x, scl) (x * scl) 

    # agepop = c('pop0to4', 'pop5to64', 'pop65plus')
    incvars = c('gdp', 'gdppc')
    popvars=c('pop')

    # check_share = any(sapply(
    #     agepop, function(x) (match(x, units, nomatch=0)>0)))
    # if (check_share)
    #     popvars=c('pop', agepop)
    # else
    #     popvars=c('pop')

    all_vars = c('region', 'year', popvars, incvars)

    df = open_econvar_nc4(glue('{DB}/{ssp}.nc4'), 
        varlist=c(popvars, incvars))[
        year %in% year_list & model==iam]
    dflist = list()
    # Extract Impact Regions
    if (!is.null(resolution_list[['ir_level']]))
        dflist[['ir_level']] = df[
            region %in% resolution_list[['ir_level']]][
                , ..all_vars]

    # Collapse aggregated regions.
    levels = c(popvars, 'gdp')
    if (!is.null(resolution_list[['aggregated']])) {
        aggregates = get_children(resolution_list[['aggregated']])
        for (reg in names(aggregates)) {
            dflist[[reg]] = df[
                region %in% aggregates[[reg]],
                lapply(.SD, sum), by=year, .SDcols=levels][
                    , gdppc := gdp / pop][, region := reg][
                        , ..all_vars]         
        }
    }

    # Convert dollars to 2019$.
    out = rbindlist(dflist, use.names=TRUE)[
    , (incvars) := lapply(.SD, scale_func, scl=1.273526), 
        .SDcols=incvars]

    # Scale and export.
    sub_vars = c('region', 'year', units)
    out = out[, (units) := lapply(.SD, scale_func, scl=scale_variable), 
        .SDcols=units][
            , ..sub_vars]

    # Convert to dataframe or leave as data.table.
    if (!as.DT) df = data.frame(df)

    return(out)

}


popwt_collapse_to_region = function(
    df,
    varlist,
    ag_region,
    ...) {

    stopifnot(length(ag_region)==1)

    reglist = get_children(ag_region)
    irs = reglist[[1]]

    if (length(irs)==0)
        return(df[df[regions]==ag_region,])

    df = df %>%
        dplyr::filter(region %in% irs)  %>%
        popwt_collapse_rows(varlist=varlist, ...) %>%
        dplyr::mutate(region = ag_region)

    return(df)

}


#' Pulls labor covariates from raw single projection output.
#'
#' Single projections output some diagnostic files along with standard projected impacts from a 
#' single climate model (usually CCSM4). The `labor-allcalcs-uninteracted_main_model.csv`
#' file provies covariates used in the projections. For most models, this is a 13-year bartlett 
#' kernel average of logged GDP per capita and a 30-year bertlett kernel average of daily average 
#' temperature. This function accesses these data and performs a population weighted collapse 
#' across regions if an aggregated region is queried.
#'
#' Inputs
#' ------
#' Path to single directory from which the `allcalcs.csv` file will be opened.
#' 
#' Outputs
#' -------
#' Dataframe containing covariates consistent with the input parameters
#' 
#' Parameters/Return
#' -----------------
#' @param  single_path Directory containing single GCM projection output.
#' @param units Covariates available in all-preds file; namely `climtas` (long
#' run average temperature') and `loggdppc` (long run average log(GDPpc))
#' @param regions Regions, can be IRs or aggregated regions. Also accepts:
#' - all: all ~25k impact regions; 
#' - iso: country-level output; 
#' - global: global outputs
#' @param year_list List of years to extract between 2020 and 2099.
#'
#' @return Dataframe containing covariates.

get_labor_covariates = function(
    single_path=S_INPUT_DEFAULT,
    units=c('climtas', 'loggdppc'),
    regions='all',
    year_list=seq(2020,2099),
    as.DT=FALSE,
    scn=NULL,
    ...) {

    # Parse inputs to determine list of regions
    region_list = return_region_list(regions)
    resolution_list = check_resolution(region_list)

    # Open input file
    df = read.csv(glue('{DB}/labor-allcalcs-uninteracted_main_model.csv')) %>%
        dplyr::filter(
            year %in% year_list) %>%
        dplyr::select(all_of(c('region', 'year', units)))

    # Construct dataframes with relevant values at each spatial resolution.
    df_list = list()
    for (resolution in names(resolution_list)) {
        if (resolution=='ir_level') {
            df_list[[resolution]] = dplyr::filter(df,
                region %in% resolution_list[[resolution]])
        } else if (resolution=='aggregated') {
            # Calculate pop-average if aggregated regions are queried.
            pop = get_econvar(
                units=c('pop'),
                regions='all',
                year_list=year_list, ...)
            message('Pop loaded...')
            ag_list = list()
            for (reg in resolution_list[[resolution]]) {
                ag_list[[reg]] = popwt_collapse_to_region(
                    df, units, reg, pop=pop)
            }
            df_list[[resolution]] = bind_rows(ag_list)
        }
    }
    df = bind_rows(df_list)

    if (as.DT) df = data.table(df)

    return(df)
}
