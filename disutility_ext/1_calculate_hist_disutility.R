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

#SET OPTIONS!

#add adjustments for assumptions about labor elasticity and piece rate/self employment

adjust <- "original"  #"adjusted"


if (adjust == "adjusted") {
  r <-0.35
  e <-  0.5
  x <- -0.5
  # x = 3 corresponds to change in wage of -30%
  # x = 1.5 corresponds to change in wage of -15%
  # x = 0.5 corresponds to change in wage of -5%
  # x = -0.5 corresponds to change in wage of +5%
} else {
  r <- 0
  e <- 0.5
  x <- 0
}

#Make Labels
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

heckman <- "no_heckman" # "no_heckman"
interacted <- "interacted" #uninteracted

#Read in Weather Data
#dfb <- fread("/project/cil/sacagawea_shares/gcp/climate/_spatial_data/impactregions/weather_data/csv_daily/GMDF_tmax_temp_and_spline_avg_year.csv")
dfb <- fread("/Users/rfrost/Documents/Labour/GMDF_tmax_temp_and_spline_avg_year.csv")

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
    
    #soc_ec <- fread("/project/cil/sacagawea_shares/gcp/integration/float32/dscim_input_data/econvars/zarrs/integration-econ-bc39.csv")
    soc_ec <- fread("/Users/rfrost/Documents/Labour/integration-econ-bc39.csv")
    soc_ec <- subset(soc_ec, year == 2010)
    soc_ec <- subset(soc_ec, ssp == "SSP3")
    soc_ec <- aggregate(cbind(gdp, pop, gdppc)~ region, data = soc_ec, FUN = "mean")
    soc_ec$wage <- (soc_ec$gdppc*0.6)/(250*6*60)
    soc_ec$loggdppc <- log(soc_ec$gdppc)
    
    dfb <- merge(dfb, soc_ec, by.x = "hierid", by.y = "region", all.x = FALSE, all.y = TRUE, allow.cartesian=TRUE)
    
    ################################################################################################################
    # Note! I have rounded the coefficients for the sake of the optimization because if i don't                    #
    # an insane thing happens where the roots of the quadratic of the derivative of the cubic function don't exist #
    # for a bunch of values of loggdppc. I think it is rounding/false precision issue but I don't know exactly     #
    ################################################################################################################
    
    #find optimum of the quadratic formula (This is from a previous version,we are using the LR optimum now)
    dfb$a <- (-3*0.062+0.006*3*dfb$loggdppc)
    dfb$b <- 54*(-1)*(-3*0.062+0.006*3*dfb$loggdppc)
    dfb$c <- 729*(-3*0.062+ 0.006*3*dfb$loggdppc)+ dfb$loggdppc*(-0.42)+ 4.32
    dfb$inc_adpt_opt_r1 <- (-dfb$b - (dfb$b^2-4*dfb$a*dfb$c)^0.5)/(2*dfb$a)
    dfb$inc_adpt_opt_r2 <- (-dfb$b + (dfb$b^2-4*dfb$a*dfb$c)^0.5)/(2*dfb$a)
    dfb$inc_adpt_opt <- ifelse(dfb$inc_adpt_opt_r1> dfb$inc_adpt_opt_r2, dfb$inc_adpt_opt_r1, dfb$inc_adpt_opt_r2)
    
    #dfb$inc_adpt_opt <- 29.3189751020172
    
    #Predict LS based on temp for each group on actual temp realizations and the optimal temp
    dfb$f_h <- dfb$temp*dfb$HR_temp_c + dfb$temp_s*dfb$HR_temp_s_c + dfb$temp*dfb$HR_temp_inc_c*dfb$loggdppc + dfb$temp_s*dfb$HR_temp_s_inc_c*dfb$loggdppc
    dfb$f_h_opt_h <- dfb$inc_adpt_opt*dfb$HR_temp_c + dfb$inc_adpt_opt*dfb$HR_temp_s_c + dfb$inc_adpt_opt*dfb$HR_temp_inc_c*dfb$loggdppc + dfb$inc_adpt_opt*dfb$HR_temp_s_inc_c*dfb$loggdppc 
    
    dfb$f_l <- dfb$temp*dfb$LR_temp_c + dfb$temp_s*dfb$LR_temp_s_c 
    dfb$f_l_opt_l <- 29.3189751020172*dfb$LR_temp_c + ((29.31897510201722-27)^3)*dfb$LR_temp_s_c
    
    #Calculate each group's daily decrease in LS  relative to its own optimum
    dfb$d_l <- dfb$f_l - dfb$f_l_opt_l
    dfb$d_h <- dfb$f_h - dfb$f_h_opt_h
    
    #do clipping
    dfb$d_h <- ifelse(dfb$d_h < dfb$d_l, dfb$d_h, dfb$d_l)
    #add adjustments 
    dfb$d_h <- dfb$d_h*adjustment
    
    #NO BUBBLES!
    #dfb$d_h <- ifelse(dfb$loggdppc < 10.1, dfb$d_h, dfb$d_l)
    
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
    dfb$d_l <- dfb$f_l - dfb$f_l_opt_l
    
    dfb$diff <- (dfb$d_h - dfb$d_l)*adjustment
  }
}

# * ~ * ~ * ~ * ~ * ~ * ~ #
# DEBUGGING RESONSE CURVE #
# * ~ * ~ * ~ * ~ * ~ * ~ #

#use this part to plot the response curve if you want

#dfb <- subset(dfb, select = c(hierid,month,day,temp, temp_s, loggdppc,d_l, d_h,diff, f_l, f_l_opt_l, f_h, f_h_opt_h))
#dfb$section <- ifelse(dfb$temp < 27, 1, 0)
#dfb$section <- ifelse(dfb$temp >= 27, 2, dfb$section )
#dfb$section <- ifelse(dfb$temp >= 37, 3, dfb$section )
#dfb$section <- ifelse(dfb$temp >= 39, 4, dfb$section )

#ggplot(dfb, aes(x=temp, y=d_h)) + geom_point(aes(color=loggdppc), size=0.5, alpha =1/10)


countries <- data.frame(do.call("rbind", strsplit(as.character(dfb$hierid), ".", fixed = TRUE)))
dfb <- cbind(dfb, countries$X1)
dfb <- dfb %>% rename("ISO" = "V2")
rm(countries)

# add up results over the full year
dfb <- aggregate(cbind(diff, d_h, d_l) ~ hierid, data = dfb, FUN = sum)

#soc_ec <- fread("/project/cil/sacagawea_shares/gcp/integration/float32/dscim_input_data/econvars/zarrs/integration-econ-bc39.csv")
soc_ec <- fread("/Users/rfrost/Documents/Labour/integration-econ-bc39.csv")
soc_ec <- subset(soc_ec, year == 2010)
soc_ec <- subset(soc_ec, ssp == "SSP3")
soc_ec <- aggregate(cbind(gdp, pop, gdppc)~ region, data = soc_ec, FUN = "mean")
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

#Check mean before writing
weighted.mean(dfb$diff_dis_p, dfb$pop, na.rm =TRUE)

fwrite(dfb, glue('/home/rfrost/repos/labor-code-release-2020/disutility_ext/outputs/hedonic_valuation_{adjust}{r_label}{e_label}{x_label}_{heckman}_{interacted}.csv'))
