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
outputwd <- paste0(DIR_FIG, "/figg2/")



#set up model
set <- 'global'
model <- 'montecarlos'
sector <- 'labor'
poly <- '4'

iam <- list("low")
ssplist <- list("SSP3")
rcplist <- list("rcp85")

green_col  <- rgb(26, 159, 116, maxColorValue = 255)
orange_col <- rgb(242, 100, 75,  maxColorValue = 255)

for (rcp in rcplist){
  for (ssp in ssplist){
    for (i in iam){
      
      #---------------------------------------------------------------------------
      #plot full adapt + costs (ub only) with uncertainty + end-of-century boxplots
      #---------------------------------------------------------------------------
      
      
      ubcosts.b <- read.csv(paste0(inputwd, ssp, "-rcp85_low_rebased_fulladapt-gdp-aggregated_global_timeseries.csv"))
      ubcosts.b[,3:length(ubcosts.b)] <- ubcosts.b[,3:length(ubcosts.b)]*-100
      
      ubcosts.b.45 <- read.csv(paste0(inputwd, ssp, "-rcp85_low_rebased_fulladapt-gdp-aggregated_global_timeseries_interacted.csv")) 
      ubcosts.b.45[,3:length(ubcosts.b.45)] <- ubcosts.b.45[,3:length(ubcosts.b.45)]*-100
      
      
      #---------------------------USE GGTIMESERIES FUNCTION HERE-----------------------------------------------
      
      # Recommended solution: Build the plot step by step
      
      # Step 1: Create base plot with RCP8.5 using ggtimeseries
      p.plume <- ggtimeseries(
        df.list = list(ubcosts.b[,c("year", "mean")]),
        df.u = ubcosts.b,
        df.x = "year",
        ub = "q95", lb = "q5",
        uncertainty.color = green_col,         # RCP8.5 confidence interval
        uncertainty.alphas = 0.2,
        
        legend.breaks = NULL,
        legend.values = green_col,              # RCP8.5 mean line
        y.label = "Climate change-induced worker disutility (% of global GDP)",
        y.limits = c(0.0, 5.0),
        rcp.value = "RCP8.5",
        ssp.value = ssp,
        iam.value = i
      )
      
      # Step 2: Manually add RCP4.5 confidence interval and mean line
      p.plume <- p.plume +
        # Add RCP4.5 confidence interval
        geom_ribbon(data = ubcosts.b.45,
                    aes(x = year, ymin = q5, ymax = q95), fill = orange_col,
                    alpha = 0.2, show.legend = FALSE) +
        # Add RCP4.5 mean line
        geom_line(data = ubcosts.b.45,
                  aes(x = year, y = mean, linetype = "interacted_model_8.5"),
                  color = orange_col, size = 1) +
        # Add RCP8.5 linetype identifier
        geom_line(data = ubcosts.b,
                  aes(x = year, y = mean, linetype = "uninteracted_main_model_8.5"),
                  color = green_col, size = 1) +
        # Set line types
        scale_linetype_manual(
          name = "Scenario",
          values = c("uninteracted_main_model_8.5" = "solid", "interacted_model_8.5" = "solid"),
          breaks = c("uninteracted_main_model_8.5", "interacted_model_8.5")
        ) +
        # Adjust legend
        guides(
          linetype = guide_legend(override.aes = list(size = 1), order = 1)
        )
      
      # Step 3: Adjust y-axis breaks and add tick marks (don't set limits to avoid cutting data)
      p.plume <- p.plume + 
        scale_y_continuous(breaks = seq(0, 5, by = 1)) +
        theme(
          axis.ticks = element_line(color = "black", size = 0.5),
          axis.ticks.length = unit(0.15, "cm"),
          axis.line = element_line(colour = "black", size = 0.5)
        )
      
      # Step 4: Save the plot
      ggsave(p.plume, file = paste0(outputwd, "labor_inte_", ssp, "_", i, "_RCP85_with_CI.pdf"),
             width = 10, height = 6)
    }
  }
}