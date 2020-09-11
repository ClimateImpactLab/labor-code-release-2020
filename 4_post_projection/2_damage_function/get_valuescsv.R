# Temp stand-in for quantiles.py ahead of Fed conf
# Author: Simon Greenhill, sgreenhill@uchicago.edu
# Date: 11/4/19

rm(list=ls())
library(tidyverse)
library(magrittr)
library(glue)
library(testthat)
library(ncdf4)
library(data.table)
library(parallel)
library(reticulate)
library(R.cache)
cilpath.r:::cilpath()

# NOTE: the below output directory is out of date.
output = glue("{DB}/Global ACP/ClimateLaborGlobalPaper/Paper/Projections/FedConference2019/TimeSeries/")
source(glue("{REPO}/post-projection-tools/timeseries/ggtimeseries.R"))

load_projection = function(gcm="CCSM4", rcp="rcp85", ssp="SSP3", iam="high", variables, adapt="fulladapt", aggregated=TRUE, version=1.1) {
    if (aggregated == TRUE) {
        proj = nc_open(glue("{SAC_SHARES}/outputs/labor/impacts-fedconference-oct2019/median/{rcp}/{gcm}/{iam}/{ssp}/labor_test-damages-{adapt}-aggregated-{version}.nc4"))
    } else {
        proj = nc_open(glue("{SAC_SHARES}/outputs/labor/impacts-fedconference-oct2019/median/{rcp}/{gcm}/{iam}/{ssp}/labor_test-damages-{adapt}-{version}.nc4"))
    }
    
    data_frames = list()

    for (var in variables){

	    val = ncvar_get(proj, var) %>%
	        as.data.frame()

	    yr = ncvar_get(proj, "year")

	    if (aggregated == FALSE) {
	        colnames(val) = yr
	        region = ncvar_get(proj, "regions")    
	        val$region = region
	        long = melt(val, id.vars=c("region"), variable.name = "year", value.name = var)
	    } else {
	        colnames(val) = var
	        val$year = yr
	        long = val
	    }
	    
	    data_frames[[var]] = long
	}

    nc_close(proj)

    if (aggregated == TRUE) {
    	data_long = data_frames %>% reduce(left_join, by=c("year"))
    } else {
    	data_long = data_frames %>% reduce(left_join, by=c("region", "year"))	
    }
   
    return(data_long)
}

prep_data = function(variables, gcm, rcp, ssp="SSP3", iam="high", adapt="fulladapt", version=1.1) {
	projection = load_projection(variables = variables, gcm=gcm, rcp=rcp, adapt=adapt, version=version)

	for (var in variables) {
		projection[glue("cil_{var}")] = projection[var]
	}

	projection %<>%
		mutate(
			gcm = gcm,
			rcp=rcp,
			ssp=ssp,
			model=iam,
			batch=NA) %>% # batch is here for compatibility w/ damage func code. Doesn't have any meaning in this context.
		select(-variables)

	return(projection)
}

get_damages = function(variables, gcms, rcps, adapt="fulladapt", version=1.1) {
	# note: gcms and rcps should be given in a vectorized format
	dat = mcmapply(prep_data, gcm=gcms, rcp=rcps, 
		MoreArgs = list(variables=variables, adapt=adapt, version=version),
		SIMPLIFY=FALSE, mc.cores=16)

	bound = do.call(rbind, dat)

	return(bound)
}

# specs
models_rcp45 =  c('ACCESS1-0','bcc-csm1-1','BNU-ESM','CanESM2','CCSM4','CESM1-BGC','CNRM-CM5','CSIRO-Mk3-6-0','GFDL-CM3','GFDL-ESM2G','GFDL-ESM2M',
    'IPSL-CM5A-LR','IPSL-CM5A-MR','MIROC-ESM-CHEM','MIROC5','MPI-ESM-LR', 'MRI-CGCM3','inmcm4','NorESM1-M') # MIROC-ESM # MRI-ESM-MR

models_rcp85 =  c('ACCESS1-0','BNU-ESM','CanESM2','CCSM4','CESM1-BGC','CNRM-CM5','CSIRO-Mk3-6-0','GFDL-CM3','GFDL-ESM2G','GFDL-ESM2M',
    'IPSL-CM5A-LR','IPSL-CM5A-MR','MIROC-ESM-CHEM', 'MIROC-ESM','MIROC5','MPI-ESM-LR','MPI-ESM-MR','MRI-CGCM3','inmcm4','NorESM1-M')

surrogates_rcp45 = c('surrogate_GFDL-ESM2G_01','surrogate_GFDL-ESM2G_11','surrogate_MRI-CGCM3_01','surrogate_MRI-CGCM3_06',
            'surrogate_MRI-CGCM3_11','surrogate_GFDL-CM3_89','surrogate_GFDL-CM3_94','surrogate_GFDL-CM3_99','surrogate_CanESM2_89',
            'surrogate_CanESM2_94','surrogate_CanESM2_99')

surrogates_rcp85 = c('surrogate_MRI-CGCM3_01','surrogate_MRI-CGCM3_06','surrogate_MRI-CGCM3_11','surrogate_GFDL-ESM2G_01',
            'surrogate_GFDL-ESM2G_06','surrogate_GFDL-ESM2G_11','surrogate_GFDL-CM3_89','surrogate_GFDL-CM3_94',
            'surrogate_GFDL-CM3_99','surrogate_CanESM2_89','surrogate_CanESM2_94','surrogate_CanESM2_99')

spec = rbind(expand.grid(models=c(models_rcp45, surrogates_rcp45), rcps=c("rcp45")),
	expand.grid(models=c(models_rcp85, surrogates_rcp85), rcps="rcp85"))

valuecsv = get_damages(variables=c("damages_total", "damages_total_percent", "impacts_combined", "impacts_riskhigh"), gcms=spec$models, rcps=spec$rcps, version=1.3)

# write value csv
fwrite(valuecsv, file=glue("{SAC_SHARES}/outputs/labor/impacts-fedconference-oct2019/median/valuecsv-1.3.csv"))

# apply weights to get quantiles and plot
# use_python(system("which python", intern=T), required = T)
use_python("/home/sgreenhill/miniconda3/envs/risingverse-py27/bin/python", required=TRUE)
prospectus.tools.lib = glue("{REPO}/prospectus-tools/gcp/extract")
dm_testing = glue("{REPO}/gcp-energy/rationalized/2_projection/delta_method_debugging/")

setwd(prospectus.tools.lib)
source_python(paste0(dm_testing,'/fetch_weight.py'))
fetch_weight.memo = addMemoization(fetch_weight)

get.normalized.weights <- function (gcms, rcp) {
    weights.list = mapply(FUN = fetch_weight.memo, gcm = gcms, rcp = rcp, SIMPLIFY = FALSE)
    normalized.weights.list = mapply(FUN = `/`, weights.list, Reduce("+",weights.list), SIMPLIFY = FALSE)
    return(normalized.weights.list)
}

# get weighted quantiles of valuecsv
quantiles = function(q, rcp, valuecsv, variable) {
	# notes: 
	# q argument can be "mean" or a number of quantile
	# variable argument should be a quosure
	
	w = get.normalized.weights(gcms=c(get(glue("models_{rcp}")), get(glue("surrogates_{rcp}"))), rcp=rcp) %>%
		as.data.frame() %>%
		t() %>%
		as.data.frame() %>%
		rename(weight = V1)

	w$gcm = gsub("\\.", "-", rownames(w))

	damages = valuecsv %>%
		mutate(gcm = as.character(gcm)) %>%
		mutate(val = as.numeric(!!variable)) %>%
		# dplyr::filter(rcp == rcp) %>%
		left_join(w, by="gcm") %>%
		dplyr::filter(!is.na(weight))

	damages = damages[damages$rcp == rcp,]
		
	if (q == "mean") {
		result = damages %>%
			group_by(year) %>%
			summarize(val = weighted.mean(x=val, w=weight, na.rm=T))
	} else {
		# expand dataframe by correct weights
		damages_expanded = damages[rep(row.names(damages), damages$weight * 10^4),]

		result = damages_expanded %>%
			group_by(year) %>%
			summarize(val = quantile(val, q, na.rm=T))
	}

	result %<>% 
		ungroup() %>%
		mutate(val = as.numeric(val),
			year = as.numeric(year)) %>%
		data.frame()

	return(result)
}

# plot multimodel time series
plot_ts = function(rcp, valuecsv, variable, y.label, out, ub=NULL, ub.2=NULL, lb=NULL, lb.2=NULL, plot_adapt=FALSE, valuecsv_ia=NULL, valuecsv_na=NULL, version=1.1) {
	
	m = quantiles(q="mean", variable=variable, rcp=rcp, valuecsv=valuecsv)
	
	if (plot_adapt == TRUE) {
		mean_ia = quantiles(q="mean", variable=variable, rcp=rcp, valuecsv=valuecsv_ia)
		mean_na = quantiles(q="mean", variable=variable, rcp=rcp, valuecsv=valuecsv_na)
		df.list = list(m, mean_ia, mean_na)

		# ub_df = quantiles(q=ub, variable=variable, rcp=rcp, valuecsv=valuecsv) %>%
		# 	rename(ub = val)
		# lb_df = quantiles(q=lb, variable=variable, rcp=rcp, valuecsv=valuecsv) %>%
		# 	rename(lb = val)
		# ub.2_df = quantiles(q=0.95, variable=variable, rcp=rcp, valuecsv=valuecsv_ia) %>%
		# 	rename(ub.2 = val)
		# lb.2_df = quantiles(q=0.05, variable=variable, rcp=rcp, valuecsv=valuecsv_ia) %>%
		# 	rename(lb.2 = val)

		# u_df = Reduce(function(x,y){merge(x,y,by="year") %>% rename()}, list(ub_df, lb_df, ub.2_df, lb.2_df))

		p = ggtimeseries(
			df.list=df.list,
			y.label=y.label,
			rcp.value=rcp,
			ssp.value="SSP3",
			iam.value="high") 
			# geom_ribbon(data = u_df, aes(x=u_df[,"year"], ymin=u_df[,"lb"], ymax=u_df[,"ub"]), fill = "black", linetype=2, alpha=0.2) + 
			# geom_ribbon(data = u_df, aes(x=u_df[,"year"], ymin=u_df[,"lb.2"], ymax=u_df[,"ub.2"]), fill = "black", linetype=2, alpha=0.1) + 
			# theme(legend.position = "None")

		filename = glue("{out}/multimodel/TimeSeries_multimodel_{rcp}_SSP3_high_{quo_name(variable)}_adapts-{version}.pdf")	
	} else {
		ub_df = quantiles(q=ub, variable=variable, rcp=rcp, valuecsv=valuecsv) %>%
			rename(ub = val)
		lb_df = quantiles(q=lb, variable=variable, rcp=rcp, valuecsv=valuecsv) %>%
			rename(lb = val)
		ub.2_df = quantiles(q=ub.2, variable=variable, rcp=rcp, valuecsv=valuecsv) %>%
			rename(ub.2 = val)
		lb.2_df = quantiles(q=lb.2, variable=variable, rcp=rcp, valuecsv=valuecsv) %>%
			rename(lb.2 = val)
		df.list = list(mean)

		u_df = Reduce(function(x,y){merge(x,y,by="year") %>% rename()}, list(ub_df, lb_df, ub.2_df, lb.2_df))

		p = ggtimeseries(
			df.list = list(m),
			y.label = y.label,
			rcp.value = rcp,
			ssp.value = "SSP3",
			iam.value = "high",
			legend.values = "black",
			# df.u = u_df,
			# ub = "ub",
			# lb = "lb"
			) + 
		geom_ribbon(data = u_df, aes(x=u_df[,"year"], ymin=u_df[,"lb"], ymax=u_df[,"ub"]), fill = "black", linetype=2, alpha=0.2) + 
		geom_ribbon(data = u_df, aes(x=u_df[,"year"], ymin=u_df[,"lb.2"], ymax=u_df[,"ub.2"]), fill = "black", linetype=2, alpha=0.1) + 
		theme(legend.position = "None")

		filename = glue("{out}/multimodel/TimeSeries_multimodel_{rcp}_SSP3_high_{quo_name(variable)}-{version}.pdf")	
	}

	dir.create(glue("{out}/multimodel/"), recursive = TRUE)
	ggsave(p, file=filename, width=7, height=7)
	return(glue("{filename}.pdf saved."))	
}

plot_ts(
	rcp="rcp85",
	ub = 0.75,
	ub.2 = 0.95,
	lb = 0.25,
	lb.2 = 0.05,
	valuecsv=valuecsv,
	variable=quo(cil_damages_total),
	y.label = "Total damages (2019 USD)",
	out=output,
	version=1.3)

plot_ts(
	rcp="rcp45",
	ub = 0.75,
	ub.2 = 0.95,
	lb = 0.25,
	lb.2 = 0.05,
	valuecsv=valuecsv,
	variable=quo(cil_damages_total),
	y.label = "Total damages (2019 USD)",
	out=output,
	version=1.3)

plot_ts(
	rcp="rcp85",
	ub = 0.75,
	ub.2 = 0.95,
	lb = 0.25,
	lb.2 = 0.05,
	valuecsv=valuecsv,
	variable=quo(cil_damages_total_percent),
	y.label = "Damages as fraction of global GDP",
	out=output,
	version=1.3)

plot_ts(
	rcp="rcp85",
	ub = 0.75,
	ub.2 = 0.95,
	lb = 0.25,
	lb.2 = 0.05,
	valuecsv=valuecsv,
	variable=quo(cil_impacts_combined),
	y.label = "Average change in minutes worked per worker per day",
	out=output,
	version=1.3)

plot_ts(
	rcp="rcp85",
	plot_adapt=TRUE,
	# ub = 0.75,
	# ub.2 = 0.75,
	# lb = 0.25,
	# lb.2 = 0.25,
	valuecsv=valuecsv,
	valuecsv_ia=valuecsv_incadapt,
	valuecsv_na=valuecsv_noadapt,
	variable=quo(cil_impacts_combined),
	y.label =  "Average change in minutes worked per worker per day",
	out=output,
	version=1.3)

# plot % GDP time series for mortality and labor together
mean_labor = quantiles(q="mean", variable=quo(cil_damages_total_percent), rcp="rcp85", valuecsv=valuecsv)
mean_mort = fread(glue("{DB}/Global ACP/ClimateLaborGlobalPaper/Paper/Projections/FedConference2019/TimeSeries/mortality/mortality_shareGDP_rcp85-high-SSP3_vly-epa-scaled.csv")) %>%
	rename(val = mortality_share_gdp) %>%
	as.data.frame()

p = ggtimeseries(
	df.list = list(mean_labor, mean_mort),
	y.label = "Damages as fraction of global GDP",
	rcp.value = "rcp85",
	ssp.value = "SSP3",
	iam.value = "high",
	legend.title = "Sector",
	legend.breaks = c("Labor", "Mortality"),
	legend.values = c("#2c7bb6", "#d7191c")
	)

ggsave(p, file=glue("{output}/multimodel/TimeSeries_multimodel_rcp85_SSP3_cil_damages_total_percent_mortality-1.3.pdf"))


plot_ts(
	rcp="rcp85",
	plot_adapt=TRUE,
	# ub = 0.75,
	# ub.2 = 0.95,
	# lb = 0.25,
	# lb.2 = 0.05,
	valuecsv=valuecsv,
	valuecsv_ia=valuecsv_incadapt,
	valuecsv_na=valuecsv_noadapt,
	variable = quo(cil_impacts_riskhigh),
	y.label="Average change in minutes worked per worker per day, high risk workers",
	out=output,
	version=1.2
	)

# plot time series of mean damages across rcps
mean_rcp85 = quantiles(q="mean", variable=quo(cil_damages_total), rcp="rcp85", valuecsv=valuecsv)
mean_rcp45 = quantiles(q="mean", variable=quo(cil_damages_total), rcp="rcp45", valuecsv=valuecsv)

p = ggtimeseries(
	df.list = list(mean_rcp45, mean_rcp85),
	y.label = "Total damages (2019 USD)",
	rcp.value = "",
	ssp.value = "SSP3",
	iam.value = "high",
	legend.title = "RCP",
	legend.breaks = c("4.5", "8.5"),
	legend.values = c("#2c7bb6", "#d7191c")) +
theme(plot.title=element_blank())

ggsave(p, file=glue("{output}/multimodel/TimeSeries_multimodel_rcp85_rcp45_SSP3_cil_damages_total-1.3.pdf"))

# plot time series of damages as % of GDP across rcps
mean_rcp85 = quantiles(q="mean", variable=quo(cil_damages_total_percent), rcp="rcp85", valuecsv=valuecsv)
mean_rcp45 = quantiles(q="mean", variable=quo(cil_damages_total_percent), rcp="rcp45", valuecsv=valuecsv)

p = ggtimeseries(
	df.list = list(mean_rcp45, mean_rcp85),
	y.label = "Damages as fraction of global GDP",
	rcp.value = "",
	ssp.value = "SSP3",
	iam.value = "high",
	legend.title = "RCP",
	legend.breaks = c("4.5", "8.5"),
	legend.values = c("#2c7bb6", "#d7191c")) +
theme(plot.title=element_blank())

ggsave(p, file=glue("{output}/multimodel/TimeSeries_multimodel_rcp85_rcp45_SSP3_cil_damages_total_percent-1.3.pdf"))





