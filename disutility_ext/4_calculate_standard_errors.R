library(data.table)
library(dplyr)
library(tidyr)
#library(ggplot2)
#library(sf)
#library(scales)
#library(purrr)
#library(glue)
library(mvtnorm)

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

dfb <- fread("/Users/rfrost/Documents/Labour/GMDF_tmax_temp_and_spline_avg_year.csv")

dfb <- rename(dfb, temp = value.x)
dfb <- rename(dfb, temp_s = value.y)

adjustment <- (1-e*x*r)

heckman <- "no_heckman" # "no_heckman"
interacted <- "interacted" #uninteracted

#Read in Weather Data
dfb <- fread("/project/cil/sacagawea_shares/gcp/climate/_spatial_data/impactregions/weather_data/csv_daily/GMDF_tmax_temp_and_spline_avg_year.csv")
#dfb <- fread("/Users/rfrost/Documents/Labour/GMDF_tmax_temp_and_spline_avg_year.csv")

dfb <- rename(dfb, temp = value.x)
dfb <- rename(dfb, temp_s = value.y)

dfb <- aggregate(cbind(temp, temp_s) ~ hierid, data=dfb, FUN=sum)

soc_ec <- fread("/project/cil/sacagawea_shares/gcp/integration/float32/dscim_input_data/econvars/zarrs/integration-econ-bc39.csv")
#soc_ec <- fread("/Users/rfrost/Documents/Labour/integration-econ-bc39.csv")

soc_ec <- subset(soc_ec, year == 2010)
soc_ec <- subset(soc_ec, ssp == "SSP3")
soc_ec <- aggregate(cbind(gdp, pop, gdppc)~ region, data = soc_ec, FUN = "mean")
soc_ec$wage <- (soc_ec$gdppc*0.6)/(250*6*60)

dfb <- merge(dfb, soc_ec, by.x = "hierid", by.y = "region", all.x = FALSE, all.y = TRUE, allow.cartesian=TRUE)
total_pop <- sum(dfb$pop)

dfb$a <- dfb$temp - 366*30.6007075824072
dfb$b <- dfb$temp_s - 366*((30.6007075824072-27)^3)
dfb$c <- dfb$temp - 366*29.3189751020172
dfb$d <- dfb$temp_s - 366*((29.3189751020172-27)^3)
dfb$pop_w <- dfb$pop/total_pop
dfb$pi_term <- 100/dfb$gdppc
dfb$wage_term <- dfb$wage/0.5


dfb$big_a <- dfb$a*dfb$pi_term*dfb$pop_w*dfb$wage_term
dfb$big_b <- dfb$b*dfb$pi_term*dfb$pop_w*dfb$wage_term
dfb$big_c <- dfb$c*dfb$pi_term*dfb$pop_w*dfb$wage_term
dfb$big_d <- dfb$d*dfb$pi_term*dfb$pop_w*dfb$wage_term

A <- sum(dfb$big_a)
B <- sum(dfb$big_b)
C <- sum(dfb$big_c)
D <- sum(dfb$big_d)


if (heckman == "heckman") {
  ###################################################
  # Uninteracted Main Model with Heckman Correction #
  ###################################################
  
  vcv <- fread('~/repos/labor-code-release-2020/disutility_ext/heckman_vars_covars.csv')
  
  V_LR_T <- as.numeric(vcv[1,2])
  V_LR_TS <- as.numeric(vcv[2,2])
  V_HR_T <- as.numeric(vcv[3,2])
  V_HR_TS <- as.numeric(vcv[4,2])
  
   
  C_LR_T_LR_TS  <- as.numeric(vcv[5,2])
  C_LR_T_HR_TS  <- as.numeric(vcv[6,2])
  C_LR_T_HR_T   <- as.numeric(vcv[7,2])
  C_LR_TS_HR_T  <- as.numeric(vcv[8,2])
  C_LR_TS_HR_TS <- as.numeric(vcv[9,2])
  C_HR_T_HR_TS  <- as.numeric(vcv[10,2])
  
  Var_diss <- (A^2)*V_HR_T + (B^2)*V_HR_TS + (C^2)*V_LR_T + (D^2)*V_LR_TS
  Var_diss <- Var_diss + 2*(A*B*C_HR_T_HR_TS - A*C*C_LR_T_HR_T -A*D*C_LR_TS_HR_T - B*C*C_LR_T_HR_TS -B*D*C_LR_TS_HR_TS +C*D*C_LR_T_LR_TS)
  
  SE_diss <- (Var_diss)^0.5
  

} else {
  if (interacted == "interacted") {
    ################################
    # Income Adaptation + Clipping #
    ################################
<<<<<<< HEAD
    dfb_original <- dfb
    coefs <- fread('~/repos/labor-code-release-2020/disutility_ext/interacted_coefs.csv')
=======
    dfb <- fread("/Users/rfrost/Documents/Labour/GMDF_tmax_temp_and_spline_avg_year.csv")
    
    dfb <- rename(dfb, temp = value.x)
    dfb <- rename(dfb, temp_s = value.y)
    
    #soc_ec <- fread("/project/cil/sacagawea_shares/gcp/integration/float32/dscim_input_data/econvars/zarrs/integration-econ-bc39.csv")
    soc_ec <- fread("/Users/rfrost/Documents/Labour/integration-econ-bc39.csv")
    soc_ec <- subset(soc_ec, year == 2010)
    soc_ec <- subset(soc_ec, ssp == "SSP3")
    soc_ec <- aggregate(cbind(gdp, pop, gdppc)~ region, data = soc_ec, FUN = "mean")
    soc_ec$wage <- (soc_ec$gdppc*0.6)/(250*6*60)
    soc_ec$loggdppc <- log(soc_ec$gdppc)
    
    dfb <- merge(dfb, soc_ec, by.x = "hierid", by.y = "region", all.x = FALSE, all.y = TRUE, allow.cartesian=TRUE)
    
    
    coefs <- fread('/Users/rfrost/BFI\ Dropbox/Rebecca\ Frost/labor-code-release-2020/disutility_ext/interacted_coefs.csv')
>>>>>>> a801922d6bb77ae5625cacafdecf65087dcac76a
    mu <- as.matrix(coefs$V2)
    vcv <- fread('~/repos/labor-code-release-2020/disutility_ext/interacted_vars_covars.csv')
    #vcv <- fread('/Users/rfrost/BFI\ Dropbox/Rebecca\ Frost/labor-code-release-2020/disutility_ext/interacted_vcv.csv')
    vcv <- as.matrix(vcv[c(1:42),c(1:42)])
    
<<<<<<< HEAD
    n <- 10000
=======
    n <- 100
>>>>>>> a801922d6bb77ae5625cacafdecf65087dcac76a
    set.seed(12346) 
    resampled <- mvtnorm::rmvnorm(n = n, mu, vcv)
    
    resampled <- as.data.frame(resampled)
    
    resampled$LR_temp <- resampled$V1 +  resampled$V2 + resampled$V3 + resampled$V4 + resampled$V5 + resampled$V6 + resampled$V7
    resampled$LR_spline <- resampled$V8 +  resampled$V9 + resampled$V10 + resampled$V11 + resampled$V12 + resampled$V13 + resampled$V14
    
    resampled$HR_temp <- resampled$V15 +  resampled$V16 + resampled$V17 + resampled$V18 + resampled$V19 + resampled$V20 + resampled$V21
    resampled$HR_temp_gdp <- resampled$V22 +  resampled$V23 + resampled$V24 + resampled$V25 + resampled$V26 + resampled$V27 + resampled$V28
    
    resampled$HR_spline <- resampled$V29 +  resampled$V30 + resampled$V31 + resampled$V32 + resampled$V33 + resampled$V34 + resampled$V35
    resampled$HR_spline_gdp <- resampled$V36 +  resampled$V37 + resampled$V38 + resampled$V39 + resampled$V40 + resampled$V41 + resampled$V42
    
    resampled <- subset(resampled, select =c(LR_temp,LR_spline,HR_temp,HR_spline,HR_temp_gdp,HR_spline_gdp))
    
    resampled <- as.matrix(resampled)
    
    results <- matrix(0, 1, n)
    
    for (i in 1:n){
      
      dfb <- fread("/Users/rfrost/Documents/Labour/GMDF_tmax_temp_and_spline_avg_year.csv")
      
      dfb <- rename(dfb, temp = value.x)
      dfb <- rename(dfb, temp_s = value.y)
      
      #soc_ec <- fread("/project/cil/sacagawea_shares/gcp/integration/float32/dscim_input_data/econvars/zarrs/integration-econ-bc39.csv")
      soc_ec <- fread("/Users/rfrost/Documents/Labour/integration-econ-bc39.csv")
      soc_ec <- subset(soc_ec, year == 2010)
      soc_ec <- subset(soc_ec, ssp == "SSP3")
      soc_ec <- aggregate(cbind(gdp, pop, gdppc)~ region, data = soc_ec, FUN = "mean")
      soc_ec$wage <- (soc_ec$gdppc*0.6)/(250*6*60)
      soc_ec$loggdppc <- log(soc_ec$gdppc)
      
      dfb <- merge(dfb, soc_ec, by.x = "hierid", by.y = "region", all.x = FALSE, all.y = TRUE, allow.cartesian=TRUE)
      
      LR_temp_c <- rep(resampled[i,1], nrow(dfb))
      LR_temp_s_c <- rep(resampled[i,2], nrow(dfb))
      
      HR_temp_c <- rep(resampled[i,3], nrow(dfb))
      s_HR_temp_c <-as.numeric(resampled[i,3])
      
      HR_temp_s_c <- rep(resampled[i,4], nrow(dfb))
      s_HR_temp_s_c <- as.numeric(resampled[i,4])
      
      HR_temp_inc_c <- rep(resampled[i,5], nrow(dfb))
      s_HR_temp_inc_c <- as.numeric(resampled[i,5])
      
      HR_temp_s_inc_c <- rep(resampled[i,6], nrow(dfb))
      s_HR_temp_s_inc_c <- as.numeric(resampled[i,6])
      
      dfb <- cbind(dfb,LR_temp_c,LR_temp_s_c,HR_temp_c,HR_temp_s_c, HR_temp_inc_c, HR_temp_s_inc_c)
      
      #find optimum of the quadratic formula (This is from a previous version,we are using the LR optimum now)
      dfb$a_hr <- (3*dfb$HR_temp_s_c +dfb$HR_temp_s_inc_c*3*dfb$loggdppc)
      dfb$b_hr <- 54*(-1)*(3)*(dfb$HR_temp_s_c +dfb$HR_temp_s_inc_c*dfb$loggdppc)
      dfb$c_hr <- 729*(3*dfb$HR_temp_s_c + dfb$HR_temp_s_inc_c*(3)*dfb$loggdppc)+ dfb$loggdppc*dfb$HR_temp_inc_c + dfb$HR_temp_c
      dfb$discrim <- dfb$b_hr^2 - 4*dfb$a_hr*dfb$c_hr
      
      dfb$inc_adpt_opt_r1 <- (-dfb$b_hr - (dfb$b_hr^2-4*dfb$a_hr*dfb$c_hr)^0.5)/(2*dfb$a_hr)
      dfb$inc_adpt_opt_r2 <- (-dfb$b_hr + (dfb$b_hr^2-4*dfb$a_hr*dfb$c_hr)^0.5)/(2*dfb$a_hr)
      dfb$inc_adpt_opt <- ifelse(dfb$inc_adpt_opt_r1> dfb$inc_adpt_opt_r2, dfb$inc_adpt_opt_r1, dfb$inc_adpt_opt_r2)
      
      #dfb$inc_adpt_opt <- 29.3189751020172
      dfb$a_lr <- 3*dfb$LR_temp_s_c 
      dfb$b_lr <- (-54)*dfb$LR_temp_s_c*3 
      dfb$c_lr <- 729*3*dfb$LR_temp_s_c + dfb$LR_temp_c
      dfb$discrim_lr <- dfb$b_lr^2 - 4*dfb$a_lr*dfb$c_lr
      
      dfb$lr_opt_r1 <- ifelse(dfb$b_lr^2-4*dfb$a_lr*dfb$c_lr >= 0, (-dfb$b_lr - (dfb$b_lr^2-4*dfb$a_lr*dfb$c_lr)^0.5)/(2*dfb$a_lr),29.3189751020172)
      dfb$lr_opt_r2 <- ifelse(dfb$b_lr^2-4*dfb$a_lr*dfb$c_lr >= 0, (-dfb$b_lr + (dfb$b_lr^2-4*dfb$a_lr*dfb$c_lr)^0.5)/(2*dfb$a_lr),29.3189751020172)
      dfb$lr_opt <- ifelse(dfb$lr_opt_r1> dfb$lr_opt_r2, dfb$lr_opt_r1, dfb$lr_opt_r2)
      
      
      #Predict LS based on temp for each group on actual temp realizations and the optimal temp
      dfb$f_h <- dfb$temp*dfb$HR_temp_c + dfb$temp_s*dfb$HR_temp_s_c + dfb$temp*dfb$HR_temp_inc_c*dfb$loggdppc + dfb$temp_s*dfb$HR_temp_s_inc_c*dfb$loggdppc
      dfb$f_h_opt_h <- dfb$inc_adpt_opt*dfb$HR_temp_c + dfb$inc_adpt_opt*dfb$HR_temp_s_c + dfb$inc_adpt_opt*dfb$HR_temp_inc_c*dfb$loggdppc + dfb$inc_adpt_opt*dfb$HR_temp_s_inc_c*dfb$loggdppc 
      
      
      dfb$f_l <- dfb$temp*dfb$LR_temp_c + dfb$temp_s*dfb$LR_temp_s_c 
      dfb$f_l_opt_l <- dfb$lr_opt*dfb$LR_temp_c + ((dfb$lr_opt-27)^3)*dfb$LR_temp_s_c
      
      #Calculate each group's daily decrease in LS  relative to its own optimum
      dfb$d_l <- ifelse(dfb$f_l - dfb$f_l_opt_l < 0, dfb$f_l - dfb$f_l_opt_l , 0)
      dfb$d_h <- dfb$f_h - dfb$f_h_opt_h
      
      #do clipping
      dfb$d_h <- ifelse(dfb$d_h < dfb$d_l, dfb$d_h, dfb$d_l)
      #add adjustments 
      #dfb$d_h <- dfb$d_h*adjustment
      
      #NO BUBBLES!
      #dfb$d_h <- ifelse(dfb$loggdppc < 10.1, dfb$d_h, dfb$d_l)
      
      dfb$diff <- dfb$d_h - dfb$d_l
      
      # add up results over the full year
      dfb <- aggregate(cbind(diff, d_h, d_l) ~ hierid, data = dfb, FUN = sum)
      
      soc_ec <- fread("/project/cil/sacagawea_shares/gcp/integration/float32/dscim_input_data/econvars/zarrs/integration-econ-bc39.csv")
      #soc_ec <- fread("/Users/rfrost/Documents/Labour/integration-econ-bc39.csv")
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
      
      #Check mean before writing
      results[1,i] <- weighted.mean(dfb$diff_dis_p, dfb$pop, na.rm =TRUE)
    }
    
    
    
  } else {
    
    ###########################
    # Uninteracted Main Model #
    ###########################
    
    V_LR_T <- 0.0819070932463607
    V_LR_TS <- 0.0000126415533199
    V_HR_T <- 0.50201239982258
    V_HR_TS <- 0.0000455119674331
    
    C_LR_T_LR_TS <- -0.0005300212712299
    C_LR_TS_HR_TS <- -0.0000019212496857
    C_LR_T_HR_TS <- 0.0000137095839116
    C_LR_TS_HR_T <- -0.000000802135702971
    C_LR_T_HR_T <- -0.0005501298406159
    C_HR_T_HR_TS <- -0.0024129062049402
    
    Var_diss <- (A^2)*V_HR_T + (B^2)*V_HR_TS + (C^2)*V_LR_T + (D^2)*V_LR_TS
    Var_diss <- Var_diss + 2*(A*B*C_HR_T_HR_TS - A*C*C_LR_T_HR_T -A*D*C_LR_TS_HR_T - B*C*C_LR_T_HR_TS -B*D*C_LR_TS_HR_TS +C*D*C_LR_T_LR_TS)
    
    SE_diss <- (Var_diss)^0.5
  }
}
<<<<<<< HEAD

mean(results)

sd(results)
=======
dfb <- fread("/Users/rfrost/Documents/Labour/GMDF_tmax_temp_and_spline_avg_year.csv")

dfb <- rename(dfb, temp = value.x)
dfb <- rename(dfb, temp_s = value.y)

#soc_ec <- fread("/project/cil/sacagawea_shares/gcp/integration/float32/dscim_input_data/econvars/zarrs/integration-econ-bc39.csv")
soc_ec <- fread("/Users/rfrost/Documents/Labour/integration-econ-bc39.csv")
soc_ec <- subset(soc_ec, year == 2010)
soc_ec <- subset(soc_ec, ssp == "SSP3")
soc_ec <- aggregate(cbind(gdp, pop, gdppc)~ region, data = soc_ec, FUN = "mean")
soc_ec$wage <- (soc_ec$gdppc*0.6)/(250*6*60)
soc_ec$loggdppc <- log(soc_ec$gdppc)

dfb <- merge(dfb, soc_ec, by.x = "hierid", by.y = "region", all.x = FALSE, all.y = TRUE, allow.cartesian=TRUE)


resampled <- as.data.frame(resampled)
LR_temp_c <- rep(mean(resampled$LR_temp),nrow(dfb))
LR_temp_s_c <- rep(mean(resampled$LR_spline),nrow(dfb))

HR_temp_c <-  rep(mean(resampled$HR_temp),nrow(dfb))
HR_temp_s_c <- rep(mean(resampled$HR_spline),nrow(dfb))

HR_temp_inc_c <- rep(mean(resampled$HR_temp_gdp),nrow(dfb))
HR_temp_s_inc_c <- rep(mean(resampled$HR_spline_gdp),nrow(dfb))

dfb <- cbind(dfb,LR_temp_c,LR_temp_s_c,HR_temp_c,HR_temp_s_c, HR_temp_inc_c, HR_temp_s_inc_c)

LR_temp_c <- mean(resampled$LR_temp)
LR_temp_s_c <- mean(resampled$LR_spline)

HR_temp_c <-  mean(resampled$HR_temp)
HR_temp_s_c <- mean(resampled$HR_spline)

HR_temp_inc_c <- mean(resampled$HR_temp_gdp)
HR_temp_s_inc_c <- mean(resampled$HR_spline_gdp)

################################################################################################################
# Note! I have rounded the coefficients for the sake of the optimization because if i don't                    #
# an insane thing happens where the roots of the quadratic of the derivative of the cubic function don't exist #
# for a bunch of values of loggdppc. I think it is rounding/false precision issue but I don't know exactly     #
################################################################################################################

#find optimum of the quadratic formula (This is from a previous version,we are using the LR optimum now)
dfb$a_hr <- (3*HR_temp_s_c +HR_temp_s_inc_c*3*dfb$loggdppc)
dfb$b_hr <- 54*(-1)*(3)*(HR_temp_s_c +HR_temp_s_inc_c*dfb$loggdppc)
dfb$c_hr <- 729*(3*HR_temp_s_c + HR_temp_s_inc_c*(3)*dfb$loggdppc)+ dfb$loggdppc*HR_temp_inc_c + HR_temp_c
dfb$inc_adpt_opt_r1 <- (-dfb$b_hr - (dfb$b_hr^2-4*dfb$a_hr*dfb$c_hr)^0.5)/(2*dfb$a_hr)
dfb$inc_adpt_opt_r2 <- (-dfb$b_hr + (dfb$b_hr^2-4*dfb$a_hr*dfb$c_hr)^0.5)/(2*dfb$a_hr)
dfb$inc_adpt_opt <- ifelse(dfb$inc_adpt_opt_r1> dfb$inc_adpt_opt_r2, dfb$inc_adpt_opt_r1, dfb$inc_adpt_opt_r2)

#dfb$inc_adpt_opt <- 29.3189751020172
dfb$a_lr <- 3*LR_temp_s_c 
dfb$b_lr <- (-54)*LR_temp_s_c*3 
dfb$c_lr <- 729*3*LR_temp_s_c + LR_temp_c

dfb$lr_opt_r1 <- (-dfb$b_lr - (dfb$b_lr^2-4*dfb$a_lr*dfb$c_lr)^0.5)/(2*dfb$a_lr)
dfb$lr_opt_r2 <- (-dfb$b_lr + (dfb$b_lr^2-4*dfb$a_lr*dfb$c_lr)^0.5)/(2*dfb$a_lr)
dfb$lr_opt <- ifelse(dfb$lr_opt_r1> dfb$lr_opt_r2, dfb$lr_opt_r1, dfb$lr_opt_r2)

#Predict LS based on temp for each group on actual temp realizations and the optimal temp
dfb$f_h <- dfb$temp*dfb$HR_temp_c + dfb$temp_s*dfb$HR_temp_s_c + dfb$temp*dfb$HR_temp_inc_c*dfb$loggdppc + dfb$temp_s*dfb$HR_temp_s_inc_c*dfb$loggdppc
dfb$f_h_opt_h <- dfb$inc_adpt_opt*dfb$HR_temp_c + dfb$inc_adpt_opt*dfb$HR_temp_s_c + dfb$inc_adpt_opt*dfb$HR_temp_inc_c*dfb$loggdppc + dfb$inc_adpt_opt*dfb$HR_temp_s_inc_c*dfb$loggdppc 


dfb$f_l <- dfb$temp*dfb$LR_temp_c + dfb$temp_s*dfb$LR_temp_s_c 
dfb$f_l_opt_l <- dfb$lr_opt*dfb$LR_temp_c + ((dfb$lr_opt-27)^3)*dfb$LR_temp_s_c

#Calculate each group's daily decrease in LS  relative to its own optimum
dfb$d_l <- dfb$f_l - dfb$f_l_opt_l
dfb$d_h <- dfb$f_h - dfb$f_h_opt_h

#do clipping
dfb$d_h <- ifelse(dfb$d_h < dfb$d_l, dfb$d_h, dfb$d_l)
#add adjustments 
#dfb$d_h <- dfb$d_h*adjustment

#NO BUBBLES!
#dfb$d_h <- ifelse(dfb$loggdppc < 10.1, dfb$d_h, dfb$d_l)

dfb$diff <- dfb$d_h - dfb$d_l

# add up results over the full year
dfb <- aggregate(cbind(diff, d_h, d_l) ~ hierid, data = dfb, FUN = sum)

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

>>>>>>> a801922d6bb77ae5625cacafdecf65087dcac76a
