# Kernel Density Plotting Function
# This function returns a kernel density plot from a specific impact region from projection impacts
# Updated 29 Oct 2020 by Ruixue Li 
# Modified to use test data directory
#----------------------------------------------------------------------------------
rm(list = ls())
source("~/repos/labor-code-release-2020/0_subroutines/paths.R")
source("~/repos/post-projection-tools/mapping/imgcat.R") # redefines the way ggplot plots
if(!require(gg.gap)) install.packages("gg.gap")
library(gg.gap)
library(Cairo)

# Load required packages, installing them if necessary
if(!require("pacman")){install.packages(("pacman"))}
pacman::p_load(ggplot2, 
               dplyr,
               readr)
library(glue)
library(parallel)
source(paste0(DIR_REPO_LABOR, "/4_post_projection/0_utils/mapping.R"))

# ========== TEST DATA DIRECTORY ==========
# Point to test data instead of production data
TEST_DATA_DIR <- "/project/cil/gcp/outputs/labor/impacts-woodwork/montecarlo/test"

# ========== OUTPUT DIRECTORY ==========
# Define output directory if DIR_FIG is not available from paths.R
if (!exists("DIR_FIG")) {
  DIR_FIG <- "/project/cil/home_dirs/maiqi/tmp/figures"
  cat("WARNING: DIR_FIG not found in paths.R, using default:", DIR_FIG, "\n")
}

# Ensure output directory exists
dir.create(DIR_FIG, recursive = TRUE, showWarnings = FALSE)

# ========== KERNEL DENSITY PLOTTING FUNCTION ==========
# Create function that plots kernel density distribution with weighted statistics
ggkd <- function(df.kd = NULL,
                 topcode.ub = NULL, topcode.lb = NULL, 
                 yr = NULL, ir.name = NULL, 
                 x.label = NULL, y.label = "Density", 
                 kd.color = "grey50") {
  
  # Remove NA values from dataset
  df.kd = df.kd %>% filter(!is.na(value))
  ir_fin <- df.kd  
  
  # Calculate weighted mean considering GCM weights
  ir_mean <- weighted.mean(ir_fin$value, ir_fin$weight)
  
  # Calculate weighted standard deviation
  weighted.sd <- function(x, w){ 
    mu <- weighted.mean(x, w)
    u <- sum(w * (x - mu)^2)
    d <- ((length(w) - 1) * sum(w)) / length(w)
    s <- sqrt(u / d)  
    return(s)
  }
  
  ir_sd <- weighted.sd(ir_fin$value, ir_fin$weight) 
  
  # Assign year if not provided
  if(is.null(yr)){ 
    yr <- ir_fin$year[1]
  }
  
  # Assign impact region name if not provided
  if(is.null(ir.name)){ 
    ir.name <- ""
  }
  
  # Normalize weights so they sum to 1
  ir_fin$weight <- ir_fin$weight / sum(ir_fin$weight)
  
  # Apply upper bound coding if specified
  if (!is.null(topcode.ub)){ 
    ir_fin$value <- ifelse(ir_fin$value > topcode.ub, topcode.ub, ir_fin$value) 
  }
  
  # Apply lower bound coding if specified
  if (!is.null(topcode.lb)){ 
    ir_fin$value <- ifelse(ir_fin$value < topcode.lb, topcode.lb, ir_fin$value) 
  }
  
  # Debug: Print mean values
  print(paste0('--- IR WEIGHTED MEAN: ', round(ir_mean, 6), ' ----'))
  print(paste0('--- IR SIMPLE MEAN: ', round(mean(ir_fin$value), 6), ' ----'))
  
  # Calculate weighted kernel density
  ir_fin_density <- data.frame(density(ir_fin$value, weights = ir_fin$weight)[c("x", "y")])
  print(names(ir_fin_density))
  print(paste0("Density X range: ", round(min(ir_fin_density$x), 3), " to ", round(max(ir_fin_density$x), 3)))
  print(paste0("Density Y range: ", round(min(ir_fin_density$y), 3), " to ", round(max(ir_fin_density$y), 3)))
  
  # Plot kernel density
  print(paste0("Plotting kernel density for ", ir.name, " year ", yr))
  
  x_max = max(ir_fin_density$x)
  x_min = min(ir_fin_density$x)
  
  # Create kernel density plot with standard deviation shading
  p <- ggplot(ir_fin_density, aes(x, y)) +
    # Main distribution area
    geom_area(fill = kd.color, alpha = .9) +
    # Shade regions beyond ±1 standard deviation (white overlay)
    geom_area(data = subset(ir_fin_density, x < (ir_mean - ir_sd)), fill = "white", alpha = .3) +
    geom_area(data = subset(ir_fin_density, x < (ir_mean - (2*ir_sd))), fill = "white", alpha = .4) +
    geom_area(data = subset(ir_fin_density, x > (ir_mean + ir_sd)), fill = "white", alpha = .3) +
    geom_area(data = subset(ir_fin_density, x > (ir_mean + (2*ir_sd))), fill = "white", alpha = .4) +
    # Add reference lines
    geom_hline(yintercept = 0, size = .2, alpha = 0.5) +
    geom_vline(xintercept = ir_mean, size = .9, alpha = 1, lty = "solid", color = "white") +
    # Theme settings
    theme_bw() +
    theme(panel.grid.major = element_blank(), 
          panel.grid.minor = element_blank(),
          panel.background = element_blank(), 
          axis.line = element_line(colour = "grey80", size = 0.2),
          plot.title = element_text(hjust = 0.5, size = 10), 
          plot.caption = element_text(hjust = 0.5, size = 7),
          axis.text.x = element_text(size = 7, hjust = .5, vjust = .5, face = "plain")) +
    # Labels
    xlab(x.label) + ylab(y.label) +
    labs(title = paste0("Kernel Density Plot ", yr, " ", ir.name), 
         caption = paste0("GCM-weighted mean = ", round(ir_mean, 6), 
                          " | max = ", round(x_max, 3), " | min = ", round(x_min, 3))) +
    # Fixed axis scales for consistency across regions
    scale_x_continuous(limits = c(-10, 35), n.breaks = 10) + 
    scale_y_continuous(limits = c(0, 1.5), n.breaks = 5) 
  
  return(p)
}

# ========== DEFINE REGIONS FOR ANALYSIS ==========
regions = c(
  "NGA.25.510",                    # Lagos
  "IND.10.121.371",                # Delhi
  "CHN.2.18.78",                   # Beijing
  "BRA.25.5212.R3fd4ed07b36dfd9c", # Sao Paulo
  "USA.14.608",                    # Chicago
  "NOR.12.288"                     # Oslo
)
# 
# # ========== LOAD CITY METADATA (OPTIONAL) ==========
# # Code to find cities in income deciles
# all_IRs = read_csv(paste0(DIR_REPO_LABOR, "/data/misc/IR_names_w_deciles.csv"))
# cities_500 = read_csv(paste0(DIR_REPO_LABOR, "/data/misc/unit_population_projections_geography_500kcities_years_all_SSP3.csv")) %>%
#   mutate(region = Region_ID) %>%
#   dplyr::select(city, country, region)
# cities_w_deciles = merge(cities_500, all_IRs, by = "region")

# ========== MAIN LOOP: GENERATE KERNEL DENSITY PLOTS ==========
for (rg in regions) {
  # ===== MODIFIED: Use test data directory =====
  csv_filename <- glue("SSP3-{rg}valuescsv_-gdp_{rg}.csv")
  csv_path <- file.path(TEST_DATA_DIR, csv_filename)
  
  # Check if file exists before attempting to read
  if (!file.exists(csv_path)) {
    cat("WARNING: File not found:", csv_path, "\n")
    cat("Skipping region:", rg, "\n\n")
    next
  }
  
  # Read data from test directory
  cat("Reading data from:", csv_path, "\n")
  df = read_csv(csv_path, show_col_types = FALSE) %>%
    # Filter for year 2099, high IAM, RCP 8.5 scenario
    dplyr::filter(year %in% 2099, iam == "high", rcp == "rcp85") %>%
    # Transform: multiply by -100 to convert to percentage GDP damages
    dplyr::mutate(value = -value * 100) %>% 
    data.frame() 
  
  # Check if data is not empty
  if (nrow(df) == 0) {
    cat("WARNING: No data rows after filtering for region:", rg, "\n\n")
    next
  }
  
  # Sort by value (descending) for inspection
  df = df %>% arrange(desc(value))
  
  # Create kernel density plot
  cat("Creating kernel density plot for region:", rg, "\n")
  gg2 = ggkd(df.kd = dplyr::filter(df), 
             ir.name = rg,
             y.label = "Density", 
             x.label = "Percentage GDP Impact (%)")
  
  # Save plot to output directory
  # Use TEST_DATA_DIR for output if DIR_FIG not available
  output_base_dir <- "/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/output/figures"
  output_subdir <- "fig6_kernel_density"
  output_path <- file.path(output_base_dir, output_subdir, 
                           glue("kernel_density_{rg}_2099_common_axis.pdf"))
  
  # Ensure output directory exists
  dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
  cat("Output directory created:", dirname(output_path), "\n")
  
  # Save the plot
  ggsave(output_path, plot = gg2, width = 7, height = 7)
  cat("Saved plot to:", output_path, "\n\n")
}

cat("Kernel density plotting completed!\n")