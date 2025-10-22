# Load packages
suppressWarnings({
  library(readr)
  library(dplyr)
  library(janitor)  # for clean_names()
})

# Input file
infile <- "/project/cil/battuta_shares/gcp/estimation/labor/code_release_int_data/projection_outputs/covariates/single-allcalcs-uninteracted_main_model.csv"

# 1) Read CSV, skipping the first 31 non-data lines
dat <- read_csv(
  file = infile,
  skip = 31,                # <-- drop the first 31 lines
  show_col_types = FALSE
) %>%
  janitor::clean_names() %>% # normalize column names
  type_convert()             # best-effort numeric parsing

# 2) Keep only the needed columns (now includes logpopop)
dat_sub <- dat %>%
  transmute(
    region     = as.character(region),
    loggdppc   = as.numeric(loggdppc),
    climtasmax = as.numeric(climtasmax),
    logpopop   = as.numeric(logpopop)   # <-- added
  )

# 3) Aggregate by region (mean across rows; ignore NAs)
by_region <- dat_sub %>%
  group_by(region) %>%
  summarise(
    loggdppc   = mean(loggdppc,   na.rm = TRUE),
    climtasmax = mean(climtasmax, na.rm = TRUE),
    logpopop   = mean(logpopop,   na.rm = TRUE),  # <-- added
    .groups = "drop"
  )

# 4) Write output next to the input file
outfile <- file.path(dirname(infile), "covariates_region_loggdppc_climtasmax_logpopop.csv")
write_csv(by_region, outfile)
message("Wrote: ", outfile)
