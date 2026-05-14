#==============================================================================#
# Density plot functions for labor
#
# Original function by Ruixue Li circa 2020, last edits from Nishka Sharma in 2026
#
# Description:
#
#   These function together plot the IR level density of impacts from labor MCs in 
#   figure 6 of the labor paper
#
#==============================================================================#

#==============================================================================#
# ggkd() documentation ----
#
# Input:
#   - df.kd: the base data to use, it should be an IR level csv file of impacts
#   - ir.name: name of the IR being plotted
#   - x.label: x-axis label
#   - y.label: y-axis label
#
# Optional Input:
#   - topcode.up: value of upper limit of the density plot
#   - topcode.lb: value of lower limit of the density plot
#   - yr: year to be plotted
#
#==============================================================================#

#==============================================================================#
# impacts.density.plot() documentation ----

# Input:
#   - model.name: the model being plotted the base map to use, it should be a shape file of IR level polygons
#   - rcp: rcp the map is being made for. valid values are "rcp45" and "rcp85." 
#          used to read the file and assign title of the map. 
#   - ssp: ssp the map is being made for. valid values are "SSP1", "SSP2", "SSP3", "SSP4", "SSP5".
#          used to read the file and assign title of the map
#   - iam: iam the map is being made for. valid values are "high" and "low". 
#          used to read the file and assign title of the map
#   - adapt: adaptation scenario the map is being made for. valid values are "fulladapt", "incadapt", "noadapt". 
#            used to read the file and assign title of the map
#   - impact: type of impact the map is being made for. used to read the file. 
#             valid values are: "clip" - this variable stores projected share of high risk workers
#                               "rebased" - this variable stores projected impacts in time spent working
#   - aggregation: applicable only if impact is "rebased". default values is "" 
#                  "" - impacts in minutes worked
#                  "-gdp-levels" - impacts as % of GDP
#                  "-pop-levels" - impacts in population weighted minutes
#                  "-wage-levels" - impacts in million dollars
#   - regions: impact regions for which density plot is being made
#   - year: the year for which map is being made. used to filter the data and assign title of the map
#   - output.folder: location of the maps
#==============================================================================#

# function that plots kernel density
ggkd <- function(df.kd = NULL,
                 topcode.ub = NULL, topcode.lb = NULL, 
                 yr = NULL, ir.name = NULL, 
                 x.label = NULL, y.label = "Density", 
                 kd.color = "grey50") {
  
  ir_fin <- df.kd
  
  ir_mean <- weighted.mean(ir_fin$value, ir_fin$weight) #calculate weighted mean
  
  #calculate weighted standard deviation
  weighted.sd <- function(x,w){ 
    mu <- weighted.mean(x,w)
    u <- sum(w*(x-mu)^2)
    d <- ((length(w)-1)*sum(w))/length(w)
    s <- sqrt(u/d)  
    return(s)
  }
  
  ir_sd <- weighted.sd(ir_fin$value, ir_fin$weight) 
  
  if(is.null(yr)){ #assign year
    yr <- ir_fin$year[1]
  }
  
  if(is.null(ir.name)){ #assign ir.name
    ir.name <- ""
  }
  
  ir_fin$weight <- ir_fin$weight/sum(ir_fin$weight) #normalize weights so they sum to 1
  
  if (!is.null(topcode.ub)){ #assign topcode if needed
    ir_fin$value <- ifelse(ir_fin$value>topcode.ub, topcode.ub, ir_fin$value) 
  }
  
  if (!is.null(topcode.lb)){ #assign bottomcode if needed
    ir_fin$value <- ifelse(ir_fin$value<topcode.lb, topcode.lb, ir_fin$value) 
  }
  
  # check the values   
  print(paste0('--- IR MEAN IS ', ir_mean, ' ----'))
  print(paste0('--- IR MEAN IS ', mean(ir_fin$value), ' ----'))
  
  #calculate density
  ir_fin_density <- data.frame(density(ir_fin$value, weights = ir_fin$weight)[c("x", "y")])
  print(names(ir_fin_density))
  print(mean(ir_fin_density$x))
  print(mean(ir_fin_density$y))
  
  #plot kernal density
  print(paste0("plotting kernel density for ", ir.name, yr))
  
  p <- ggplot(ir_fin_density, aes(x, y)) +
    geom_area(fill = kd.color, alpha = .9) + #full distribution #grey
    geom_area(data = subset(ir_fin_density, x < (ir_mean - ir_sd)), fill = "white", alpha = .3) + #1 sd below
    geom_area(data = subset(ir_fin_density, x < (ir_mean - (2*ir_sd))), fill = "white", alpha = .4) + #2 sd below
    geom_area(data = subset(ir_fin_density, x > (ir_mean + ir_sd)), fill = "white", alpha = .3) + #1 sd above
    geom_area(data = subset(ir_fin_density, x > (ir_mean + (2*ir_sd))), fill = "white", alpha = .4) + #2 sd above
    geom_hline(yintercept=0, lwd=.2, alpha = 0.5) + #zeroline
    geom_vline(xintercept = ir_mean, lwd=.9, alpha = 1, lty = "solid", color = "white") + #mean line
    #scale_x_continuous(expand=c(0, 0)) +
    theme_classic() +
    theme(axis.line = element_line(colour = "grey80", size = 0.2),
          plot.title = element_text(hjust=0.5, size = 10), 
          plot.caption = element_text(hjust=0.5, size = 7),
          axis.text.x = element_text(size=7, hjust=.5, vjust=.5, face="plain")) +
    xlab(x.label) + ylab(y.label) +
    coord_cartesian(xlim = c(-5, 30), ylim = c(0, 1.25)) +
    scale_x_continuous(breaks = seq(-5, 30, by = 5)) #+
  # labs(title = paste0("Kernel Density Plot ", yr, " ", ir.name), 
  #      caption = paste0("GCM-weighted mean = ", round(ir_mean, 6)))  
  
  return(p)
}


# run ggkd for all IRs
impacts.density.plot <- function(model.name, ssp, rcp, iam, impact, adapt, 
                                 aggregation, regions, year, output.folder){
  for (ir in regions) {
    
    # clean the data
    df.ir = read_csv(glue('{input_path}/{model.name}/kernel_density/{ssp}-{rcp}_{iam}_{impact}_{adapt}{aggregation}-{ir}.csv')) %>%
      dplyr::filter(year == !!year) %>%
      dplyr::mutate(value = -value * 100) %>% 
      data.frame() 
    # browser()
    
    df.ir = df.ir %>% arrange(desc(value))  
    
    # plot the data
    p = ggkd(df.kd = df.ir, 
             ir.name = ir,
             y.label = "", 
             x.label = "Worker disutility costs of climate change \n(% of 2099 GDP)")
    
    ggsave(glue("{output.folder}/{ir}-{ssp}-{rcp}_{iam}_{impact}_{adapt}{aggregation}_{year}_density.png"), p, dpi = 300, width = 15.75, height = 5)
  }
}

