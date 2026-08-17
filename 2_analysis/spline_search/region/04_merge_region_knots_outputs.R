#-------------------------------------------------------------------------------
# 04_merge_region_knots_outputs.R
#-------------------------------------------------------------------------------
# PURPOSE
#   Combine regional knot-search CSV rows into one ranked file per region
#
# STEPS
#   1. Read all sidecar CSV files written by the region knot-search script
#   2. Add the region name from the folder
#   3. Sort by within R2 
#   4. Save the combined region files
#
# INPUTS
#   Sidecar CSV files from the region knot-search script
#
# OUTPUTS
#   Combined region CSV files used to choose the final knots
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# Packages
#-------------------------------------------------------------------------------
suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
})

#-------------------------------------------------------------------------------
# Paths
#-------------------------------------------------------------------------------
local_machine <- 0  # 1 = local (Volumes/), 0 = RCC (/project/)

if (local_machine == 1) {
  root_dir <- "/Volumes/project/cil"
} else {
  root_dir <- "/project/cil"
}

base_out_dir <- file.path(
  root_dir,
  "battuta_shares/gcp/estimation/labor/code_release_int_data/spline_search/region"
)

sidecars_dir <- file.path(base_out_dir, "r2_output/sidecars")
combined_dir <- file.path(base_out_dir, "r2_output/combined")
dir.create(combined_dir, recursive = TRUE, showWarnings = FALSE)

#-------------------------------------------------------------------------------
# Find region folders and loop
#-------------------------------------------------------------------------------
regions <- c("EuropeUS", "LatinAmerica", "SouthAsia")
region_dirs <- file.path(sidecars_dir, regions)
region_dirs <- region_dirs[dir.exists(region_dirs)]
regions <- basename(region_dirs)

message("Found region folders: ", paste(regions, collapse = ", "))

for (region in regions) {
  region_dir <- file.path(sidecars_dir, region)
  files <- list.files(region_dir, pattern = "\\.csv$", full.names = TRUE)
  
  if (length(files) == 0) {
    message("[", region, "] No CSV files found, skipping.")
    next
  }
  
  message("[", region, "] Reading ", length(files), " CSV files...")
  
  # Read all .csv files into list
  dfs <- lapply(files, function(f) {
    tryCatch(
      {
        df <- read_csv(f, show_col_types = FALSE)
        df$region <- region
        df
      },
      error = function(e) {
        warning("Failed to read ", f, ": ", e$message)
        NULL
      }
    )
  })
  
  dfs <- dfs[!vapply(dfs, is.null, logical(1))]
  if (length(dfs) == 0) {
    message("[", region, "] All reads failed, skipping.")
    next
  }
  
  # Combine all for that region
  region_df <- bind_rows(dfs)
  
  # Order by within R2 if available
  if ("within_r2" %in% names(region_df)) {
    region_df <- region_df %>%
      arrange(desc(within_r2)) %>%
      mutate(order_r2 = row_number())
  }
  
  # Write per-region file
  out_path <- file.path(combined_dir, paste0("knot_results_", region, ".csv"))
  write_csv(region_df, out_path)
  message("[", region, "] Wrote ", nrow(region_df), " rows -> ", out_path)
}

message("Done. All per-region combined files saved in: ", combined_dir)
