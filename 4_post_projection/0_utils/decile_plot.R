#==============================================================================#
# deciles.plot() documentation ----

# Input:
#   - model.name: name of the model being plotted the base map to use, it should be a shape file of IR level 
#            polygons
#   - rcp: rcp the map is being made for. valid values are "rcp45" and "rcp85." 
#          used to read the file and assign title of the map. 
#   - ssp: ssp the map is being made for. valid values are "SSP1", "SSP2", "SSP3", "SSP4", "SSP5".
#          used to read the file and assign title of the map
#   - iam: iam the map is being made for. valid values are "high" and "low". 
#          used to read the file and assign title of the map
#   - adapt: adaptation scenario the map is being made for. valid values are "fulladapt", "incadapt", "noadapt". 
#            used to read the file and assign title of the map
#   - aggregation: applicable only if impact is "rebased". default values is "" 
#                  "" - impacts in minutes worked
#                  "-gdp-levels" - impacts as % of GDP
#                  "-pop-levels" - impacts in population weighted minutes
#                  "-wage-levels" - impacts in million dollars
#   - covar: the x-axis variable whose deciles are being made
#   - year_fin: the year for which the decile plot is being made.
#   - baseline: the year in which deciles are being calculated
#   - output.dir: location of the maps
#==============================================================================#

# Produces box-and-whisker plots of future impacts at deciles of today's income
# and climate distributions (Figures 7)
deciles.plot = function(model.name, ssp, iam, rcp, adapt, aggregation, covar, 
                        year_fin = 2099, baseline = 2015, output.dir){
  
  # read end of century impacts
  impacts_fin = read_csv(glue('{input_path}/{model.name}/{rcp}/{iam}/{ssp}/{ssp}-{rcp}_{iam}_rebased_{adapt}{aggregation}.csv')) %>%
    dplyr::filter(year == !!year_fin)
  
  # loggdppc, climtas and population 
  cov_path = glue('{ROOT_INT_DATA}/projection_outputs/covariates',
                  '/{ssp}-{rcp}_{iam}_covariates_decile_plots.csv')
  
  # read population data in baseline year
  pop.baseline = read_csv(cov_path) %>% 
    dplyr::filter(year == !!baseline) %>% 
    dplyr::select(region, population)
  
  # read population data in final year
  pop.EOC = read_csv(cov_path) %>%
    dplyr::filter(year == !!year_fin) %>% 
    dplyr::select(region, population)
  
  stopifnot(covar == 'loggdppc' | covar == 'climtas')
  
  # 2015 income and climate
  covariates = read_csv(cov_path) %>%
    dplyr::filter(year == !!baseline) %>% 
    dplyr::select(region, loggdppc, climtas)
  
  # merge in baseline population
  covariates = left_join(covariates, pop.baseline, by = "region")
  # generate weights
  covariates <- covariates %>%
    filter(!is.na(population)) %>%
    mutate(pop = population/sum(population, na.rm = TRUE))
  
  # weighted quantiles.
  quantile_cov_box = data.frame(cov = rep(covariates[[covar]], times = covariates$pop*100000000))
  quantiles_cov = quantile(quantile_cov_box['cov'], probs = seq(0, 1, by = 0.1), na.rm = T)
  
  # assign values based on quantiles
  covariates$quantile = cut(covariates[[covar]], breaks = quantiles_cov, 
                            labels = c("1","2","3","4","5","6","7","8","9","10"), include.lowest=TRUE)
  
  # merge deciles into impacts df
  impacts_fin = left_join(impacts_fin, covariates, by = "region")
  
  # count the number of impact regions in each quantile
  total = 0
  for (qt in 1:10){
    count = length(unique(impacts_fin$region[impacts_fin$quantile==qt]))
    print(paste0("There are ", count, " impact regions in decile ", qt))
    total = total + count
  }
  
  # assign x label based on decile covariate
  if (covar == 'loggdppc'){
    x_title = "2015 Income Decile"
    cities = data.frame(
      decile = factor(c(1, 4, 7, 10)),
      label = c("Mogadishu,\nSomalia", "Kolkata,\nIndia", "Kyiv,\nUkraine", "Chicago,\nUSA")
    )
  } else { #share
    x_title = "2015 Annual Average Temperature Decile"
    cities = data.frame(
      decile = factor(c(1, 4, 7, 10)),
      label = c("Oslo,\nNorway", "Buenos Aires,\nArgentina", "Orlando,\nUSA", "Khartoum,\nSudan")
    )
  }
  
  # assign y label based on adaptation scenario
  if (aggregation == "-pop-levels") {
    y_title <- "Pop Weighted Impacts - Mins Worked"
    
  } else if (aggregation == "-gdp-levels") {
    y_title <- glue("Climate change-induced worker disutility \n(percent of {year_fin} GDP)")
    
  } else if (aggregation == "-wage-levels") {
    y_title <- glue("Climate change-induced worker disutility \n(million dollars)")
    
  } else if (aggregation == "") {
    y_title <- glue("Climate change-induced change in minutes worked per worker per day")
    
  } else {
    print("wrong aggregation!")
    return()
    
  }
  
  # create a blank quantiles df
  quantiles.df = c()
  for (decile_num in 1:10) { #loop over quantiles
    
    print(paste("subsetting to quantile", decile_num))
    
    #subset to decile
    impacts_quantile = dplyr::filter(impacts_fin, quantile == decile_num)
    
    length(unique(impacts_quantile$region))
    
    # select the impacts variable to show in boxplots
    impacts_quantile$value = impacts_quantile$mean
    color.bar = "dodgerblue4"
    
    # calculate 2099 pop-weighted median and quantiles.
    impacts_quantile_year = impacts_quantile %>%
      dplyr::select(-pop, -population) %>%
      left_join(pop.EOC, by = c("region")) 
    
    impacts_quantile_year <- impacts_quantile_year %>%
      filter(!is.na(population)) %>%
      mutate(pop = population/sum(population, na.rm = TRUE))
    
    quantile_box = data.frame(value = rep(impacts_quantile_year$value, times = impacts_quantile_year$pop*100000000)) 
    quantiles = quantile(quantile_box$value, probs = c(0.01, 0.05, 0.1, 0.25, 0.5, 0.75, 0.9, 0.95, 0.99), na.rm = T)
    
    # collect everything in a dataframe
    whisker = data.frame(
      decile = factor(decile_num), #set position 
      minerrorbar = -100*quantiles['5%'], # multiply by -100 to convert to % and display results on positive y-axis
      maxerrorbar = -100*quantiles['95%'],
      whisker_min = -100*quantiles['10%'], 
      whisker_max = -100*quantiles['90%'], 
      box_lower = -100*quantiles['25%'], 
      box_upper = -100*quantiles['75%'],
      middle.median = -100*quantiles['50%'],
      middle.mean = -100*weighted.mean(impacts_quantile_year$value, impacts_quantile_year$pop)) # population weighted-mean
    
    # bind rows to combine into one df
    quantiles.df = rbind(quantiles.df, whisker) 
  }
  
  p = ggplot() + 
    geom_errorbar(
      data = quantiles.df,  
      aes(x=decile, ymin = minerrorbar, ymax = maxerrorbar), 
      color = color.bar,
      lty = "solid",
      width = 0,
      alpha = 0.5,
      lwd = 0.5) +
    geom_boxplot(
      data = quantiles.df, 
      aes(group=decile, x=decile, ymin = whisker_min, ymax = whisker_max, 
          lower = box_lower, upper = box_upper, middle = middle.median), 
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
    geom_abline(intercept=0, slope=0, lwd=0.1, alpha = 0.5) + 
    scale_fill_gradientn(
      colors = rev(brewer.pal(9, "RdGy"))) + 
    scale_color_gradientn(
      colors = rev(brewer.pal(9, "RdGy"))) + 
    scale_x_discrete(limits=factor(seq(1,10)), breaks=factor(seq(1,10))) +
    geom_segment(
      data = cities,
      aes(x = decile, xend = decile, y = -4.2, yend = -4.7),
      arrow = arrow(length = unit(0.2, "cm"), type = "closed"),
      color = "black",
      lwd = 0.3) +
    geom_text(
      data = cities,
      aes(x = decile, y = -3.95, label = label),
      size = 2.5,
      lineheight = 0.8) +
    theme_bw() +
    theme(
      panel.grid.major = element_blank(), 
      panel.grid.minor = element_blank(),
      panel.background = element_blank(),
      legend.position="none",
      axis.line = element_line(colour = "black")) +
    xlab(x_title) +
    ylab(y_title) +
    coord_cartesian(ylim = c(-4, 10), clip = "off") # change this according to the widest y-axis range
  
  # save the plot
  ggsave(p, file = glue("{output.dir}/deciles_{adapt}_{ssp}_{rcp}_{iam}_{covar}.png"), width = 6, height = 7)
}
