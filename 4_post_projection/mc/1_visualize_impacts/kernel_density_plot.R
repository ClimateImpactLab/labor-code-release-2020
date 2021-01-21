# Kernel Density Plotting Function

# This function returns a kernel density plot from a specific impact region from projection impacts
# Updated 29 Oct 2020 by Ruixue Li 

#----------------------------------------------------------------------------------



rm(list = ls())
source("~/repos/labor-code-release-2020/0_subroutines/paths.R")
source("~/repos/post-projection-tools/mapping/imgcat.R") #this redefines the way ggplot plots. 

# Load in the required packages, installing them if necessary 
if(!require("pacman")){install.packages(("pacman"))}
pacman::p_load(ggplot2, 
               dplyr,
               readr)
library(glue)
library(parallel)

source(paste0(DIR_REPO_LABOR, "/4_post_projection/0_utils/mapping.R"))


#create function that plots kernel density
ggkd <- function(df.kd = NULL,
                 topcode.ub = NULL, topcode.lb = NULL, 
                 yr = NULL, ir.name = NULL, 
                 x.label = NULL, y.label = "Density", 
                 kd.color = "grey50") {
  

  # browser()
  df.kd = df.kd %>% filter(!is.na(value))

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
  

  print(paste0('--- IR MEAN IS', ir_mean, ' ----'))

  print(paste0('--- IR MEAN IS', mean(ir_fin$value), ' ----'))
  
  #calculate gcm-weighted mean per year per batch per IR 
  #ir_fin$wt_value <- ir_fin$value * ir_fin$weight #multiply value by weight 
  #ir_mean <- aggregate(list(value = (ir_fin$wt_value)), by = list(year = ir_fin$year, region = ir_fin$region), FUN = sum, na.rm = T) #get the average value across the batches for each year per IR
  
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
    geom_hline(yintercept=0, size=.2, alpha = 0.5) + #zeroline
    geom_vline(xintercept = ir_mean, size=.9, alpha = 1, lty = "solid", color = "white") + #mean line
    #scale_x_continuous(expand=c(0, 0)) +
    theme_bw() +
    theme(panel.grid.major = element_blank(), 
          panel.grid.minor = element_blank(),
          panel.background = element_blank(), 
          axis.line = element_line(colour = "grey80", size = 0.2),
          plot.title = element_text(hjust=0.5, size = 10), 
          plot.caption = element_text(hjust=0.5, size = 7),
          axis.text.x = element_text(size=7, hjust=.5, vjust=.5, face="plain")) +
    xlab(x.label) + ylab(y.label) +
    labs(title = paste0("Kernel Density Plot ",yr," ",ir.name), 
         caption = paste0("GCM-weighted mean = ", round(ir_mean, 6)))  
  
  return(p)
}

regions = c(
  "COD.7.29.103", # (1)Kinshasa Urban
  "KEN.4.22.R2947e0197ea9b378", # (2) Nairobi West
  "MMR.14.62.285", # (3)Rangoon, Burma (Yangon (Rangoon))
  "VNM.2.18.Ra5f28dabe4b12dfc", # (4)Hanoi, Vietnam 
  "IND.10.121.371", # (5) Delh
  "CHN.1.14.66", # (6) Suzhou, China
  "PRK.11.170", #(7)Pyongyang, Korea, North
  "PER.15.135.1340",  # (8) Lima, Peru 
  "JPN.22.962", # (9) Kyoto, Japan 
  "AUS.11.Rea19393e048c00bc" 
  )


# code to find the cities in deciles: 

# all_IRs = read_csv(paste0(DIR_REPO_LABOR, "/data/misc/IR_names_w_deciles.csv"))
# cities_500 = read_csv(paste0(DIR_REPO_LABOR, "/data/misc/unit_population_projections_geography_500kcities_years_all_SSP3.csv")) %>%
#             mutate(region = Region_ID) %>%
#             dplyr::select(city, country, region)
# cities_w_deciles = merge(cities_500, all_IRs, by = "region")
# cities_w_deciles %>% dplyr::filter(decile == 10)


for (rg in regions) {
  input.dir = "/shares/gcp/estimation/labor/code_release_int_data/projection_outputs/extracted_data_mc"

  df = read_csv(paste0(input.dir, "/SSP3-",rg,"valuescsv_gdp_",rg,".csv")) %>%
        # dplyr::mutate(value = value*100000) %>%
        dplyr::filter(year %in% 2099) %>%
        dplyr::mutate(value = value * 100) %>%
        data.frame() 
    
  gg2 = ggkd(df.kd = dplyr::filter(df) , ir.name = rg,
      y.label = "density", x.label = "percentage GDP")
  # +
  #     scale_y_continuous(limits = c(0,1))
  
      #  , topcode.ub = 100, topcode.lb = -50) +
      # scale_x_continuous(expand=c(0, 0), limits = c(-300,600)) 
    
  # browser()
  ggsave(paste0(DIR_FIG,'/mc/kernel_density_',rg ,"_2099.pdf"), plot=gg2, width = 7, height = 7)
      
}









