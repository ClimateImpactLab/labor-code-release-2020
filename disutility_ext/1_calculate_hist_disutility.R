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

###########################################################################################################
# Code to make the weather Dataset - DON'T RUN THIS IT TAKES FOREVER, this is just here for documentation #
###########################################################################################################

#df <- fread("/shares/gcp/climate/_spatial_data/impactregions/weather_data/csv_daily/GMDF_tmax_temp_1950_to_2010_daily.csv")
#df_agg <- aggregate(value ~ month + day + hierid, data = df, FUN = mean)

#Load Spline Terms
#dfs <- fread("/shares/gcp/climate/_spatial_data/impactregions/weather_data/csv_daily/GMDF_tmax_spline_1950_to_2010_daily.csv")
#dfs_agg <- aggregate(value ~ month + day + hierid, data = dfs, FUN = mean)

#dfb <- merge(df_agg, dfs_agg, by.x = c("hierid","month","day"), by.y = c("hierid","month","day"), all.x = FALSE, all.y = FALSE)
#dfb <- dfb %>% rename("temp" = "value.x")
#dfb <- dfb %>% rename("temp_s" = "value.y")

#write.csv(dfb, "/shares/gcp/climate/_spatial_data/impactregions/weather_data/csv_daily/GMDF_tmax_temp_and_spline_avg_year.csv")

#add adjustments for assumptions about labor elasticity and piece rate/self employment

adjust <- "adjusted" #"original" 

if (adjust == "adjusted") {
  r <-0.35
  e <-  0.5
  x <- 3
} else {
  r <- 0
  e <- 0.5
  x <- 0
}

adjustment <- (1-e*x*r)

heckman <- "no_heckman" # "no_heckman"
interacted <- "uninteracted" #uninteracted

#setwd("")
dfb <- fread("/project/cil/sacagawea_shares/gcp/climate/_spatial_data/impactregions/weather_data/csv_daily/GMDF_tmax_temp_and_spline_avg_year.csv")
dfb <- rename(dfb, temp = value.x)
dfb <- rename(dfb, temp_s = value.y)

if (heckman == "heckman") {
    ###################################################
    # Uninteracted Main Model with Heckman Correction #
    ###################################################
    
    #These are hardcoded values for the betas from the main uninteracted model 
    LR_temp <- rep(0.0254575, nrow(dfb))
    LR_temp_s <- rep(-0.0030206, nrow(dfb))
    
    HR_temp <- rep(0.7888221, nrow(dfb))
    HR_temp_s <- rep(-0.019498, nrow(dfb))
    
    
    dfb <- cbind(dfb,LR_temp,LR_temp_s,HR_temp,HR_temp_s)
    
    #Predict LS based on temp for each group on actual temp realizations and the optimal temp
    dfb$f_h <- dfb$temp*dfb$HR_temp + dfb$temp_s*dfb$HR_temp_s
    dfb$f_h_opt_h <- 30.6723*dfb$HR_temp + ((30.6723-27)^3)*dfb$HR_temp_s
    
    dfb$f_l <- dfb$temp*dfb$LR_temp + dfb$temp_s*dfb$LR_temp_s
    dfb$f_l_opt_l <- 28.6751*dfb$LR_temp + ((28.6751-27)^3)*dfb$LR_temp_s
    
    #Calculate each group's daily decrease in LS  relative to its own optimum
    dfb$d_h <- dfb$f_h - dfb$f_h_opt_h
    dfb$d_h <- dfb$d_h*adjustment
    dfb$d_l <- dfb$f_l - dfb$f_l_opt_l
    
    dfb$diff <- dfb$d_h - dfb$d_l
    } else {
      if (interacted == "interacted") {
      ################################
      # Income Adaptation + Clipping #
      ################################
    
     
      #These are hardcoded values for the betas from the hi 1 factor, low uninteracted model
      LR_temp_c <- rep(0.0499968692364216, nrow(dfb))
      LR_temp_s_c <- rep(-0.0030990557122301, nrow(dfb))
    
      HR_temp_c <- rep(4.31963659302658, nrow(dfb))
      HR_temp_s_c <- rep(-0.0623342655530531, nrow(dfb))
    
      HR_temp_inc_c <- rep(-0.423440709308935, nrow(dfb))
      HR_temp_s_inc_c <- rep(0.0062603009512727, nrow(dfb))
    
      dfb <- cbind(dfb,LR_temp_c,LR_temp_s_c,HR_temp_c,HR_temp_s_c, HR_temp_inc_c, HR_temp_s_inc_c)
    
      soc_ec <- fread("/project/cil/sacagawea_shares/gcp/integration/float32/dscim_input_data/econvars/zarrs/integration-econ-bc39.csv")
      soc_ec <- subset(soc_ec, year == 2010)
      soc_ec <- subset(soc_ec, ssp == "SSP3")
      soc_ec <- aggregate(cbind(gdp, pop, gdppc)~ region, data = soc_ec, FUN = mean)
      soc_ec$wage <- (soc_ec$gdppc*0.6)/(250*6*60)
      soc_ec$loggdppc <- log(soc_ec$gdppc)
    
      dfb <- merge(dfb, soc_ec, by.x = "hierid", by.y = "region", all.x = TRUE, all.y = TRUE,allow.cartesian=TRUE)
  
      ################################################################################################################
      # Note! I have rounded the coefficients for the sake of the optimization because if i don't                    #
      # an insane thing happens where the roots of the quadratic of the derivative of the cubic function don't exist #
      # for a bunch of values of loggdppc. I think it is rounding/false precision issue but I don't know exactly     #
      ################################################################################################################
    
      #find optimum of the quadratic formula 
      dfb$a <- (-3*0.062+0.006*3*dfb$loggdppc)
      dfb$b <- 54*(-1)*(-3*0.062+0.006*3*dfb$loggdppc)
      dfb$c <- 729*(-3*0.062+ 0.006*3*dfb$loggdppc)+ dfb$loggdppc*(-0.42)+ 4.32
    
      dfb$inc_adpt_opt <- (-dfb$b - (dfb$b^2-4*dfb$a*dfb$c)^0.5)/(2*dfb$a)
    
      #check to make sure we are all good here
      #dfb_clipped <- subset(dfb, loggdppc > 10.2)
      #dfb_unclipped <- subset(dfb, loggdppc <= 10.2)
    
      #Predict LS based on temp for each group on actual temp realizations and the optimal temp
      dfb$f_h <- dfb$temp*dfb$HR_temp_c + dfb$temp_s*dfb$HR_temp_s_c + dfb$temp*dfb$HR_temp_inc_c + dfb$temp_s*dfb$HR_temp_s_inc_c 
      dfb$f_h_opt_h <- dfb$inc_adpt_opt*dfb$HR_temp_c + dfb$inc_adpt_opt*dfb$HR_temp_s_c + dfb$inc_adpt_opt*dfb$HR_temp_inc_c + dfb$inc_adpt_opt*dfb$HR_temp_s_inc_c 
    
    
      dfb$f_l <- dfb$temp*dfb$LR_temp_c + dfb$temp_s*dfb$LR_temp_s_c 
      dfb$f_l_opt_l <- 29.3189751020172*dfb$LR_temp_c + ((29.31897510201722-27)^3)*dfb$LR_temp_s_c
    
      #Calculate each group's daily decrease in LS  relative to its own optimum
      dfb$d_l <- dfb$f_l - dfb$f_l_opt_l
      #do clipping
      dfb$d_h <- ifelse(dfb$f_h < dfb$f_l ,dfb$f_h - dfb$f_h_opt_h, dfb$f_l - dfb$f_l_opt_l)
      #add adjustments 
      dfb$d_h <- dfb$d_h*adjustment
    
    
      dfb$diff <- dfb$d_h - dfb$d_l
      } else {
    
      ########################################################
      # Do the welfare calculations - Uninteracted Main Model #
      ########################################################
    
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
      dfb$d_h <- dfb$d_h*adjustment
      dfb$d_l <- dfb$f_l - dfb$f_l_opt_l
    
      dfb$diff <- dfb$d_h - dfb$d_l
      }
    }

countries <- data.frame(do.call("rbind", strsplit(as.character(dfb$hierid), ".", fixed = TRUE)))
dfb <- cbind(dfb, countries$X1)
dfb <- dfb %>% rename("ISO" = "V2")
rm(countries)

# add up results over the full year
dfb <- aggregate(cbind(diff, d_h, d_l) ~ ISO + hierid, data = dfb, FUN = sum)

soc_ec <- fread("/project/cil/sacagawea_shares/gcp/integration/float32/dscim_input_data/econvars/zarrs/integration-econ-bc39.csv")
soc_ec <- subset(soc_ec, year == 2010)
soc_ec <- subset(soc_ec, model == "OECD Env-Growth")
soc_ec <- subset(soc_ec, ssp == "SSP3")
soc_ec <- subset(soc_ec, select = c(region,gdp,pop,gdppc))
soc_ec$wage <- (soc_ec$gdppc*0.6)/(250*6*60)

dfb <- merge(dfb, soc_ec, by.x = "hierid", by.y = "region", all.x = TRUE, all.y = TRUE,allow.cartesian=TRUE)

dfb$diff_dis <- (-1)*(dfb$diff*dfb$wage)/0.5

dfb$h_dis <- (-1)*(dfb$d_h*dfb$wage)/0.5
dfb$l_dis <- (-1)*(dfb$d_l*dfb$wage)/0.5


#calculate disultility as % of annual income
dfb$diff_dis_p <- ifelse(dfb$gdppc != 0,((dfb$diff_dis)/dfb$gdppc)*100, 0)
dfb$h_dis_p <- ifelse(dfb$gdppc != 0,((dfb$h_dis)/dfb$gdppc)*100, 0)
dfb$l_dis_p <- ifelse(dfb$gdppc != 0,((dfb$l_dis)/dfb$gdppc)*100, 0)

total_pop <- sum(dfb$pop, na.rm = TRUE)
dfb$pop_w <- dfb$pop/total_pop


dfb$diff_dis_p_pw <- (dfb$pop_w)*(dfb$diff_dis_p)
mean <- as.matrix(sum(dfb$diff_dis_p_pw, na.rm = TRUE))
value <- c("mean")
mean <- as.data.frame(cbind(value,mean))
mean

fwrite(dfb, glue('/home/rfrost/repos/labor-code-release-2020/disutility_ext/outputs/hedonic_valuation_{adjust}_{heckman}_r0.35_x3.csv'))

