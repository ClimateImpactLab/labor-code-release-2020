#--------------------------------
# Labor time series with confidence intervals and boxplots
#--------------------------------

rm(list = ls())

library(ggplot2)
library(magrittr)
library(dplyr)
library(readr)

source("/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/0_subroutines/paths.R")
source(paste0(DIR_REPO_LABOR, "/4_post_projection/0_utils/time_series.R"))
source("/project/cil/home_dirs/maiqi/repos/post-projection-tools/timeseries/ggtimeseries.R")
inputwd <- "/project/cil/gcp/outputs/labor/impacts-woodwork/montecarlo/timeseries/"
outputwd <- paste0(DIR_FIG, "/fig8/")



#set up model
set <- 'global'
model <- 'montecarlos'
sector <- 'labor'
poly <- '4'


iam <- list("low")
ssplist <- list("SSP3")
rcplist <- list("rcp85")


for (rcp in rcplist){
  for (ssp in ssplist){
    for (i in iam){
      
      #---------------------------------------------------------------------------
      #plot full adapt + costs (ub only) with uncertainty + end-of-century boxplots
      #---------------------------------------------------------------------------

      
      ubcosts.b <- read.csv(paste0(inputwd, ssp, "-rcp85_low_rebased_fulladapt-gdp-aggregated_global_timeseries.csv")) %>%
        filter(year != 2100)
      ubcosts.b[,3:length(ubcosts.b)] <- ubcosts.b[,3:length(ubcosts.b)]*-100
      
      ubcosts.b.45 <- read.csv(paste0(inputwd, ssp, "-rcp45_low_rebased_fulladapt-gdp-aggregated_global_timeseries.csv")) %>%
        filter(year != 2100)
      ubcosts.b.45[,3:length(ubcosts.b.45)] <- ubcosts.b.45[,3:length(ubcosts.b.45)]*-100
      
      #pull out 7 EOC values for boxplots
      boxplot.85 <- c(ubcosts.b[ubcosts.b$year==2099,'q5'], #rcp8.5 boxplot, vector of 7 values, from whisker to whisker
                      ubcosts.b[ubcosts.b$year==2099,'q10'],
                      ubcosts.b[ubcosts.b$year==2099,'q25'],
                      ubcosts.b[ubcosts.b$year==2099,'mean'],
                      ubcosts.b[ubcosts.b$year==2099,'q75'],
                      ubcosts.b[ubcosts.b$year==2099,'q90'],
                      ubcosts.b[ubcosts.b$year==2099,'q95'])
      
      boxplot.45 <- c(ubcosts.b.45[ubcosts.b.45$year==2099,'q5'], #rcp4.5 boxplot, vector of 7 values, from whisker to whisker
                      ubcosts.b.45[ubcosts.b.45$year==2099,'q10'],
                      ubcosts.b.45[ubcosts.b.45$year==2099,'q25'],
                      ubcosts.b.45[ubcosts.b.45$year==2099,'mean'],
                      ubcosts.b.45[ubcosts.b.45$year==2099,'q75'],
                      ubcosts.b.45[ubcosts.b.45$year==2099,'q90'],
                      ubcosts.b.45[ubcosts.b.45$year==2099,'q95'])
      
      #---------------------------USE GGTIMESERIES FUNCTION HERE-----------------------------------------------
      
      # Recommended solution: Build the plot step by step
      
      # Step 1: Create base plot with RCP8.5 using ggtimeseries
      p.plume <- ggtimeseries(
        df.list = list(ubcosts.b[,c("year", "mean")]), 
        df.u = ubcosts.b,           
        df.x = "year",              
        ub = "q95", lb = "q5",
        uncertainty.color = "gray10",         # RCP8.5 confidence interval: dark gray
        uncertainty.alphas = 0.6,
        df.box = boxplot.85,        
        df.box.2 = boxplot.45,      
        legend.breaks = NULL,  
        legend.values = "black",              # RCP8.5 mean line: black
        y.label = "", 
        rcp.value = "RCP8.5 vs RCP4.5", 
        ssp.value = ssp, 
        iam.value = i
      )
      
      # Step 2: Manually add RCP4.5 confidence interval and mean line
      p.plume <- p.plume + 
        # Add RCP4.5 confidence interval (light gray)
        geom_ribbon(data = ubcosts.b.45, 
                    aes(x = year, ymin = q5, ymax = q95, fill = "5th-95th percentile range"), 
                    alpha = 0.6) +
        # Add RCP4.5 mean line (black dashed line)
        geom_line(data = ubcosts.b.45, 
                  aes(x = year, y = mean, linetype = "RCP4.5"), 
                  color = "black", size = 1) +
        # Add RCP8.5 linetype identifier (solid line)
        geom_line(data = ubcosts.b, 
                  aes(x = year, y = mean, linetype = "RCP8.5"), 
                  color = "black", size = 1) +
        # Set line types
        scale_linetype_manual(
          name = "Scenario",
          values = c("RCP8.5" = "solid", "RCP4.5" = "dashed"),
          breaks = c("RCP8.5", "RCP4.5")
        ) +
        # Set fill colors for confidence intervals
        scale_fill_manual(
          name = "",
          values = c("5th-95th percentile range" = "gray60"),
          labels = c("5th-95th percentile range")
        ) +
        # Adjust legend
        guides(
          linetype = guide_legend(override.aes = list(size = 1), order = 1),
          fill = guide_legend(override.aes = list(alpha = 0.5), order = 2)
        )
      
      # Step 3: Add y-axis tick marks
      p.plume <- p.plume + scale_y_continuous(breaks=seq(0,350, by = 50))
      
      # Step 4: Save the plot
      ggsave(p.plume, file = paste0(outputwd, "labor_final_", ssp, "_", i, "_RCP85_vs_RCP45_with_CI.pdf"), 
             width = 10, height = 6)
    }
  }
}  