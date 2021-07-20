# Purpose: Master R script for reproducing post-projection figures in Carleton
# et al. (2019).
# 
# This script reproduces Figures 1 (Panel A), 3, 5, 6, 7, 8, and 11. It's
# organized into six sections:
# 
# 1.  Data Coverage.
# 2.  Temperature sensitivity of mortality maps and response function plots.
# 3.  End of century mortality risk of climate change maps and density plots.
# 4.  Time series of projected mortality risk of climate change.
# 5.  The impact of climate change in 2100 compared to contemporary leading
#     causes of death.
# 6.  2099 impacts of climate change by decile of today's income and climate.
# 7.  Appendix F figures.
# 
# The toggles below control which portions of the analysis are run.

rm(list=ls())

# TOGGLES
Part1 = TRUE # Data coverage
Part2 = TRUE # Temp. sensitivity maps and response Functions
Part3 = TRUE # Maps and histograms
Part4 = TRUE # Time series
Part5 = TRUE # Bar Chart
Part6 = TRUE # Decile plot
Appendix = FALSE # Appendix F figures.

# RCP scenario ('rcp85', 'rcp45')
rcp='rcp85' 

# Economic modeling scenario:
#  'low': "IIASA GDP"
#  'high': "OECD Econ Growth"
iam='low'

# SSP ('SSP2', 'SSP3', 'SSP4')
ssp='SSP3'


# Produces box-and-whisker plots of future impacts at deciles of today's income
# and climate distributions (Figures F4 and F5 of the appendix.)

DECILES_OUTPUT = glue("{OUTPUT}/2_projection/figures/appendix/decile_plots")

deciles_plot = function(
    covar,
    ssp='SSP3', 
    iam='low', 
    rcp='rcp85',
    scnlist=c('fulladaptcosts', 'fulladapt', 'costs'),
    year=2099, 
    baseline=2015,
    output_dir=DECILES_OUTPUT,
    demean=FALSE,
    suffix='',
    ftype='pdf') {
    
    #load impacts
    impacts_fin = wrap_mapply(
        scn=c('fulladaptcosts', 'fulladapt', 'costs'),
        FUN=get_mortality_impacts,
        MoreArgs=list(
            year_list=2099, as.DT=T,
            ssp=ssp, iam=iam, rcp=rcp))

    impacts_fin = rbindlist(impacts_fin, use.names=T, idcol='scn')
    impacts_fin = as.data.table(dcast(impacts_fin, region + year ~ scn, value.var='mean'))[, year:=NULL]
    impacts_fin=data.frame(impacts_fin)

    # Load Population (2015, 2099)
    pop.baseline = get_econvar('pop', iam=iam, ssp=ssp, year_list=baseline) %>%
        dplyr::select(region, pop)
    
    pop.EOC = get_econvar('pop', iam=iam, ssp=ssp, year_list=year) %>%
        dplyr::select(region, pop) 

    stopifnot(covar=='loggdppc' | covar=='climtas')
    #baseline pop-weighted deciles
    cov_path = glue('{DB}/2_projection/3_impacts/',
        'main_specification/raw/single/{rcp}/CCSM4/{iam}/{ssp}')

    covariates = get_mortality_covariates(single_path=cov_path, year_list=2015) %>%
                dplyr::select(region, year, climtas, loggdppc)
    
    #merge in baseline population
    covariates = left_join(covariates, pop.baseline, by = "region")
    covariates$pop = covariates$pop/sum(covariates$pop)
    
    # Weighted quantiles.
    quantile_cov_box = data.frame(cov = rep(covariates[,covar],
        times = covariates$pop*100000000))
    quantiles_cov = quantile(quantile_cov_box['cov'], probs = seq(0, 1, by = 0.1), na.rm = T)
    
    #assign values based on quantiles
    covariates$quantile = cut(covariates[,covar], breaks = quantiles_cov, 
        labels = c("1","2","3","4","5","6","7","8","9","10"), include.lowest=TRUE)
                            
    #merge deciles into main df
    impacts_fin = left_join(impacts_fin, covariates, by = "region")
    
    #count the number of impact regions in each quantile
    total = 0
    for (qt in 1:10){
        count = length(unique(impacts_fin$region[impacts_fin$quantile==qt]))
        print(paste0("There are ", count, " impact regions in decile ", qt))
        total = total + count
    }
    
    xlabel = glue('{baseline} {covar} Decile')

    
    # If TRUE, demean each impact by its IR's gcm-weighted mean
    if (demean){
    
        # Calculate each IR's gcm-weighted mean per year
        sum_wts_ir = sum(impacts_fin$weight)/length(unique(impacts_fin$region)) 
        
        # multiply value by weight and normalize weights because they don't sum to one, 
        # and get the average value across the batches for each year per IR
        impacts_fin_year = aggregate(
            list(mean.fulladaptcosts = (impacts_fin$fulladaptcosts*impacts_fin$weight/sum_wts_ir), 
                mean.costs = (impacts_fin$costs*impacts_fin$weight/sum_wts_ir), 
                mean.fulladapt = (impacts_fin$fulladapt*impacts_fin$weight/sum_wts_ir)), 
            by = list(year = impacts_fin$year, region = impacts_fin$region), FUN = sum, na.rm = T) 
        
        #merge IR means into impacts_fin
        impacts_fin = left_join(impacts_fin, impacts_fin_year, by = c("region", "year"))
        
        #demean each impact
        impacts_fin$fulladaptcosts = impacts_fin$fulladaptcosts - impacts_fin$mean.fulladaptcosts
        impacts_fin$fulladapt = impacts_fin$fulladapt - impacts_fin$mean.fulladapt
        impacts_fin$costs = impacts_fin$costs - impacts_fin$mean.costs

        impacts_fin = impacts_fin %>%
            dplyr::select(year, batch, gcm, region, 
                loggdppc, quantile, costs, fulladapt, fulladaptcosts)
        suffix = paste0('_demean', suffix)
    }

    #Create boxplots for each decile
    for (adapt in scnlist) {
        
        quantiles.df = c()
        
        for (q in 1:10) { #loop over quantiles
            
            print(paste("subsetting to quantile", q))
                        
            #subset to decile
            impacts_quantile = dplyr::filter(impacts_fin, quantile == q)
            
            length(unique(impacts_quantile$region))
            
            if (adapt == "fulladapt"){
                impacts_quantile$value = impacts_quantile$fulladapt
                color.bar = "dodgerblue4"
            } else if (adapt == "fulladaptcosts"){
                impacts_quantile$value = impacts_quantile$fulladaptcosts
                color.bar = "turquoise4"
            } else if (adapt == "costs"){
                impacts_quantile$value = impacts_quantile$costs
                color.bar = "maroon"
            } else { #share
                impacts_quantile$value = impacts_quantile$costs/impacts_quantile$fulladaptcosts
            }

            # Calculate 2099 pop-weighted median and quantiles.
            impacts_quantile_year = impacts_quantile %>%
                dplyr::select(-pop) %>%
                left_join(pop.EOC, by = c("region")) 
            impacts_quantile_year$pop = impacts_quantile_year$pop/sum(impacts_quantile_year$pop) 
            quantile_box = data.frame(value = rep(impacts_quantile_year$value, times = impacts_quantile_year$pop*100000000)) 
            quantiles = quantile(quantile_box$value, probs = c(0.01, 0.05, 0.1, 0.25, 0.5, 0.75, 0.9, 0.95, 0.99), na.rm = T)
            
            whisker = data.frame(
                decile = q, #set position 
                minerrorbar = quantiles['5%'],
                maxerrorbar = quantiles['95%'],
                ymin = quantiles['10%'], 
                ymax = quantiles['90%'], 
                lower = quantiles['25%'], 
                upper = quantiles['75%'],
                middle.median = quantiles['50%'],
                middle.mean = weighted.mean(impacts_quantile_year$value, impacts_quantile_year$pop)) #popweighted-mean

             quantiles.df = rbind(quantiles.df, whisker) #combine into one df
             
        }
            
        p = ggplot() + 
            geom_errorbar(
                data = quantiles.df,  
                aes(x=decile, ymin = minerrorbar, ymax = maxerrorbar), 
                color = color.bar,
                lty = "solid",
                width = 0,
                alpha = 0.5,
                size = 0.5) +
            geom_boxplot(
                data = quantiles.df, 
                aes(group=decile, x=decile, ymin = ymin, ymax = ymax, 
                    lower = lower, upper = upper, middle = middle.median), 
                fill=color.bar, 
                color="white",
                size = 0.2, 
                stat = "identity") + #boxplot 
            geom_point(
                data = quantiles.df, 
                aes(x=decile, y = middle.mean, group = 1), 
                size=0.5, 
                color="grey88", 
                alpha = 0.9) + 
            geom_abline(intercept=0, slope=0, size=0.1, alpha = 0.5) + 
            scale_fill_gradientn(
                colors = rev(brewer.pal(9, "RdGy"))) + 
            scale_color_gradientn(
                colors = rev(brewer.pal(9, "RdGy"))) + 
            scale_x_discrete(limits=seq(1,10),breaks=seq(1,10)) +
            theme_bw() +
            theme() +
            theme(
                panel.grid.major = element_blank(), 
                panel.grid.minor = element_blank(),
                panel.background = element_blank(),
                legend.position="none",
                axis.line = element_line(colour = "black")) +
            xlab("2015 Income Decile") +
            ylab("Change in deaths per 100,000 population") +
            coord_cartesian(ylim = c(-350, 600))  +
            ggtitle(paste0(rcp,"-",ssp, "-", iam, "-", adapt)) 

        ggsave(p, file = glue("{output_dir}/deciles_{adapt}_{ssp}_{rcp}_{iam}_{covar}{suffix}.{ftype}"), width = 6, height = 7)
        
    }
}



# Figure F5: Uncertainty in climate change impacts and adaptation costs across 
# present-day income groups. (Demeaned decile plot.)
#   - Dependencies: `2_projection/1_utils/mortality_deciles.R`
#   - Output: `output/2_projection/figures/4_timeseries/appendix/decile_plots`
lapply(c('loggdppc', 'climtas'), deciles_plot. demean=TRUE)

