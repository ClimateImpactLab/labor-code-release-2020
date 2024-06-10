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
#library(Hmisc)


#Read in the various options for the analysis
adjust <- "adjusted"  #"original"

if (adjust == "adjusted") {
  r <-0.35
  e <-  0.5
  x <- 3
  # x = 3 corresponds to change in wage of -30%
  # x = 1.5 corresponds to change in wage of -15%
  # x = 0.5 corresponds to change in wage of -5%
  # x = -0.5 corresponds to change in wage of +5%
} else {
  r <- 0
  e <- 0.5
  x <- 0
}

if (adjust == "adjusted") {
  r_label <- paste0("_r=",r)
  e_label <- paste0("_e=_",e)
  x_label <- paste0("_x=",x)
} else {
  r_label <- paste0("")
  e_label <- paste0("")
  x_label <- paste0("")
}

adjustment <- (1-e*x*r)

heckman <- "no_heckman" # "heckman"
interacted <- "uninteracted" #interacted

#read in the IR-level damages (calculated in 1_calculate_hist_disutility.R)
dfb <- fread(glue('/home/rfrost/repos/labor-code-release-2020/disutility_ext/outputs/hedonic_valuation_{adjust}{r_label}{e_label}{x_label}_{heckman}_{interacted}.csv'))

weighted.mean(dfb$diff_dis_p, dfb$pop, na.rm =TRUE)

#Choose Calculation
calculation <- "map" # #quantiles #aggregates key_cities


#Do Chosen Calculation
if (calculation == "key_cities") {
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
  
}

if (calculation == "map"){
  #CARTOGRAPHY TIME
  shp <- st_read("/project/cil/battuta_shares/gcp/regions/world-combo-new/agglomerated-world-new.shp")
  
  effects <- merge(shp, dfb, by.x = "hierid", by.y = "hierid", all.x = TRUE, all.y = TRUE)
  
  # We only use the negative colour sceme for this since there are no positive values
  
  #color.values <- rev(c("#2c7bb6","#9dcfe4","#e7f8f8","grey95", "#ffedaa","#fec980","#d7191c"))
  color.values <- c("grey95", "#ffedaa","#fec980","#d7191c")
  
  #bound = ceiling(max(abs(effects$diff_dis_p), na.rm=TRUE))
  bound = 17 #hardcoding bound to be 17 so all the maps are on the same scale
  #scale_v = c(-1, -0.2, -0.05, -0.005, 0, 0.005, 0.05, 0.2, 1)
  scale_v = c(0, 0.005, 0.05, 0.2, 1)
  rescale_value <- scale_v*bound
  
  limits_val = round(c(0, bound), 5)
  
  breaks_labels_val = round(seq(0, bound, 2*bound/5), 5)
  
  effects <- subset(effects, !(is.na(effects$hierid)))
  
  #lakeslist = c("CA-", "USA.23.1273","USA.14.642","USA.50.3082","USA.50.3083",
                #"USA.23.1275","USA.15.740", "USA.24.1355", "USA.33.1855", "USA.36.2089", 
                #"USA.23.1272", "UGA.32.80.484","UGA.31.79.483.2760","UGA.32.80.484.2761", "TZA.13.59.1169", 
                #"TZA.5.26.564", "TZA.17.86.1759", "ATA", "PER.8.71.705","PER.7.67.677","ARM.7","USA.23.1274","TZA.8.37.779")
  
  lakeslist = c("CA-", "USA.23.1273","USA.14.642","USA.50.3082","USA.50.3083",
                "USA.23.1275","USA.15.740", "USA.24.1355", "USA.33.1855", "USA.36.2089", 
                "USA.23.1272", "UGA.32.80.484","UGA.32.80.484.2761", "TZA.13.59.1169", 
                "TZA.5.26.564", "TZA.17.86.1759", "ATA")
  effects <- subset(effects, !(hierid %in% lakeslist))
  
  
  p <- ggplot(data = effects) + 
    geom_sf(aes(fill = diff_dis_p), color=NA)  + 
    theme_void() +
    labs( caption = glue("{heckman} {r_label} {e_label} {x_label} {interacted}"))+
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
  
  ggsave(p,glue("~/repos/labor-code-release-2020/disutility_ext/outputs/Value_LR_job_map_{adjust}{r_label}{e_label}{x_label}_{heckman}_{interacted}.png"),bg = "white",width = 8, height = 6)
  

}

if (calculation == "quantiles"){
  effects <- subset(dfb, !(is.na(dfb$hierid)))
  lakeslist = c("CA-", "USA.23.1273","USA.14.642","USA.50.3082","USA.50.3083",
                "USA.23.1275","USA.15.740", "USA.24.1355", "USA.33.1855", "USA.36.2089", 
                "USA.23.1272", "UGA.32.80.484","UGA.31.79.483.2760","UGA.32.80.484.2761", "TZA.13.59.1169", 
                "TZA.5.26.564", "TZA.17.86.1759", "ATA", "PER.8.71.705","PER.7.67.677","ARM.7","USA.23.1274","TZA.8.37.779")
  effects <- subset(effects, !(hierid %in% lakeslist))
  
  #pop-weighte quantiles
  p01 <- as.matrix(weighted.quantile(effects$diff_dis_p, effects$pop_w, prob = 0.01, plot = FALSE))
  p05 <- as.matrix(weighted.quantile(effects$diff_dis_p, effects$pop_w, prob = 0.05, plot = FALSE))
  p10 <- as.matrix(weighted.quantile(effects$diff_dis_p, effects$pop_w, prob = 0.10, plot = FALSE))
  p25 <- as.matrix(weighted.quantile(effects$diff_dis_p, effects$pop_w, prob = 0.25, plot = FALSE))
  p50 <- as.matrix(weighted.quantile(effects$diff_dis_p, effects$pop_w, prob = 0.50, plot = FALSE))
  p75 <- as.matrix(weighted.quantile(effects$diff_dis_p, effects$pop_w, prob = 0.75, plot = FALSE))
  p90 <- as.matrix(weighted.quantile(effects$diff_dis_p, effects$pop_w, prob = 0.90, plot = FALSE))
  p95 <- as.matrix(weighted.quantile(effects$diff_dis_p, effects$pop_w, prob = 0.95, plot = FALSE))
  p99 <- as.matrix(weighted.quantile(effects$diff_dis_p, effects$pop_w, prob = 0.99, plot = FALSE))
  
  quants <- as.data.frame(rbind(p01,p05,p10,p25,p50,p75,p90,p95,p99))
  
  percs <- as.data.frame(c("1st","5th","10th","25th","50th","75th","90th","95th","99th"))

  
  quants <- cbind(percs, quants)
  quants <- rename(quants, "value" = "V1")
  quants <- rename(quants, "percentile" = "c(\"1st\", \"5th\", \"10th\", \"25th\", \"50th\", \"75th\", \"90th\", \"95th\", \"99th\")")
  fwrite(quants,glue("~/repos/labor-code-release-2020/disutility_ext/outputs/pop_w_quantiles_{adjust}{r_label}{e_label}{x_label}_{heckman}_{interacted}.csv"))
  
}

if (calculation == "aggregations") {
  effects <- subset(dfb, !(is.na(effects$hierid)))
  lakeslist = c("CA-", "USA.23.1273","USA.14.642","USA.50.3082","USA.50.3083",
                "USA.23.1275","USA.15.740", "USA.24.1355", "USA.33.1855", "USA.36.2089", 
                "USA.23.1272", "UGA.32.80.484","UGA.31.79.483.2760","UGA.32.80.484.2761", "TZA.13.59.1169", 
                "TZA.5.26.564", "TZA.17.86.1759", "ATA", "PER.8.71.705","PER.7.67.677","ARM.7","USA.23.1274","TZA.8.37.779")
  effects <- subset(effects, !(hierid %in% lakeslist))
  #  Make aggregations #
  
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
}




