library(glue)
library(data.table)

setwd("/project/")

rcp <- "rcp85"
adapt <- "fulladapt"


dir <- '/project/cil/kupe_shares/CIL_temp_storage/labor/code_release_int_data/projection_outputs/extracted_data_mc'

riskshare_low <- fread(glue('{dir}/SSP3-{rcp}_low_riskshare_fulladapt-pop-aggregated_global_timeseries.csv'))
lr_low <- fread(glue('{dir}/SSP3-rcp85_low_lowrisk_fulladapt-pop-aggregated_global_timeseries.csv'))
hr_low <- fread(glue('{dir}/SSP3-rcp85_low_highrisk_fulladapt-pop-aggregated_global_timeseries.csv'))

riskshare_high <- fread(glue('{dir}/SSP3-{rcp}_high_riskshare_fulladapt-pop-aggregated_global_timeseries.csv'))
lr_high<- fread(glue('{dir}/SSP3-{rcp}_high_highrisk_fulladapt-pop-aggregated_global_timeseries.csv'))
hr_high <- fread(glue('{dir}/SSP3-{rcp}_high_highrisk_fulladapt-pop-aggregated_global_timeseries.csv'))

hist_riskshare_low <- fread(glue('{dir}/SSP3-{rcp}_low_riskshare_histclim-pop-aggregated_global_timeseries.csv'))
hist_lr_low <- fread(glue('{dir}/SSP3-{rcp}_low_lowrisk_histclim-pop-aggregated_global_timeseries.csv'))
hist_hr_low <- fread(glue('{dir}/SSP3-{rcp}_low_highrisk_histclim-pop-aggregated_global_timeseries.csv'))

hist_riskshare_high <- fread(glue('{dir}/SSP3-{rcp}_high_riskshare_histclim-pop-aggregated_global_timeseries.csv'))
hist_lr_high<- fread(glue('{dir}/SSP3-{rcp}_high_highrisk_histclim-pop-aggregated_global_timeseries.csv'))
hist_hr_high <- fread(glue('{dir}/SSP3-{rcp}_high_highrisk_histclim-pop-aggregated_global_timeseries.csv'))

riskshare_low$iam <- ifelse(riskshare_low$year == 1999, "low", "low")
riskshare_high$iam <- ifelse(riskshare_high$year == 1999, "high", "high")
riskshare <- rbind(riskshare_low, riskshare_high)
riskshare <- aggregate(mean ~ year, data = riskshare, FUN = mean)
rm(riskshare_low, riskshare_high)

hist_riskshare_low$iam <- ifelse(hist_riskshare_low$year == 1999, "low", "low")
hist_riskshare_high$iam <- ifelse(hist_riskshare_high$year == 1999, "high", "high")
hist_riskshare <- rbind(hist_riskshare_low, hist_riskshare_high)
hist_riskshare <- aggregate(mean ~ year, data = hist_riskshare, FUN = mean)
rm(hist_riskshare_low, hist_riskshare_high)

hr_low$iam <- ifelse(hr_low$year ==1999,'low', 'low')
hr_high$iam <- ifelse(hr_high$year == 1999, 'high','high')
hr <- rbind(hr_low, hr_high)
hr <- aggregate(mean ~year, data = hr, FUN = mean)
rm(hr_low, hr_high)

hist_hr_low$iam <- ifelse(hist_hr_low$year == 1999, 'low','low')
hist_hr_high$iam <- ifelse(hist_hr_high$year == 1999, 'high','high')
hist_hr <- rbind(hist_hr_low, hist_hr_high)
hist_hr <- aggregate(mean ~year, data = hist_hr, FUN =mean)
rm(hist_hr_low, hist_hr_high)

lr_low$iam <- ifelse(lr_low$year == 1999, 'low','low')
lr_high$iam <- ifelse(lr_high$year ==  1999, 'high','high')
lr <- rbind(lr_low, lr_high)
lr <- aggregate(mean ~ year, data = lr, FUN = mean)
rm(lr_low, lr_high)

hist_lr_low$iam <- ifelse(hist_lr_low$year == 1999,'low','low')
hist_lr_high$iam <- ifelse(hist_lr_high$year ==  1999, 'high','high')
hist_lr <- rbind(hist_lr_low, hist_lr_high)
hist_lr <- aggregate(mean ~ year, data = hist_lr, FUN = mean)
rm(hist_lr_low, hist_lr_high)

hist_lr <- rename(hist_lr, c('year'='year','low_risk_hist'='mean'))
hist_hr <- rename(hist_hr, c('year'='year','high_risk_hist'='mean'))
hist_riskshare <- rename(hist_riskshare, c('year'='year','riskshare_hist' = 'mean'))

lr <- rename(lr, c('year'='year','low_risk'='mean'))
hr <- rename(hr, c('year'='year','high_risk'='mean'))
riskshare <- rename(riskshare, c('year'='year','riskshare' = 'mean'))

df <- merge(lr, hr, by.x = 'year', by.y = 'year')
df <- merge(df, riskshare, by.x = 'year',by.y = 'year')
rm(lr,hr,riskshare)

hist_df <- merge(hist_lr, hist_hr, by.x = 'year', by.y = 'year')
hist_df <- merge(hist_df, hist_riskshare, by.x = 'year',by.y = 'year')
rm(hist_lr,hist_hr,hist_riskshare)

df <- merge(df, hist_df, by.x = 'year', by.y = 'year')
rm(hist_df)

df_2010 <- subset(df, year > 2000 & year < 2011)
df_2010$impact <- df_2010$riskshare*df_2010$high_risk + (1-df_2010$riskshare)df_2010$low_risk
df_2010$impact_hist <- df_2010$riskshare_hist*df_2010$high_risk_hist + (1-df_2010$riskshare_hist)*df_2010$low_risk_hist
lr_hist_2010 <- mean(df_2010$low_risk_hist)
hr_hist_2010 <- mean(df_2010$high_risk_hist)
riskshare_hist_2010 <- mean(df_2010$riskshare_hist)
riskshare_2010 <- mean(df_2010$riskshare)
lr_2010 <- mean(df_2010$low_risk)
hr_2010 <- mean(df_2010$high_risk)
impact_2010 <- mean(df_2010$impact)
impact_2010_hist <- mean(df_2010$impact_hist)

df$low_risk_hist2 <- df$low_risk_hist - lr_hist_2010
df$high_risk_hist2 <- df$high_risk_hist - hr_hist_2010

df$lr_diff <- df$low_risk - df$low_risk_hist
df$hr_diff <- df$high_risk - df$high_risk_hist
df$lr_diff <- df$low_risk - df$low_risk_hist
  
lr_hist <- df$low_risk_hist[119]
hr_hist <- df$high_risk_hist[119]
riskshare_hist <- df$riskshare_hist[119]

lr <- df$low_risk[119]
hr <- df$high_risk[119]
riskshare <- df$riskshare[119]

impact <- riskshare*(hr - hr_2010) + (1-riskshare)*(lr - lr_2010) - riskshare_hist*(hr_hist - hr_hist_2010) + (1 - riskshare_hist)*(lr_hist - lr_hist_2010)
impact2 <- riskshare*(hr) + (1-riskshare)*(lr) - riskshare_hist*(hr_hist-hr_hist_2010) + (1 - riskshare_hist)*(lr_hist - lr_hist_2010)



all_low <- fread(glue('{dir}/SSP3-rcp85_low_allrisk_fulladapt-pop-aggregated_global_timeseries.csv'))
all_high <- fread(glue('{dir}/SSP3-rcp85_high_allrisk_fulladapt-pop-aggregated_global_timeseries.csv'))

all <- rbind(all_low, all_high)
all <- aggregate(mean ~ year, data = all, FUN = mean)

pop_val2 <- fread(glue('{dir}_correct_rebasing_for_integration/SSP3-valuescsv_-pop_global.csv'))
pop_val2$val_w <- pop_val2$weight*pop_val2$value
pop_val2 <- aggregate(val_w ~ rcp + year+ batch + iam, data = pop_val2, FUN = sum)
pop_val2 <- aggregate(val_w ~ rcp + year, data = pop_val2, FUN = mean)

pop_val <- fread(glue('{dir}/SSP3-valuescsv_pop_global.csv'))
pop_val$val_w <- pop_val$weight*pop_val$value
pop_val <- aggregate(val_w ~ rcp + year + batch + iam, data = pop_val,FUN = sum)
pop_val <- aggregate(val_w ~ rcp + year, data = pop_val,FUN = mean)

pop_val2$val_w[238] - pop_val$val_w[238]





