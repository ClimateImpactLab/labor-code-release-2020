# Back out weights and compute high/low shares, then save in "merged" file
# 
# NOTATION:
# w_high, w_low   : Population proportion (share of people/samples)
#                   - w_high = proportion of population from high-risk scenario
#                   - w_low  = proportion of population from low-risk scenario
#                   - w_high + w_low = 1.0
#
# highshare, lowshare : Quantity proportion (share of total output/value)
#                       - highshare = proportion of total quantity from high-risk population
#                       - lowshare  = proportion of total quantity from low-risk population
#                       - highshare + lowshare = 1.0 (when rebased ≠ 0)
#
# EXAMPLE:
#   If w_high = 0.50 and highshare = 0.82, it means:
#   - 50% of the population comes from the high-risk scenario
#   - But they contribute 82% of the total quantity (because high-risk population has higher per-capita output)
#
library(dplyr)
library(readr)
library(stringr)

# ============================================================
# SELECT COLUMN TO USE: "mean", "q5", "q95", etc.
# ============================================================
column_select <- "mean"  #  "mean", "q5", "q95"

# Paths
path_rebased <- "/project/cil/gcp/outputs/labor/impacts-woodwork/montecarlo/test/SSP3-rcp45_low_rebased_fulladapt-gdp-aggregated_2099_map.csv"
path_low     <- "/project/cil/gcp/outputs/labor/impacts-woodwork/montecarlo/test/SSP3-rcp45_low_lowriskimpacts_fulladapt-gdp-aggregated_2099_map.csv"
path_high    <- "/project/cil/gcp/outputs/labor/impacts-woodwork/montecarlo/test/SSP3-rcp45_low_highriskimpacts_fulladapt-gdp-aggregated_2099_map.csv"

# Read CSVs
df_rebased <- read_csv(path_rebased)
df_low     <- read_csv(path_low)
df_high    <- read_csv(path_high)

# Extract values based on column selection
rebased <- df_rebased[[column_select]]
low     <- df_low[[column_select]]
high    <- df_high[[column_select]]

eps <- .Machine$double.eps

# Back out weights for high
den_w  <- (high - low)
w_high <- (rebased - low) / den_w
w_low  <- 1 - w_high

# Undefined weights when high == low
w_high[abs(den_w) < eps] <- NA_real_
w_low[abs(den_w)  < eps] <- NA_real_

# Shares relative to rebased
highshare <- (w_high * high) / rebased
lowshare  <- (w_low  * low)  / rebased

# Undefined shares when rebased == 0
highshare[abs(rebased) < eps] <- NA_real_
lowshare[abs(rebased)  < eps] <- NA_real_

# Create dynamic column names based on selection
col_rebased   <- paste0("rebased_", column_select)
col_highrisk  <- paste0("highrisk_", column_select)
col_lowrisk   <- paste0("lowrisk_", column_select)
col_highshare <- paste0("highshare_", column_select)
col_lowshare  <- paste0("lowshare_", column_select)

# Merge all dataframes with shares
dat_merged <- df_rebased %>%
  select(region, year) %>%
  mutate(
    !!col_rebased   := rebased,
    !!col_highrisk  := high,
    !!col_lowrisk   := low,
    !!col_highshare := highshare,
    !!col_lowshare  := lowshare,
    w_high          := w_high,
    w_low           := w_low
  )

# Define output path - replace with column name
out_merged <- str_replace(path_rebased, 
                          "rebased_fulladapt", 
                          paste0(column_select, "_merged_fulladapt"))

# Write merged CSV
write_csv(dat_merged, out_merged)

cat("Merged file saved to:", out_merged, "\n")
cat("Column used:", column_select, "\n")