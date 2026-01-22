library(data.table)
library(dplyr)
library(tidyr)
library(ggplot2)
library(sf)
library(scales)
library(purrr)
library(glue)

df <- fread("/shares/gcp/climate/_spatial_data/impactregions/weather_data/csv_daily/GMDF_tmax_temp_1950_to_2010_daily.csv")

#Find hottest and coldest 3 months in a given IR
df_agg <- aggregate(value ~ month + hierid, data = df, FUN = mean)

df_agg <- df_agg %>% arrange(hierid, value) %>%
  group_by(hierid) %>%
  mutate(rank = rank(value))

df_agg <- df_agg %>% arrange(hierid, value) %>%
  group_by(hierid) %>%
  mutate(max = max(rank))

hottest_three <- subset(df_agg, rank == 12 | rank == 11 | rank == 10)
coldest_three <- subset(df_agg, rank == 1 | rank == 2 | rank == 3)

#Get Summer and Winter Months
df <- fread("/shares/gcp/climate/_spatial_data/impactregions/weather_data/csv_daily/GMDF_tmax_temp_1950_to_2010_daily.csv")

shp <- st_read("/home/rfrost/repos/mortality/outreach/WP_2023/ir_shp/impact-region.shp")

shp <- shp %>% 
  mutate(lon = map_dbl(geometry, ~st_centroid(.x)[[1]]),
         lat = map_dbl(geometry, ~st_centroid(.x)[[2]]))

lat <- cbind(shp$hierid, shp$lat)

df <- subset(df, month == 12 & month == 1 & month == 2 & month == 6 & month == 7 & month == 8)

df <- merge(df, lat, by.x = "hierid", by.y = 'V1', all.x = TRUE, all.y = TRUE)
df <- df %>% rename("lat" = "V2")
df$hemisphere <- ifelse(df$lat < 0, 1, 2)

df$summer <- ifelse(df$month == 12 & df$hemisphere == 1,1,0)
df$summer <- ifelse(df$month == 1 & df$hemisphere == 1,1,df$summer)
df$summer <- ifelse(df$month == 2 & df$hemisphere == 1,1,df$summer)
df$summer <- ifelse(df$month == 6 & df$hemisphere == 2,1,df$summer)
df$summer <- ifelse(df$month == 7 & df$hemisphere == 2,1,df$summer)
df$summer <- ifelse(df$month == 8 & df$hemisphere == 2,1,df$summer)

df$winter <- ifelse(df$month == 12 & df$hemisphere == 2,1,0)
df$winter <- ifelse(df$month == 1 & df$hemisphere == 2,1,df$winter)
df$winter <- ifelse(df$month == 2 & df$hemisphere == 2,1,df$winter)
df$winter <- ifelse(df$month == 6 & df$hemisphere == 1,1,df$winter)
df$winter <- ifelse(df$month == 7 & df$hemisphere == 1,1,df$winter)
df$winter <- ifelse(df$month == 8 & df$hemisphere == 1,1,df$winter)

df_summer <- subset(df, summer==1)
df_winter <- subset(df, winter==1)

gc()

#Get median year and year with hottest hot season

df <- fread("/shares/gcp/climate/_spatial_data/impactregions/weather_data/csv_daily/GMDF_tmax_temp_1950_to_2010_daily.csv")
df <- merge(df, hottest_three, by.x= c("month","hierid"), by.y = c("month","hierid"), all.x = FALSE, all.y = TRUE)

#figure out coldest cold season

#Get median year and year with the hottest summer
df_agg_sum <- aggregate(value ~ year + hierid, data = df_summer, FUN = mean)

df_agg_sum <- df_agg_sum %>% arrange(hierid, value) %>%
  group_by(hierid) %>%
  mutate(rank = rank(value))

df_agg_sum <- df_agg_sum %>% arrange(hierid, value) %>%
  group_by(hierid) %>%
  mutate(max = max(rank))

summer <- subset(df_agg_sum, rank == 61 | rank == 31 )

#get median year and year with the coldest Winter
df_agg_win <- aggregate(value ~ year + hierid, data = df_winter, FUN = mean)

df_agg_win <- df_agg_win %>% arrange(hierid, value) %>%
  group_by(hierid) %>%
  mutate(rank = rank(value))

df_agg_win <- df_agg_win %>% arrange(hierid, value) %>%
  group_by(hierid) %>%
  mutate(max = max(rank))

winter <- subset(df_agg_win, rank == 1 | rank == 31 )

df <- fread("/home/rfrost/repos/labor-code-release-2020/disutility_ext/backup_just_temp.csv")


#Choose version of ranking
df_trim<- merge(df,hottest_three, by.x = c("hierid", "month"), by.y = c("hierid", "month"), all.x = FALSE, all.y = TRUE)
#df_trim_ <- merge(df,coldest_three, by.x = c("hierid", "month"), by.y = c("hierid", "month"), all.x = FALSE, all.y = TRUE)

#df_trim <- merge(df,first_med, by.x = c("hierid", "year"), by.y = c("hierid", "year"), all.x = FALSE, all.y = TRUE)
df_trim <- df_trim %>% rename("month" = "X2")
df_trim <- df_trim %>% rename("day" = "X3")
df_trim$position <- ifelse(df_trim$rank == 16, "median", "extreme")

df_trim <- subset(df_trim, select = -c(value.y))
df_trim <- subset(df_trim, select = -c(rank))

df_trim <- df_trim %>% rename("temp" = "value.x")

df_trim_m <-subset(df_trim, position == "median")
df_trim_h <-subset(df_trim, position == "extreme")
df_trim <- merge(df_trim_m , df_trim_h, by.x = c("hierid", "month","day"), by.y = c("hierid", "month","day"), all.x = TRUE, all.y = TRUE)
df_trim <- df_trim %>% rename("temp_med" = "temp.x")
df_trim <- df_trim %>% rename("temp_extreme" = "temp.y")
df_trim <- subset(df_trim, select = -c(position.x, position.y))
df_trim <- df_trim %>% rename("year_med" = "year.x")
df_trim <- df_trim %>% rename("year_extreme" = "year.y")

#Load Spline Terms
dfs <- fread('/shares/gcp/climate/_spatial_data/impactregions/weather_data/csv_daily/GMFD_tmax_rcspline_term1_v2_1980_1980_daily_popwt.csv')

dfs <- melt(dfs, id = "hierid")
dfs <- dfs %>% rename("long_date" = "variable")

dates <- data.frame(do.call("rbind", strsplit(as.character(dfs$long_date), "_", fixed = TRUE)))
dfs <- cbind(dfs, dates)
dfs <- subset(dfs, select = -c(long_date))
dfs <- dfs %>% rename("year" = "X1")


years <- 1981:2010

for (y in years) {
  add <- fread(glue('/shares/gcp/climate/_spatial_data/impactregions/weather_data/csv_daily/GMFD_tmax_rcspline_term1_v2_{y}_{y}_daily_popwt.csv'))
  
  add <- melt(add, id = "hierid")
  add <- add %>% rename("long_date" = "variable")
  
  dates <- data.frame(do.call("rbind", strsplit(as.character(add$long_date), "_", fixed = TRUE)))
  add <- cbind(add, dates)
  add <- subset(add, select = -c(long_date))
  add <- add %>% rename("year" = "X1")

  
  dfs <- rbind(dfs,add)
}
write.csv(dfs, "/home/rfrost/repos/labor-code-release-2020/disutility_ext/backup_just_spline.csv")
dfs <- fread( "/home/rfrost/repos/labor-code-release-2020/disutility_ext/backup_just_spline.csv")

dfs$year <- sub('y', '', dfs$year)
dfs <- dfs %>% rename("month" = "X2")
dfs <- dfs %>% rename("day" = "X3")

dfs$year <- as.integer(dfs$year)

dfs_trim <- merge(dfs,first_med, by.x = c("hierid", "year"), by.y = c("hierid", "year"), all.x = FALSE, all.y = TRUE)

dfs_trim$position <- ifelse(dfs_trim$rank == 16, "median", "extreme")

dfs_trim <- subset(dfs_trim, select = -c(value.y))
dfs_trim <- subset(dfs_trim, select = -c(rank))

dfs_trim <- dfs_trim %>% rename("temp_s" = "value.x")

dfs_trim_m <-subset(dfs_trim, position == "median")
dfs_trim_h <-subset(dfs_trim, position == "extreme")

dfs_trim <- merge(dfs_trim_m , dfs_trim_h, by.x = c("hierid", "month","day"), by.y = c("hierid", "month","day"), all.x = TRUE, all.y = TRUE)
dfs_trim <- dfs_trim %>% rename("temp_s_med" = "temp_s.x")
dfs_trim <- dfs_trim %>% rename("temp_s_extreme" = "temp_s.y")
dfs_trim <- subset(dfs_trim, select = -c(position.x, position.y,V1.x,V1.y))
dfs_trim <- dfs_trim %>% rename("year_med" = "year.x")
dfs_trim <- dfs_trim %>% rename("year_extreme" = "year.y")
dfs_trim$year_med <- as.integer(dfs_trim$year_med)
dfs_trim$year_extreme <- as.integer(dfs_trim$year_extreme)

dfb <- merge(df_trim, dfs_trim, by.x = c("hierid","year_med","year_extreme","month","day"), by.y = c("hierid","year_med","year_extreme","month","day"), all.x = TRUE, all.y = FALSE)
write.csv(dfb, "/home/rfrost/repos/labor-code-release-2020/disutility_ext/backup_only_winter_months.csv")
dfb <- fread("/home/rfrost/repos/labor-code-release-2020/disutility_ext/backup_only_summer_months.csv")

LR_temp <- rep(0.0499968692364216, nrow(dfb))
LR_temp_s <- rep(-0.0030990557122301, nrow(dfb))
HR_temp <- rep(0.726375435490015, nrow(dfb))
HR_temp_s <- rep(-0.0186751538193722, nrow(dfb))

dfb <- cbind(dfb,LR_temp,LR_temp_s,HR_temp,HR_temp_s)

#get rid of leap days because we have nothing to compare them too
dfb$leap_year <-ifelse(dfb$month == "m02" & dfb$day == "d29", 1,0)
dfb <- subset(dfb, leap_year == 0)

dfb$fh_extreme<- dfb$temp_extreme*dfb$HR_temp + dfb$temp_s_extreme*dfb$HR_temp_s
dfb$fh_med <- dfb$temp_med*dfb$HR_temp + dfb$temp_s_med*dfb$HR_temp_s


dfb$fl_extreme <- dfb$temp_extreme*dfb$LR_temp + dfb$temp_s_extreme*dfb$LR_temp_s
dfb$fl_med <- dfb$temp_med*dfb$LR_temp + dfb$temp_s_med*dfb$LR_temp_s

dfb$effect_HR <- dfb$fh_extreme - dfb$fh_med 
dfb$effect_LR <- dfb$fl_extreme - dfb$fl_med 

#
#get wage data
soc_ec <- fread("/home/rfrost/repos/labor-code-release-2020/disutility_ext/country_level_econvars_SSP3.csv")
soc_ec <- subset(soc_ec, year == 2010)
soc_ec <- subset(soc_ec, model == "high")

gdp <- subset(soc_ec, select = c(region,gdp,pop,gdppc))

soc_ec$wage <- (soc_ec$gdppc*0.6)/(250*6*60)
soc_ec <- subset(soc_ec, select = c(region, wage))

countries <- data.frame(do.call("rbind", strsplit(as.character(dfb$hierid), ".", fixed = TRUE)))
dfb <- cbind(dfb, countries$X1)
dfb <- dfb %>% rename("adm0" = "V2")

dfb <- merge(dfb, soc_ec, by.x = "adm0", by.y = "region", all.x = TRUE, all.y = TRUE,allow.cartesian=TRUE)

dfb$effect_HR_d <- (dfb$effect_HR*dfb$wage)/0.5
dfb$effect_LR_d <- (dfb$effect_LR*dfb$wage)/0.5

effects <- aggregate(cbind(wage, effect_HR,effect_LR,effect_HR_d,effect_LR_d) ~ hierid + adm0 , data = dfb, FUN = sum)
effects <- merge(effects, gdp, by.x = "adm0", by.y = "region", all.x = TRUE, all.y = TRUE,allow.cartesian=TRUE)

effects$HR_d_p_gdp <- ifelse(effects$gdppc != 0,((effects$effect_HR_d)/effects$gdppc)*100, 0)
effects$LR_d_p_gdp <- ifelse(effects$gdppc != 0,((effects$effect_LR_d)/effects$gdppc)*100, 0)
write.csv(effects, "/home/rfrost/repos/labor-code-release-2020/disutility_ext/effects_all_hottest.csv")
effects <- fread("/home/rfrost/repos/labor-code-release-2020/disutility_ext/effects_all_hottest.csv")

key_irs <- subset(effects, hierid == "USA.14.608" | hierid == "USA.5.221" | hierid ==  "USA.22.1228" | hierid == "DEU.3.12.141" |hierid == "FRA.11.75" | hierid == "CHN.6.46.280" | hierid == "CHN.2.18.78" |hierid == "BGD.3.9.18.132" | hierid == "IND.10.121.371" | hierid == "BRA.25.5212.R3fd4ed07b36dfd9c" | hierid == "NGA.25.510" | hierid == "NOR.12.288")
effects$city <- ifelse(effects$hierid == "USA.14.608", "Chicago", "")
effects$city <- ifelse(effects$hierid == "USA.5.221", "San Fransicso", effects$city)
effects$city <- ifelse(effects$hierid == "USA.22.1228", "Boston", effects$city)
effects$city <- ifelse(effects$hierid == "DEU.3.12.141", "Berlin", effects$city)
effects$city <- ifelse(effects$hierid == "FRA.11.75", "France", effects$city)
effects$city <- ifelse(effects$hierid == "CHN.6.46.280", "Guangzhou", effects$city)
effects$city <- ifelse(effects$hierid == "CHN.2.18.78", "Beijing", effects$city)
effects$city <- ifelse(effects$hierid == "BGD.3.9.18.132", "Dhaka", effects$city)
effects$city <- ifelse(effects$hierid == "IND.10.121.371", "Delhi", effects$city)
effects$city <- ifelse(effects$hierid == "BRA.25.5212.R3fd4ed07b36dfd9c", "Sao Paulo", effects$city)
effects$city <- ifelse(effects$hierid == "NGA.25.510", "Lagos", effects$city)
effects$city <- ifelse(effects$hierid == "NOR.12.288", "Oslo", effects$city)

key_irs <- subset(effects, select = c(city,HR_d_p_gdp, LR_d_p_gdp ))
key_irs <- subset(key_irs, city != "")

#write.csv(key_irs, "/home/rfrost/repos/labor-code-release-2020/disutility_ext/key_irs_only_winter_months.csv")

#let's map some impacts
shp <- st_read("/home/rfrost/repos/mortality/outreach/WP_2023/ir_shp/impact-region.shp")

effects <- merge(shp, effects, by.x = "hierid", by.y = "hierid", all.x = TRUE, all.y = TRUE)

color.values <- rev(c("#2c7bb6","#9dcfe4","#e7f8f8","grey95", "#ffedaa","#fec980","#d7191c"))

bound = ceiling(max(abs(effects$HR_d_p_gdp), na.rm=TRUE))
bound = 5
scale_v = c(-1, -0.2, -0.05, -0.005, 0, 0.005, 0.05, 0.2, 1)
rescale_value <- scale_v*bound

limits_val = round(c(-bound, bound), 4)

breaks_labels_val = round(seq(-bound, bound, 2*bound/5), 4)

effects <- subset(effects, !(is.na(effects$hierid)))
#effects <- subset(effects, !(is.na(effects$effect_HR)))

ggplot(data = effects) +
  geom_sf(aes(fill = HR_d_p_gdp), color=NA)  + 
  theme_void() +
  #scale_fill_gradient2(low="red",mid = "grey99", high = "navy", midpoint=0,na.value = "grey99",guide = "colourbar") +
  #theme(legend.key.height=unit(0.5, 'cm'),legend.position = "bottom", legend.key.width=unit(0.5, "cm"),axis.text.x=element_blank(), axis.ticks.x=element_blank(), axis.text.y=element_blank(), axis.ticks.y=element_blank(), plot.title = element_text(family="Times New Roman",hjust = 0.5),panel.background = element_blank(),legend.title=element_text(size=10, family="Times New Roman"),legend.text=element_text(size=10,family="Times New Roman")) +
  theme(legend.key.height=unit(0.5, 'cm'),legend.position = "bottom", legend.key.width=unit(0.5, "cm"),axis.text.x=element_blank(), axis.ticks.x=element_blank(), axis.text.y=element_blank(), axis.ticks.y=element_blank(), plot.title = element_text(family="Times New Roman",hjust = 0.5),panel.background = element_blank(),legend.title=element_text(size=10, family="Times New Roman"),legend.text=element_text(size=10,family="Times New Roman")) +
  ggtitle(glue("Low Risk Disultility Per Worker Per Year - Coldest Winter Relative to Median Winter 1980 to 2010")) +
  scale_fill_gradientn(
    colors = color.values,
    values=rescale(rescale_value),
    na.value = "grey95",
    limits = limits_val, #center color scale so white is at 0
    breaks = breaks_labels_val, 
    labels = breaks_labels_val, #set freq of tick labels
    guide = guide_colorbar(title = "% GDP per Capita",
                          direction = "horizontal",
                          barheight = unit(4, units = "mm"),
                          barwidth = unit(100, units = "mm"),
                          draw.ulim = F,
                          title.position = 'top',
                          title.hjust = 0.5,
                          label.hjust = 0.5))


#effects relative to optimum
soc_ec_adm0 <- fread("/home/rfrost/repos/labor-code-release-2020/disutility_ext/country_level_econvars_SSP3.csv")
soc_ec_adm0 <- subset(soc_ec_adm0, year == 2099)
soc_ec_adm0 <- subset(soc_ec_adm0, model == "high")
total_pop <- sum(soc_ec_adm0$pop)
soc_ec_adm0$gdppc_w <- soc_ec_adm0$gdppc*(soc_ec_adm0$pop/total_pop)
soc_ec_adm0 <- subset(soc_ec_adm0, !(is.na(gdppc)))
mean_gdppc <- sum(soc_ec_adm0$gdppc_w)

disutility <- ((globe_mean*(mean_gdppc*0.6)/(250*6*60))/0.5)*(100/mean_gdppc)


soc_ec <- fread("/home/rfrost/repos/labor-code-release-2020/disutility_ext/pop_gdppc_for_rebecca.csv")
soc_ec <- subset(soc_ec, year == 2010)
soc_ec <- subset(soc_ec, model == "high")


gdp <- subset(soc_ec, select = c(region,pop,gdppc))
soc_ec$wage <- (soc_ec$gdppc*0.6)/(250*6*60)
soc_ec <- subset(soc_ec, select = c(region, wage))

shp <- st_read("/home/rfrost/repos/mortality/outreach/WP_2023/ir_shp/impact-region.shp")

#df <- fread("/shares/gcp/climate/_spatial_data/impactregions/weather_data/csv_daily/GMDF_tmax_temp_1950_to_2010_daily.csv")
#df_mean <- aggregate(value ~ month + day+ hierid, data = df, FUN = mean)
#write.csv(df_mean,"/home/rfrost/repos/labor-code-release-2020/df_mean.csv")
df_mean <- fread("/home/rfrost/repos/labor-code-release-2020/df_mean.csv")
#df_mean <- subset(df, year == 2010)
#rm(df)
#dfs <- fread("/shares/gcp/climate/_spatial_data/impactregions/weather_data/csv_daily/GMDF_tmax_spline_1950_to_2010_daily.csv")
#dfs_mean <- aggregate(value ~  month + day + hierid, data = dfs, FUN = mean)
dfs_mean <- fread("/home/rfrost/repos/labor-code-release-2020/dfs_mean.csv")
#write.csv(dfs_mean,"/home/rfrost/repos/labor-code-release-2020/dfs_mean.csv")
#dfs_mean <- subset(dfs, year == 2010)
#rm(dfs)
#subset(df_mean, month !=2 & day != 29)

dfb <- merge(df_mean, dfs_mean,  by.x = c("hierid","month","day"),  by.y = c("hierid","month","day"), all.x = TRUE, all.y = TRUE)

LR_temp <- rep(0.0499968692364216, nrow(dfb))
LR_temp_s <- rep(-0.0030990557122301, nrow(dfb))
HR_temp <- rep(0.726375435490015, nrow(dfb))
HR_temp_s <- rep(-0.0186751538193722, nrow(dfb))

dfb <- cbind(dfb,LR_temp,LR_temp_s,HR_temp,HR_temp_s)

dfb <- dfb %>% rename("temp" = "value.x")
dfb <- dfb %>% rename("temp_s" = "value.y")

dfb$f_h <- dfb$temp*dfb$HR_temp + dfb$temp_s*dfb$HR_temp_s
dfb$f_h_opt_h <- 30.6007075824072*dfb$HR_temp + ((30.6007075824072-27)^3)*dfb$HR_temp_s

dfb$f_l <- dfb$temp*dfb$LR_temp + dfb$temp_s*dfb$LR_temp_s
dfb$f_l_opt_l <- 29.3189751020172*dfb$LR_temp + ((29.31897510201722-27)^3)*dfb$LR_temp_s

#each group is relative to its own optimum
dfb$d_h <- dfb$f_h - dfb$f_h_opt_h
dfb$d_l <- dfb$f_l - dfb$f_l_opt_l

dfb$diff <- dfb$d_h - dfb$d_l

#countries <- data.frame(do.call("rbind", strsplit(as.character(dfb$hierid), ".", fixed = TRUE)))
#dfb <- cbind(dfb, countries$X1)
#dfb <- dfb %>% rename("adm0" = "V2")

dfb <- merge(dfb, soc_ec, by.x = "hierid", by.y = "region", all.x = TRUE, all.y = TRUE,allow.cartesian=TRUE)

dfb$diff_dis <- (-1)*(dfb$diff*dfb$wage)/0.5

dfb$h_dis <- (-1)*(dfb$d_h*dfb$wage)/0.5
dfb$l_dis <- (-1)*(dfb$d_l*dfb$wage)/0.5

effects <- aggregate(cbind(diff,diff_dis,d_h,d_l,h_dis, l_dis) ~ hierid, data = dfb, FUN = sum)

effects <- merge(shp, effects, by.x = "hierid", by.y = "hierid", all.x = TRUE, all.y = TRUE)

effects <- merge(effects, gdp, by.x = "hierid", by.y = "region", all.x = TRUE, all.y = TRUE,allow.cartesian=TRUE)

effects$gdp <- effects$gdppc*effects$pop
effects$diff_dis_p <- ifelse(effects$gdp != 0,((effects$diff_dis*effects$pop)/effects$gdp)*100, 0)
effects$h_dis_p <- ifelse(effects$gdp != 0,((effects$h_dis*effects$pop)/effects$gdp)*100, 0)
effects$l_dis_p <- ifelse(effects$gdp != 0,((effects$l_dis*effects$pop)/effects$gdp)*100, 0)

#pop <- read.csv("/home/rfrost/repos/mortality/outreach/WP_2023/pop_backward_proj_no_round.csv")

#pop <- subset(pop, year == 2010)

#pop <- subset(pop, select = c(region,pop))
#effects <- subset(effects, select = -c(pop))
#effects <- merge(effects, pop, by.x = "hierid", by.y = "region", all.x = FALSE, all.y = TRUE)
#effects <- subset(effects, !(is.na(effects$adm0)))
effects <- subset(effects, effects$pop != 0)

total_pop <- sum(effects$pop)

effects$pw_dis_diff <- (effects$diff_dis_p)*(effects$pop/total_pop)

sum(effects$pw_dis_diff)

#color.values <- rev(c("#2c7bb6","#9dcfe4","#e7f8f8","grey95", "#ffedaa","#fec980","#d7191c"))
color.values <- c("grey95", "#ffedaa","#fec980","#d7191c")

bound = ceiling(max(abs(effects$h_dis_p), na.rm=TRUE))
#bound = ceiling(max(abs(effects$dis_h_1/365), na.rm=TRUE))
bound = 16
#scale_v = c(-1, -0.2, -0.05, -0.005, 0, 0.005, 0.05, 0.2, 1)
scale_v = c(0, 0.005, 0.05, 0.2, 1)
rescale_value <- scale_v*bound

limits_val = round(c(0, bound), 5)

breaks_labels_val = round(seq(0, bound, 2*bound/5), 5)

effects <- subset(effects, !(is.na(effects$hierid)))
#effects <- subset(effects, adm0 != "ATA")
#effects <- subset(effects, !(is.na(effects$effect_HR)))
ir <- subset(shp, hierid == "NGA.25.510")

lakeslist = c("CA-", "USA.23.1273","USA.14.642","USA.50.3082","USA.50.3083",
  "USA.23.1275","USA.15.740", "USA.24.1355", "USA.33.1855", "USA.36.2089", 
  "USA.23.1272", "UGA.32.80.484","UGA.32.80.484.2761", "TZA.13.59.1169", 
  "TZA.5.26.564", "TZA.17.86.1759", "ATA")
effects <- subset(effects, !(hierid %in% lakeslist))

ggplot(data = effects) +
  geom_sf(aes(fill = h_dis_p), color=NA)  + 
  theme_void() +
  #scale_fill_gradient2(low="red",mid = "grey99", high = "navy", midpoint=0,na.value = "grey99",guide = "colourbar") +
  #theme(legend.key.height=unit(0.5, 'cm'),legend.position = "bottom", legend.key.width=unit(0.5, "cm"),axis.text.x=element_blank(), axis.ticks.x=element_blank(), axis.text.y=element_blank(), axis.ticks.y=element_blank(), plot.title = element_text(family="Times New Roman",hjust = 0.5),panel.background = element_blank(),legend.title=element_text(size=10, family="Times New Roman"),legend.text=element_text(size=10,family="Times New Roman")) +
  theme(legend.key.height=unit(0.5, 'cm'),legend.position = "bottom", legend.key.width=unit(0.5, "cm"),axis.text.x=element_blank(), axis.ticks.x=element_blank(), axis.text.y=element_blank(), axis.ticks.y=element_blank(), plot.title = element_text(family="CenturySch",hjust = 0.5,),panel.background = element_blank(),legend.title=element_text(size=10, family="CenturySch"),legend.text=element_text(size=10,family="CenturySch")) +
  geom_rect(aes(xmin = -88.893717 , xmax = -86.893717 , ymin = 40.813365 , ymax = 42.813365), color = "black", fill = NA, size =0.01)  +
  geom_rect(aes(xmin = 9.716375 , xmax = 11.716375 , ymin = 58.970345 , ymax = 60.970345), color = "black", fill = NA, size =0.01)  +
  geom_rect(aes(xmin = -47.582095 , xmax = -45.582095 , ymin = -24.60702 , ymax = -22.60702), color = "black", fill = NA, size =0.01)  +
  geom_rect(aes(xmin = 115.33405 , xmax = 117.33405 , ymin = 38.954685 , ymax = 40.954685), color = "black", fill = NA, size =0.01)  +
  geom_rect(aes(xmin = 76.08533 , xmax = 78.08533 , ymin = 27.87319 , ymax = 29.87319), color = "black", fill = NA, size =0.01)  +
  geom_rect(aes(xmin = 2.404933 , xmax = 4.404933 , ymin = 5.482383 , ymax = 7.482383), color = "black", fill = NA, size =0.01)  +
  #ggtitle(glue("Difference in Disutility Between High and Low Risk Workers")) +
  scale_fill_gradientn(
    colors = color.values,
    values= rescale(rescale_value),
    na.value = "grey95",
    limits = limits_val, #center color scale so white is at 0
    breaks = breaks_labels_val, 
    labels = breaks_labels_val, #set freq of tick labels
    guide = guide_colorbar(title = "WTP (% Income)",
                           direction = "horizontal",
                           barheight = unit(4, units = "mm"),
                           barwidth = unit(200, units = "mm"),
                           draw.ulim = F,
                           title.position = 'top',
                           title.hjust = 0.5,
                           label.hjust = 0.7))
ggsave("/home/rfrost/repos/labor-code-release-2020/disutility_ext/hist_dis_map.png",bg = "white")
ggsave("/home/rfrost/repos/labor-code-release-2020/disutility_ext/hist_dis_map.pdf",bg = "white")

key_irs <- subset(effects, hierid == "USA.14.608" | hierid == "USA.5.221" | hierid ==  "USA.22.1228" | hierid == "DEU.3.12.141" |hierid == "FRA.11.75" | hierid == "CHN.6.46.280" | hierid == "CHN.2.18.78" |hierid == "BGD.3.9.18.132" | hierid == "IND.10.121.371" | hierid == "BRA.25.5212.R3fd4ed07b36dfd9c" | hierid == "NGA.25.510" | hierid == "NOR.12.288")
effects$city <- ifelse(effects$hierid == "USA.14.608", "Chicago", "")
effects$city <- ifelse(effects$hierid == "USA.5.221", "San Fransicso", effects$city)
effects$city <- ifelse(effects$hierid == "USA.22.1228", "Boston", effects$city)
effects$city <- ifelse(effects$hierid == "DEU.3.12.141", "Berlin", effects$city)
effects$city <- ifelse(effects$hierid == "FRA.11.75", "France", effects$city)
effects$city <- ifelse(effects$hierid == "CHN.6.46.280", "Guangzhou", effects$city)
effects$city <- ifelse(effects$hierid == "CHN.2.18.78", "Beijing", effects$city)
effects$city <- ifelse(effects$hierid == "BGD.3.9.18.132", "Dhaka", effects$city)
effects$city <- ifelse(effects$hierid == "IND.10.121.371", "Delhi", effects$city)
effects$city <- ifelse(effects$hierid == "BRA.25.5212.R3fd4ed07b36dfd9c", "Sao Paulo", effects$city)
effects$city <- ifelse(effects$hierid == "NGA.25.510", "Lagos", effects$city)
effects$city <- ifelse(effects$hierid == "NOR.12.288", "Oslo", effects$city)

key_irs <- subset(effects, select = c(city,diff_dis_p,h_dis_p, l_dis_p))
key_irs <- subset(key_irs, city != "")

write.csv(key_irs, "/home/rfrost/repos/labor-code-release-2020/disutility_ext/key_irs_disutility_diff_mean.csv")


#each group is relative to high risk optimum

dfb_2010$dis_h_3 <- dfb_2010$f_h - dfb_2010$f_h_opt_h
dfb_2010$dis_l_3 <- dfb_2010$f_l - dfb_2010$f_l_opt_h


#total_pop <- sum(effects$pop,na.rm = TRUE)
#effects$HR_pw_d <- effects$HR_d_p_gdp*(effects$pop/total_pop)
#effects$LR_pw_d <- effects$LR_d_p_gdp*(effects$pop/total_pop)

#total_gdp <- sum(effects$gdp,na.rm = TRUE)
#effects$HR_gw_d <- effects$HR_d_p_gdp*(effects$gdp/total_gdp)
#effects$LR_gw_d <- effects$LR_d_p_gdp*(effects$gdp/total_gdp)
pop <- read.csv("/home/rfrost/repos/mortality/outreach/WP_2023/pop_backward_proj_no_round.csv")
pop <- subset(pop, year ==2010)
effects <- merge(effects, pop, by.x = "hierid",by.y = "region", all.x = TRUE, all.y = TRUE)
effects$pop_total <- effects$pop0to4 + effects$pop5to64 + effects$pop65plus

effects$HR_total_d <- effects$effect_HR_d*effects$pop_total
effects$LR_total_d <- effects$effect_LR_d*effects$pop_total

totals <- aggregate(cbind(HR_total_d,LR_total_d ) ~ ISO, data = effects, FUN = 'sum')
totals <- merge(totals,gdp, by.x="ISO", by.y = "region", all.x = TRUE, all.y = TRUE)

totals$HR_total_d_pgdp <- (totals$HR_total_d/totals$gdp)*100
totals$LR_total_d_pgdp <- (totals$LR_total_d/totals$gdp)*100

USA <- subset(effects, ISO == "USA")
USA_geo <- data.frame(do.call("rbind", strsplit(as.character(USA$hierid), ".", fixed = TRUE)))
USA <- cbind(USA, USA_geo)
mass <- subset(USA, X2 == 22)

totals$HR_total_d_pgdp <- (totals$HR_total_d/totals$gdp)*100
totals$LR_total_d_pgdp <- (totals$LR_total_d/totals$gdp)*100
