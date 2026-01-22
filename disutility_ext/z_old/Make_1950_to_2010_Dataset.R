library(data.table)
library(dplyr)
library(tidyr)
library(ggplot2)
library(sf)
library(scales)
library(purrr)
library(glue)
library(readr)

# MAKE FULL DATASET ##

#Temperature Term
df <- fread('/shares/gcp/climate/_spatial_data/impactregions/weather_data/csv_daily/GMFD_tmax_rcspline_term0_v2_1950_1950_daily_popwt.csv')

df <- melt(df, id = "hierid")
df <- df %>% rename("long_date" = "variable")

dates <- data.frame(do.call("rbind", strsplit(as.character(df$long_date), "_", fixed = TRUE)))
df <- cbind(df, dates)
df <- subset(df, select = -c(long_date))

df <- df %>% rename("year" = "X1")
df$year <- sub('y', '', df$year)
df$year <- as.integer(df$year)

df <- df %>% rename("month" = "X2")
df$month <- sub('m', '', df$month)
df$month <- as.integer(df$month)

df <- df %>% rename("day" = "X3")
df$day <- sub('d', '', df$day)
df$day <- as.integer(df$day)

years <- 1951:2010

for (y in years) {
  add <- fread(glue('/shares/gcp/climate/_spatial_data/impactregions/weather_data/csv_daily/GMFD_tmax_rcspline_term0_v2_{y}_{y}_daily_popwt.csv'))
  
  add <- melt(add, id = "hierid")
  add <- add %>% rename("long_date" = "variable")
  
  dates <- data.frame(do.call("rbind", strsplit(as.character(add$long_date), "_", fixed = TRUE)))
  add <- cbind(add, dates)
  add <- subset(add, select = -c(long_date))
  
  add <- add %>% rename("year" = "X1")
  add$year <- sub('y', '', add$year)
  add$year <- as.integer(add$year)
  
  add <- add %>% rename("month" = "X2")
  add$month <- sub('m', '', add$month)
  add$month <- as.integer(add$month)
  
  add <- add %>% rename("day" = "X3")
  add$day <- sub('d', '', add$day)
  add$day <- as.integer(add$day)
  
  df <- rbind(df,add)
}

write_csv(df, "/shares/gcp/climate/_spatial_data/impactregions/weather_data/csv_daily/GMDF_tmax_temp_1950_to_2010_daily.csv")

rm(df, add)

#Spline term
df <- fread('/shares/gcp/climate/_spatial_data/impactregions/weather_data/csv_daily/GMFD_tmax_rcspline_term1_v2_1950_1950_daily_popwt.csv')

df <- melt(df, id = "hierid")
df <- df %>% rename("long_date" = "variable")

dates <- data.frame(do.call("rbind", strsplit(as.character(df$long_date), "_", fixed = TRUE)))
df <- cbind(df, dates)
df <- subset(df, select = -c(long_date))

df <- df %>% rename("year" = "X1")
df$year <- sub('y', '', df$year)
df$year <- as.integer(df$year)

df <- df %>% rename("month" = "X2")
df$month <- sub('m', '', df$month)
df$month <- as.integer(df$month)

df <- df %>% rename("day" = "X3")
df$day <- sub('d', '', df$day)
df$day <- as.integer(df$day)

years <- 1951:2010

for (y in years) {
  add <- fread(glue('/shares/gcp/climate/_spatial_data/impactregions/weather_data/csv_daily/GMFD_tmax_rcspline_term1_v2_{y}_{y}_daily_popwt.csv'))
  
  add <- melt(add, id = "hierid")
  add <- add %>% rename("long_date" = "variable")
  
  dates <- data.frame(do.call("rbind", strsplit(as.character(add$long_date), "_", fixed = TRUE)))
  add <- cbind(add, dates)
  add <- subset(add, select = -c(long_date))
  
  add <- add %>% rename("year" = "X1")
  add$year <- sub('y', '', add$year)
  add$year <- as.integer(add$year)
  
  add <- add %>% rename("month" = "X2")
  add$month <- sub('m', '', add$month)
  add$month <- as.integer(add$month)
  
  add <- add %>% rename("day" = "X3")
  add$day <- sub('d', '', add$day)
  add$day <- as.integer(add$day)
  
  df <- rbind(df,add)
}

write_csv(df, "/shares/gcp/climate/_spatial_data/impactregions/weather_data/csv_daily/GMDF_tmax_spline_1950_to_2010_daily.csv")

