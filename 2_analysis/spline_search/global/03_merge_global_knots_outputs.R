#-------------------------------------------------------------------------------
# 03_merge_global_knots_outputs.R
#-------------------------------------------------------------------------------
# PURPOSE
#   Combine the row-level output from the global knot-search regressions and
#   produce the global knot ranking and comparison file
#
# STEPS
#   1. Read the row-level CSV files written by the Slurm jobs
#   2. Stack the rows and keep one result per knot triple
#   3. Rank candidates by within R2
#   4. Merge against the saved comparison file
#   5. Write the comparison CSV
#
# INPUTS
#   Row-level knot-search CSVs and the saved global comparison file
#
# OUTPUT
#   Global knot-search comparison CSV
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
local_machine <- 0  # 1 = local machine, 0 = RCC

if (local_machine == 1) {
  root_dir <- "/Volumes/project/cil"
} else {
  root_dir <- "/project/cil"
}

comparison_dir <- file.path(
  root_dir,
  "battuta_shares/gcp/estimation/labor/code_release_int_data/spline_search/global/comparison"
)

run_results_dir <- file.path(
  root_dir,
  "battuta_shares/gcp/estimation/labor/code_release_int_data/spline_search/global/results"
)

#-------------------------------------------------------------------------------
# Read row-level knot-search outputs
#-------------------------------------------------------------------------------
knots_csv_files <- list.files(
  path = run_results_dir,
  pattern = "^full_run.*\\.csv$",
  full.names = TRUE
)

if (length(knots_csv_files) == 0) {
  stop("No full_run CSV files found in: ", run_results_dir)
}

knots_r2 <- bind_rows(lapply(knots_csv_files, read_csv, show_col_types = FALSE))

#-------------------------------------------------------------------------------
# Rank the row-level results
#-------------------------------------------------------------------------------
knots_r2 <- knots_r2 %>%
  select(-any_of(c("id", "N_total", "N_high", "N_low"))) %>%
  mutate(knot = paste0(k1, "_", k2, "_", k3)) %>%
  filter(!duplicated(knot)) %>%
  arrange(desc(r2_within)) %>%
  mutate(order_search_r2 = row_number()) %>%
  rename(r2_search = r2_within)

#-------------------------------------------------------------------------------
# Merge with the saved comparison
#-------------------------------------------------------------------------------
saved_comparison <- read_csv(
  file.path(comparison_dir, "global_knots_r2_comparison.csv"),
  show_col_types = FALSE
)

knots_r2 <- left_join(saved_comparison, knots_r2, by = c("knot", "k1", "k2", "k3"))

#-------------------------------------------------------------------------------
# Write output
#-------------------------------------------------------------------------------
write_csv(
  knots_r2,
  file.path(comparison_dir, "global_knots_r2_comparison.csv")
)
