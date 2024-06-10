library(data.table)
library(dplyr)
library(tidyr)
library(ggplot2)
library(sf)
library(scales)
library(purrr)
library(glue)

#add adjustments for assumptions about labor elasticity and piece rate/self employment

adjust <- "adjusted"  #"original"


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
interacted <- "uninteracted" #interacted

#Read in Weather Data
dfb <- fread("/project/cil/sacagawea_shares/gcp/climate/_spatial_data/impactregions/weather_data/csv_daily/GMDF_tmax_temp_and_spline_avg_year.csv")
dfb <- rename(dfb, temp = value.x)
dfb <- rename(dfb, temp_s = value.y)

dfb <- aggregate(cbind(temp, temp_s) ~ hierid, data=dfb, FUN=sum)

soc_ec <- fread("/project/cil/sacagawea_shares/gcp/integration/float32/dscim_input_data/econvars/zarrs/integration-econ-bc39.csv")
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
    
    #These are hardcoded values for the betas from the hi 1 factor, low uninteracted model
    LR_temp_c <- rep(0.0499968692364216, nrow(dfb))
    LR_temp_s_c <- rep(-0.0030990557122301, nrow(dfb))
    
    HR_temp_c <- rep(4.31963659302658, nrow(dfb))
    HR_temp_s_c <- rep(-0.0623342655530531, nrow(dfb))
    
    HR_temp_inc_c <- rep(-0.423440709308935, nrow(dfb))
    HR_temp_s_inc_c <- rep(0.0062603009512727, nrow(dfb))
    
    vcv <- fread('~/repos/labor-code-release-2020/disutility_ext/interacted_vars_covars.csv')
    
    V_LR_T <- as.numeric(vcv[1,2])
    V_LR_TS <- as.numeric(vcv[2,2])
    V_HR_T <- as.numeric(vcv[3,2])
    V_HR_TS <- as.numeric(vcv[4,2])
    V_HR_T_G <- as.numeric(vcv[5,2])
    V_HR_TS_G <- as.numeric(vcv[6,2])
    
    C_HR_TS_HR_TS_G <- as.numeric(vcv[7,2])
    C_HR_T_G_HR_TS_G <- as.numeric(vcv[8,2])
    C_HR_T_HR_TS_G   <- as.numeric(vcv[9,2])
    C_HR_T_HR_T_G <- as.numeric(vcv[10,2])
    C_HR_T_G_HR_TS <- as.numeric(vcv[11,2])
    C_LR_TS_HR_TS_G  <- as.numeric(vcv[12,2])
    C_LR_T_HR_T_G <- as.numeric(vcv[13,2])
    C_LR_T_LR_TS <- as.numeric(vcv[14,2])
    C_LR_T_HR_TS <- as.numeric(vcv[15,2])
    C_LR_T_HR_T <- as.numeric(vcv[16,2])
    C_LR_TS_HR_T <- as.numeric(vcv[17,2])
    C_LR_TS_HR_TS <- as.numeric(vcv[18,2])
    C_HR_T_HR_TS <- as.numeric(vcv[19,2])
    C_LR_T_HR_TS_G <- as.numeric(vcv[20,2])
    C_LR_TS_HR_T_G <- as.numeric(vcv[21,2])
    
    
    vcv_matrix <- matrix(c(V_LR_T, C_LR_T_LR_TS, C_LR_T_HR_T, C_LR_T_HR_TS, C_LR_T_HR_T_G,C_LR_T_HR_TS_G,
                           C_LR_T_LR_TS, V_LR_TS, C_LR_TS_HR_T, C_LR_TS_HR_TS, C_LR_TS_HR_T_G, C_LR_TS_HR_TS_G,
                           C_LR_T_HR_T, C_LR_TS_HR_T, V_HR_T,C_HR_T_HR_TS,C_HR_T_HR_T_G,C_HR_T_HR_TS_G,
                           C_LR_T_HR_TS, C_LR_TS_HR_TS, C_HR_T_HR_TS, V_HR_TS, C_HR_T_G_HR_TS, C_HR_TS_HR_TS_G ,
                           C_LR_T_HR_T_G, C_LR_TS_HR_T_G, C_HR_T_HR_T_G, C_HR_T_G_HR_TS, V_HR_T_G, C_HR_T_G_HR_TS_G,
                           C_LR_T_HR_TS_G, C_LR_TS_HR_TS_G, C_HR_T_HR_TS_G, C_HR_TS_HR_TS_G, C_HR_T_G_HR_TS_G, V_HR_TS_G), 
                         nrow = 6, ncol = 6, byrow = TRUE)
    
    
    dfb <- cbind(dfb,LR_temp_c,LR_temp_s_c,HR_temp_c,HR_temp_s_c, HR_temp_inc_c, HR_temp_s_inc_c)
    
    soc_ec <- fread("/project/cil/sacagawea_shares/gcp/integration/float32/dscim_input_data/econvars/zarrs/integration-econ-bc39.csv")
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
    #dfb$a <- (-3*0.062+0.006*3*dfb$loggdppc)
    #dfb$b <- 54*(-1)*(-3*0.062+0.006*3*dfb$loggdppc)
    #dfb$c <- 729*(-3*0.062+ 0.006*3*dfb$loggdppc)+ dfb$loggdppc*(-0.42)+ 4.32
    #dfb$inc_adpt_opt <- (-dfb$b - (dfb$b^2-4*dfb$a*dfb$c)^0.5)/(2*dfb$a)
    
    dfb$inc_adpt_opt <- 29.3189751020172
    
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