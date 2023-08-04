#This script takes the temperature realizations from 1950 to 2010 and calculates the average for every day of the year
#It calculates the disutlitly associated with a high-risk job in each IR
#It then calculates the aggregates for a list of countries/regions
library(data.table)
library(dplyr)
library(tidyr)
library(ggplot2)
library(sf)
library(scales)
library(purrr)
library(glue)
library(Hmisc)

# Code to make the Dataset - DON'T RUN THIS IT TAKES FOREVER, this is just here for documentation

#df <- fread("/shares/gcp/climate/_spatial_data/impactregions/weather_data/csv_daily/GMDF_tmax_temp_1950_to_2010_daily.csv")
#df_agg <- aggregate(value ~ month + day + hierid, data = df, FUN = mean)

#Load Spline Terms
#dfs <- fread("/shares/gcp/climate/_spatial_data/impactregions/weather_data/csv_daily/GMDF_tmax_spline_1950_to_2010_daily.csv")
#dfs_agg <- aggregate(value ~ month + day + hierid, data = dfs, FUN = mean)

#dfb <- merge(df_agg, dfs_agg, by.x = c("hierid","month","day"), by.y = c("hierid","month","day"), all.x = FALSE, all.y = FALSE)
#dfb <- dfb %>% rename("temp" = "value.x")
#dfb <- dfb %>% rename("temp_s" = "value.y")

#write.csv(dfb, "/shares/gcp/climate/_spatial_data/impactregions/weather_data/csv_daily/GMDF_tmax_temp_and_spline_avg_year.csv")

dfb <- fread("/shares/gcp/climate/_spatial_data/impactregions/weather_data/csv_daily/GMDF_tmax_temp_and_spline_avg_year.csv")

#These are hardcoded values for the betas from the main uninteracted model 
LR_temp <- rep(0.0499968692364216, nrow(dfb))
LR_temp_s <- rep(-0.0030990557122301, nrow(dfb))
HR_temp <- rep(0.726375435490015, nrow(dfb))
HR_temp_s <- rep(-0.0186751538193722, nrow(dfb))

dfb <- cbind(dfb,LR_temp,LR_temp_s,HR_temp,HR_temp_s)

#Predict LS based on temp for each group on actual temp realizations and the optimal temp
dfb$f_h <- dfb$temp*dfb$HR_temp + dfb$temp_s*dfb$HR_temp_s
dfb$f_h_opt_h <- 30.6007075824072*dfb$HR_temp + ((30.6007075824072-27)^3)*dfb$HR_temp_s

dfb$f_l <- dfb$temp*dfb$LR_temp + dfb$temp_s*dfb$LR_temp_s
dfb$f_l_opt_l <- 29.3189751020172*dfb$LR_temp + ((29.31897510201722-27)^3)*dfb$LR_temp_s

#Calculate each group's daily decrease in LS  relative to its own optimum
dfb$d_h <- dfb$f_h - dfb$f_h_opt_h
dfb$d_l <- dfb$f_l - dfb$f_l_opt_l

dfb$diff <- dfb$d_h - dfb$d_l

soc_ec <- fread("/shares/gcp/integration/float32/dscim_input_data/econvars/zarrs/integration-econ-bc39.csv")
soc_ec <- subset(soc_ec, year == 2010)
soc_ec <- subset(soc_ec, model == "OECD Env-Growth")
soc_ec <- subset(soc_ec, ssp == "SSP3")
gdp <- subset(soc_ec, select = c(region,gdp,pop,gdppc))
soc_ec$wage <- (soc_ec$gdppc*0.6)/(250*6*60)

dfb <- merge(dfb, soc_ec, by.x = "hierid", by.y = "region", all.x = TRUE, all.y = TRUE,allow.cartesian=TRUE)

countries <- data.frame(do.call("rbind", strsplit(as.character(dfb$hierid), ".", fixed = TRUE)))
dfb <- cbind(dfb, countries$X1)
dfb <- dfb %>% rename("ISO" = "V2")

dfb$diff_dis <- (-1)*(dfb$diff*dfb$wage)/0.5

dfb$h_dis <- (-1)*(dfb$d_h*dfb$wage)/0.5
dfb$l_dis <- (-1)*(dfb$d_l*dfb$wage)/0.5

#add up results over the full year
effects <- aggregate(cbind(diff, d_h, d_l,diff_dis,h_dis, l_dis) ~ ISO + hierid, data = dfb, FUN = sum)
effects <- merge(effects, soc_ec, by.x = "hierid", by.y = "region", all.x = TRUE, all.y = TRUE,allow.cartesian=TRUE)

#calculate disultility as % of annual income
effects$diff_dis_p <- ifelse(effects$gdppc != 0,((effects$diff_dis)/effects$gdppc)*100, 0)
effects$h_dis_p <- ifelse(effects$gdppc != 0,((effects$h_dis)/effects$gdppc)*100, 0)
effects$l_dis_p <- ifelse(effects$gdppc != 0,((effects$l_dis)/effects$gdppc)*100, 0)

#Get results for key cities and write them in  a CSV
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
effects$city <- ifelse(effects$hierid == "NOR.12.288", "Oslo", effects$city)
effects$city <- ifelse(effects$hierid == "USA.3.101", "Pheonix (Maricopa County)", effects$city)
effects$city <- ifelse(effects$hierid == "IRQ.10.55", "Baghdad", effects$city)

key_irs <- subset(effects, city != "")
key_irs <- subset(key_irs, select = c(city, diff_dis_p, h_dis_p, l_dis_p ))

write.csv(key_irs, "~/repos/labor-code-release-2020/disutility_ext/outputs/key_cities.csv")

#CARTOGRAPHY TIME
shp <- st_read("/shares/gcp/regions/world-combo-new/agglomerated-world-new.shp")

effects <- merge(shp, effects, by.x = "hierid", by.y = "hierid", all.x = TRUE, all.y = TRUE)

# We only use the negative colour sceme for this since there are no positive values

#color.values <- rev(c("#2c7bb6","#9dcfe4","#e7f8f8","grey95", "#ffedaa","#fec980","#d7191c"))
color.values <- c("grey95", "#ffedaa","#fec980","#d7191c")

bound = ceiling(max(abs(effects$diff_dis_p), na.rm=TRUE))
#bound = ceiling(max(abs(effects$dis_h_1/365), na.rm=TRUE))
#bound = 16
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
  geom_sf(aes(fill = diff_dis_p), color=NA)  + 
  theme_void() +
  #scale_fill_gradient2(low="red",mid = "grey99", high = "navy", midpoint=0,na.value = "grey99",guide = "colourbar") +
  #theme(legend.key.height=unit(0.5, 'cm'),legend.position = "bottom", legend.key.width=unit(0.5, "cm"),axis.text.x=element_blank(), axis.ticks.x=element_blank(), axis.text.y=element_blank(), axis.ticks.y=element_blank(), plot.title = element_text(family="Times New Roman",hjust = 0.5),panel.background = element_blank(),legend.title=element_text(size=10, family="Times New Roman"),legend.text=element_text(size=10,family="Times New Roman")) +
  #theme(legend.key.height=unit(0.5, 'cm'),legend.position = "bottom", legend.key.width=unit(0.5, "cm"),axis.text.x=element_blank(), axis.ticks.x=element_blank(), axis.text.y=element_blank(), axis.ticks.y=element_blank(), plot.title = element_text(family="CenturySch",hjust = 0.5,),panel.background = element_blank(),legend.title=element_text(size=10, family="CenturySch"),legend.text=element_text(size=10,family="CenturySch")) +
  theme(plot.title = element_text(hjust=0.5, size = 10), 
        plot.caption = element_text(hjust=0.5, size = 7), 
        legend.title = element_text(hjust=0.5, size = 10), 
        legend.position = "bottom",
        legend.text = element_text(size = 7),
        axis.title= element_blank(), 
        axis.text = element_blank(),
        axis.ticks = element_blank(),
        panel.grid = element_blank(),
        panel.border = element_blank()) +   
  #labs(title = map.title, caption = caption_val) +
  # BOXES
  #geom_rect(aes(xmin = -88.893717 , xmax = -86.893717 , ymin = 40.813365 , ymax = 42.813365), color = "black", fill = NA, size =0.01)  +
  #geom_rect(aes(xmin = 9.716375 , xmax = 11.716375 , ymin = 58.970345 , ymax = 60.970345), color = "black", fill = NA, size =0.01)  +
  #geom_rect(aes(xmin = -47.582095 , xmax = -45.582095 , ymin = -24.60702 , ymax = -22.60702), color = "black", fill = NA, size =0.01)  +
  #geom_rect(aes(xmin = 115.33405 , xmax = 117.33405 , ymin = 38.954685 , ymax = 40.954685), color = "black", fill = NA, size =0.01)  +
  #geom_rect(aes(xmin = 76.08533 , xmax = 78.08533 , ymin = 27.87319 , ymax = 29.87319), color = "black", fill = NA, size =0.01)  +
  #geom_rect(aes(xmin = 2.404933 , xmax = 4.404933 , ymin = 5.482383 , ymax = 7.482383), color = "black", fill = NA, size =0.01)  +
  #ggtitle(glue("Difference in Disutility Between High and Low Risk Workers")) +
  scale_fill_gradientn(
    colors = color.values,
    values= rescale(rescale_value),
    na.value = "grey95",
    limits = limits_val, #center color scale so white is at 0
    breaks = breaks_labels_val, 
    labels = breaks_labels_val, #set freq of tick labels
    guide = guide_colorbar(title = "Willingness to Pay for Low-Risk Job (% 2010 Income)",
                           direction = "horizontal",
                           barheight = unit(4, units = "mm"),
                           barwidth = unit(100, units = "mm"),
                           draw.ulim = F,
                           title.position = 'top',
                           title.hjust = 0.5,
                           label.hjust = 0.5))

ggsave("~/repos/labor-code-release-2020/disutility_ext/outputs/Value_LR_job_map.pdf",bg = "white",width = 8, height = 6)

#  Make aggregations #

# Global pop-weighted average # 

effects <- subset(effects, effects$pop != 0)
total_pop <- sum(effects$pop)
effects$pw_dis_diff <- (effects$diff_dis_p)*(effects$pop/total_pop)
world_pw_mean <- sum(effects$pw_dis_diff)

USA <- subset(effects, ISO.x == "USA")
USA_geo <- data.frame(do.call("rbind", strsplit(as.character(USA$hierid), ".", fixed = TRUE)))
USA <- cbind(USA, USA_geo)
USA  <- USA  %>% rename("state_code" = "X2")

usa_pop <- sum(USA$pop)
USA$pw_dis_diff <- (USA$diff_dis_p)*(USA$pop/usa_pop)
usa_pw_mean <- sum(USA$pw_dis_diff)

alaska <- subset(USA, state_code == 2)
alaska_pop <- sum(alaska$pop)
alaska$pw_dis_diff <- (alaska$diff_dis_p)*(alaska$pop/alaska_pop)
alaska_pw_mean <- sum(alaska$pw_dis_diff)

CAN <- subset(effects, ISO.x == "CAN")
can_pop <- sum(CAN$pop)
CAN$pw_dis_diff <- (CAN$diff_dis_p)*(CAN$pop/can_pop)
can_pw_mean <- sum(CAN$pw_dis_diff)


SDN <- subset(effects, ISO.x == "SDN")
sdn_pop <- sum(SDN$pop)
SDN$pw_dis_diff <- (SDN$diff_dis_p)*(SDN$pop/sdn_pop)
sdn_pw_mean <- sum(SDN$pw_dis_diff)

IND <- subset(effects, ISO.x == "IND")
ind_pop <- sum(IND$pop)
IND$pw_dis_diff <- (IND$diff_dis_p)*(IND$pop/ind_pop)
ind_pw_mean <- sum(IND$pw_dis_diff)

PAK <- subset(effects, ISO.x == "PAK")
pak_pop <- sum(PAK$pop)
PAK$pw_dis_diff <- (PAK$diff_dis_p)*(PAK$pop/pak_pop)
pak_pw_mean <- sum(PAK$pw_dis_diff)

CHN <- subset(effects, ISO.x == "CHN")
chn_pop <- sum(CHN$pop)
CHN$pw_dis_diff <- (CHN$diff_dis_p)*(CHN$pop/chn_pop)
chn_pw_mean <- sum(CHN$pw_dis_diff)

BRA <- subset(effects, ISO.x == "BRA")
bra_pop <- sum(BRA$pop)
BRA$pw_dis_diff <- (BRA$diff_dis_p)*(BRA$pop/bra_pop)
bra_pw_mean <- sum(BRA$pw_dis_diff)

AUS <- subset(effects, ISO.x == "AUS")
aus_pop <- sum(AUS$pop)
AUS$pw_dis_diff <- (AUS$diff_dis_p)*(AUS$pop/aus_pop)
aus_pw_mean <- sum(AUS$pw_dis_diff)

#get continents and regions!
conts <- fread("/shares/gcp/regions/continents2.csv")
conts <- conts %>% rename("iso" = "alpha-3")
conts <- conts %>% rename("sub_region" = "sub-region")

europe <- subset(conts, region == "Europe")
sub_saharan_africa <- subset(conts, sub_region == "Sub-Saharan Africa")

europe <- as.matrix(unique(europe$iso))
sub_saharan_africa <- unique(sub_saharan_africa$iso)

EUR <- subset(effects, ISO.x %in% europe)
EUR_pop <- sum(EUR$pop)
EUR$pw_dis_diff <- (EUR$diff_dis_p)*(EUR$pop/EUR_pop)
eur_pw_mean <- sum(EUR$pw_dis_diff)

SSA <- subset(effects, ISO.x %in% sub_saharan_africa)
ssa_pop <- sum(EUR$pop)
SSA$pw_dis_diff <- (SSA$diff_dis_p)*(SSA$pop/ssa_pop)
ssa_pw_mean <- sum(SSA$pw_dis_diff)

agg_titles <- c("World", "USA", "Alaska", "Canada","Sudan","India", "Pakisan","China","Brazil","Australia","Sub-Saharan Africa","Europe")
agg_values <- c(world_pw_mean, usa_pw_mean, alaska_pw_mean, can_pw_mean, sdn_pw_mean, ind_pw_mean, pak_pw_mean, chn_pw_mean, bra_pw_mean, aus_pw_mean, ssa_pw_mean, eur_pw_mean)

aggregates <- as.data.frame(cbind(agg_titles,agg_values))

fwrite(aggregates,"~/repos/labor-code-release-2020/disutility_ext/outputs/regional_aggregates.csv")

#Quantiles
effects$pop_w <- (effects$pop/total_pop)

quants <- as.matrix(weighted.quantile(effects$diff_dis_p, weights = effects$pop_w, probs = c(0.05,0.1, 0.25,0.5,0.75,0.90,0.95)))
percs <- c("5th","10th","25th","50th","75th","90th","95th")

pw_quants <- as.data.frame(cbind(percs,quants))
fwrite(pw_quants,"~/repos/labor-code-release-2020/disutility_ext/outputs/pop_w_quantiles.csv")

