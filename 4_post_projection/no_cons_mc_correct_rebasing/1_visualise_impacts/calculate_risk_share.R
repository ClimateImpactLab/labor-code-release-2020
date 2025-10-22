# ---------------------------------------------
# Back out weights and compute high/low shares (robust)
# ---------------------------------------------
library(dplyr)
library(readr)
library(stringr)

# Paths
path_rebased <- "/project/cil/gcp/outputs/labor/impacts-woodwork/montecarlo/test/SSP3-rcp85_low_rebased_fulladapt-gdp-aggregated_2099_map.csv"
path_low     <- "/project/cil/gcp/outputs/labor/impacts-woodwork/montecarlo/test/SSP3-rcp85_low_lowriskimpacts_fulladapt-gdp-aggregated_2099_map.csv"
path_high    <- "/project/cil/gcp/outputs/labor/impacts-woodwork/montecarlo/test/SSP3-rcp85_low_highriskimpacts_fulladapt-gdp-aggregated_2099_map.csv"

df_rebased <- read_csv(path_rebased)
df_low     <- read_csv(path_low)
df_high    <- read_csv(path_high)

# OPTIONAL but recommended: merge by a stable key instead of row position.
# Replace 'region' with your actual key(s). If no key, skip and rely on row order.
# df_rebased <- df_rebased %>% rename(mean_rebased = mean)
# df_low     <- df_low     %>% rename(mean_low = mean)
# df_high    <- df_high    %>% rename(mean_high = mean)
# dat <- df_rebased %>% inner_join(df_low,  by = "region") %>%
#                       inner_join(df_high, by = "region")

# If rows align 1:1 across files, use vectors directly:
rebased <- df_rebased$mean
low     <- df_low$mean
high    <- df_high$mean

eps <- .Machine$double.eps

# Back out weight for high
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

# Attach to original frames and write out
# Attach to original frames
df_high$highshare <- highshare
df_low$lowshare   <- lowshare

# Remove the original 'mean' column
df_high <- df_high %>% select(-mean)
df_low  <- df_low  %>% select(-mean)

# Define output paths
out_high <- str_replace(path_high, "highriskimpacts", "highshare")
out_low  <- str_replace(path_low,  "lowriskimpacts",  "lowshare")

# Write new CSVs
write_csv(df_high, out_high)
write_csv(df_low,  out_low)
