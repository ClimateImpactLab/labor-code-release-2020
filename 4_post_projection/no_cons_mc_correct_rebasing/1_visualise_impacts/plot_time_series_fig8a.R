#clean environment
rm(list = ls())

#load packages - load packages in correct order and check for conflicts
library(dplyr)
library(readr) 
library(ggplot2)

# Check for scale_index function conflicts
if(exists("scale_index")) {
  print("scale_index function exists, removing it")
  rm(scale_index, envir = .GlobalEnv)
}

# Load required packages
if(!require("magrittr")){install.packages("magrittr")}
library(magrittr)

#set working directory and paths
source("/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/0_subroutines/paths.R")

inputwd <- "/project/cil/gcp/outputs/labor/impacts-woodwork/montecarlo/timeseries/"
outputwd <- paste0(DIR_FIG, "/fig8/")

# Create output directory
dir.create(outputwd, recursive = TRUE, showWarnings = FALSE)

#-------------------------------- GET THE GGTIMESERIES FUNCTION --------------------------------------------------------
# Attempt to load ggtimeseries function and capture potential errors
tryCatch({
  source(paste0(DIR_REPO_LABOR, "/4_post_projection/0_utils/time_series.R"))
  print("time_series.R loaded successfully")
}, error = function(e) {
  print(paste("Error loading time_series.R:", e$message))
})

# Check if ggtimeseries function exists
if(!exists("ggtimeseries")) {
  print("ggtimeseries function not found, trying alternative path")
  # Try other possible paths
  tryCatch({
    source("/project/cil/home_dirs/maiqi/repos/post-projection-tools/timeseries/ggtimeseries.R")
    print("Alternative ggtimeseries.R loaded")
  }, error = function(e) {
    print(paste("Error loading alternative ggtimeseries.R:", e$message))
    stop("Cannot find ggtimeseries function")
  })
}

# Check function dependencies
print("Checking function dependencies...")
if(!exists("ggtimeseries")) {
  stop("ggtimeseries function not available")
}

print("ggtimeseries function is available")
#-------------------------------- -------------------------------------------------------- -------------------------------

#set up parameters
set <- 'global'
model <- 'timeseries'
sector <- 'labor'
iam <- list("low")
ssplist <- list("SSP3")
rcplist <- list("rcp85")
risk <- "rebased"
aggregation <- "-gdp-aggregated"
region <- "global"

for (rcp in rcplist){
  for (ssp in ssplist){
    for (i in iam){
      
      #-----------------------------------------------------------------------------------------------------------------------
      #transform data according to Labor's needs 
      
      #load impacts - first check if files exist and data structure
      full_file <- paste0(inputwd, ssp, "-", rcp, "_", i, "_", risk, "_fulladapt", aggregation, "_", region, "_timeseries.csv")
      inc_file <- paste0(inputwd, ssp, "-", rcp, "_", i, "_", risk, "_incadapt", aggregation, "_", region, "_timeseries.csv")
      no_file <- paste0(inputwd, ssp, "-", rcp, "_", i, "_", risk, "_noadapt", aggregation, "_", region, "_timeseries.csv")
      
      if(!file.exists(full_file) | !file.exists(inc_file) | !file.exists(no_file)) {
        print(paste("Missing files for", ssp, rcp, i))
        print(!file.exists(full_file))
        print(!file.exists(inc_file))
        print(!file.exists(no_file))
        next
      }
      
      # Read and check data structure
      full_raw <- read_csv(full_file, show_col_types = FALSE)
      inc_raw <- read_csv(inc_file, show_col_types = FALSE)
      no_raw <- read_csv(no_file, show_col_types = FALSE)
      
      print(paste("Full data columns:", paste(colnames(full_raw), collapse = ", ")))
      print(paste("Full data dimensions:", nrow(full_raw), "x", ncol(full_raw)))
      
      # Process data - correct column names and filtering logic
      full <- full_raw %>%
        dplyr::filter(is.na(region) | region %in% c("", 0, "0") | region == "global") %>%
        dplyr::select(year, mean) %>%
        dplyr::mutate(mean = as.numeric(mean) * -100) %>%
        filter(!is.na(mean), !is.na(year))
      
      inc <- inc_raw %>%
        dplyr::filter(is.na(region) | region %in% c("", 0, "0") | region == "global") %>%
        dplyr::select(year, mean) %>%
        dplyr::mutate(mean = as.numeric(mean) * -100) %>%
        filter(!is.na(mean), !is.na(year))
      
      no <- no_raw %>%
        dplyr::filter(is.na(region) | region %in% c("", 0, "0") | region == "global") %>%
        dplyr::select(year, mean) %>%
        dplyr::mutate(mean = as.numeric(mean) * -100) %>%
        filter(!is.na(mean), !is.na(year))
      
      # Check data structure to ensure it meets ggtimeseries requirements
      print("Data structure check:")
      print(paste("Full data:", paste(colnames(full), collapse = ", "), "- dims:", nrow(full), "x", ncol(full)))
      print(paste("Sample full data:"))
      print(head(full))
      
      # Ensure correct data format - ggtimeseries may require specific format
      full <- full %>% arrange(year) %>% as.data.frame()
      inc <- inc %>% arrange(year) %>% as.data.frame()  
      no <- no %>% arrange(year) %>% as.data.frame()
      
      # Check data again
      print("After arranging:")
      print(paste("Full:", nrow(full), "rows"))
      print(paste("Year range:", min(full$year), "to", max(full$year)))
      print(paste("Value range:", min(full$mean, na.rm=T), "to", max(full$mean, na.rm=T)))
      
      #order matters: df order should align with the default legend.breaks order or the user specified legend.breaks order
      dflist = list(full, inc, no)
      
      # Check dflist structure
      print("dflist structure:")
      for(j in 1:length(dflist)) {
        print(paste("List item", j, ":", nrow(dflist[[j]]), "rows,", ncol(dflist[[j]]), "cols"))
        print(colnames(dflist[[j]]))
      }
      
      #-------------------------------- THIS IS THE MOST RELEVANT PART --------------------------------------------------------
      
      #use function with error handling
      tryCatch({
        plot <- ggtimeseries(df.list = dflist, 
                             x.limits = c(2010, 2098),
                             y.label = 'Climate change-induced worker disutility (% of global GDP)',
                             rcp.value = rcp, 
                             ssp.value = ssp, 
                             end.yr = 2100,
                             legend.breaks = c("Full Adapt", "Inc Adapt", "No Adapt")) +
          ggtitle(paste0("Worker disutility costs of climate change (", toupper(rcp), ", mean)"))
        
        print("ggtimeseries executed successfully")
        
      }, error = function(e) {
        print(paste("Error in ggtimeseries:", e$message))
        print("Stack trace:")
        print(traceback())
        
        # If ggtimeseries fails, use fallback ggplot method
        print("Using fallback ggplot method...")
        
        # Fallback method
        full$scenario <- "Full Adapt"
        inc$scenario <- "Inc Adapt"
        no$scenario <- "No Adapt"
        
        combined_data <- rbind(full, inc, no)
        
        plot <- ggplot(combined_data, aes(x = year, y = mean, color = scenario)) +
          geom_line(size = 1.2) +
          labs(x = "Year", 
               y = "Climate change-induced worker disutility (% of global GDP)",
               title = paste0("Worker disutility costs of climate change (", toupper(rcp), ", mean)"),
               color = "") +
          theme_minimal() +
          xlim(2010, 2098)
      })
      
      #-------------------------------- -------------------------------------------------------- -------------------------------
      
      #save plot
      ggsave(plot, file = paste0(outputwd, "labor_timeseries_", rcp, "-", ssp, "_", i, "_", risk, "_multi_adapt.pdf"), 
             width = 10, height = 6)
      
      print(paste0("Plot saved: ", outputwd, "labor_timeseries_", rcp, "-", ssp, "_", i, "_", risk, "_multi_adapt.pdf"))
    }
  }
}