# This script calculates the standard errors for the willingness to pay for a LR job

# This script calculates the standard errors for the willingness to pay for a LR job

library(data.table)
library(dplyr)
library(tidyr)
library(ggplot2)
library(sf)
library(scales)
library(purrr)
library(glue)


adjust <- "original"  # "adjusted"


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

heckman <- "no_heckman" # "heckman"
interacted <- "uninteracted" #interacted

#Read in Weather Data
dfb <- fread("/project/cil/sacagawea_shares/gcp/climate/_spatial_data/impactregions/weather_data/csv_daily/GMDF_tmax_temp_and_spline_avg_year.csv")
dfb <- rename(dfb, temp = value.x)
dfb <- rename(dfb, temp_s = value.y)

if (heckman == "heckman") {
  
  #vcv <- as.matrix(fread("~/repos/labor-code-release-2020/disutility_ext/heckman_vcv.csv"))
  vcv <- as.matrix(fread("~/repos/labor-code-release-2020/disutility_ext/original_vcv.csv"))
  
  #Varience LR Linear
  {#Low Linear
  
  {v_t0    <- as.vector(vcv[1,1])
  v_t0_v1 <- as.vector(vcv[2,2])
  v_t0_v2 <- as.vector(vcv[3,3])
  v_t0_v3 <- as.vector(vcv[4,4])
  v_t0_v4 <- as.vector(vcv[5,5])
  v_t0_v5 <- as.vector(vcv[6,6])
  v_t0_v6 <- as.vector(vcv[7,7])}
  
  v <- as.vector(c(v_t0, v_t0_v1, v_t0_v2, v_t0_v3, v_t0_v4, v_t0_v5, v_t0_v6))
  rm(v_t0, v_t0_v1, v_t0_v2, v_t0_v3, v_t0_v4, v_t0_v5, v_t0_v6)
  
  cov_t0_t0v1 <- as.vector(vcv[2,1])
  cov_t0_t0v2 <- as.vector(vcv[3,1])
  cov_t0_t0v3 <- as.vector(vcv[4,1])
  cov_t0_t0v4 <- as.vector(vcv[5,1])
  cov_t0_t0v5 <- as.vector(vcv[6,1])
  cov_t0_t0v6 <- as.vector(vcv[7,1])
  
  c <- as.vector(c(cov_t0_t0v1, cov_t0_t0v2, cov_t0_t0v3, cov_t0_t0v4,cov_t0_t0v5,cov_t0_t0v6))
  rm(cov_t0_t0v1, cov_t0_t0v2, cov_t0_t0v3, cov_t0_t0v4,cov_t0_t0v5,cov_t0_t0v6)
  
  {cov_t0v1_t0v2 <- as.vector(vcv[3,2])
  cov_t0v1_t0v3 <- as.vector(vcv[4,2])
  cov_t0v1_t0v4 <- as.vector(vcv[5,2])
  cov_t0v1_t0v5 <- as.vector(vcv[6,2])
  cov_t0v1_t0v6 <- as.vector(vcv[7,2])}
  
  c <- as.vector(c(c, cov_t0v1_t0v2, cov_t0v1_t0v3, cov_t0v1_t0v4,cov_t0v1_t0v5,cov_t0v1_t0v6))
  rm(cov_t0v1_t0v2, cov_t0v1_t0v3, cov_t0v1_t0v4,cov_t0v1_t0v5,cov_t0v1_t0v6)
  
  
  {cov_t0v2_t0v3 <- as.vector(vcv[4,3])
  cov_t0v2_t0v4 <- as.vector(vcv[5,3])
  cov_t0v2_t0v5 <- as.vector(vcv[6,3])
  cov_t0v2_t0v6 <- as.vector(vcv[7,3])}
  
  c <- as.vector(c(c, cov_t0v2_t0v3, cov_t0v2_t0v4,cov_t0v2_t0v5,cov_t0v2_t0v6))
  rm(cov_t0v2_t0v3, cov_t0v2_t0v4,cov_t0v2_t0v5,cov_t0v2_t0v6)
  
  {cov_t0v3_t0v4 <- as.vector(vcv[5,4])
  cov_t0v3_t0v5 <- as.vector(vcv[6,4])
  cov_t0v3_t0v6 <- as.vector(vcv[7,4])}
  
  c <- as.vector(c(c,  cov_t0v3_t0v4,cov_t0v3_t0v5,cov_t0v3_t0v6))
  rm(cov_t0v3_t0v4,cov_t0v3_t0v5,cov_t0v3_t0v6)
  
  {cov_t0v4_t0v5 <- as.vector(vcv[6,5])
  cov_t0v4_t0v6 <- as.vector(vcv[7,5])}
  
  c <- as.vector(c(c,cov_t0v4_t0v5,cov_t0v4_t0v6))
  rm(cov_t0v4_t0v5,cov_t0v4_t0v6)
  
  {cov_t0v5_t0v6 <- as.vector(vcv[7,6])
  }
  
  c <- as.vector(c(c,cov_t0v5_t0v6))
  rm(cov_t0v5_t0v6)
  
  v_t_lr <- v
  c_t_lr <- c }
  V_LR_T <- sum(v_t_lr) + 2*sum(c_t_lr)
  
  #Varience LR Spline
  {#Low Spline

  {v_t1    <- as.vector(vcv[1+7,1+7])
  v_t1_v1 <- as.vector(vcv[2+7,2+7])
  v_t1_v2 <- as.vector(vcv[3+7,3+7])
  v_t1_v3 <- as.vector(vcv[4+7,4+7])
  v_t1_v4 <- as.vector(vcv[5+7,5+7])
  v_t1_v5 <- as.vector(vcv[6+7,6+7])
  v_t1_v6 <- as.vector(vcv[7+7,7+7])}
  
  v <- as.vector(c(v_t1, v_t1_v1, v_t1_v2, v_t1_v3, v_t1_v4, v_t1_v5, v_t1_v6))
  rm(v_t1, v_t1_v1, v_t1_v2, v_t1_v3, v_t1_v4, v_t1_v5, v_t1_v6)

  {cov_t1_t1v1 <- as.vector(vcv[2+7,1+7])
  cov_t1_t1v2 <- as.vector(vcv[3+7,1+7])
  cov_t1_t1v3 <- as.vector(vcv[4+7,1+7])
  cov_t1_t1v4 <- as.vector(vcv[5+7,1+7])
  cov_t1_t1v5 <- as.vector(vcv[6+7,1+7])
  cov_t1_t1v6 <- as.vector(vcv[7+7,1+7])}
  
  c <- as.vector(c(cov_t1_t1v1, cov_t1_t1v2, cov_t1_t1v3, cov_t1_t1v4,cov_t1_t1v5,cov_t1_t1v6))
  rm(cov_t1_t1v1, cov_t1_t1v2, cov_t1_t1v3, cov_t1_t1v4,cov_t1_t1v5,cov_t1_t1v6)
  
  {cov_t1v1_t1v2 <- as.vector(vcv[3+7,2+7])
  cov_t1v1_t1v3 <- as.vector(vcv[4+7,2+7])
  cov_t1v1_t1v4 <- as.vector(vcv[5+7,2+7])
  cov_t1v1_t1v5 <- as.vector(vcv[6+7,2+7])
  cov_t1v1_t1v6 <- as.vector(vcv[7+7,2+7])}
  
  c <- as.vector(c(c, cov_t1v1_t1v2, cov_t1v1_t1v3, cov_t1v1_t1v4, cov_t1v1_t1v5,cov_t1v1_t1v6))
  rm(cov_t0v1_t1v2, cov_t1v1_t1v3, cov_t1v1_t1v4,cov_t1v1_t1v5,cov_t1v1_t1v6)
  
  {cov_t1v2_t1v3 <- as.vector(vcv[4+7,3+7])
  cov_t1v2_t1v4 <- as.vector(vcv[5+7,3+7])
  cov_t1v2_t1v5 <- as.vector(vcv[6+7,3+7])
  cov_t1v2_t1v6 <- as.vector(vcv[7+7,3+7])}
  
  c <- as.vector(c(c, cov_t1v2_t1v3, cov_t1v2_t1v4, cov_t1v2_t1v5,cov_t1v2_t1v6))
  rm( cov_t1v2_t1v3, cov_t1v2_t1v4,cov_t1v2_t1v5,cov_t1v2_t1v6)
  
  {cov_t1v3_t1v4 <- as.vector(vcv[5+7,4+7])
  cov_t1v3_t1v5 <- as.vector(vcv[6+7,4+7])
  cov_t1v3_t1v6 <- as.vector(vcv[7+7,4+7])}
  
  c <- as.vector(c(c,  cov_t1v3_t1v4, cov_t1v3_t1v5,cov_t1v3_t1v6))
  rm( cov_t1v3_t1v4,cov_t1v3_t1v5,cov_t1v3_t1v6)
  
  {cov_t1v4_t1v5 <- as.vector(vcv[6+7,5+7])
  cov_t1v4_t1v6 <- as.vector(vcv[7+7,5+7])}
  
  c <- as.vector(c(c, cov_t1v4_t1v5,cov_t1v4_t1v6))
  rm(cov_t1v4_t1v5,cov_t1v4_t1v6)
  
  cov_t1v5_t1v6 <- as.vector(vcv[7+7,6+7])
  
  c <- as.vector(c(c,cov_t1v5_t1v6))
  rm(cov_t1v5_t1v6)
  
  v_ts_lr <- v
  c_ts_lr <- c }
  V_LR_TS <- sum(v_ts_lr) + 2*sum(c_ts_lr)
  
  #Varience HR Linear
  {#High Linear
  
 {v_t0    <- as.vector(vcv[1+14,1+14])
  v_t0_v1 <- as.vector(vcv[2+14,2+14])
  v_t0_v2 <- as.vector(vcv[3+14,3+14])
  v_t0_v3 <- as.vector(vcv[4+14,4+14])
  v_t0_v4 <- as.vector(vcv[5+14,5+14])
  v_t0_v5 <- as.vector(vcv[6+14,6+14])
  v_t0_v6 <- as.vector(vcv[7+14,7+14])}
  
  v <- as.vector(c(v_t0, v_t0_v1, v_t0_v2, v_t0_v3, v_t0_v4, v_t0_v5, v_t0_v6))
  rm(v_t0, v_t0_v1, v_t0_v2, v_t0_v3, v_t0_v4, v_t0_v5, v_t0_v6)
  
  {cov_t0_t0v1 <- as.vector(vcv[2+14,1+14])
  cov_t0_t0v2 <- as.vector(vcv[3+14,1+14])
  cov_t0_t0v3 <- as.vector(vcv[4+14,1+14])
  cov_t0_t0v4 <- as.vector(vcv[5+14,1+14])
  cov_t0_t0v5 <- as.vector(vcv[6+14,1+14])
  cov_t0_t0v6 <- as.vector(vcv[7+14,1+14])}
  
  c <- as.vector(c(cov_t0_t0v1, cov_t0_t0v2, cov_t0_t0v3, cov_t0_t0v4,cov_t0_t0v5,cov_t0_t0v6))
  rm(cov_t0_t0v1, cov_t0_t0v2, cov_t0_t0v3, cov_t0_t0v4,cov_t0_t0v5,cov_t0_t0v6)
  
  {cov_t0v1_t0v2 <- as.vector(vcv[3+14,2+14])
  cov_t0v1_t0v3 <- as.vector(vcv[4+14,2+14])
  cov_t0v1_t0v4 <- as.vector(vcv[5+14,2+14])
  cov_t0v1_t0v5 <- as.vector(vcv[6+14,2+14])
  cov_t0v1_t0v6 <- as.vector(vcv[7+14,2+14])}
  
  c <- as.vector(c(c, cov_t0v1_t0v2, cov_t0v1_t0v3, cov_t0v1_t0v4,cov_t0v1_t0v5,cov_t0v1_t0v6))
  rm(cov_t0v1_t0v2, cov_t0v1_t0v3, cov_t0v1_t0v4,cov_t0v1_t0v5,cov_t0v1_t0v6)
  
  {cov_t0v2_t0v3 <- as.vector(vcv[4+14,3+14])
  cov_t0v2_t0v4 <- as.vector(vcv[5+14,3+14])
  cov_t0v2_t0v5 <- as.vector(vcv[6+14,3+14])
  cov_t0v2_t0v6 <- as.vector(vcv[7+14,3+14])}
  
  c <- as.vector(c(c, cov_t0v2_t0v3, cov_t0v2_t0v4,cov_t0v2_t0v5,cov_t0v2_t0v6))
  rm(cov_t0v2_t0v3, cov_t0v2_t0v4,cov_t0v2_t0v5,cov_t0v2_t0v6)
  
  {cov_t0v3_t0v4 <- as.vector(vcv[5+14,4+14])
  cov_t0v3_t0v5 <- as.vector(vcv[6+14,4+14])
  cov_t0v3_t0v6 <- as.vector(vcv[7+14,4+14])}
  
  c <- as.vector(c(c,  cov_t0v3_t0v4,cov_t0v3_t0v5,cov_t0v3_t0v6))
  rm(cov_t0v3_t0v4,cov_t0v3_t0v5,cov_t0v3_t0v6)
  
  {cov_t0v4_t0v5 <- as.vector(vcv[6+14,5+14])
  cov_t0v4_t0v6 <- as.vector(vcv[7+14,5+14])}
  
  c <- as.vector(c(c,cov_t0v4_t0v5,cov_t0v4_t0v6))
  rm(cov_t0v4_t0v5,cov_t0v4_t0v6)
  
  {cov_t0v5_t0v6 <- as.vector(vcv[7+14,6+14])
    }
  
  c <- as.vector(c(c,cov_t0v5_t0v6))
  rm(cov_t0v5_t0v6)
  
  v_t_hr_alone <- v
  c_t_hr_alone <- c 
  
  ###
  #Extra Covarience Term
  
  #lr 
  {c_lr_hr   <-  as.vector(vcv[1,1+14])
  c_lr_hrv1 <- as.vector(vcv[1,2+14])
  c_lr_hrv2 <- as.vector(vcv[1,3+14])
  c_lr_hrv3 <- as.vector(vcv[1,4+14])
  c_lr_hrv4 <- as.vector(vcv[1,5+14])
  c_lr_hrv5 <- as.vector(vcv[1,6+14])
  c_lr_hrv6 <- as.vector(vcv[1,7+14])}
  
  c_lr <- as.vector(c(c_lr_hr,c_lr_hrv1,c_lr_hrv2,c_lr_hrv3,c_lr_hrv4,c_lr_hrv5,c_lr_hrv6))
  
  #lr_v1
  {c_lrv1_hr   <- as.vector(vcv[2,1+14])
  c_lrv1_hrv1 <- as.vector(vcv[2,2+14])
  c_lrv1_hrv2 <- as.vector(vcv[2,3+14])
  c_lrv1_hrv3 <- as.vector(vcv[2,4+14])
  c_lrv1_hrv4 <- as.vector(vcv[2,5+14])
  c_lrv1_hrv5 <- as.vector(vcv[2,6+14])
  c_lrv1_hrv6 <- as.vector(vcv[2,7+14])}
  
  c_lrv1 <- as.vector(c(c_lrv1_hr, c_lrv1_hrv1, c_lrv1_hrv2, c_lrv1_hrv3, c_lrv1_hrv4, c_lrv1_hrv5, c_lrv1_hrv6))
  
  
  #lr_v2
  {c_lrv2_hr   <- as.vector(vcv[3,1+14])
  c_lrv2_hrv1 <- as.vector(vcv[3,2+14])
  c_lrv2_hrv2 <- as.vector(vcv[3,3+14])
  c_lrv2_hrv3 <- as.vector(vcv[3,4+14])
  c_lrv2_hrv4 <- as.vector(vcv[3,5+14])
  c_lrv2_hrv5 <- as.vector(vcv[3,6+14])
  c_lrv2_hrv6 <- as.vector(vcv[3,7+14])}
  
  c_lrv2 <- as.vector(c(c_lrv2_hr,c_lrv2_hrv1, c_lrv2_hrv2, c_lrv2_hrv3, c_lrv2_hrv4, c_lrv2_hrv5, c_lrv2_hrv6))
  
  #lr_v3
  {c_lrv3_hr   <- as.vector(vcv[4,1+14])
  c_lrv3_hrv1 <- as.vector(vcv[4,2+14])
  c_lrv3_hrv2 <- as.vector(vcv[4,3+14])
  c_lrv3_hrv3 <- as.vector(vcv[4,4+14])
  c_lrv3_hrv4 <- as.vector(vcv[4,5+14])
  c_lrv3_hrv5 <- as.vector(vcv[4,6+14])
  c_lrv3_hrv6 <- as.vector(vcv[4,7+14])}
  
  c_lrv3 <- as.vector(c(c_lrv3_hr,c_lrv3_hrv1, c_lrv3_hrv2, c_lrv3_hrv3, c_lrv3_hrv4, c_lrv3_hrv5, c_lrv3_hrv6))
  
  #lr_v4
  {c_lrv4_hr   <- as.vector(vcv[5,1+14])
  c_lrv4_hrv1 <- as.vector(vcv[5,2+14])
  c_lrv4_hrv2 <- as.vector(vcv[5,3+14])
  c_lrv4_hrv3 <- as.vector(vcv[5,4+14])
  c_lrv4_hrv4 <- as.vector(vcv[5,5+14])
  c_lrv4_hrv5 <- as.vector(vcv[5,6+14])
  c_lrv4_hrv6 <- as.vector(vcv[5,7+14])}
  
  c_lrv4 <- as.vector(c(c_lrv4_hr,c_lrv4_hrv1, c_lrv4_hrv2, c_lrv4_hrv3, c_lrv4_hrv4, c_lrv4_hrv5, c_lrv4_hrv6))
  
  #lr_v5
  {c_lrv5_hr   <-  as.vector(vcv[6,1+14])
  c_lrv5_hrv1 <- as.vector(vcv[6,2+14])
  c_lrv5_hrv2 <- as.vector(vcv[6,3+14])
  c_lrv5_hrv3 <- as.vector(vcv[6,4+14])
  c_lrv5_hrv4 <- as.vector(vcv[6,5+14])
  c_lrv5_hrv5 <- as.vector(vcv[6,6+14])
  c_lrv5_hrv6 <- as.vector(vcv[6,7+14])}
  
  c_lrv5 <- as.vector(c(c_lrv5_hr,c_lrv5_hrv1, c_lrv5_hrv2, c_lrv5_hrv3, c_lrv5_hrv4, c_lrv5_hrv5, c_lrv5_hrv6))
  
  #lr_v6
  {c_lrv6_hr   <- as.vector(vcv[7,1+14])
  c_lrv6_hrv1 <- as.vector(vcv[7,2+14])
  c_lrv6_hrv2 <- as.vector(vcv[7,3+14])
  c_lrv6_hrv3 <- as.vector(vcv[7,4+14])
  c_lrv6_hrv4 <- as.vector(vcv[7,5+14])
  c_lrv6_hrv5 <- as.vector(vcv[7,6+14])
  c_lrv6_hrv6 <- as.vector(vcv[7,7+14])}
  
  c_lrv6 <- as.vector(c(c_lrv6_hr,c_lrv6_hrv1, c_lrv6_hrv2, c_lrv6_hrv3, c_lrv6_hrv4, c_lrv6_hrv5, c_lrv6_hrv6))
  
  cov_extra_lr_hr <- sum(c_lr) + sum(c_lrv1) + sum(c_lrv2) + sum(c_lrv3)+ sum(c_lrv4)+ sum(c_lrv5) + sum(c_lrv6)}
  V_HR_T <- sum(v_t_hr_alone) + 2*sum(c_t_hr_alone) + V_LR_T + 2*sum(cov_extra_lr_hr)
  
  #Varience HR Spline
  {#High Spline
  {v_t1    <- as.vector(vcv[1+21,1+21])
  v_t1_v1 <- as.vector(vcv[2+21,2+21])
  v_t1_v2 <- as.vector(vcv[3+21,3+21])
  v_t1_v3 <- as.vector(vcv[4+21,4+21])
  v_t1_v4 <- as.vector(vcv[5+21,5+21])
  v_t1_v5 <- as.vector(vcv[6+21,6+21])
  v_t1_v6 <- as.vector(vcv[7+21,7+21])}
  
  v <- as.vector(c(v_t1, v_t1_v1, v_t1_v2, v_t1_v3, v_t1_v4, v_t1_v5, v_t1_v6))
  rm(v_t1, v_t1_v1, v_t1_v2, v_t1_v3, v_t1_v4, v_t1_v5, v_t1_v6)
  
  {cov_t1_t1v1 <- as.vector(vcv[2+21,1+21])
  cov_t1_t1v2 <- as.vector(vcv[3+21,1+21])
  cov_t1_t1v3 <- as.vector(vcv[4+21,1+21])
  cov_t1_t1v4 <- as.vector(vcv[5+21,1+21])
  cov_t1_t1v5 <- as.vector(vcv[6+21,1+21])
  cov_t1_t1v6 <- as.vector(vcv[7+21,1+21])}
  
  c <- as.vector(c(cov_t1_t1v1, cov_t1_t1v2, cov_t1_t1v3, cov_t1_t1v4,cov_t1_t1v5,cov_t1_t1v6))
  rm(cov_t1_t1v1, cov_t1_t1v2, cov_t1_t1v3, cov_t1_t1v4,cov_t1_t1v5,cov_t1_t1v6)
  
  {cov_t1v1_t1v2 <- as.vector(vcv[3+21,2+21])
  cov_t1v1_t1v3 <- as.vector(vcv[4+21,2+21])
  cov_t1v1_t1v4 <- as.vector(vcv[5+21,2+21])
  cov_t1v1_t1v5 <- as.vector(vcv[6+21,2+21])
  cov_t1v1_t1v6 <- as.vector(vcv[7+21,2+21])}
  
  c <- as.vector(c(c, cov_t1v1_t1v2, cov_t1v1_t1v3, cov_t1v1_t1v4, cov_t1v1_t1v5,cov_t1v1_t1v6))
  rm(cov_t0v1_t1v2, cov_t1v1_t1v3, cov_t1v1_t1v4,cov_t1v1_t1v5,cov_t1v1_t1v6)
  
  {cov_t1v2_t1v3 <- as.vector(vcv[4+21,3+21])
  cov_t1v2_t1v4 <- as.vector(vcv[5+21,3+21])
  cov_t1v2_t1v5 <- as.vector(vcv[6+21,3+21])
  cov_t1v2_t1v6 <- as.vector(vcv[7+21,3+21])}
  
  c <- as.vector(c(c, cov_t1v2_t1v3, cov_t1v2_t1v4, cov_t1v2_t1v5,cov_t1v2_t1v6))
  rm( cov_t1v2_t1v3, cov_t1v2_t1v4,cov_t1v2_t1v5,cov_t1v2_t1v6)
  
  {cov_t1v3_t1v4 <- as.vector(vcv[5+21,4+21])
  cov_t1v3_t1v5 <- as.vector(vcv[6+21,4+21])
  cov_t1v3_t1v6 <- as.vector(vcv[7+21,4+21])}
  
  c <- as.vector(c(c,  cov_t1v3_t1v4, cov_t1v3_t1v5,cov_t1v3_t1v6))
  rm( cov_t1v3_t1v4,cov_t1v3_t1v5,cov_t1v3_t1v6)
  
  {cov_t1v4_t1v5 <- as.vector(vcv[6+21,5+21])
  cov_t1v4_t1v6 <- as.vector(vcv[7+21,5+21])}
  
  c <- as.vector(c(c, cov_t1v4_t1v5,cov_t1v4_t1v6))
  rm(cov_t1v4_t1v5,cov_t1v4_t1v6)
  
  {cov_t1v5_t1v6 <- as.vector(vcv[7+21,6+21])
    }
  
  c <- as.vector(c(c,cov_t1v5_t1v6))
  rm(cov_t1v5_t1v6)
  
  v_ts_hr_alone <- v
  c_ts_hr_alone <- c 
  
  #Extra Covarience Term
  
  #lr 
  {c_lr_hr   <-  as.vector(vcv[1+7,1+21])
  c_lr_hrv1 <- as.vector(vcv[1+7,2+21])
  c_lr_hrv2 <- as.vector(vcv[1+7,3+21])
  c_lr_hrv3 <- as.vector(vcv[1+7,4+21])
  c_lr_hrv4 <- as.vector(vcv[1+7,5+21])
  c_lr_hrv5 <- as.vector(vcv[1+7,6+21])
  c_lr_hrv6 <- as.vector(vcv[1+7,7+21])}
  
  c_lr <- as.vector(c(c_lr_hr,c_lr_hrv1,c_lr_hrv2,c_lr_hrv3,c_lr_hrv4,c_lr_hrv5,c_lr_hrv6))
  rm(c_lr_hr,c_lr_hrv1,c_lr_hrv2,c_lr_hrv3,c_lr_hrv4,c_lr_hrv5,c_lr_hrv6)
  
  #lr_v1
  {c_lrv1_hr   <- as.vector(vcv[2+7,1+21])
  c_lrv1_hrv1 <- as.vector(vcv[2+7,2+21])
  c_lrv1_hrv2 <- as.vector(vcv[2+7,3+21])
  c_lrv1_hrv3 <- as.vector(vcv[2+7,4+21])
  c_lrv1_hrv4 <- as.vector(vcv[2+7,5+21])
  c_lrv1_hrv5 <- as.vector(vcv[2+7,6+21])
  c_lrv1_hrv6 <- as.vector(vcv[2+7,7+21])}
  
  c_lrv1 <- as.vector(c(c_lrv1_hr, c_lrv1_hrv1, c_lrv1_hrv2, c_lrv1_hrv3, c_lrv1_hrv4, c_lrv1_hrv5, c_lrv1_hrv6))
  rm(c_lrv1_hr, c_lrv1_hrv1, c_lrv1_hrv2, c_lrv1_hrv3, c_lrv1_hrv4, c_lrv1_hrv5, c_lrv1_hrv6)
  
  #lr_v2
  {c_lrv2_hr   <- as.vector(vcv[3+7,1+21])
  c_lrv2_hrv1 <- as.vector(vcv[3+7,2+21])
  c_lrv2_hrv2 <- as.vector(vcv[3+7,3+21])
  c_lrv2_hrv3 <- as.vector(vcv[3+7,4+21])
  c_lrv2_hrv4 <- as.vector(vcv[3+7,5+21])
  c_lrv2_hrv5 <- as.vector(vcv[3+7,6+21])
  c_lrv2_hrv6 <- as.vector(vcv[3+7,7+21])}
  
  c_lrv2 <- as.vector(c(c_lrv2_hr,c_lrv2_hrv1, c_lrv2_hrv2, c_lrv2_hrv3, c_lrv2_hrv4, c_lrv2_hrv5, c_lrv2_hrv6))
  rm(c_lrv2_hr,c_lrv2_hrv1, c_lrv2_hrv2, c_lrv2_hrv3, c_lrv2_hrv4, c_lrv2_hrv5, c_lrv2_hrv6)
  
  #lr_v3
  {c_lrv3_hr   <- as.vector(vcv[4+7,1+21])
  c_lrv3_hrv1 <- as.vector(vcv[4+7,2+21])
  c_lrv3_hrv2 <- as.vector(vcv[4+7,3+21])
  c_lrv3_hrv3 <- as.vector(vcv[4+7,4+21])
  c_lrv3_hrv4 <- as.vector(vcv[4+7,5+21])
  c_lrv3_hrv5 <- as.vector(vcv[4+7,6+21])
  c_lrv3_hrv6 <- as.vector(vcv[4+7,7+21])}
  
  c_lrv3 <- as.vector(c(c_lrv3_hr,c_lrv3_hrv1, c_lrv3_hrv2, c_lrv3_hrv3, c_lrv3_hrv4, c_lrv3_hrv5, c_lrv3_hrv6))
  
  #lr_v4
  {c_lrv4_hr   <- as.vector(vcv[5+7,1+21])
  c_lrv4_hrv1 <- as.vector(vcv[5+7,2+21])
  c_lrv4_hrv2 <- as.vector(vcv[5+7,3+21])
  c_lrv4_hrv3 <- as.vector(vcv[5+7,4+21])
  c_lrv4_hrv4 <- as.vector(vcv[5+7,5+21])
  c_lrv4_hrv5 <- as.vector(vcv[5+7,6+21])
  c_lrv4_hrv6 <- as.vector(vcv[5+7,7+21])}
  
  c_lrv4 <- as.vector(c(c_lrv4_hr,c_lrv4_hrv1, c_lrv4_hrv2, c_lrv4_hrv3, c_lrv4_hrv4, c_lrv4_hrv5, c_lrv4_hrv6))
  
  #lr_v5
  {c_lrv5_hr   <-  as.vector(vcv[6+7,1+21])
  c_lrv5_hrv1 <- as.vector(vcv[6+7,2+21])
  c_lrv5_hrv2 <- as.vector(vcv[6+7,3+21])
  c_lrv5_hrv3 <- as.vector(vcv[6+7,4+21])
  c_lrv5_hrv4 <- as.vector(vcv[6+7,5+21])
  c_lrv5_hrv5 <- as.vector(vcv[6+7,6+21])
  c_lrv5_hrv6 <- as.vector(vcv[6+7,7+21])}
  
  c_lrv5 <- as.vector(c(c_lrv5_hr,c_lrv5_hrv1, c_lrv5_hrv2, c_lrv5_hrv3, c_lrv5_hrv4, c_lrv5_hrv5, c_lrv5_hrv6))
  rm(c_lrv5_hr,c_lrv5_hrv1, c_lrv5_hrv2, c_lrv5_hrv3, c_lrv5_hrv4, c_lrv5_hrv5, c_lrv5_hrv6)
  
  #lr_v6
  {c_lrv6_hr   <- as.vector(vcv[7+7,1+21])
  c_lrv6_hrv1 <- as.vector(vcv[7+7,2+21])
  c_lrv6_hrv2 <- as.vector(vcv[7+7,3+21])
  c_lrv6_hrv3 <- as.vector(vcv[7+7,4+21])
  c_lrv6_hrv4 <- as.vector(vcv[7+7,5+21])
  c_lrv6_hrv5 <- as.vector(vcv[7+7,6+21])
  c_lrv6_hrv6 <- as.vector(vcv[7+7,7+21])}
  
  c_lrv6 <- as.vector(c(c_lrv6_hr,c_lrv6_hrv1, c_lrv6_hrv2, c_lrv6_hrv3, c_lrv6_hrv4, c_lrv6_hrv5, c_lrv6_hrv6))
  rm(c_lrv6_hr,c_lrv6_hrv1, c_lrv6_hrv2, c_lrv6_hrv3, c_lrv6_hrv4, c_lrv6_hrv5, c_lrv6_hrv6)
  
  cov_extra_lr_hr <- sum(c_lr) + sum(c_lrv1) + sum(c_lrv2) + sum(c_lrv3)+ sum(c_lrv4)+ sum(c_lrv5) + sum(c_lrv6)}
  V_HR_TS <- sum(v_ts_hr_alone) + 2*sum(c_ts_hr_alone) + V_LR_TS + 2*cov_extra_lr_hr
  
  #Cov LR_T and LR_TS
  {#t0 
  {c_t0_t1   <- as.vector(vcv[1,1+7])
  c_t0_t1v1 <- as.vector(vcv[1,2+7])
  c_t0_t1v2 <- as.vector(vcv[1,3+7])
  c_t0_t1v3 <- as.vector(vcv[1,4+7])
  c_t0_t1v4 <- as.vector(vcv[1,5+7])
  c_t0_t1v5 <- as.vector(vcv[1,6+7])
  c_t0_t1v6 <- as.vector(vcv[1,7+7])}
  
  c_t0 <- as.vector(c(c_t0_t1,c_t0_t1v1,c_t0_t1v2,c_t0_t1v3,c_t0_t1v4,c_t0_t1v5,c_t0_t1v6))
  rm(c_t0_t1,c_t0_t1v1,c_t0_t1v2,c_t0_t1v3,c_t0_t1v4,c_t0_t1v5,c_t0_t1v6)
  
  #t0_v1
  {c_t0v1_t1   <- as.vector(vcv[2,1+7])
  c_t0v1_t1v1 <- as.vector(vcv[2,2+7])
  c_t0v1_t1v2 <- as.vector(vcv[2,3+7])
  c_t0v1_t1v3 <- as.vector(vcv[2,4+7])
  c_t0v1_t1v4 <- as.vector(vcv[2,5+7])
  c_t0v1_t1v5 <- as.vector(vcv[2,6+7])
  c_t0v1_t1v6 <- as.vector(vcv[2,7+7])}
  
  c_t0v1 <- as.vector(c(c_t0v1_t1, c_t0v1_t1v1, c_t0v1_t1v2, c_t0v1_t1v3, c_t0v1_t1v4, c_t0v1_t1v5, c_t0v1_t1v6))
  rm(c_t0v1_t1, c_t0v1_t1v1, c_t0v1_t1v2, c_t0v1_t1v3, c_t0v1_t1v4, c_t0v1_t1v5, c_t0v1_t1v6)
  
  #t0_v2
  {c_t0v2_t1   <- as.vector(vcv[3,1+7])
  c_t0v2_t1v1 <- as.vector(vcv[3,2+7])
  c_t0v2_t1v2 <- as.vector(vcv[3,3+7])
  c_t0v2_t1v3 <- as.vector(vcv[3,4+7])
  c_t0v2_t1v4 <- as.vector(vcv[3,5+7])
  c_t0v2_t1v5 <- as.vector(vcv[3,6+7])
  c_t0v2_t1v6 <- as.vector(vcv[3,7+7])}
  
  c_t0v2 <- as.vector(c(c_t0v2_t1,c_t0v2_t1v1, c_t0v2_t1v2, c_t0v2_t1v3, c_t0v2_t1v4, c_t0v2_t1v5, c_t0v2_t1v6))
  rm(c_t0v2_t1,c_t0v2_t1v1, c_t0v2_t1v2, c_t0v2_t1v3, c_t0v2_t1v4, c_t0v2_t1v5, c_t0v2_t1v6)
  
  #t0_v3
  {c_t0v3_t1   <- as.vector(vcv[4,1+7])
  c_t0v3_t1v1 <- as.vector(vcv[4,2+7])
  c_t0v3_t1v2 <- as.vector(vcv[4,3+7])
  c_t0v3_t1v3 <- as.vector(vcv[4,4+7])
  c_t0v3_t1v4 <- as.vector(vcv[4,5+7])
  c_t0v3_t1v5 <- as.vector(vcv[4,6+7])
  c_t0v3_t1v6 <- as.vector(vcv[4,7+7])}
  
  c_t0v3 <- as.vector(c(c_t0v3_t1,c_t0v3_t1v1, c_t0v3_t1v2, c_t0v3_t1v3, c_t0v3_t1v4, c_t0v3_t1v5, c_t0v3_t1v6))
  rm(c_t0v3_t1,c_t0v3_t1v1, c_t0v3_t1v2, c_t0v3_t1v3, c_t0v3_t1v4, c_t0v3_t1v5, c_t0v3_t1v6)
  
  #t0_v4
  {c_t0v4_t1   <- as.vector(vcv[5,1+7])
  c_t0v4_t1v1 <- as.vector(vcv[5,2+7])
  c_t0v4_t1v2 <- as.vector(vcv[5,3+7])
  c_t0v4_t1v3 <- as.vector(vcv[5,4+7])
  c_t0v4_t1v4 <- as.vector(vcv[5,5+7])
  c_t0v4_t1v5 <- as.vector(vcv[5,6+7])
  c_t0v4_t1v6 <- as.vector(vcv[5,7+7])}
  
  c_t0v4 <- as.vector(c(c_t0v4_t1,c_t0v4_t1v1, c_t0v4_t1v2, c_t0v4_t1v3, c_t0v4_t1v4, c_t0v4_t1v5, c_t0v4_t1v6))
  rm(c_t0v4_t1,c_t0v4_t1v1, c_t0v4_t1v2, c_t0v4_t1v3, c_t0v4_t1v4, c_t0v4_t1v5, c_t0v4_t1v6)
  
  #t0_v5
  {c_t0v5_t1   <- as.vector(vcv[6,1+7])
  c_t0v5_t1v1 <- as.vector(vcv[6,2+7])
  c_t0v5_t1v2 <- as.vector(vcv[6,3+7])
  c_t0v5_t1v3 <- as.vector(vcv[6,4+7])
  c_t0v5_t1v4 <- as.vector(vcv[6,5+7])
  c_t0v5_t1v5 <- as.vector(vcv[6,6+7])
  c_t0v5_t1v6 <- as.vector(vcv[6,7+7])}
  
  c_t0v5 <- as.vector(c(c_t0v5_t1,c_t0v5_t1v1, c_t0v5_t1v2, c_t0v5_t1v3, c_t0v5_t1v4, c_t0v5_t1v5, c_t0v5_t1v6))
  rm(c_t0v5_t1,c_t0v5_t1v1, c_t0v5_t1v2, c_t0v5_t1v3, c_t0v5_t1v4, c_t0v5_t1v5, c_t0v5_t1v6)
  
  #t0_v6
  {c_t0v6_t1   <- as.vector(vcv[7,1+7])
  c_t0v6_t1v1 <- as.vector(vcv[7,2+7])
  c_t0v6_t1v2 <- as.vector(vcv[7,3+7])
  c_t0v6_t1v3 <- as.vector(vcv[7,4+7])
  c_t0v6_t1v4 <- as.vector(vcv[7,5+7])
  c_t0v6_t1v5 <- as.vector(vcv[7,6+7])
  c_t0v6_t1v6 <- as.vector(vcv[7,7+7])}
  
  c_t0v6 <- as.vector(c(c_t0v6_t1,c_t0v6_t1v1, c_t0v6_t1v2, c_t0v6_t1v3, c_t0v6_t1v4, c_t0v6_t1v5, c_t0v6_t1v6))
  rm(c_t0v6_t1,c_t0v6_t1v1, c_t0v6_t1v2, c_t0v6_t1v3, c_t0v6_t1v4, c_t0v6_t1v5, c_t0v6_t1v6)}
  C_LR_T_LR_TS <- sum(c_t0) + sum(c_t0v1) + sum(c_t0v2) + sum(c_t0v3) + sum(c_t0v4) + sum(c_t0v5) + sum(c_t0v6)
  rm(c_t0,c_t0v1,c_t0v2,c_t0v3,c_t0v4,c_t0v5,c_t0v6)
  
  {#misc cleanup
  rm(c_lrv4_hr,c_lrv4_hrv1,c_lrv4_hrv2,c_lrv4_hrv3,c_lrv4_hrv4,c_lrv4_hrv5,c_lrv4_hrv6)
  rm(c_lrv5, c_lrv6)}
  
  #Cov Linear LR / Linear HR
  {#t0 
  {c_lr_hr   <- as.vector(vcv[1,1+14])
  c_lr_hrv1 <- as.vector(vcv[1,2+14])
  c_lr_hrv2 <- as.vector(vcv[1,3+14])
  c_lr_hrv3 <- as.vector(vcv[1,4+14])
  c_lr_hrv4 <- as.vector(vcv[1,5+14])
  c_lr_hrv5 <- as.vector(vcv[1,6+14])
  c_lr_hrv6 <- as.vector(vcv[1,7+14])}
  
  c_lr <- as.vector(c(c_lr_hr,c_lr_hrv1,c_lr_hrv2,c_lr_hrv3,c_lr_hrv4,c_lr_hrv5,c_lr_hrv6))
  rm(c_lr_hr,c_lr_hrv1,c_lr_hrv2,c_lr_hrv3,c_lr_hrv4,c_lr_hrv5,c_lr_hrv6)
  #t0_v1
  {c_lrv1_hr   <- as.vector(vcv[2,1+14])
  c_lrv1_hrv1 <- as.vector(vcv[2,2+14])
  c_lrv1_hrv2 <- as.vector(vcv[2,3+14])
  c_lrv1_hrv3 <- as.vector(vcv[2,4+14])
  c_lrv1_hrv4 <- as.vector(vcv[2,5+14])
  c_lrv1_hrv5 <- as.vector(vcv[2,6+14])
  c_lrv1_hrv6 <- as.vector(vcv[2,7+14])}
  
  c_lrv1 <- as.vector(c(c_lrv1_hr, c_lrv1_hrv1, c_lrv1_hrv2, c_lrv1_hrv3, c_lrv1_hrv4, c_lrv1_hrv5, c_lrv1_hrv6))
  rm(c_lrv1_hr, c_lrv1_hrv1, c_lrv1_hrv2, c_lrv1_hrv3, c_lrv1_hrv4, c_lrv1_hrv5, c_lrv1_hrv6)
  
  #t0_v2
  {c_lrv2_hr   <- as.vector(vcv[3,1+14])
  c_lrv2_hrv1 <- as.vector(vcv[3,2+14])
  c_lrv2_hrv2 <- as.vector(vcv[3,3+14])
  c_lrv2_hrv3 <- as.vector(vcv[3,4+14])
  c_lrv2_hrv4 <- as.vector(vcv[3,5+14])
  c_lrv2_hrv5 <- as.vector(vcv[3,6+14])
  c_lrv2_hrv6 <- as.vector(vcv[3,7+14])}
  
  c_lrv2 <- as.vector(c(c_lrv2_hr,c_lrv2_hrv1, c_lrv2_hrv2, c_lrv2_hrv3, c_lrv2_hrv4, c_lrv2_hrv5, c_lrv2_hrv6))
  rm(c_lrv2_hr,c_lrv2_hrv1, c_lrv2_hrv2, c_lrv2_hrv3, c_lrv2_hrv4, c_lrv2_hrv5, c_lrv2_hrv6)
  
  #t0_v3
  {c_lrv3_hr   <- as.vector(vcv[4,1+14])
  c_lrv3_hrv1 <- as.vector(vcv[4,2+14])
  c_lrv3_hrv2 <- as.vector(vcv[4,3+14])
  c_lrv3_hrv3 <- as.vector(vcv[4,4+14])
  c_lrv3_hrv4 <- as.vector(vcv[4,5+14])
  c_lrv3_hrv5 <- as.vector(vcv[4,6+14])
  c_lrv3_hrv6 <- as.vector(vcv[4,7+14])}
  
  c_lrv3 <- as.vector(c(c_lrv3_hr,c_lrv3_hrv1, c_lrv3_hrv2, c_lrv3_hrv3, c_lrv3_hrv4, c_lrv3_hrv5, c_lrv3_hrv6))
  rm(c_lrv3_hr,c_lrv3_hrv1, c_lrv3_hrv2, c_lrv3_hrv3, c_lrv3_hrv4, c_lrv3_hrv5, c_lrv3_hrv6)
  
  #t0_v4
  {c_lrv4_hr   <- as.vector(vcv[5,1+14])
  c_lrv4_hrv1 <- as.vector(vcv[5,2+14])
  c_lrv4_hrv2 <- as.vector(vcv[5,3+14])
  c_lrv4_hrv3 <- as.vector(vcv[5,4+14])
  c_lrv4_hrv4 <- as.vector(vcv[5,5+14])
  c_lrv4_hrv5 <- as.vector(vcv[5,6+14])
  c_lrv4_hrv6 <- as.vector(vcv[5,7+14])}
  
  c_lrv4 <- as.vector(c(c_lrv4_hr,c_lrv4_hrv1, c_lrv4_hrv2, c_lrv4_hrv3, c_lrv4_hrv4, c_lrv4_hrv5, c_lrv4_hrv6))
  rm(c_lrv4_hr,c_lrv4_hrv1, c_lrv4_hrv2, c_lrv4_hrv3, c_lrv4_hrv4, c_lrv4_hrv5, c_lrv4_hrv6)
  
  #t0_v5
  {c_lrv5_hr   <- as.vector(vcv[6,1+14])
  c_lrv5_hrv1 <- as.vector(vcv[6,2+14])
  c_lrv5_hrv2 <- as.vector(vcv[6,3+14])
  c_lrv5_hrv3 <- as.vector(vcv[6,4+14])
  c_lrv5_hrv4 <- as.vector(vcv[6,5+14])
  c_lrv5_hrv5 <- as.vector(vcv[6,6+14])
  c_lrv5_hrv6 <- as.vector(vcv[6,7+14])}
  
  c_lrv5 <- as.vector(c(c_lrv5_hr,c_lrv5_hrv1, c_lrv5_hrv2, c_lrv5_hrv3, c_lrv5_hrv4, c_lrv5_hrv5, c_lrv5_hrv6))
  rm(c_lrv5_hr,c_lrv5_hrv1, c_lrv5_hrv2, c_lrv5_hrv3, c_lrv5_hrv4, c_lrv5_hrv5, c_lrv5_hrv6)
  
  #t0_v6
  {c_lrv6_hr   <- as.vector(vcv[7,1+14])
  c_lrv6_hrv1 <- as.vector(vcv[7,2+14])
  c_lrv6_hrv2 <- as.vector(vcv[7,3+14])
  c_lrv6_hrv3 <- as.vector(vcv[7,4+14])
  c_lrv6_hrv4 <- as.vector(vcv[7,5+14])
  c_lrv6_hrv5 <- as.vector(vcv[7,6+14])
  c_lrv6_hrv6 <- as.vector(vcv[7,7+14])}
  
  c_lrv6 <- as.vector(c(c_lrv6_hr,c_lrv6_hrv1, c_lrv6_hrv2, c_lrv6_hrv3, c_lrv6_hrv4, c_lrv6_hrv5, c_lrv6_hrv6))
  rm(c_lrv6_hr,c_lrv6_hrv1, c_lrv6_hrv2, c_lrv6_hrv3, c_lrv6_hrv4, c_lrv6_hrv5, c_lrv6_hrv6)}
  C_LR_T_HR_T <- V_LR_T + sum(c_lr) + sum(c_lrv1) + sum(c_lrv2) + sum(c_lrv3) + sum(c_lrv4) + sum(c_lrv5) + sum(c_lrv6)
  rm(c_lr,c_lrv1,c_lrv2,c_lrv3,c_lrv4,c_lrv5,c_lrv6)   
  
  #Cov Linear LR/ Spline HR
  {#t0 
  {c_lr_hrs   <- as.vector(vcv[1,1+21])
  c_lr_hrsv1 <- as.vector(vcv[1,2+21])
  c_lr_hrsv2 <- as.vector(vcv[1,3+21])
  c_lr_hrsv3 <- as.vector(vcv[1,4+21])
  c_lr_hrsv4 <- as.vector(vcv[1,5+21])
  c_lr_hrsv5 <- as.vector(vcv[1,6+21])
  c_lr_hrsv6 <- as.vector(vcv[1,7+21])}
  
  c_lr <- as.vector(c(c_lr_hrs,c_lr_hrsv1,c_lr_hrsv2,c_lr_hrsv3,c_lr_hrsv4,c_lr_hrsv5,c_lr_hrsv6))
  rm(c_lr_hrs,c_lr_hrsv1,c_lr_hrsv2,c_lr_hrsv3,c_lr_hrsv4,c_lr_hrsv5,c_lr_hrsv6)
  #t0_v1
  {c_lrv1_hrs   <- as.vector(vcv[2,1+21])
  c_lrv1_hrsv1 <- as.vector(vcv[2,2+21])
  c_lrv1_hrsv2 <- as.vector(vcv[2,3+21])
  c_lrv1_hrsv3 <- as.vector(vcv[2,4+21])
  c_lrv1_hrsv4 <- as.vector(vcv[2,5+21])
  c_lrv1_hrsv5 <- as.vector(vcv[2,6+21])
  c_lrv1_hrsv6 <- as.vector(vcv[2,7+21])}
  
  c_lrv1 <- as.vector(c(c_lrv1_hrs, c_lrv1_hrsv1, c_lrv1_hrsv2, c_lrv1_hrsv3, c_lrv1_hrsv4, c_lrv1_hrsv5, c_lrv1_hrsv6))
  rm(c_lrv1_hrs, c_lrv1_hrsv1, c_lrv1_hrsv2, c_lrv1_hrsv3, c_lrv1_hrsv4, c_lrv1_hrsv5, c_lrv1_hrsv6)
  
  #t0_v2
  {c_lrv2_hrs   <- as.vector(vcv[3,1+21])
  c_lrv2_hrsv1 <- as.vector(vcv[3,2+21])
  c_lrv2_hrsv2 <- as.vector(vcv[3,3+21])
  c_lrv2_hrsv3 <- as.vector(vcv[3,4+21])
  c_lrv2_hrsv4 <- as.vector(vcv[3,5+21])
  c_lrv2_hrsv5 <- as.vector(vcv[3,6+21])
  c_lrv2_hrsv6 <- as.vector(vcv[3,7+21])}
  
  c_lrv2 <- as.vector(c(c_lrv2_hrs,c_lrv2_hrsv1, c_lrv2_hrsv2, c_lrv2_hrsv3, c_lrv2_hrsv4, c_lrv2_hrsv5, c_lrv2_hrsv6))
  rm(c_lrv2_hrs,c_lrv2_hrsv1, c_lrv2_hrsv2, c_lrv2_hrsv3, c_lrv2_hrsv4, c_lrv2_hrsv5, c_lrv2_hrsv6)
  
  #t0_v3
  {c_lrv3_hrs   <- as.vector(vcv[4,1+21])
  c_lrv3_hrsv1 <- as.vector(vcv[4,2+21])
  c_lrv3_hrsv2 <- as.vector(vcv[4,3+21])
  c_lrv3_hrsv3 <- as.vector(vcv[4,4+21])
  c_lrv3_hrsv4 <- as.vector(vcv[4,5+21])
  c_lrv3_hrsv5 <- as.vector(vcv[4,6+21])
  c_lrv3_hrsv6 <- as.vector(vcv[4,7+21])}
  
  c_lrv3 <- as.vector(c(c_lrv3_hrs,c_lrv3_hrsv1, c_lrv3_hrsv2, c_lrv3_hrsv3, c_lrv3_hrsv4, c_lrv3_hrsv5, c_lrv3_hrsv6))
  rm(c_lrv3_hrs,c_lrv3_hrsv1, c_lrv3_hrsv2, c_lrv3_hrsv3, c_lrv3_hrsv4, c_lrv3_hrsv5, c_lrv3_hrsv6)
  
  #t0_v4
  {c_lrv4_hrs   <- as.vector(vcv[5,1+21])
  c_lrv4_hrsv1 <- as.vector(vcv[5,2+21])
  c_lrv4_hrsv2 <- as.vector(vcv[5,3+21])
  c_lrv4_hrsv3 <- as.vector(vcv[5,4+21])
  c_lrv4_hrsv4 <- as.vector(vcv[5,5+21])
  c_lrv4_hrsv5 <- as.vector(vcv[5,6+21])
  c_lrv4_hrsv6 <- as.vector(vcv[5,7+21])}
  
  c_lrv4 <- as.vector(c(c_lrv4_hrs,c_lrv4_hrsv1, c_lrv4_hrsv2, c_lrv4_hrsv3, c_lrv4_hrsv4, c_lrv4_hrsv5, c_lrv4_hrsv6))
  rm(c_lrv4_hrs,c_lrv4_hrsv1, c_lrv4_hrsv2, c_lrv4_hrsv3, c_lrv4_hrsv4, c_lrv4_hrsv5, c_lrv4_hrsv6)
  
  #t0_v5
  {c_lrv5_hrs   <- as.vector(vcv[6,1+21])
  c_lrv5_hrsv1 <- as.vector(vcv[6,2+21])
  c_lrv5_hrsv2 <- as.vector(vcv[6,3+21])
  c_lrv5_hrsv3 <- as.vector(vcv[6,4+21])
  c_lrv5_hrsv4 <- as.vector(vcv[6,5+21])
  c_lrv5_hrsv5 <- as.vector(vcv[6,6+21])
  c_lrv5_hrsv6 <- as.vector(vcv[6,7+21])}
  
  c_lrv5 <- as.vector(c(c_lrv5_hrs,c_lrv5_hrsv1, c_lrv5_hrsv2, c_lrv5_hrsv3, c_lrv5_hrsv4, c_lrv5_hrsv5, c_lrv5_hrsv6))
  rm(c_lrv5_hrs,c_lrv5_hrsv1, c_lrv5_hrsv2, c_lrv5_hrsv3, c_lrv5_hrsv4, c_lrv5_hrsv5, c_lrv5_hrsv6)
  
  #t0_v6
  {c_lrv6_hrs   <- as.vector(vcv[7,1+21])
  c_lrv6_hrsv1 <- as.vector(vcv[7,2+21])
  c_lrv6_hrsv2 <- as.vector(vcv[7,3+21])
  c_lrv6_hrsv3 <- as.vector(vcv[7,4+21])
  c_lrv6_hrsv4 <- as.vector(vcv[7,5+21])
  c_lrv6_hrsv5 <- as.vector(vcv[7,6+21])
  c_lrv6_hrsv6 <- as.vector(vcv[7,7+21])}
  
  c_lrv6 <- as.vector(c(c_lrv6_hrs,c_lrv6_hrsv1, c_lrv6_hrsv2, c_lrv6_hrsv3, c_lrv6_hrsv4, c_lrv6_hrsv5, c_lrv6_hrsv6))
  rm(c_lrv6_hrs,c_lrv6_hrsv1, c_lrv6_hrsv2, c_lrv6_hrsv3, c_lrv6_hrsv4, c_lrv6_hrsv5, c_lrv6_hrsv6)}
  C_LR_T_HR_TS <- C_LR_T_LR_TS + sum(c_lr) + sum(c_lrv1) + sum(c_lrv2) + sum(c_lrv3) + sum(c_lrv4) + sum(c_lrv5) + sum(c_lrv6)
  rm(c_lr,c_lrv1,c_lrv2,c_lrv3,c_lrv4,c_lrv5,c_lrv6)  
  
  #Cov LR Spline / HR Linear
  {#t0 
  {c_lrs_hr   <- as.vector(vcv[1+7,1+14])
  c_lrs_hrv1 <- as.vector(vcv[1+7,2+14])
  c_lrs_hrv2 <- as.vector(vcv[1+7,3+14])
  c_lrs_hrv3 <- as.vector(vcv[1+7,4+14])
  c_lrs_hrv4 <- as.vector(vcv[1+7,5+14])
  c_lrs_hrv5 <- as.vector(vcv[1+7,6+14])
  c_lrs_hrv6 <- as.vector(vcv[1+7,7+14])}
  
  c_lrs <- as.vector(c(c_lrs_hr,c_lrs_hrv1,c_lrs_hrv2,c_lrs_hrv3,c_lrs_hrv4,c_lrs_hrv5,c_lrs_hrv6))
  rm(c_lrs_hr,c_lrs_hrv1,c_lrs_hrv2,c_lrs_hrv3,c_lrs_hrv4,c_lrs_hrv5,c_lrs_hrv6)
  #t0_v1
  {c_lrsv1_hr   <- as.vector(vcv[2+7,1+14])
  c_lrsv1_hrv1 <- as.vector(vcv[2+7,2+14])
  c_lrsv1_hrv2 <- as.vector(vcv[2+7,3+14])
  c_lrsv1_hrv3 <- as.vector(vcv[2+7,4+14])
  c_lrsv1_hrv4 <- as.vector(vcv[2+7,5+14])
  c_lrsv1_hrv5 <- as.vector(vcv[2+7,6+14])
  c_lrsv1_hrv6 <- as.vector(vcv[2+7,7+14])}
  
  c_lrsv1 <- as.vector(c(c_lrsv1_hr, c_lrsv1_hrv1, c_lrsv1_hrv2, c_lrsv1_hrv3, c_lrsv1_hrv4, c_lrsv1_hrv5, c_lrsv1_hrv6))
  rm(c_lrsv1_hr, c_lrsv1_hrv1, c_lrsv1_hrv2, c_lrsv1_hrv3, c_lrsv1_hrv4, c_lrsv1_hrv5, c_lrsv1_hrv6)
  
  #t0_v2
  {c_lrsv2_hr   <- as.vector(vcv[3+7,1+14])
  c_lrsv2_hrv1 <- as.vector(vcv[3+7,2+14])
  c_lrsv2_hrv2 <- as.vector(vcv[3+7,3+14])
  c_lrsv2_hrv3 <- as.vector(vcv[3+7,4+14])
  c_lrsv2_hrv4 <- as.vector(vcv[3+7,5+14])
  c_lrsv2_hrv5 <- as.vector(vcv[3+7,6+14])
  c_lrsv2_hrv6 <- as.vector(vcv[3+7,7+14])}
  
  c_lrsv2 <- as.vector(c(c_lrsv2_hr,c_lrsv2_hrv1, c_lrsv2_hrv2, c_lrsv2_hrv3, c_lrsv2_hrv4, c_lrsv2_hrv5, c_lrsv2_hrv6))
  rm(c_lrsv2_hr,c_lrsv2_hrv1, c_lrsv2_hrv2, c_lrsv2_hrv3, c_lrsv2_hrv4, c_lrsv2_hrv5, c_lrsv2_hrv6)
  
  #t0_v3
  {c_lrsv3_hr   <- as.vector(vcv[4+7,1+14])
  c_lrsv3_hrv1 <- as.vector(vcv[4+7,2+14])
  c_lrsv3_hrv2 <- as.vector(vcv[4+7,3+14])
  c_lrsv3_hrv3 <- as.vector(vcv[4+7,4+14])
  c_lrsv3_hrv4 <- as.vector(vcv[4+7,5+14])
  c_lrsv3_hrv5 <- as.vector(vcv[4+7,6+14])
  c_lrsv3_hrv6 <- as.vector(vcv[4+7,7+14])}
  
  c_lrsv3 <- as.vector(c(c_lrsv3_hr,c_lrsv3_hrv1, c_lrsv3_hrv2, c_lrsv3_hrv3, c_lrsv3_hrv4, c_lrsv3_hrv5, c_lrsv3_hrv6))
  rm(c_lrsv3_hr,c_lrsv3_hrv1, c_lrsv3_hrv2, c_lrsv3_hrv3, c_lrsv3_hrv4, c_lrsv3_hrv5, c_lrsv3_hrv6)
  
  #t0_v4
  {c_lrsv4_hr   <- as.vector(vcv[5+7,1+14])
  c_lrsv4_hrv1 <- as.vector(vcv[5+7,2+14])
  c_lrsv4_hrv2 <- as.vector(vcv[5+7,3+14])
  c_lrsv4_hrv3 <- as.vector(vcv[5+7,4+14])
  c_lrsv4_hrv4 <- as.vector(vcv[5+7,5+14])
  c_lrsv4_hrv5 <- as.vector(vcv[5+7,6+14])
  c_lrsv4_hrv6 <- as.vector(vcv[5+7,7+14])}
  
  c_lrsv4 <- as.vector(c(c_lrsv4_hr,c_lrsv4_hrv1, c_lrsv4_hrv2, c_lrsv4_hrv3, c_lrsv4_hrv4, c_lrsv4_hrv5, c_lrsv4_hrv6))
  rm(c_lrsv4_hr,c_lrsv4_hrv1, c_lrsv4_hrv2, c_lrsv4_hrv3, c_lrsv4_hrv4, c_lrsv4_hrv5, c_lrsv4_hrv6)
  
  #t0_v5
  {c_lrsv5_hr   <- as.vector(vcv[6+7,1+14])
  c_lrsv5_hrv1 <- as.vector(vcv[6+7,2+14])
  c_lrsv5_hrv2 <- as.vector(vcv[6+7,3+14])
  c_lrsv5_hrv3 <- as.vector(vcv[6+7,4+14])
  c_lrsv5_hrv4 <- as.vector(vcv[6+7,5+14])
  c_lrsv5_hrv5 <- as.vector(vcv[6+7,6+14])
  c_lrsv5_hrv6 <- as.vector(vcv[6+7,7+14])}
  
  c_lrsv5 <- as.vector(c(c_lrsv5_hr,c_lrsv5_hrv1, c_lrsv5_hrv2, c_lrsv5_hrv3, c_lrsv5_hrv4, c_lrsv5_hrv5, c_lrsv5_hrv6))
  rm(c_lrsv5_hr,c_lrsv5_hrv1, c_lrsv5_hrv2, c_lrsv5_hrv3, c_lrsv5_hrv4, c_lrsv5_hrv5, c_lrsv5_hrv6)
  
  #t0_v6
  {c_lrsv6_hr   <- as.vector(vcv[7+7,1+14])
  c_lrsv6_hrv1 <- as.vector(vcv[7+7,2+14])
  c_lrsv6_hrv2 <- as.vector(vcv[7+7,3+14])
  c_lrsv6_hrv3 <- as.vector(vcv[7+7,4+14])
  c_lrsv6_hrv4 <- as.vector(vcv[7+7,5+14])
  c_lrsv6_hrv5 <- as.vector(vcv[7+7,6+14])
  c_lrsv6_hrv6 <- as.vector(vcv[7+7,7+14])}
  
  c_lrsv6 <- as.vector(c(c_lrsv6_hr,c_lrsv6_hrv1, c_lrsv6_hrv2, c_lrsv6_hrv3, c_lrsv6_hrv4, c_lrsv6_hrv5, c_lrsv6_hrv6))
  rm(c_lrsv6_hr,c_lrsv6_hrv1, c_lrsv6_hrv2, c_lrsv6_hrv3, c_lrsv6_hrv4, c_lrsv6_hrv5, c_lrsv6_hrv6)}
  C_LR_TS_HR_T <- C_LR_T_LR_TS + sum(c_lrs) + sum(c_lrsv1) + sum(c_lrsv2) + sum(c_lrsv3) + sum(c_lrsv4) + sum(c_lrsv5) + sum(c_lrsv6)
  rm(c_lrs,c_lrsv1,c_lrsv2,c_lrsv3,c_lrsv4,c_lrsv5,c_lrsv6)    
  
  #COV LR Spline / COV HR Spline
  {#t0 
  {c_lrs_hrs   <- as.vector(vcv[1+7,1+21])
  c_lrs_hrsv1 <- as.vector(vcv[1+7,2+21])
  c_lrs_hrsv2 <- as.vector(vcv[1+7,3+21])
  c_lrs_hrsv3 <- as.vector(vcv[1+7,4+21])
  c_lrs_hrsv4 <- as.vector(vcv[1+7,5+21])
  c_lrs_hrsv5 <- as.vector(vcv[1+7,6+21])
  c_lrs_hrsv6 <- as.vector(vcv[1+7,7+21])}
  
  c_lrs <- as.vector(c(c_lrs_hrs,c_lrs_hrsv1,c_lrs_hrsv2,c_lrs_hrsv3,c_lrs_hrsv4,c_lrs_hrsv5,c_lrs_hrsv6))
  rm(c_lrs_hrs,c_lrs_hrsv1,c_lrs_hrsv2,c_lrs_hrsv3,c_lrs_hrsv4,c_lrs_hrsv5,c_lrs_hrsv6)
  #t0_v1
  {c_lrsv1_hrs   <- as.vector(vcv[2+7,1+21])
  c_lrsv1_hrsv1 <- as.vector(vcv[2+7,2+21])
  c_lrsv1_hrsv2 <- as.vector(vcv[2+7,3+21])
  c_lrsv1_hrsv3 <- as.vector(vcv[2+7,4+21])
  c_lrsv1_hrsv4 <- as.vector(vcv[2+7,5+21])
  c_lrsv1_hrsv5 <- as.vector(vcv[2+7,6+21])
  c_lrsv1_hrsv6 <- as.vector(vcv[2+7,7+21])}
  
  c_lrsv1 <- as.vector(c(c_lrsv1_hrs, c_lrsv1_hrsv1, c_lrsv1_hrsv2, c_lrsv1_hrsv3, c_lrsv1_hrsv4, c_lrsv1_hrsv5, c_lrsv1_hrsv6))
  rm(c_lrsv1_hrs, c_lrsv1_hrsv1, c_lrsv1_hrsv2, c_lrsv1_hrsv3, c_lrsv1_hrsv4, c_lrsv1_hrsv5, c_lrsv1_hrsv6)
  
  #t0_v2
  {c_lrsv2_hrs   <- as.vector(vcv[3+7,1+21])
  c_lrsv2_hrsv1 <- as.vector(vcv[3+7,2+21])
  c_lrsv2_hrsv2 <- as.vector(vcv[3+7,3+21])
  c_lrsv2_hrsv3 <- as.vector(vcv[3+7,4+21])
  c_lrsv2_hrsv4 <- as.vector(vcv[3+7,5+21])
  c_lrsv2_hrsv5 <- as.vector(vcv[3+7,6+21])
  c_lrsv2_hrsv6 <- as.vector(vcv[3+7,7+21])}
  
  c_lrsv2 <- as.vector(c(c_lrsv2_hrs,c_lrsv2_hrsv1, c_lrsv2_hrsv2, c_lrsv2_hrsv3, c_lrsv2_hrsv4, c_lrsv2_hrsv5, c_lrsv2_hrsv6))
  rm(c_lrsv2_hrs,c_lrsv2_hrsv1, c_lrsv2_hrsv2, c_lrsv2_hrsv3, c_lrsv2_hrsv4, c_lrsv2_hrsv5, c_lrsv2_hrsv6)
  
  #t0_v3
  {c_lrsv3_hrs   <- as.vector(vcv[4+7,1+21])
  c_lrsv3_hrsv1 <- as.vector(vcv[4+7,2+21])
  c_lrsv3_hrsv2 <- as.vector(vcv[4+7,3+21])
  c_lrsv3_hrsv3 <- as.vector(vcv[4+7,4+21])
  c_lrsv3_hrsv4 <- as.vector(vcv[4+7,5+21])
  c_lrsv3_hrsv5 <- as.vector(vcv[4+7,6+21])
  c_lrsv3_hrsv6 <- as.vector(vcv[4+7,7+21])}
  
  c_lrsv3 <- as.vector(c(c_lrsv3_hrs,c_lrsv3_hrsv1, c_lrsv3_hrsv2, c_lrsv3_hrsv3, c_lrsv3_hrsv4, c_lrsv3_hrsv5, c_lrsv3_hrsv6))
  rm(c_lrsv3_hrs,c_lrsv3_hrsv1, c_lrsv3_hrsv2, c_lrsv3_hrsv3, c_lrsv3_hrsv4, c_lrsv3_hrsv5, c_lrsv3_hrsv6)
  
  #t0_v4
  {c_lrsv4_hrs   <- as.vector(vcv[5+7,1+21])
  c_lrsv4_hrsv1 <- as.vector(vcv[5+7,2+21])
  c_lrsv4_hrsv2 <- as.vector(vcv[5+7,3+21])
  c_lrsv4_hrsv3 <- as.vector(vcv[5+7,4+21])
  c_lrsv4_hrsv4 <- as.vector(vcv[5+7,5+21])
  c_lrsv4_hrsv5 <- as.vector(vcv[5+7,6+21])
  c_lrsv4_hrsv6 <- as.vector(vcv[5+7,7+21])}
  
  c_lrsv4 <- as.vector(c(c_lrsv4_hrs,c_lrsv4_hrsv1, c_lrsv4_hrsv2, c_lrsv4_hrsv3, c_lrsv4_hrsv4, c_lrsv4_hrsv5, c_lrsv4_hrsv6))
  rm(c_lrsv4_hrs,c_lrsv4_hrsv1, c_lrsv4_hrsv2, c_lrsv4_hrsv3, c_lrsv4_hrsv4, c_lrsv4_hrsv5, c_lrsv4_hrsv6)
  
  #t0_v5
  {c_lrsv5_hrs   <- as.vector(vcv[6+7,1+21])
  c_lrsv5_hrsv1 <- as.vector(vcv[6+7,2+21])
  c_lrsv5_hrsv2 <- as.vector(vcv[6+7,3+21])
  c_lrsv5_hrsv3 <- as.vector(vcv[6+7,4+21])
  c_lrsv5_hrsv4 <- as.vector(vcv[6+7,5+21])
  c_lrsv5_hrsv5 <- as.vector(vcv[6+7,6+21])
  c_lrsv5_hrsv6 <- as.vector(vcv[6+7,7+21])}
  
  c_lrsv5 <- as.vector(c(c_lrsv5_hrs,c_lrsv5_hrsv1, c_lrsv5_hrsv2, c_lrsv5_hrsv3, c_lrsv5_hrsv4, c_lrsv5_hrsv5, c_lrsv5_hrsv6))
  rm(c_lrsv5_hrs,c_lrsv5_hrsv1, c_lrsv5_hrsv2, c_lrsv5_hrsv3, c_lrsv5_hrsv4, c_lrsv5_hrsv5, c_lrsv5_hrsv6)
  
  #t0_v6
  {c_lrsv6_hrs   <- as.vector(vcv[7+7,1+21])
  c_lrsv6_hrsv1 <- as.vector(vcv[7+7,2+21])
  c_lrsv6_hrsv2 <- as.vector(vcv[7+7,3+21])
  c_lrsv6_hrsv3 <- as.vector(vcv[7+7,4+21])
  c_lrsv6_hrsv4 <- as.vector(vcv[7+7,5+21])
  c_lrsv6_hrsv5 <- as.vector(vcv[7+7,6+21])
  c_lrsv6_hrsv6 <- as.vector(vcv[7+7,7+21])}
  
  c_lrsv6 <- as.vector(c(c_lrsv6_hrs,c_lrsv6_hrsv1, c_lrsv6_hrsv2, c_lrsv6_hrsv3, c_lrsv6_hrsv4, c_lrsv6_hrsv5, c_lrsv6_hrsv6))
  rm(c_lrsv6_hrs,c_lrsv6_hrsv1, c_lrsv6_hrsv2, c_lrsv6_hrsv3, c_lrsv6_hrsv4, c_lrsv6_hrsv5, c_lrsv6_hrsv6)}
  
  C_LR_TS_HR_TS <- V_LR_TS + sum(c_lrs) + sum(c_lrsv1) + sum(c_lrsv2) + sum(c_lrsv3) + sum(c_lrsv4) + sum(c_lrsv5) + sum(c_lrsv6)
  rm(c_lrs,c_lrsv1,c_lrsv2,c_lrsv3,c_lrsv4,c_lrsv5,c_lrsv6) 
  
  #Cov HR Linear HR Spline
  {#t0 
  {c_hr_hrs   <- as.vector(vcv[1+14,1+21])
  c_hr_hrsv1 <- as.vector(vcv[1+14,2+21])
  c_hr_hrsv2 <- as.vector(vcv[1+14,3+21])
  c_hr_hrsv3 <- as.vector(vcv[1+14,4+21])
  c_hr_hrsv4 <- as.vector(vcv[1+14,5+21])
  c_hr_hrsv5 <- as.vector(vcv[1+14,6+21])
  c_hr_hrsv6 <- as.vector(vcv[1+14,7+21])}
  
  c_hr <- as.vector(c(c_hr_hrs,c_hr_hrsv1,c_hr_hrsv2,c_hr_hrsv3,c_hr_hrsv4,c_hr_hrsv5,c_hr_hrsv6))
  rm(c_hr_hrs,c_hr_hrsv1,c_hr_hrsv2,c_hr_hrsv3,c_hr_hrsv4,c_hr_hrsv5,c_hr_hrsv6)
  
  #t0_v1
  {c_hrv1_hrs   <- as.vector(vcv[2+14,1+21])
  c_hrv1_hrsv1 <- as.vector(vcv[2+14,2+21])
  c_hrv1_hrsv2 <- as.vector(vcv[2+14,3+21])
  c_hrv1_hrsv3 <- as.vector(vcv[2+14,4+21])
  c_hrv1_hrsv4 <- as.vector(vcv[2+14,5+21])
  c_hrv1_hrsv5 <- as.vector(vcv[2+14,6+21])
  c_hrv1_hrsv6 <- as.vector(vcv[2+14,7+21])}
  
  c_hrv1 <- as.vector(c(c_hrv1_hrs, c_hrv1_hrsv1, c_hrv1_hrsv2, c_hrv1_hrsv3, c_hrv1_hrsv4, c_hrv1_hrsv5, c_hrv1_hrsv6))
  rm(c_hrv1_hrs, c_hrv1_hrsv1, c_hrv1_hrsv2, c_hrv1_hrsv3, c_hrv1_hrsv4, c_hrv1_hrsv5, c_hrv1_hrsv6)
  
  #t0_v2
  {c_hrv2_hrs   <- as.vector(vcv[3+14,1+21])
  c_hrv2_hrsv1 <- as.vector(vcv[3+14,2+21])
  c_hrv2_hrsv2 <- as.vector(vcv[3+14,3+21])
  c_hrv2_hrsv3 <- as.vector(vcv[3+14,4+21])
  c_hrv2_hrsv4 <- as.vector(vcv[3+14,5+21])
  c_hrv2_hrsv5 <- as.vector(vcv[3+14,6+21])
  c_hrv2_hrsv6 <- as.vector(vcv[3+14,7+21])}
  
  c_hrv2 <- as.vector(c(c_hrv2_hrs,c_hrv2_hrsv1, c_hrv2_hrsv2, c_hrv2_hrsv3, c_hrv2_hrsv4, c_hrv2_hrsv5, c_hrv2_hrsv6))
  rm(c_hrv2_hrs,c_hrv2_hrsv1, c_hrv2_hrsv2, c_hrv2_hrsv3, c_hrv2_hrsv4, c_hrv2_hrsv5, c_hrv2_hrsv6)
  
  #t0_v3
  {c_hrv3_hrs   <- as.vector(vcv[4+14,1+21])
  c_hrv3_hrsv1 <- as.vector(vcv[4+14,2+21])
  c_hrv3_hrsv2 <- as.vector(vcv[4+14,3+21])
  c_hrv3_hrsv3 <- as.vector(vcv[4+14,4+21])
  c_hrv3_hrsv4 <- as.vector(vcv[4+14,5+21])
  c_hrv3_hrsv5 <- as.vector(vcv[4+14,6+21])
  c_hrv3_hrsv6 <- as.vector(vcv[4+14,7+21])}
  
  c_hrv3 <- as.vector(c(c_hrv3_hrs,c_hrv3_hrsv1, c_hrv3_hrsv2, c_hrv3_hrsv3, c_hrv3_hrsv4, c_hrv3_hrsv5, c_hrv3_hrsv6))
  rm(c_hrv3_hrs,c_hrv3_hrsv1, c_hrv3_hrsv2, c_hrv3_hrsv3, c_hrv3_hrsv4, c_hrv3_hrsv5, c_hrv3_hrsv6)
  
  #t0_v4
  {c_hrv4_hrs   <- as.vector(vcv[5+14,1+21])
  c_hrv4_hrsv1 <- as.vector(vcv[5+14,2+21])
  c_hrv4_hrsv2 <- as.vector(vcv[5+14,3+21])
  c_hrv4_hrsv3 <- as.vector(vcv[5+14,4+21])
  c_hrv4_hrsv4 <- as.vector(vcv[5+14,5+21])
  c_hrv4_hrsv5 <- as.vector(vcv[5+14,6+21])
  c_hrv4_hrsv6 <- as.vector(vcv[5+14,7+21])}
  
  c_hrv4 <- as.vector(c(c_hrv4_hrs,c_hrv4_hrsv1, c_hrv4_hrsv2, c_hrv4_hrsv3, c_hrv4_hrsv4, c_hrv4_hrsv5, c_hrv4_hrsv6))
  rm(c_hrv4_hrs,c_hrv4_hrsv1, c_hrv4_hrsv2, c_hrv4_hrsv3, c_hrv4_hrsv4, c_hrv4_hrsv5, c_hrv4_hrsv6)
  
  #t0_v5
  {c_hrv5_hrs   <- as.vector(vcv[6+14,1+21])
  c_hrv5_hrsv1 <- as.vector(vcv[6+14,2+21])
  c_hrv5_hrsv2 <- as.vector(vcv[6+14,3+21])
  c_hrv5_hrsv3 <- as.vector(vcv[6+14,4+21])
  c_hrv5_hrsv4 <- as.vector(vcv[6+14,5+21])
  c_hrv5_hrsv5 <- as.vector(vcv[6+14,6+21])
  c_hrv5_hrsv6 <- as.vector(vcv[6+14,7+21])}
  
  c_hrv5 <- as.vector(c(c_hrv5_hrs,c_hrv5_hrsv1, c_hrv5_hrsv2, c_hrv5_hrsv3, c_hrv5_hrsv4, c_hrv5_hrsv5, c_hrv5_hrsv6))
  rm(c_hrv5_hrs,c_hrv5_hrsv1, c_hrv5_hrsv2, c_hrv5_hrsv3, c_hrv5_hrsv4, c_hrv5_hrsv5, c_hrv5_hrsv6)
  
  #t0_v6
  {c_hrv6_hrs   <- as.vector(vcv[7+14,1+21])
  c_hrv6_hrsv1 <- as.vector(vcv[7+14,2+21])
  c_hrv6_hrsv2 <- as.vector(vcv[7+14,3+21])
  c_hrv6_hrsv3 <- as.vector(vcv[7+14,4+21])
  c_hrv6_hrsv4 <- as.vector(vcv[7+14,5+21])
  c_hrv6_hrsv5 <- as.vector(vcv[7+14,6+21])
  c_hrv6_hrsv6 <- as.vector(vcv[7+14,7+21])}
  
  c_hrv6 <- as.vector(c(c_hrv6_hrs,c_hrv6_hrsv1, c_hrv6_hrsv2, c_hrv6_hrsv3, c_hrv6_hrsv4, c_hrv6_hrsv5, c_hrv6_hrsv6))
  rm(c_hrv6_hrs,c_hrv6_hrsv1, c_hrv6_hrsv2, c_hrv6_hrsv3, c_hrv6_hrsv4, c_hrv6_hrsv5, c_hrv6_hrsv6)}
  C_HR_T_HR_TS <- C_LR_T_LR_TS + (C_LR_T_HR_TS - C_LR_T_LR_TS) + (C_LR_TS_HR_T-C_LR_T_LR_TS) + sum(c_hr) + sum(c_hrv1) + sum(c_hrv2) + sum(c_hrv3) + sum(c_hrv4) + sum(c_hrv5) + sum(c_hrv6)
  rm(c_hr,c_hrv1,c_hrv2,c_hrv3,c_hrv4,c_hrv5,c_hrv6)    
  
  
} else {
  if (interacted == "interacted") {
    vcv <- as.matrix(fread("~/repos/labor-code-release-2020/disutility_ext/interacted_vcv.csv"))
    
    #Varience LR Linear
    {#Low Linear
      
      {v_t0    <- as.vector(vcv[1,1])
      v_t0_v1 <- as.vector(vcv[2,2])
      v_t0_v2 <- as.vector(vcv[3,3])
      v_t0_v3 <- as.vector(vcv[4,4])
      v_t0_v4 <- as.vector(vcv[5,5])
      v_t0_v5 <- as.vector(vcv[6,6])
      v_t0_v6 <- as.vector(vcv[7,7])}
      
      v <- as.vector(c(v_t0, v_t0_v1, v_t0_v2, v_t0_v3, v_t0_v4, v_t0_v5, v_t0_v6))
      rm(v_t0, v_t0_v1, v_t0_v2, v_t0_v3, v_t0_v4, v_t0_v5, v_t0_v6)
      
      cov_t0_t0v1 <- as.vector(vcv[2,1])
      cov_t0_t0v2 <- as.vector(vcv[3,1])
      cov_t0_t0v3 <- as.vector(vcv[4,1])
      cov_t0_t0v4 <- as.vector(vcv[5,1])
      cov_t0_t0v5 <- as.vector(vcv[6,1])
      cov_t0_t0v6 <- as.vector(vcv[7,1])
      
      c <- as.vector(c(cov_t0_t0v1, cov_t0_t0v2, cov_t0_t0v3, cov_t0_t0v4,cov_t0_t0v5,cov_t0_t0v6))
      rm(cov_t0_t0v1, cov_t0_t0v2, cov_t0_t0v3, cov_t0_t0v4,cov_t0_t0v5,cov_t0_t0v6)
      
      {cov_t0v1_t0v2 <- as.vector(vcv[3,2])
        cov_t0v1_t0v3 <- as.vector(vcv[4,2])
        cov_t0v1_t0v4 <- as.vector(vcv[5,2])
        cov_t0v1_t0v5 <- as.vector(vcv[6,2])
        cov_t0v1_t0v6 <- as.vector(vcv[7,2])}
      
      c <- as.vector(c(c, cov_t0v1_t0v2, cov_t0v1_t0v3, cov_t0v1_t0v4,cov_t0v1_t0v5,cov_t0v1_t0v6))
      rm(cov_t0v1_t0v2, cov_t0v1_t0v3, cov_t0v1_t0v4,cov_t0v1_t0v5,cov_t0v1_t0v6)
      
      
      {cov_t0v2_t0v3 <- as.vector(vcv[4,3])
        cov_t0v2_t0v4 <- as.vector(vcv[5,3])
        cov_t0v2_t0v5 <- as.vector(vcv[6,3])
        cov_t0v2_t0v6 <- as.vector(vcv[7,3])}
      
      c <- as.vector(c(c, cov_t0v2_t0v3, cov_t0v2_t0v4,cov_t0v2_t0v5,cov_t0v2_t0v6))
      rm(cov_t0v2_t0v3, cov_t0v2_t0v4,cov_t0v2_t0v5,cov_t0v2_t0v6)
      
      {cov_t0v3_t0v4 <- as.vector(vcv[5,4])
        cov_t0v3_t0v5 <- as.vector(vcv[6,4])
        cov_t0v3_t0v6 <- as.vector(vcv[7,4])}
      
      c <- as.vector(c(c,  cov_t0v3_t0v4,cov_t0v3_t0v5,cov_t0v3_t0v6))
      rm(cov_t0v3_t0v4,cov_t0v3_t0v5,cov_t0v3_t0v6)
      
      {cov_t0v4_t0v5 <- as.vector(vcv[6,5])
        cov_t0v4_t0v6 <- as.vector(vcv[7,5])}
      
      c <- as.vector(c(c,cov_t0v4_t0v5,cov_t0v4_t0v6))
      rm(cov_t0v4_t0v5,cov_t0v4_t0v6)
      
      {cov_t0v5_t0v6 <- as.vector(vcv[7,6])
      }
      
      c <- as.vector(c(c,cov_t0v5_t0v6))
      rm(cov_t0v5_t0v6)
      
      v_t_lr <- v
      c_t_lr <- c }
    V_LR_T <- sum(v_t_lr) + 2*sum(c_t_lr)
    
    #Varience LR Spline
    {#Low Spline
      
      {v_t1    <- as.vector(vcv[1+7,1+7])
      v_t1_v1 <- as.vector(vcv[2+7,2+7])
      v_t1_v2 <- as.vector(vcv[3+7,3+7])
      v_t1_v3 <- as.vector(vcv[4+7,4+7])
      v_t1_v4 <- as.vector(vcv[5+7,5+7])
      v_t1_v5 <- as.vector(vcv[6+7,6+7])
      v_t1_v6 <- as.vector(vcv[7+7,7+7])}
      
      v <- as.vector(c(v_t1, v_t1_v1, v_t1_v2, v_t1_v3, v_t1_v4, v_t1_v5, v_t1_v6))
      rm(v_t1, v_t1_v1, v_t1_v2, v_t1_v3, v_t1_v4, v_t1_v5, v_t1_v6)
      
      {cov_t1_t1v1 <- as.vector(vcv[2+7,1+7])
        cov_t1_t1v2 <- as.vector(vcv[3+7,1+7])
        cov_t1_t1v3 <- as.vector(vcv[4+7,1+7])
        cov_t1_t1v4 <- as.vector(vcv[5+7,1+7])
        cov_t1_t1v5 <- as.vector(vcv[6+7,1+7])
        cov_t1_t1v6 <- as.vector(vcv[7+7,1+7])}
      
      c <- as.vector(c(cov_t1_t1v1, cov_t1_t1v2, cov_t1_t1v3, cov_t1_t1v4,cov_t1_t1v5,cov_t1_t1v6))
      rm(cov_t1_t1v1, cov_t1_t1v2, cov_t1_t1v3, cov_t1_t1v4,cov_t1_t1v5,cov_t1_t1v6)
      
      {cov_t1v1_t1v2 <- as.vector(vcv[3+7,2+7])
        cov_t1v1_t1v3 <- as.vector(vcv[4+7,2+7])
        cov_t1v1_t1v4 <- as.vector(vcv[5+7,2+7])
        cov_t1v1_t1v5 <- as.vector(vcv[6+7,2+7])
        cov_t1v1_t1v6 <- as.vector(vcv[7+7,2+7])}
      
      c <- as.vector(c(c, cov_t1v1_t1v2, cov_t1v1_t1v3, cov_t1v1_t1v4, cov_t1v1_t1v5,cov_t1v1_t1v6))
      rm(cov_t0v1_t1v2, cov_t1v1_t1v3, cov_t1v1_t1v4,cov_t1v1_t1v5,cov_t1v1_t1v6)
      
      {cov_t1v2_t1v3 <- as.vector(vcv[4+7,3+7])
        cov_t1v2_t1v4 <- as.vector(vcv[5+7,3+7])
        cov_t1v2_t1v5 <- as.vector(vcv[6+7,3+7])
        cov_t1v2_t1v6 <- as.vector(vcv[7+7,3+7])}
      
      c <- as.vector(c(c, cov_t1v2_t1v3, cov_t1v2_t1v4, cov_t1v2_t1v5,cov_t1v2_t1v6))
      rm( cov_t1v2_t1v3, cov_t1v2_t1v4,cov_t1v2_t1v5,cov_t1v2_t1v6)
      
      {cov_t1v3_t1v4 <- as.vector(vcv[5+7,4+7])
        cov_t1v3_t1v5 <- as.vector(vcv[6+7,4+7])
        cov_t1v3_t1v6 <- as.vector(vcv[7+7,4+7])}
      
      c <- as.vector(c(c,  cov_t1v3_t1v4, cov_t1v3_t1v5,cov_t1v3_t1v6))
      rm( cov_t1v3_t1v4,cov_t1v3_t1v5,cov_t1v3_t1v6)
      
      {cov_t1v4_t1v5 <- as.vector(vcv[6+7,5+7])
        cov_t1v4_t1v6 <- as.vector(vcv[7+7,5+7])}
      
      c <- as.vector(c(c, cov_t1v4_t1v5,cov_t1v4_t1v6))
      rm(cov_t1v4_t1v5,cov_t1v4_t1v6)
      
      cov_t1v5_t1v6 <- as.vector(vcv[7+7,6+7])
      
      c <- as.vector(c(c,cov_t1v5_t1v6))
      rm(cov_t1v5_t1v6)
      
      v_ts_lr <- v
      c_ts_lr <- c }
    V_LR_TS <- sum(v_ts_lr) + 2*sum(c_ts_lr)
    
    #Varience HR Linear
    {#High Linear
      
      {v_t0    <- as.vector(vcv[1+14,1+14])
      v_t0_v1 <- as.vector(vcv[2+14,2+14])
      v_t0_v2 <- as.vector(vcv[3+14,3+14])
      v_t0_v3 <- as.vector(vcv[4+14,4+14])
      v_t0_v4 <- as.vector(vcv[5+14,5+14])
      v_t0_v5 <- as.vector(vcv[6+14,6+14])
      v_t0_v6 <- as.vector(vcv[7+14,7+14])}
      
      v <- as.vector(c(v_t0, v_t0_v1, v_t0_v2, v_t0_v3, v_t0_v4, v_t0_v5, v_t0_v6))
      rm(v_t0, v_t0_v1, v_t0_v2, v_t0_v3, v_t0_v4, v_t0_v5, v_t0_v6)
      
      {cov_t0_t0v1 <- as.vector(vcv[2+14,1+14])
        cov_t0_t0v2 <- as.vector(vcv[3+14,1+14])
        cov_t0_t0v3 <- as.vector(vcv[4+14,1+14])
        cov_t0_t0v4 <- as.vector(vcv[5+14,1+14])
        cov_t0_t0v5 <- as.vector(vcv[6+14,1+14])
        cov_t0_t0v6 <- as.vector(vcv[7+14,1+14])}
      
      c <- as.vector(c(cov_t0_t0v1, cov_t0_t0v2, cov_t0_t0v3, cov_t0_t0v4,cov_t0_t0v5,cov_t0_t0v6))
      rm(cov_t0_t0v1, cov_t0_t0v2, cov_t0_t0v3, cov_t0_t0v4,cov_t0_t0v5,cov_t0_t0v6)
      
      {cov_t0v1_t0v2 <- as.vector(vcv[3+14,2+14])
        cov_t0v1_t0v3 <- as.vector(vcv[4+14,2+14])
        cov_t0v1_t0v4 <- as.vector(vcv[5+14,2+14])
        cov_t0v1_t0v5 <- as.vector(vcv[6+14,2+14])
        cov_t0v1_t0v6 <- as.vector(vcv[7+14,2+14])}
      
      c <- as.vector(c(c, cov_t0v1_t0v2, cov_t0v1_t0v3, cov_t0v1_t0v4,cov_t0v1_t0v5,cov_t0v1_t0v6))
      rm(cov_t0v1_t0v2, cov_t0v1_t0v3, cov_t0v1_t0v4,cov_t0v1_t0v5,cov_t0v1_t0v6)
      
      {cov_t0v2_t0v3 <- as.vector(vcv[4+14,3+14])
        cov_t0v2_t0v4 <- as.vector(vcv[5+14,3+14])
        cov_t0v2_t0v5 <- as.vector(vcv[6+14,3+14])
        cov_t0v2_t0v6 <- as.vector(vcv[7+14,3+14])}
      
      c <- as.vector(c(c, cov_t0v2_t0v3, cov_t0v2_t0v4,cov_t0v2_t0v5,cov_t0v2_t0v6))
      rm(cov_t0v2_t0v3, cov_t0v2_t0v4,cov_t0v2_t0v5,cov_t0v2_t0v6)
      
      {cov_t0v3_t0v4 <- as.vector(vcv[5+14,4+14])
        cov_t0v3_t0v5 <- as.vector(vcv[6+14,4+14])
        cov_t0v3_t0v6 <- as.vector(vcv[7+14,4+14])}
      
      c <- as.vector(c(c,  cov_t0v3_t0v4,cov_t0v3_t0v5,cov_t0v3_t0v6))
      rm(cov_t0v3_t0v4,cov_t0v3_t0v5,cov_t0v3_t0v6)
      
      {cov_t0v4_t0v5 <- as.vector(vcv[6+14,5+14])
        cov_t0v4_t0v6 <- as.vector(vcv[7+14,5+14])}
      
      c <- as.vector(c(c,cov_t0v4_t0v5,cov_t0v4_t0v6))
      rm(cov_t0v4_t0v5,cov_t0v4_t0v6)
      
      {cov_t0v5_t0v6 <- as.vector(vcv[7+14,6+14])
      }
      
      c <- as.vector(c(c,cov_t0v5_t0v6))
      rm(cov_t0v5_t0v6)
      
      v_t_hr_alone <- v
      c_t_hr_alone <- c }
    V_HR_T <- sum(v_t_hr_alone) + 2*sum(c_t_hr_alone) 
    
    #Varience HR Linear Interacted
    {#High Linear
      
      {v_t0    <- as.vector(vcv[1+21,1+21])
      v_t0_v1 <- as.vector(vcv[2+21,2+21])
      v_t0_v2 <- as.vector(vcv[3+21,3+21])
      v_t0_v3 <- as.vector(vcv[4+21,4+21])
      v_t0_v4 <- as.vector(vcv[5+21,5+21])
      v_t0_v5 <- as.vector(vcv[6+21,6+21])
      v_t0_v6 <- as.vector(vcv[7+21,7+21])}
      
      v <- as.vector(c(v_t0, v_t0_v1, v_t0_v2, v_t0_v3, v_t0_v4, v_t0_v5, v_t0_v6))
      rm(v_t0, v_t0_v1, v_t0_v2, v_t0_v3, v_t0_v4, v_t0_v5, v_t0_v6)
      
      {cov_t0_t0v1 <- as.vector(vcv[2+21,1+21])
        cov_t0_t0v2 <- as.vector(vcv[3+21,1+21])
        cov_t0_t0v3 <- as.vector(vcv[4+21,1+21])
        cov_t0_t0v4 <- as.vector(vcv[5+21,1+21])
        cov_t0_t0v5 <- as.vector(vcv[6+21,1+21])
        cov_t0_t0v6 <- as.vector(vcv[7+21,1+21])}
      
      c <- as.vector(c(cov_t0_t0v1, cov_t0_t0v2, cov_t0_t0v3, cov_t0_t0v4,cov_t0_t0v5,cov_t0_t0v6))
      rm(cov_t0_t0v1, cov_t0_t0v2, cov_t0_t0v3, cov_t0_t0v4,cov_t0_t0v5,cov_t0_t0v6)
      
      {cov_t0v1_t0v2 <- as.vector(vcv[3+21,2+21])
        cov_t0v1_t0v3 <- as.vector(vcv[4+21,2+21])
        cov_t0v1_t0v4 <- as.vector(vcv[5+21,2+21])
        cov_t0v1_t0v5 <- as.vector(vcv[6+21,2+21])
        cov_t0v1_t0v6 <- as.vector(vcv[7+21,2+21])}
      
      c <- as.vector(c(c, cov_t0v1_t0v2, cov_t0v1_t0v3, cov_t0v1_t0v4,cov_t0v1_t0v5,cov_t0v1_t0v6))
      rm(cov_t0v1_t0v2, cov_t0v1_t0v3, cov_t0v1_t0v4,cov_t0v1_t0v5,cov_t0v1_t0v6)
      
      {cov_t0v2_t0v3 <- as.vector(vcv[4+21,3+21])
        cov_t0v2_t0v4 <- as.vector(vcv[5+21,3+21])
        cov_t0v2_t0v5 <- as.vector(vcv[6+21,3+21])
        cov_t0v2_t0v6 <- as.vector(vcv[7+21,3+21])}
      
      c <- as.vector(c(c, cov_t0v2_t0v3, cov_t0v2_t0v4,cov_t0v2_t0v5,cov_t0v2_t0v6))
      rm(cov_t0v2_t0v3, cov_t0v2_t0v4,cov_t0v2_t0v5,cov_t0v2_t0v6)
      
      {cov_t0v3_t0v4 <- as.vector(vcv[5+21,4+21])
        cov_t0v3_t0v5 <- as.vector(vcv[6+21,4+21])
        cov_t0v3_t0v6 <- as.vector(vcv[7+21,4+21])}
      
      c <- as.vector(c(c,  cov_t0v3_t0v4,cov_t0v3_t0v5,cov_t0v3_t0v6))
      rm(cov_t0v3_t0v4,cov_t0v3_t0v5,cov_t0v3_t0v6)
      
      {cov_t0v4_t0v5 <- as.vector(vcv[6+21,5+21])
        cov_t0v4_t0v6 <- as.vector(vcv[7+21,5+21])}
      
      c <- as.vector(c(c,cov_t0v4_t0v5,cov_t0v4_t0v6))
      rm(cov_t0v4_t0v5,cov_t0v4_t0v6)
      
      {cov_t0v5_t0v6 <- as.vector(vcv[7+21,6+21])
      }
      
      c <- as.vector(c(c,cov_t0v5_t0v6))
      rm(cov_t0v5_t0v6)
      
      v_t_hr_alone_g <- v
      c_t_hr_alone_g <- c }
    V_HR_T_G <- sum(v_t_hr_alone_g) + 2*sum(c_t_hr_alone_g)
    
    
    #Varience HR Spline
    {#High Spline
      {v_t1    <- as.vector(vcv[1+28,1+28])
      v_t1_v1 <- as.vector(vcv[2+28,2+28])
      v_t1_v2 <- as.vector(vcv[3+28,3+28])
      v_t1_v3 <- as.vector(vcv[4+28,4+28])
      v_t1_v4 <- as.vector(vcv[5+28,5+28])
      v_t1_v5 <- as.vector(vcv[6+28,6+28])
      v_t1_v6 <- as.vector(vcv[7+28,7+28])}
      
      v <- as.vector(c(v_t1, v_t1_v1, v_t1_v2, v_t1_v3, v_t1_v4, v_t1_v5, v_t1_v6))
      rm(v_t1, v_t1_v1, v_t1_v2, v_t1_v3, v_t1_v4, v_t1_v5, v_t1_v6)
      
      {cov_t1_t1v1 <- as.vector(vcv[2+28,1+28])
        cov_t1_t1v2 <- as.vector(vcv[3+28,1+28])
        cov_t1_t1v3 <- as.vector(vcv[4+28,1+28])
        cov_t1_t1v4 <- as.vector(vcv[5+28,1+28])
        cov_t1_t1v5 <- as.vector(vcv[6+28,1+28])
        cov_t1_t1v6 <- as.vector(vcv[7+28,1+28])}
      
      c <- as.vector(c(cov_t1_t1v1, cov_t1_t1v2, cov_t1_t1v3, cov_t1_t1v4,cov_t1_t1v5,cov_t1_t1v6))
      rm(cov_t1_t1v1, cov_t1_t1v2, cov_t1_t1v3, cov_t1_t1v4,cov_t1_t1v5,cov_t1_t1v6)
      
      {cov_t1v1_t1v2 <- as.vector(vcv[3+28,2+28])
        cov_t1v1_t1v3 <- as.vector(vcv[4+28,2+28])
        cov_t1v1_t1v4 <- as.vector(vcv[5+28,2+28])
        cov_t1v1_t1v5 <- as.vector(vcv[6+28,2+28])
        cov_t1v1_t1v6 <- as.vector(vcv[7+28,2+28])}
      
      c <- as.vector(c(c, cov_t1v1_t1v2, cov_t1v1_t1v3, cov_t1v1_t1v4, cov_t1v1_t1v5,cov_t1v1_t1v6))
      rm(cov_t0v1_t1v2, cov_t1v1_t1v3, cov_t1v1_t1v4,cov_t1v1_t1v5,cov_t1v1_t1v6)
      
      {cov_t1v2_t1v3 <- as.vector(vcv[4+28,3+28])
        cov_t1v2_t1v4 <- as.vector(vcv[5+28,3+28])
        cov_t1v2_t1v5 <- as.vector(vcv[6+28,3+28])
        cov_t1v2_t1v6 <- as.vector(vcv[7+28,3+28])}
      
      c <- as.vector(c(c, cov_t1v2_t1v3, cov_t1v2_t1v4, cov_t1v2_t1v5,cov_t1v2_t1v6))
      rm( cov_t1v2_t1v3, cov_t1v2_t1v4,cov_t1v2_t1v5,cov_t1v2_t1v6)
      
      {cov_t1v3_t1v4 <- as.vector(vcv[5+28,4+28])
        cov_t1v3_t1v5 <- as.vector(vcv[6+28,4+28])
        cov_t1v3_t1v6 <- as.vector(vcv[7+28,4+28])}
      
      c <- as.vector(c(c,  cov_t1v3_t1v4, cov_t1v3_t1v5,cov_t1v3_t1v6))
      rm( cov_t1v3_t1v4,cov_t1v3_t1v5,cov_t1v3_t1v6)
      
      {cov_t1v4_t1v5 <- as.vector(vcv[6+28,5+28])
        cov_t1v4_t1v6 <- as.vector(vcv[7+28,5+28])}
      
      c <- as.vector(c(c, cov_t1v4_t1v5,cov_t1v4_t1v6))
      rm(cov_t1v4_t1v5,cov_t1v4_t1v6)
      
      {cov_t1v5_t1v6 <- as.vector(vcv[7+28,6+28])
      }
      
      c <- as.vector(c(c,cov_t1v5_t1v6))
      rm(cov_t1v5_t1v6)
      
      v_ts_hr_alone <- v
      c_ts_hr_alone <- c} 
    V_HR_TS <- sum(v_ts_hr_alone) + 2*sum(c_ts_hr_alone) 
    
    #Varience HR Spline Interacted
    {#High Spline
      {v_t1    <- as.vector(vcv[1+35,1+35])
      v_t1_v1 <- as.vector(vcv[2+35,2+35])
      v_t1_v2 <- as.vector(vcv[3+35,3+35])
      v_t1_v3 <- as.vector(vcv[4+35,4+35])
      v_t1_v4 <- as.vector(vcv[5+35,5+35])
      v_t1_v5 <- as.vector(vcv[6+35,6+35])
      v_t1_v6 <- as.vector(vcv[7+35,7+35])}
      
      v <- as.vector(c(v_t1, v_t1_v1, v_t1_v2, v_t1_v3, v_t1_v4, v_t1_v5, v_t1_v6))
      rm(v_t1, v_t1_v1, v_t1_v2, v_t1_v3, v_t1_v4, v_t1_v5, v_t1_v6)
      
      {cov_t1_t1v1 <- as.vector(vcv[2+35,1+35])
        cov_t1_t1v2 <- as.vector(vcv[3+35,1+35])
        cov_t1_t1v3 <- as.vector(vcv[4+35,1+35])
        cov_t1_t1v4 <- as.vector(vcv[5+35,1+35])
        cov_t1_t1v5 <- as.vector(vcv[6+35,1+35])
        cov_t1_t1v6 <- as.vector(vcv[7+35,1+35])}
      
      c <- as.vector(c(cov_t1_t1v1, cov_t1_t1v2, cov_t1_t1v3, cov_t1_t1v4,cov_t1_t1v5,cov_t1_t1v6))
      rm(cov_t1_t1v1, cov_t1_t1v2, cov_t1_t1v3, cov_t1_t1v4,cov_t1_t1v5,cov_t1_t1v6)
      
      {cov_t1v1_t1v2 <- as.vector(vcv[3+35,2+35])
        cov_t1v1_t1v3 <- as.vector(vcv[4+35,2+35])
        cov_t1v1_t1v4 <- as.vector(vcv[5+35,2+35])
        cov_t1v1_t1v5 <- as.vector(vcv[6+35,2+35])
        cov_t1v1_t1v6 <- as.vector(vcv[7+35,2+35])}
      
      c <- as.vector(c(c, cov_t1v1_t1v2, cov_t1v1_t1v3, cov_t1v1_t1v4, cov_t1v1_t1v5,cov_t1v1_t1v6))
      rm(cov_t0v1_t1v2, cov_t1v1_t1v3, cov_t1v1_t1v4,cov_t1v1_t1v5,cov_t1v1_t1v6)
      
      {cov_t1v2_t1v3 <- as.vector(vcv[4+35,3+35])
        cov_t1v2_t1v4 <- as.vector(vcv[5+35,3+35])
        cov_t1v2_t1v5 <- as.vector(vcv[6+35,3+35])
        cov_t1v2_t1v6 <- as.vector(vcv[7+35,3+35])}
      
      c <- as.vector(c(c, cov_t1v2_t1v3, cov_t1v2_t1v4, cov_t1v2_t1v5,cov_t1v2_t1v6))
      rm( cov_t1v2_t1v3, cov_t1v2_t1v4,cov_t1v2_t1v5,cov_t1v2_t1v6)
      
      {cov_t1v3_t1v4 <- as.vector(vcv[5+35,4+35])
        cov_t1v3_t1v5 <- as.vector(vcv[6+35,4+35])
        cov_t1v3_t1v6 <- as.vector(vcv[7+35,4+35])}
      
      c <- as.vector(c(c,  cov_t1v3_t1v4, cov_t1v3_t1v5,cov_t1v3_t1v6))
      rm( cov_t1v3_t1v4,cov_t1v3_t1v5,cov_t1v3_t1v6)
      
      {cov_t1v4_t1v5 <- as.vector(vcv[6+35,5+35])
        cov_t1v4_t1v6 <- as.vector(vcv[7+35,5+35])}
      
      c <- as.vector(c(c, cov_t1v4_t1v5,cov_t1v4_t1v6))
      rm(cov_t1v4_t1v5,cov_t1v4_t1v6)
      
      {cov_t1v5_t1v6 <- as.vector(vcv[7+35,6+35])
      }
      
      c <- as.vector(c(c,cov_t1v5_t1v6))
      rm(cov_t1v5_t1v6)
      
      v_ts_hr_alone_g <- v
      c_ts_hr_alone_g <- c} 
    V_HR_TS_G <- sum(v_ts_hr_alone_g) + 2*sum(c_ts_hr_alone_g)
    
    #Cov LR_T and LR_TS
    {#t0 
      {c_t0_t1   <- as.vector(vcv[1,1+7])
      c_t0_t1v1 <- as.vector(vcv[1,2+7])
      c_t0_t1v2 <- as.vector(vcv[1,3+7])
      c_t0_t1v3 <- as.vector(vcv[1,4+7])
      c_t0_t1v4 <- as.vector(vcv[1,5+7])
      c_t0_t1v5 <- as.vector(vcv[1,6+7])
      c_t0_t1v6 <- as.vector(vcv[1,7+7])}
      
      c_t0 <- as.vector(c(c_t0_t1,c_t0_t1v1,c_t0_t1v2,c_t0_t1v3,c_t0_t1v4,c_t0_t1v5,c_t0_t1v6))
      rm(c_t0_t1,c_t0_t1v1,c_t0_t1v2,c_t0_t1v3,c_t0_t1v4,c_t0_t1v5,c_t0_t1v6)
      
      #t0_v1
      {c_t0v1_t1   <- as.vector(vcv[2,1+7])
        c_t0v1_t1v1 <- as.vector(vcv[2,2+7])
        c_t0v1_t1v2 <- as.vector(vcv[2,3+7])
        c_t0v1_t1v3 <- as.vector(vcv[2,4+7])
        c_t0v1_t1v4 <- as.vector(vcv[2,5+7])
        c_t0v1_t1v5 <- as.vector(vcv[2,6+7])
        c_t0v1_t1v6 <- as.vector(vcv[2,7+7])}
      
      c_t0v1 <- as.vector(c(c_t0v1_t1, c_t0v1_t1v1, c_t0v1_t1v2, c_t0v1_t1v3, c_t0v1_t1v4, c_t0v1_t1v5, c_t0v1_t1v6))
      rm(c_t0v1_t1, c_t0v1_t1v1, c_t0v1_t1v2, c_t0v1_t1v3, c_t0v1_t1v4, c_t0v1_t1v5, c_t0v1_t1v6)
      
      #t0_v2
      {c_t0v2_t1   <- as.vector(vcv[3,1+7])
        c_t0v2_t1v1 <- as.vector(vcv[3,2+7])
        c_t0v2_t1v2 <- as.vector(vcv[3,3+7])
        c_t0v2_t1v3 <- as.vector(vcv[3,4+7])
        c_t0v2_t1v4 <- as.vector(vcv[3,5+7])
        c_t0v2_t1v5 <- as.vector(vcv[3,6+7])
        c_t0v2_t1v6 <- as.vector(vcv[3,7+7])}
      
      c_t0v2 <- as.vector(c(c_t0v2_t1,c_t0v2_t1v1, c_t0v2_t1v2, c_t0v2_t1v3, c_t0v2_t1v4, c_t0v2_t1v5, c_t0v2_t1v6))
      rm(c_t0v2_t1,c_t0v2_t1v1, c_t0v2_t1v2, c_t0v2_t1v3, c_t0v2_t1v4, c_t0v2_t1v5, c_t0v2_t1v6)
      
      #t0_v3
      {c_t0v3_t1   <- as.vector(vcv[4,1+7])
        c_t0v3_t1v1 <- as.vector(vcv[4,2+7])
        c_t0v3_t1v2 <- as.vector(vcv[4,3+7])
        c_t0v3_t1v3 <- as.vector(vcv[4,4+7])
        c_t0v3_t1v4 <- as.vector(vcv[4,5+7])
        c_t0v3_t1v5 <- as.vector(vcv[4,6+7])
        c_t0v3_t1v6 <- as.vector(vcv[4,7+7])}
      
      c_t0v3 <- as.vector(c(c_t0v3_t1,c_t0v3_t1v1, c_t0v3_t1v2, c_t0v3_t1v3, c_t0v3_t1v4, c_t0v3_t1v5, c_t0v3_t1v6))
      rm(c_t0v3_t1,c_t0v3_t1v1, c_t0v3_t1v2, c_t0v3_t1v3, c_t0v3_t1v4, c_t0v3_t1v5, c_t0v3_t1v6)
      
      #t0_v4
      {c_t0v4_t1   <- as.vector(vcv[5,1+7])
        c_t0v4_t1v1 <- as.vector(vcv[5,2+7])
        c_t0v4_t1v2 <- as.vector(vcv[5,3+7])
        c_t0v4_t1v3 <- as.vector(vcv[5,4+7])
        c_t0v4_t1v4 <- as.vector(vcv[5,5+7])
        c_t0v4_t1v5 <- as.vector(vcv[5,6+7])
        c_t0v4_t1v6 <- as.vector(vcv[5,7+7])}
      
      c_t0v4 <- as.vector(c(c_t0v4_t1,c_t0v4_t1v1, c_t0v4_t1v2, c_t0v4_t1v3, c_t0v4_t1v4, c_t0v4_t1v5, c_t0v4_t1v6))
      rm(c_t0v4_t1,c_t0v4_t1v1, c_t0v4_t1v2, c_t0v4_t1v3, c_t0v4_t1v4, c_t0v4_t1v5, c_t0v4_t1v6)
      
      #t0_v5
      {c_t0v5_t1   <- as.vector(vcv[6,1+7])
        c_t0v5_t1v1 <- as.vector(vcv[6,2+7])
        c_t0v5_t1v2 <- as.vector(vcv[6,3+7])
        c_t0v5_t1v3 <- as.vector(vcv[6,4+7])
        c_t0v5_t1v4 <- as.vector(vcv[6,5+7])
        c_t0v5_t1v5 <- as.vector(vcv[6,6+7])
        c_t0v5_t1v6 <- as.vector(vcv[6,7+7])}
      
      c_t0v5 <- as.vector(c(c_t0v5_t1,c_t0v5_t1v1, c_t0v5_t1v2, c_t0v5_t1v3, c_t0v5_t1v4, c_t0v5_t1v5, c_t0v5_t1v6))
      rm(c_t0v5_t1,c_t0v5_t1v1, c_t0v5_t1v2, c_t0v5_t1v3, c_t0v5_t1v4, c_t0v5_t1v5, c_t0v5_t1v6)
      
      #t0_v6
      {c_t0v6_t1   <- as.vector(vcv[7,1+7])
        c_t0v6_t1v1 <- as.vector(vcv[7,2+7])
        c_t0v6_t1v2 <- as.vector(vcv[7,3+7])
        c_t0v6_t1v3 <- as.vector(vcv[7,4+7])
        c_t0v6_t1v4 <- as.vector(vcv[7,5+7])
        c_t0v6_t1v5 <- as.vector(vcv[7,6+7])
        c_t0v6_t1v6 <- as.vector(vcv[7,7+7])}
      
      c_t0v6 <- as.vector(c(c_t0v6_t1,c_t0v6_t1v1, c_t0v6_t1v2, c_t0v6_t1v3, c_t0v6_t1v4, c_t0v6_t1v5, c_t0v6_t1v6))
      rm(c_t0v6_t1,c_t0v6_t1v1, c_t0v6_t1v2, c_t0v6_t1v3, c_t0v6_t1v4, c_t0v6_t1v5, c_t0v6_t1v6)}
    C_LR_T_LR_TS <- sum(c_t0) + sum(c_t0v1) + sum(c_t0v2) + sum(c_t0v3) + sum(c_t0v4) + sum(c_t0v5) + sum(c_t0v6)
    rm(c_t0,c_t0v1,c_t0v2,c_t0v3,c_t0v4,c_t0v5,c_t0v6)
    
    {#misc cleanup
      rm(c_lrv4_hr,c_lrv4_hrv1,c_lrv4_hrv2,c_lrv4_hrv3,c_lrv4_hrv4,c_lrv4_hrv5,c_lrv4_hrv6)
      rm(c_lrv5, c_lrv6)}
    
    #Cov Linear LR / Linear HR
    {#t0 
      {c_lr_hr   <- as.vector(vcv[1,1+14])
      c_lr_hrv1 <- as.vector(vcv[1,2+14])
      c_lr_hrv2 <- as.vector(vcv[1,3+14])
      c_lr_hrv3 <- as.vector(vcv[1,4+14])
      c_lr_hrv4 <- as.vector(vcv[1,5+14])
      c_lr_hrv5 <- as.vector(vcv[1,6+14])
      c_lr_hrv6 <- as.vector(vcv[1,7+14])}
      
      c_lr <- as.vector(c(c_lr_hr,c_lr_hrv1,c_lr_hrv2,c_lr_hrv3,c_lr_hrv4,c_lr_hrv5,c_lr_hrv6))
      rm(c_lr_hr,c_lr_hrv1,c_lr_hrv2,c_lr_hrv3,c_lr_hrv4,c_lr_hrv5,c_lr_hrv6)
      #t0_v1
      {c_lrv1_hr   <- as.vector(vcv[2,1+14])
        c_lrv1_hrv1 <- as.vector(vcv[2,2+14])
        c_lrv1_hrv2 <- as.vector(vcv[2,3+14])
        c_lrv1_hrv3 <- as.vector(vcv[2,4+14])
        c_lrv1_hrv4 <- as.vector(vcv[2,5+14])
        c_lrv1_hrv5 <- as.vector(vcv[2,6+14])
        c_lrv1_hrv6 <- as.vector(vcv[2,7+14])}
      
      c_lrv1 <- as.vector(c(c_lrv1_hr, c_lrv1_hrv1, c_lrv1_hrv2, c_lrv1_hrv3, c_lrv1_hrv4, c_lrv1_hrv5, c_lrv1_hrv6))
      rm(c_lrv1_hr, c_lrv1_hrv1, c_lrv1_hrv2, c_lrv1_hrv3, c_lrv1_hrv4, c_lrv1_hrv5, c_lrv1_hrv6)
      
      #t0_v2
      {c_lrv2_hr   <- as.vector(vcv[3,1+14])
        c_lrv2_hrv1 <- as.vector(vcv[3,2+14])
        c_lrv2_hrv2 <- as.vector(vcv[3,3+14])
        c_lrv2_hrv3 <- as.vector(vcv[3,4+14])
        c_lrv2_hrv4 <- as.vector(vcv[3,5+14])
        c_lrv2_hrv5 <- as.vector(vcv[3,6+14])
        c_lrv2_hrv6 <- as.vector(vcv[3,7+14])}
      
      c_lrv2 <- as.vector(c(c_lrv2_hr,c_lrv2_hrv1, c_lrv2_hrv2, c_lrv2_hrv3, c_lrv2_hrv4, c_lrv2_hrv5, c_lrv2_hrv6))
      rm(c_lrv2_hr,c_lrv2_hrv1, c_lrv2_hrv2, c_lrv2_hrv3, c_lrv2_hrv4, c_lrv2_hrv5, c_lrv2_hrv6)
      
      #t0_v3
      {c_lrv3_hr   <- as.vector(vcv[4,1+14])
        c_lrv3_hrv1 <- as.vector(vcv[4,2+14])
        c_lrv3_hrv2 <- as.vector(vcv[4,3+14])
        c_lrv3_hrv3 <- as.vector(vcv[4,4+14])
        c_lrv3_hrv4 <- as.vector(vcv[4,5+14])
        c_lrv3_hrv5 <- as.vector(vcv[4,6+14])
        c_lrv3_hrv6 <- as.vector(vcv[4,7+14])}
      
      c_lrv3 <- as.vector(c(c_lrv3_hr,c_lrv3_hrv1, c_lrv3_hrv2, c_lrv3_hrv3, c_lrv3_hrv4, c_lrv3_hrv5, c_lrv3_hrv6))
      rm(c_lrv3_hr,c_lrv3_hrv1, c_lrv3_hrv2, c_lrv3_hrv3, c_lrv3_hrv4, c_lrv3_hrv5, c_lrv3_hrv6)
      
      #t0_v4
      {c_lrv4_hr   <- as.vector(vcv[5,1+14])
        c_lrv4_hrv1 <- as.vector(vcv[5,2+14])
        c_lrv4_hrv2 <- as.vector(vcv[5,3+14])
        c_lrv4_hrv3 <- as.vector(vcv[5,4+14])
        c_lrv4_hrv4 <- as.vector(vcv[5,5+14])
        c_lrv4_hrv5 <- as.vector(vcv[5,6+14])
        c_lrv4_hrv6 <- as.vector(vcv[5,7+14])}
      
      c_lrv4 <- as.vector(c(c_lrv4_hr,c_lrv4_hrv1, c_lrv4_hrv2, c_lrv4_hrv3, c_lrv4_hrv4, c_lrv4_hrv5, c_lrv4_hrv6))
      rm(c_lrv4_hr,c_lrv4_hrv1, c_lrv4_hrv2, c_lrv4_hrv3, c_lrv4_hrv4, c_lrv4_hrv5, c_lrv4_hrv6)
      
      #t0_v5
      {c_lrv5_hr   <- as.vector(vcv[6,1+14])
        c_lrv5_hrv1 <- as.vector(vcv[6,2+14])
        c_lrv5_hrv2 <- as.vector(vcv[6,3+14])
        c_lrv5_hrv3 <- as.vector(vcv[6,4+14])
        c_lrv5_hrv4 <- as.vector(vcv[6,5+14])
        c_lrv5_hrv5 <- as.vector(vcv[6,6+14])
        c_lrv5_hrv6 <- as.vector(vcv[6,7+14])}
      
      c_lrv5 <- as.vector(c(c_lrv5_hr,c_lrv5_hrv1, c_lrv5_hrv2, c_lrv5_hrv3, c_lrv5_hrv4, c_lrv5_hrv5, c_lrv5_hrv6))
      rm(c_lrv5_hr,c_lrv5_hrv1, c_lrv5_hrv2, c_lrv5_hrv3, c_lrv5_hrv4, c_lrv5_hrv5, c_lrv5_hrv6)
      
      #t0_v6
      {c_lrv6_hr   <- as.vector(vcv[7,1+14])
        c_lrv6_hrv1 <- as.vector(vcv[7,2+14])
        c_lrv6_hrv2 <- as.vector(vcv[7,3+14])
        c_lrv6_hrv3 <- as.vector(vcv[7,4+14])
        c_lrv6_hrv4 <- as.vector(vcv[7,5+14])
        c_lrv6_hrv5 <- as.vector(vcv[7,6+14])
        c_lrv6_hrv6 <- as.vector(vcv[7,7+14])}
      
      c_lrv6 <- as.vector(c(c_lrv6_hr,c_lrv6_hrv1, c_lrv6_hrv2, c_lrv6_hrv3, c_lrv6_hrv4, c_lrv6_hrv5, c_lrv6_hrv6))
      rm(c_lrv6_hr,c_lrv6_hrv1, c_lrv6_hrv2, c_lrv6_hrv3, c_lrv6_hrv4, c_lrv6_hrv5, c_lrv6_hrv6)}
    C_LR_T_HR_T <- sum(c_lr) + sum(c_lrv1) + sum(c_lrv2) + sum(c_lrv3) + sum(c_lrv4) + sum(c_lrv5) + sum(c_lrv6)
    rm(c_lr,c_lrv1,c_lrv2,c_lrv3,c_lrv4,c_lrv5,c_lrv6) 
    
    #Cov Linear LR / Linear HR Interacted
    {#t0 
      {c_lr_hr   <- as.vector(vcv[1,1+21])
      c_lr_hrv1 <- as.vector(vcv[1,2+21])
      c_lr_hrv2 <- as.vector(vcv[1,3+21])
      c_lr_hrv3 <- as.vector(vcv[1,4+21])
      c_lr_hrv4 <- as.vector(vcv[1,5+21])
      c_lr_hrv5 <- as.vector(vcv[1,6+21])
      c_lr_hrv6 <- as.vector(vcv[1,7+21])}
      
      c_lr <- as.vector(c(c_lr_hr,c_lr_hrv1,c_lr_hrv2,c_lr_hrv3,c_lr_hrv4,c_lr_hrv5,c_lr_hrv6))
      rm(c_lr_hr,c_lr_hrv1,c_lr_hrv2,c_lr_hrv3,c_lr_hrv4,c_lr_hrv5,c_lr_hrv6)
      #t0_v1
      {c_lrv1_hr   <- as.vector(vcv[2,1+21])
        c_lrv1_hrv1 <- as.vector(vcv[2,2+21])
        c_lrv1_hrv2 <- as.vector(vcv[2,3+21])
        c_lrv1_hrv3 <- as.vector(vcv[2,4+21])
        c_lrv1_hrv4 <- as.vector(vcv[2,5+21])
        c_lrv1_hrv5 <- as.vector(vcv[2,6+21])
        c_lrv1_hrv6 <- as.vector(vcv[2,7+21])}
      
      c_lrv1 <- as.vector(c(c_lrv1_hr, c_lrv1_hrv1, c_lrv1_hrv2, c_lrv1_hrv3, c_lrv1_hrv4, c_lrv1_hrv5, c_lrv1_hrv6))
      rm(c_lrv1_hr, c_lrv1_hrv1, c_lrv1_hrv2, c_lrv1_hrv3, c_lrv1_hrv4, c_lrv1_hrv5, c_lrv1_hrv6)
      
      #t0_v2
      {c_lrv2_hr   <- as.vector(vcv[3,1+21])
        c_lrv2_hrv1 <- as.vector(vcv[3,2+21])
        c_lrv2_hrv2 <- as.vector(vcv[3,3+21])
        c_lrv2_hrv3 <- as.vector(vcv[3,4+21])
        c_lrv2_hrv4 <- as.vector(vcv[3,5+21])
        c_lrv2_hrv5 <- as.vector(vcv[3,6+21])
        c_lrv2_hrv6 <- as.vector(vcv[3,7+21])}
      
      c_lrv2 <- as.vector(c(c_lrv2_hr,c_lrv2_hrv1, c_lrv2_hrv2, c_lrv2_hrv3, c_lrv2_hrv4, c_lrv2_hrv5, c_lrv2_hrv6))
      rm(c_lrv2_hr,c_lrv2_hrv1, c_lrv2_hrv2, c_lrv2_hrv3, c_lrv2_hrv4, c_lrv2_hrv5, c_lrv2_hrv6)
      
      #t0_v3
      {c_lrv3_hr   <- as.vector(vcv[4,1+21])
        c_lrv3_hrv1 <- as.vector(vcv[4,2+21])
        c_lrv3_hrv2 <- as.vector(vcv[4,3+21])
        c_lrv3_hrv3 <- as.vector(vcv[4,4+21])
        c_lrv3_hrv4 <- as.vector(vcv[4,5+21])
        c_lrv3_hrv5 <- as.vector(vcv[4,6+21])
        c_lrv3_hrv6 <- as.vector(vcv[4,7+21])}
      
      c_lrv3 <- as.vector(c(c_lrv3_hr,c_lrv3_hrv1, c_lrv3_hrv2, c_lrv3_hrv3, c_lrv3_hrv4, c_lrv3_hrv5, c_lrv3_hrv6))
      rm(c_lrv3_hr,c_lrv3_hrv1, c_lrv3_hrv2, c_lrv3_hrv3, c_lrv3_hrv4, c_lrv3_hrv5, c_lrv3_hrv6)
      
      #t0_v4
      {c_lrv4_hr   <- as.vector(vcv[5,1+21])
        c_lrv4_hrv1 <- as.vector(vcv[5,2+21])
        c_lrv4_hrv2 <- as.vector(vcv[5,3+21])
        c_lrv4_hrv3 <- as.vector(vcv[5,4+21])
        c_lrv4_hrv4 <- as.vector(vcv[5,5+21])
        c_lrv4_hrv5 <- as.vector(vcv[5,6+21])
        c_lrv4_hrv6 <- as.vector(vcv[5,7+21])}
      
      c_lrv4 <- as.vector(c(c_lrv4_hr,c_lrv4_hrv1, c_lrv4_hrv2, c_lrv4_hrv3, c_lrv4_hrv4, c_lrv4_hrv5, c_lrv4_hrv6))
      rm(c_lrv4_hr,c_lrv4_hrv1, c_lrv4_hrv2, c_lrv4_hrv3, c_lrv4_hrv4, c_lrv4_hrv5, c_lrv4_hrv6)
      
      #t0_v5
      {c_lrv5_hr   <- as.vector(vcv[6,1+21])
        c_lrv5_hrv1 <- as.vector(vcv[6,2+21])
        c_lrv5_hrv2 <- as.vector(vcv[6,3+21])
        c_lrv5_hrv3 <- as.vector(vcv[6,4+21])
        c_lrv5_hrv4 <- as.vector(vcv[6,5+21])
        c_lrv5_hrv5 <- as.vector(vcv[6,6+21])
        c_lrv5_hrv6 <- as.vector(vcv[6,7+21])}
      
      c_lrv5 <- as.vector(c(c_lrv5_hr,c_lrv5_hrv1, c_lrv5_hrv2, c_lrv5_hrv3, c_lrv5_hrv4, c_lrv5_hrv5, c_lrv5_hrv6))
      rm(c_lrv5_hr,c_lrv5_hrv1, c_lrv5_hrv2, c_lrv5_hrv3, c_lrv5_hrv4, c_lrv5_hrv5, c_lrv5_hrv6)
      
      #t0_v6
      {c_lrv6_hr   <- as.vector(vcv[7,1+21])
        c_lrv6_hrv1 <- as.vector(vcv[7,2+21])
        c_lrv6_hrv2 <- as.vector(vcv[7,3+21])
        c_lrv6_hrv3 <- as.vector(vcv[7,4+21])
        c_lrv6_hrv4 <- as.vector(vcv[7,5+21])
        c_lrv6_hrv5 <- as.vector(vcv[7,6+21])
        c_lrv6_hrv6 <- as.vector(vcv[7,7+21])}
      
      c_lrv6 <- as.vector(c(c_lrv6_hr,c_lrv6_hrv1, c_lrv6_hrv2, c_lrv6_hrv3, c_lrv6_hrv4, c_lrv6_hrv5, c_lrv6_hrv6))
      rm(c_lrv6_hr,c_lrv6_hrv1, c_lrv6_hrv2, c_lrv6_hrv3, c_lrv6_hrv4, c_lrv6_hrv5, c_lrv6_hrv6)}
    C_LR_T_HR_T_G <- sum(c_lr) + sum(c_lrv1) + sum(c_lrv2) + sum(c_lrv3) + sum(c_lrv4) + sum(c_lrv5) + sum(c_lrv6)
    rm(c_lr,c_lrv1,c_lrv2,c_lrv3,c_lrv4,c_lrv5,c_lrv6) 
    
    #Cov Linear LR/ Spline HR
    {#t0 
      {c_lr_hrs   <- as.vector(vcv[1,1+28])
      c_lr_hrsv1 <- as.vector(vcv[1,2+28])
      c_lr_hrsv2 <- as.vector(vcv[1,3+28])
      c_lr_hrsv3 <- as.vector(vcv[1,4+28])
      c_lr_hrsv4 <- as.vector(vcv[1,5+28])
      c_lr_hrsv5 <- as.vector(vcv[1,6+28])
      c_lr_hrsv6 <- as.vector(vcv[1,7+28])}
      
      c_lr <- as.vector(c(c_lr_hrs,c_lr_hrsv1,c_lr_hrsv2,c_lr_hrsv3,c_lr_hrsv4,c_lr_hrsv5,c_lr_hrsv6))
      rm(c_lr_hrs,c_lr_hrsv1,c_lr_hrsv2,c_lr_hrsv3,c_lr_hrsv4,c_lr_hrsv5,c_lr_hrsv6)
      #t0_v1
      {c_lrv1_hrs   <- as.vector(vcv[2,1+28])
        c_lrv1_hrsv1 <- as.vector(vcv[2,2+28])
        c_lrv1_hrsv2 <- as.vector(vcv[2,3+28])
        c_lrv1_hrsv3 <- as.vector(vcv[2,4+28])
        c_lrv1_hrsv4 <- as.vector(vcv[2,5+28])
        c_lrv1_hrsv5 <- as.vector(vcv[2,6+28])
        c_lrv1_hrsv6 <- as.vector(vcv[2,7+28])}
      
      c_lrv1 <- as.vector(c(c_lrv1_hrs, c_lrv1_hrsv1, c_lrv1_hrsv2, c_lrv1_hrsv3, c_lrv1_hrsv4, c_lrv1_hrsv5, c_lrv1_hrsv6))
      rm(c_lrv1_hrs, c_lrv1_hrsv1, c_lrv1_hrsv2, c_lrv1_hrsv3, c_lrv1_hrsv4, c_lrv1_hrsv5, c_lrv1_hrsv6)
      
      #t0_v2
      {c_lrv2_hrs   <- as.vector(vcv[3,1+28])
        c_lrv2_hrsv1 <- as.vector(vcv[3,2+28])
        c_lrv2_hrsv2 <- as.vector(vcv[3,3+28])
        c_lrv2_hrsv3 <- as.vector(vcv[3,4+28])
        c_lrv2_hrsv4 <- as.vector(vcv[3,5+28])
        c_lrv2_hrsv5 <- as.vector(vcv[3,6+28])
        c_lrv2_hrsv6 <- as.vector(vcv[3,7+28])}
      
      c_lrv2 <- as.vector(c(c_lrv2_hrs,c_lrv2_hrsv1, c_lrv2_hrsv2, c_lrv2_hrsv3, c_lrv2_hrsv4, c_lrv2_hrsv5, c_lrv2_hrsv6))
      rm(c_lrv2_hrs,c_lrv2_hrsv1, c_lrv2_hrsv2, c_lrv2_hrsv3, c_lrv2_hrsv4, c_lrv2_hrsv5, c_lrv2_hrsv6)
      
      #t0_v3
      {c_lrv3_hrs   <- as.vector(vcv[4,1+28])
        c_lrv3_hrsv1 <- as.vector(vcv[4,2+28])
        c_lrv3_hrsv2 <- as.vector(vcv[4,3+28])
        c_lrv3_hrsv3 <- as.vector(vcv[4,4+28])
        c_lrv3_hrsv4 <- as.vector(vcv[4,5+28])
        c_lrv3_hrsv5 <- as.vector(vcv[4,6+28])
        c_lrv3_hrsv6 <- as.vector(vcv[4,7+28])}
      
      c_lrv3 <- as.vector(c(c_lrv3_hrs,c_lrv3_hrsv1, c_lrv3_hrsv2, c_lrv3_hrsv3, c_lrv3_hrsv4, c_lrv3_hrsv5, c_lrv3_hrsv6))
      rm(c_lrv3_hrs,c_lrv3_hrsv1, c_lrv3_hrsv2, c_lrv3_hrsv3, c_lrv3_hrsv4, c_lrv3_hrsv5, c_lrv3_hrsv6)
      
      #t0_v4
      {c_lrv4_hrs   <- as.vector(vcv[5,1+28])
        c_lrv4_hrsv1 <- as.vector(vcv[5,2+28])
        c_lrv4_hrsv2 <- as.vector(vcv[5,3+28])
        c_lrv4_hrsv3 <- as.vector(vcv[5,4+28])
        c_lrv4_hrsv4 <- as.vector(vcv[5,5+28])
        c_lrv4_hrsv5 <- as.vector(vcv[5,6+28])
        c_lrv4_hrsv6 <- as.vector(vcv[5,7+28])}
      
      c_lrv4 <- as.vector(c(c_lrv4_hrs,c_lrv4_hrsv1, c_lrv4_hrsv2, c_lrv4_hrsv3, c_lrv4_hrsv4, c_lrv4_hrsv5, c_lrv4_hrsv6))
      rm(c_lrv4_hrs,c_lrv4_hrsv1, c_lrv4_hrsv2, c_lrv4_hrsv3, c_lrv4_hrsv4, c_lrv4_hrsv5, c_lrv4_hrsv6)
      
      #t0_v5
      {c_lrv5_hrs   <- as.vector(vcv[6,1+28])
        c_lrv5_hrsv1 <- as.vector(vcv[6,2+28])
        c_lrv5_hrsv2 <- as.vector(vcv[6,3+28])
        c_lrv5_hrsv3 <- as.vector(vcv[6,4+28])
        c_lrv5_hrsv4 <- as.vector(vcv[6,5+28])
        c_lrv5_hrsv5 <- as.vector(vcv[6,6+28])
        c_lrv5_hrsv6 <- as.vector(vcv[6,7+28])}
      
      c_lrv5 <- as.vector(c(c_lrv5_hrs,c_lrv5_hrsv1, c_lrv5_hrsv2, c_lrv5_hrsv3, c_lrv5_hrsv4, c_lrv5_hrsv5, c_lrv5_hrsv6))
      rm(c_lrv5_hrs,c_lrv5_hrsv1, c_lrv5_hrsv2, c_lrv5_hrsv3, c_lrv5_hrsv4, c_lrv5_hrsv5, c_lrv5_hrsv6)
      
      #t0_v6
      {c_lrv6_hrs   <- as.vector(vcv[7,1+28])
        c_lrv6_hrsv1 <- as.vector(vcv[7,2+28])
        c_lrv6_hrsv2 <- as.vector(vcv[7,3+28])
        c_lrv6_hrsv3 <- as.vector(vcv[7,4+28])
        c_lrv6_hrsv4 <- as.vector(vcv[7,5+28])
        c_lrv6_hrsv5 <- as.vector(vcv[7,6+28])
        c_lrv6_hrsv6 <- as.vector(vcv[7,7+28])}
      
      c_lrv6 <- as.vector(c(c_lrv6_hrs,c_lrv6_hrsv1, c_lrv6_hrsv2, c_lrv6_hrsv3, c_lrv6_hrsv4, c_lrv6_hrsv5, c_lrv6_hrsv6))
      rm(c_lrv6_hrs,c_lrv6_hrsv1, c_lrv6_hrsv2, c_lrv6_hrsv3, c_lrv6_hrsv4, c_lrv6_hrsv5, c_lrv6_hrsv6)}
    C_LR_T_HR_TS <- sum(c_lr) + sum(c_lrv1) + sum(c_lrv2) + sum(c_lrv3) + sum(c_lrv4) + sum(c_lrv5) + sum(c_lrv6)
    rm(c_lr,c_lrv1,c_lrv2,c_lrv3,c_lrv4,c_lrv5,c_lrv6)  
    
    #Cov Linear LR/ Spline HR Interacted
    {#t0 
      {c_lr_hrs   <- as.vector(vcv[1,1+35])
      c_lr_hrsv1 <- as.vector(vcv[1,2+35])
      c_lr_hrsv2 <- as.vector(vcv[1,3+35])
      c_lr_hrsv3 <- as.vector(vcv[1,4+35])
      c_lr_hrsv4 <- as.vector(vcv[1,5+35])
      c_lr_hrsv5 <- as.vector(vcv[1,6+35])
      c_lr_hrsv6 <- as.vector(vcv[1,7+35])}
      
      c_lr <- as.vector(c(c_lr_hrs,c_lr_hrsv1,c_lr_hrsv2,c_lr_hrsv3,c_lr_hrsv4,c_lr_hrsv5,c_lr_hrsv6))
      rm(c_lr_hrs,c_lr_hrsv1,c_lr_hrsv2,c_lr_hrsv3,c_lr_hrsv4,c_lr_hrsv5,c_lr_hrsv6)
      #t0_v1
      {c_lrv1_hrs   <- as.vector(vcv[2,1+35])
        c_lrv1_hrsv1 <- as.vector(vcv[2,2+35])
        c_lrv1_hrsv2 <- as.vector(vcv[2,3+35])
        c_lrv1_hrsv3 <- as.vector(vcv[2,4+35])
        c_lrv1_hrsv4 <- as.vector(vcv[2,5+35])
        c_lrv1_hrsv5 <- as.vector(vcv[2,6+35])
        c_lrv1_hrsv6 <- as.vector(vcv[2,7+35])}
      
      c_lrv1 <- as.vector(c(c_lrv1_hrs, c_lrv1_hrsv1, c_lrv1_hrsv2, c_lrv1_hrsv3, c_lrv1_hrsv4, c_lrv1_hrsv5, c_lrv1_hrsv6))
      rm(c_lrv1_hrs, c_lrv1_hrsv1, c_lrv1_hrsv2, c_lrv1_hrsv3, c_lrv1_hrsv4, c_lrv1_hrsv5, c_lrv1_hrsv6)
      
      #t0_v2
      {c_lrv2_hrs   <- as.vector(vcv[3,1+35])
        c_lrv2_hrsv1 <- as.vector(vcv[3,2+35])
        c_lrv2_hrsv2 <- as.vector(vcv[3,3+35])
        c_lrv2_hrsv3 <- as.vector(vcv[3,4+35])
        c_lrv2_hrsv4 <- as.vector(vcv[3,5+35])
        c_lrv2_hrsv5 <- as.vector(vcv[3,6+35])
        c_lrv2_hrsv6 <- as.vector(vcv[3,7+35])}
      
      c_lrv2 <- as.vector(c(c_lrv2_hrs,c_lrv2_hrsv1, c_lrv2_hrsv2, c_lrv2_hrsv3, c_lrv2_hrsv4, c_lrv2_hrsv5, c_lrv2_hrsv6))
      rm(c_lrv2_hrs,c_lrv2_hrsv1, c_lrv2_hrsv2, c_lrv2_hrsv3, c_lrv2_hrsv4, c_lrv2_hrsv5, c_lrv2_hrsv6)
      
      #t0_v3
      {c_lrv3_hrs   <- as.vector(vcv[4,1+35])
        c_lrv3_hrsv1 <- as.vector(vcv[4,2+35])
        c_lrv3_hrsv2 <- as.vector(vcv[4,3+35])
        c_lrv3_hrsv3 <- as.vector(vcv[4,4+35])
        c_lrv3_hrsv4 <- as.vector(vcv[4,5+35])
        c_lrv3_hrsv5 <- as.vector(vcv[4,6+35])
        c_lrv3_hrsv6 <- as.vector(vcv[4,7+35])}
      
      c_lrv3 <- as.vector(c(c_lrv3_hrs,c_lrv3_hrsv1, c_lrv3_hrsv2, c_lrv3_hrsv3, c_lrv3_hrsv4, c_lrv3_hrsv5, c_lrv3_hrsv6))
      rm(c_lrv3_hrs,c_lrv3_hrsv1, c_lrv3_hrsv2, c_lrv3_hrsv3, c_lrv3_hrsv4, c_lrv3_hrsv5, c_lrv3_hrsv6)
      
      #t0_v4
      {c_lrv4_hrs   <- as.vector(vcv[5,1+35])
        c_lrv4_hrsv1 <- as.vector(vcv[5,2+35])
        c_lrv4_hrsv2 <- as.vector(vcv[5,3+35])
        c_lrv4_hrsv3 <- as.vector(vcv[5,4+35])
        c_lrv4_hrsv4 <- as.vector(vcv[5,5+35])
        c_lrv4_hrsv5 <- as.vector(vcv[5,6+35])
        c_lrv4_hrsv6 <- as.vector(vcv[5,7+35])}
      
      c_lrv4 <- as.vector(c(c_lrv4_hrs,c_lrv4_hrsv1, c_lrv4_hrsv2, c_lrv4_hrsv3, c_lrv4_hrsv4, c_lrv4_hrsv5, c_lrv4_hrsv6))
      rm(c_lrv4_hrs,c_lrv4_hrsv1, c_lrv4_hrsv2, c_lrv4_hrsv3, c_lrv4_hrsv4, c_lrv4_hrsv5, c_lrv4_hrsv6)
      
      #t0_v5
      {c_lrv5_hrs   <- as.vector(vcv[6,1+35])
        c_lrv5_hrsv1 <- as.vector(vcv[6,2+35])
        c_lrv5_hrsv2 <- as.vector(vcv[6,3+35])
        c_lrv5_hrsv3 <- as.vector(vcv[6,4+35])
        c_lrv5_hrsv4 <- as.vector(vcv[6,5+35])
        c_lrv5_hrsv5 <- as.vector(vcv[6,6+35])
        c_lrv5_hrsv6 <- as.vector(vcv[6,7+35])}
      
      c_lrv5 <- as.vector(c(c_lrv5_hrs,c_lrv5_hrsv1, c_lrv5_hrsv2, c_lrv5_hrsv3, c_lrv5_hrsv4, c_lrv5_hrsv5, c_lrv5_hrsv6))
      rm(c_lrv5_hrs,c_lrv5_hrsv1, c_lrv5_hrsv2, c_lrv5_hrsv3, c_lrv5_hrsv4, c_lrv5_hrsv5, c_lrv5_hrsv6)
      
      #t0_v6
      {c_lrv6_hrs   <- as.vector(vcv[7,1+35])
        c_lrv6_hrsv1 <- as.vector(vcv[7,2+35])
        c_lrv6_hrsv2 <- as.vector(vcv[7,3+35])
        c_lrv6_hrsv3 <- as.vector(vcv[7,4+35])
        c_lrv6_hrsv4 <- as.vector(vcv[7,5+35])
        c_lrv6_hrsv5 <- as.vector(vcv[7,6+35])
        c_lrv6_hrsv6 <- as.vector(vcv[7,7+35])}
      
      c_lrv6 <- as.vector(c(c_lrv6_hrs,c_lrv6_hrsv1, c_lrv6_hrsv2, c_lrv6_hrsv3, c_lrv6_hrsv4, c_lrv6_hrsv5, c_lrv6_hrsv6))
      rm(c_lrv6_hrs,c_lrv6_hrsv1, c_lrv6_hrsv2, c_lrv6_hrsv3, c_lrv6_hrsv4, c_lrv6_hrsv5, c_lrv6_hrsv6)}
    C_LR_T_HR_TS_G <- sum(c_lr) + sum(c_lrv1) + sum(c_lrv2) + sum(c_lrv3) + sum(c_lrv4) + sum(c_lrv5) + sum(c_lrv6)
    rm(c_lr,c_lrv1,c_lrv2,c_lrv3,c_lrv4,c_lrv5,c_lrv6)  
    
    
    #Cov LR Spline / HR Linear
    {#t0 
      {c_lrs_hr   <- as.vector(vcv[1+7,1+14])
      c_lrs_hrv1 <- as.vector(vcv[1+7,2+14])
      c_lrs_hrv2 <- as.vector(vcv[1+7,3+14])
      c_lrs_hrv3 <- as.vector(vcv[1+7,4+14])
      c_lrs_hrv4 <- as.vector(vcv[1+7,5+14])
      c_lrs_hrv5 <- as.vector(vcv[1+7,6+14])
      c_lrs_hrv6 <- as.vector(vcv[1+7,7+14])}
      
      c_lrs <- as.vector(c(c_lrs_hr,c_lrs_hrv1,c_lrs_hrv2,c_lrs_hrv3,c_lrs_hrv4,c_lrs_hrv5,c_lrs_hrv6))
      rm(c_lrs_hr,c_lrs_hrv1,c_lrs_hrv2,c_lrs_hrv3,c_lrs_hrv4,c_lrs_hrv5,c_lrs_hrv6)
      #t0_v1
      {c_lrsv1_hr   <- as.vector(vcv[2+7,1+14])
        c_lrsv1_hrv1 <- as.vector(vcv[2+7,2+14])
        c_lrsv1_hrv2 <- as.vector(vcv[2+7,3+14])
        c_lrsv1_hrv3 <- as.vector(vcv[2+7,4+14])
        c_lrsv1_hrv4 <- as.vector(vcv[2+7,5+14])
        c_lrsv1_hrv5 <- as.vector(vcv[2+7,6+14])
        c_lrsv1_hrv6 <- as.vector(vcv[2+7,7+14])}
      
      c_lrsv1 <- as.vector(c(c_lrsv1_hr, c_lrsv1_hrv1, c_lrsv1_hrv2, c_lrsv1_hrv3, c_lrsv1_hrv4, c_lrsv1_hrv5, c_lrsv1_hrv6))
      rm(c_lrsv1_hr, c_lrsv1_hrv1, c_lrsv1_hrv2, c_lrsv1_hrv3, c_lrsv1_hrv4, c_lrsv1_hrv5, c_lrsv1_hrv6)
      
      #t0_v2
      {c_lrsv2_hr   <- as.vector(vcv[3+7,1+14])
        c_lrsv2_hrv1 <- as.vector(vcv[3+7,2+14])
        c_lrsv2_hrv2 <- as.vector(vcv[3+7,3+14])
        c_lrsv2_hrv3 <- as.vector(vcv[3+7,4+14])
        c_lrsv2_hrv4 <- as.vector(vcv[3+7,5+14])
        c_lrsv2_hrv5 <- as.vector(vcv[3+7,6+14])
        c_lrsv2_hrv6 <- as.vector(vcv[3+7,7+14])}
      
      c_lrsv2 <- as.vector(c(c_lrsv2_hr,c_lrsv2_hrv1, c_lrsv2_hrv2, c_lrsv2_hrv3, c_lrsv2_hrv4, c_lrsv2_hrv5, c_lrsv2_hrv6))
      rm(c_lrsv2_hr,c_lrsv2_hrv1, c_lrsv2_hrv2, c_lrsv2_hrv3, c_lrsv2_hrv4, c_lrsv2_hrv5, c_lrsv2_hrv6)
      
      #t0_v3
      {c_lrsv3_hr   <- as.vector(vcv[4+7,1+14])
        c_lrsv3_hrv1 <- as.vector(vcv[4+7,2+14])
        c_lrsv3_hrv2 <- as.vector(vcv[4+7,3+14])
        c_lrsv3_hrv3 <- as.vector(vcv[4+7,4+14])
        c_lrsv3_hrv4 <- as.vector(vcv[4+7,5+14])
        c_lrsv3_hrv5 <- as.vector(vcv[4+7,6+14])
        c_lrsv3_hrv6 <- as.vector(vcv[4+7,7+14])}
      
      c_lrsv3 <- as.vector(c(c_lrsv3_hr,c_lrsv3_hrv1, c_lrsv3_hrv2, c_lrsv3_hrv3, c_lrsv3_hrv4, c_lrsv3_hrv5, c_lrsv3_hrv6))
      rm(c_lrsv3_hr,c_lrsv3_hrv1, c_lrsv3_hrv2, c_lrsv3_hrv3, c_lrsv3_hrv4, c_lrsv3_hrv5, c_lrsv3_hrv6)
      
      #t0_v4
      {c_lrsv4_hr   <- as.vector(vcv[5+7,1+14])
        c_lrsv4_hrv1 <- as.vector(vcv[5+7,2+14])
        c_lrsv4_hrv2 <- as.vector(vcv[5+7,3+14])
        c_lrsv4_hrv3 <- as.vector(vcv[5+7,4+14])
        c_lrsv4_hrv4 <- as.vector(vcv[5+7,5+14])
        c_lrsv4_hrv5 <- as.vector(vcv[5+7,6+14])
        c_lrsv4_hrv6 <- as.vector(vcv[5+7,7+14])}
      
      c_lrsv4 <- as.vector(c(c_lrsv4_hr,c_lrsv4_hrv1, c_lrsv4_hrv2, c_lrsv4_hrv3, c_lrsv4_hrv4, c_lrsv4_hrv5, c_lrsv4_hrv6))
      rm(c_lrsv4_hr,c_lrsv4_hrv1, c_lrsv4_hrv2, c_lrsv4_hrv3, c_lrsv4_hrv4, c_lrsv4_hrv5, c_lrsv4_hrv6)
      
      #t0_v5
      {c_lrsv5_hr   <- as.vector(vcv[6+7,1+14])
        c_lrsv5_hrv1 <- as.vector(vcv[6+7,2+14])
        c_lrsv5_hrv2 <- as.vector(vcv[6+7,3+14])
        c_lrsv5_hrv3 <- as.vector(vcv[6+7,4+14])
        c_lrsv5_hrv4 <- as.vector(vcv[6+7,5+14])
        c_lrsv5_hrv5 <- as.vector(vcv[6+7,6+14])
        c_lrsv5_hrv6 <- as.vector(vcv[6+7,7+14])}
      
      c_lrsv5 <- as.vector(c(c_lrsv5_hr,c_lrsv5_hrv1, c_lrsv5_hrv2, c_lrsv5_hrv3, c_lrsv5_hrv4, c_lrsv5_hrv5, c_lrsv5_hrv6))
      rm(c_lrsv5_hr,c_lrsv5_hrv1, c_lrsv5_hrv2, c_lrsv5_hrv3, c_lrsv5_hrv4, c_lrsv5_hrv5, c_lrsv5_hrv6)
      
      #t0_v6
      {c_lrsv6_hr   <- as.vector(vcv[7+7,1+14])
        c_lrsv6_hrv1 <- as.vector(vcv[7+7,2+14])
        c_lrsv6_hrv2 <- as.vector(vcv[7+7,3+14])
        c_lrsv6_hrv3 <- as.vector(vcv[7+7,4+14])
        c_lrsv6_hrv4 <- as.vector(vcv[7+7,5+14])
        c_lrsv6_hrv5 <- as.vector(vcv[7+7,6+14])
        c_lrsv6_hrv6 <- as.vector(vcv[7+7,7+14])}
      
      c_lrsv6 <- as.vector(c(c_lrsv6_hr,c_lrsv6_hrv1, c_lrsv6_hrv2, c_lrsv6_hrv3, c_lrsv6_hrv4, c_lrsv6_hrv5, c_lrsv6_hrv6))
      rm(c_lrsv6_hr,c_lrsv6_hrv1, c_lrsv6_hrv2, c_lrsv6_hrv3, c_lrsv6_hrv4, c_lrsv6_hrv5, c_lrsv6_hrv6)}
    C_LR_TS_HR_T <- sum(c_lrs) + sum(c_lrsv1) + sum(c_lrsv2) + sum(c_lrsv3) + sum(c_lrsv4) + sum(c_lrsv5) + sum(c_lrsv6)
    rm(c_lrs,c_lrsv1,c_lrsv2,c_lrsv3,c_lrsv4,c_lrsv5,c_lrsv6)  
    
    #Cov LR Spline / HR Linear Interacted
    {#t0 
      {c_lrs_hr   <- as.vector(vcv[1+7,1+28])
      c_lrs_hrv1 <- as.vector(vcv[1+7,2+28])
      c_lrs_hrv2 <- as.vector(vcv[1+7,3+28])
      c_lrs_hrv3 <- as.vector(vcv[1+7,4+28])
      c_lrs_hrv4 <- as.vector(vcv[1+7,5+28])
      c_lrs_hrv5 <- as.vector(vcv[1+7,6+28])
      c_lrs_hrv6 <- as.vector(vcv[1+7,7+28])}
      
      c_lrs <- as.vector(c(c_lrs_hr,c_lrs_hrv1,c_lrs_hrv2,c_lrs_hrv3,c_lrs_hrv4,c_lrs_hrv5,c_lrs_hrv6))
      rm(c_lrs_hr,c_lrs_hrv1,c_lrs_hrv2,c_lrs_hrv3,c_lrs_hrv4,c_lrs_hrv5,c_lrs_hrv6)
      #t0_v1
      {c_lrsv1_hr   <- as.vector(vcv[2+7,1+28])
        c_lrsv1_hrv1 <- as.vector(vcv[2+7,2+28])
        c_lrsv1_hrv2 <- as.vector(vcv[2+7,3+28])
        c_lrsv1_hrv3 <- as.vector(vcv[2+7,4+28])
        c_lrsv1_hrv4 <- as.vector(vcv[2+7,5+28])
        c_lrsv1_hrv5 <- as.vector(vcv[2+7,6+28])
        c_lrsv1_hrv6 <- as.vector(vcv[2+7,7+28])}
      
      c_lrsv1 <- as.vector(c(c_lrsv1_hr, c_lrsv1_hrv1, c_lrsv1_hrv2, c_lrsv1_hrv3, c_lrsv1_hrv4, c_lrsv1_hrv5, c_lrsv1_hrv6))
      rm(c_lrsv1_hr, c_lrsv1_hrv1, c_lrsv1_hrv2, c_lrsv1_hrv3, c_lrsv1_hrv4, c_lrsv1_hrv5, c_lrsv1_hrv6)
      
      #t0_v2
      {c_lrsv2_hr   <- as.vector(vcv[3+7,1+28])
        c_lrsv2_hrv1 <- as.vector(vcv[3+7,2+28])
        c_lrsv2_hrv2 <- as.vector(vcv[3+7,3+28])
        c_lrsv2_hrv3 <- as.vector(vcv[3+7,4+28])
        c_lrsv2_hrv4 <- as.vector(vcv[3+7,5+28])
        c_lrsv2_hrv5 <- as.vector(vcv[3+7,6+28])
        c_lrsv2_hrv6 <- as.vector(vcv[3+7,7+28])}
      
      c_lrsv2 <- as.vector(c(c_lrsv2_hr,c_lrsv2_hrv1, c_lrsv2_hrv2, c_lrsv2_hrv3, c_lrsv2_hrv4, c_lrsv2_hrv5, c_lrsv2_hrv6))
      rm(c_lrsv2_hr,c_lrsv2_hrv1, c_lrsv2_hrv2, c_lrsv2_hrv3, c_lrsv2_hrv4, c_lrsv2_hrv5, c_lrsv2_hrv6)
      
      #t0_v3
      {c_lrsv3_hr   <- as.vector(vcv[4+7,1+28])
        c_lrsv3_hrv1 <- as.vector(vcv[4+7,2+28])
        c_lrsv3_hrv2 <- as.vector(vcv[4+7,3+28])
        c_lrsv3_hrv3 <- as.vector(vcv[4+7,4+28])
        c_lrsv3_hrv4 <- as.vector(vcv[4+7,5+28])
        c_lrsv3_hrv5 <- as.vector(vcv[4+7,6+28])
        c_lrsv3_hrv6 <- as.vector(vcv[4+7,7+28])}
      
      c_lrsv3 <- as.vector(c(c_lrsv3_hr,c_lrsv3_hrv1, c_lrsv3_hrv2, c_lrsv3_hrv3, c_lrsv3_hrv4, c_lrsv3_hrv5, c_lrsv3_hrv6))
      rm(c_lrsv3_hr,c_lrsv3_hrv1, c_lrsv3_hrv2, c_lrsv3_hrv3, c_lrsv3_hrv4, c_lrsv3_hrv5, c_lrsv3_hrv6)
      
      #t0_v4
      {c_lrsv4_hr   <- as.vector(vcv[5+7,1+28])
        c_lrsv4_hrv1 <- as.vector(vcv[5+7,2+28])
        c_lrsv4_hrv2 <- as.vector(vcv[5+7,3+28])
        c_lrsv4_hrv3 <- as.vector(vcv[5+7,4+28])
        c_lrsv4_hrv4 <- as.vector(vcv[5+7,5+28])
        c_lrsv4_hrv5 <- as.vector(vcv[5+7,6+28])
        c_lrsv4_hrv6 <- as.vector(vcv[5+7,7+28])}
      
      c_lrsv4 <- as.vector(c(c_lrsv4_hr,c_lrsv4_hrv1, c_lrsv4_hrv2, c_lrsv4_hrv3, c_lrsv4_hrv4, c_lrsv4_hrv5, c_lrsv4_hrv6))
      rm(c_lrsv4_hr,c_lrsv4_hrv1, c_lrsv4_hrv2, c_lrsv4_hrv3, c_lrsv4_hrv4, c_lrsv4_hrv5, c_lrsv4_hrv6)
      
      #t0_v5
      {c_lrsv5_hr   <- as.vector(vcv[6+7,1+28])
        c_lrsv5_hrv1 <- as.vector(vcv[6+7,2+28])
        c_lrsv5_hrv2 <- as.vector(vcv[6+7,3+28])
        c_lrsv5_hrv3 <- as.vector(vcv[6+7,4+28])
        c_lrsv5_hrv4 <- as.vector(vcv[6+7,5+28])
        c_lrsv5_hrv5 <- as.vector(vcv[6+7,6+28])
        c_lrsv5_hrv6 <- as.vector(vcv[6+7,7+28])}
      
      c_lrsv5 <- as.vector(c(c_lrsv5_hr,c_lrsv5_hrv1, c_lrsv5_hrv2, c_lrsv5_hrv3, c_lrsv5_hrv4, c_lrsv5_hrv5, c_lrsv5_hrv6))
      rm(c_lrsv5_hr,c_lrsv5_hrv1, c_lrsv5_hrv2, c_lrsv5_hrv3, c_lrsv5_hrv4, c_lrsv5_hrv5, c_lrsv5_hrv6)
      
      #t0_v6
      {c_lrsv6_hr   <- as.vector(vcv[7+7,1+28])
        c_lrsv6_hrv1 <- as.vector(vcv[7+7,2+28])
        c_lrsv6_hrv2 <- as.vector(vcv[7+7,3+28])
        c_lrsv6_hrv3 <- as.vector(vcv[7+7,4+28])
        c_lrsv6_hrv4 <- as.vector(vcv[7+7,5+28])
        c_lrsv6_hrv5 <- as.vector(vcv[7+7,6+28])
        c_lrsv6_hrv6 <- as.vector(vcv[7+7,7+28])}
      
      c_lrsv6 <- as.vector(c(c_lrsv6_hr,c_lrsv6_hrv1, c_lrsv6_hrv2, c_lrsv6_hrv3, c_lrsv6_hrv4, c_lrsv6_hrv5, c_lrsv6_hrv6))
      rm(c_lrsv6_hr,c_lrsv6_hrv1, c_lrsv6_hrv2, c_lrsv6_hrv3, c_lrsv6_hrv4, c_lrsv6_hrv5, c_lrsv6_hrv6)}
    C_LR_TS_HR_T_G <- sum(c_lrs) + sum(c_lrsv1) + sum(c_lrsv2) + sum(c_lrsv3) + sum(c_lrsv4) + sum(c_lrsv5) + sum(c_lrsv6)
    rm(c_lrs,c_lrsv1,c_lrsv2,c_lrsv3,c_lrsv4,c_lrsv5,c_lrsv6)  
    
    #COV LR Spline / COV HR Spline
    {#t0 
      {c_lrs_hrs   <- as.vector(vcv[1+7,1+28])
      c_lrs_hrsv1 <- as.vector(vcv[1+7,2+28])
      c_lrs_hrsv2 <- as.vector(vcv[1+7,3+28])
      c_lrs_hrsv3 <- as.vector(vcv[1+7,4+28])
      c_lrs_hrsv4 <- as.vector(vcv[1+7,5+28])
      c_lrs_hrsv5 <- as.vector(vcv[1+7,6+28])
      c_lrs_hrsv6 <- as.vector(vcv[1+7,7+28])}
      
      c_lrs <- as.vector(c(c_lrs_hrs,c_lrs_hrsv1,c_lrs_hrsv2,c_lrs_hrsv3,c_lrs_hrsv4,c_lrs_hrsv5,c_lrs_hrsv6))
      rm(c_lrs_hrs,c_lrs_hrsv1,c_lrs_hrsv2,c_lrs_hrsv3,c_lrs_hrsv4,c_lrs_hrsv5,c_lrs_hrsv6)
      #t0_v1
      {c_lrsv1_hrs   <- as.vector(vcv[2+7,1+28])
        c_lrsv1_hrsv1 <- as.vector(vcv[2+7,2+28])
        c_lrsv1_hrsv2 <- as.vector(vcv[2+7,3+28])
        c_lrsv1_hrsv3 <- as.vector(vcv[2+7,4+28])
        c_lrsv1_hrsv4 <- as.vector(vcv[2+7,5+28])
        c_lrsv1_hrsv5 <- as.vector(vcv[2+7,6+28])
        c_lrsv1_hrsv6 <- as.vector(vcv[2+7,7+28])}
      
      c_lrsv1 <- as.vector(c(c_lrsv1_hrs, c_lrsv1_hrsv1, c_lrsv1_hrsv2, c_lrsv1_hrsv3, c_lrsv1_hrsv4, c_lrsv1_hrsv5, c_lrsv1_hrsv6))
      rm(c_lrsv1_hrs, c_lrsv1_hrsv1, c_lrsv1_hrsv2, c_lrsv1_hrsv3, c_lrsv1_hrsv4, c_lrsv1_hrsv5, c_lrsv1_hrsv6)
      
      #t0_v2
      {c_lrsv2_hrs   <- as.vector(vcv[3+7,1+28])
        c_lrsv2_hrsv1 <- as.vector(vcv[3+7,2+28])
        c_lrsv2_hrsv2 <- as.vector(vcv[3+7,3+28])
        c_lrsv2_hrsv3 <- as.vector(vcv[3+7,4+28])
        c_lrsv2_hrsv4 <- as.vector(vcv[3+7,5+28])
        c_lrsv2_hrsv5 <- as.vector(vcv[3+7,6+28])
        c_lrsv2_hrsv6 <- as.vector(vcv[3+7,7+28])}
      
      c_lrsv2 <- as.vector(c(c_lrsv2_hrs,c_lrsv2_hrsv1, c_lrsv2_hrsv2, c_lrsv2_hrsv3, c_lrsv2_hrsv4, c_lrsv2_hrsv5, c_lrsv2_hrsv6))
      rm(c_lrsv2_hrs,c_lrsv2_hrsv1, c_lrsv2_hrsv2, c_lrsv2_hrsv3, c_lrsv2_hrsv4, c_lrsv2_hrsv5, c_lrsv2_hrsv6)
      
      #t0_v3
      {c_lrsv3_hrs   <- as.vector(vcv[4+7,1+28])
        c_lrsv3_hrsv1 <- as.vector(vcv[4+7,2+28])
        c_lrsv3_hrsv2 <- as.vector(vcv[4+7,3+28])
        c_lrsv3_hrsv3 <- as.vector(vcv[4+7,4+28])
        c_lrsv3_hrsv4 <- as.vector(vcv[4+7,5+28])
        c_lrsv3_hrsv5 <- as.vector(vcv[4+7,6+28])
        c_lrsv3_hrsv6 <- as.vector(vcv[4+7,7+28])}
      
      c_lrsv3 <- as.vector(c(c_lrsv3_hrs,c_lrsv3_hrsv1, c_lrsv3_hrsv2, c_lrsv3_hrsv3, c_lrsv3_hrsv4, c_lrsv3_hrsv5, c_lrsv3_hrsv6))
      rm(c_lrsv3_hrs,c_lrsv3_hrsv1, c_lrsv3_hrsv2, c_lrsv3_hrsv3, c_lrsv3_hrsv4, c_lrsv3_hrsv5, c_lrsv3_hrsv6)
      
      #t0_v4
      {c_lrsv4_hrs   <- as.vector(vcv[5+7,1+28])
        c_lrsv4_hrsv1 <- as.vector(vcv[5+7,2+28])
        c_lrsv4_hrsv2 <- as.vector(vcv[5+7,3+28])
        c_lrsv4_hrsv3 <- as.vector(vcv[5+7,4+28])
        c_lrsv4_hrsv4 <- as.vector(vcv[5+7,5+28])
        c_lrsv4_hrsv5 <- as.vector(vcv[5+7,6+28])
        c_lrsv4_hrsv6 <- as.vector(vcv[5+7,7+28])}
      
      c_lrsv4 <- as.vector(c(c_lrsv4_hrs,c_lrsv4_hrsv1, c_lrsv4_hrsv2, c_lrsv4_hrsv3, c_lrsv4_hrsv4, c_lrsv4_hrsv5, c_lrsv4_hrsv6))
      rm(c_lrsv4_hrs,c_lrsv4_hrsv1, c_lrsv4_hrsv2, c_lrsv4_hrsv3, c_lrsv4_hrsv4, c_lrsv4_hrsv5, c_lrsv4_hrsv6)
      
      #t0_v5
      {c_lrsv5_hrs   <- as.vector(vcv[6+7,1+28])
        c_lrsv5_hrsv1 <- as.vector(vcv[6+7,2+28])
        c_lrsv5_hrsv2 <- as.vector(vcv[6+7,3+28])
        c_lrsv5_hrsv3 <- as.vector(vcv[6+7,4+28])
        c_lrsv5_hrsv4 <- as.vector(vcv[6+7,5+28])
        c_lrsv5_hrsv5 <- as.vector(vcv[6+7,6+28])
        c_lrsv5_hrsv6 <- as.vector(vcv[6+7,7+28])}
      
      c_lrsv5 <- as.vector(c(c_lrsv5_hrs,c_lrsv5_hrsv1, c_lrsv5_hrsv2, c_lrsv5_hrsv3, c_lrsv5_hrsv4, c_lrsv5_hrsv5, c_lrsv5_hrsv6))
      rm(c_lrsv5_hrs,c_lrsv5_hrsv1, c_lrsv5_hrsv2, c_lrsv5_hrsv3, c_lrsv5_hrsv4, c_lrsv5_hrsv5, c_lrsv5_hrsv6)
      
      #t0_v6
      {c_lrsv6_hrs   <- as.vector(vcv[7+7,1+28])
        c_lrsv6_hrsv1 <- as.vector(vcv[7+7,2+28])
        c_lrsv6_hrsv2 <- as.vector(vcv[7+7,3+28])
        c_lrsv6_hrsv3 <- as.vector(vcv[7+7,4+28])
        c_lrsv6_hrsv4 <- as.vector(vcv[7+7,5+28])
        c_lrsv6_hrsv5 <- as.vector(vcv[7+7,6+28])
        c_lrsv6_hrsv6 <- as.vector(vcv[7+7,7+28])}
      
      c_lrsv6 <- as.vector(c(c_lrsv6_hrs,c_lrsv6_hrsv1, c_lrsv6_hrsv2, c_lrsv6_hrsv3, c_lrsv6_hrsv4, c_lrsv6_hrsv5, c_lrsv6_hrsv6))
      rm(c_lrsv6_hrs,c_lrsv6_hrsv1, c_lrsv6_hrsv2, c_lrsv6_hrsv3, c_lrsv6_hrsv4, c_lrsv6_hrsv5, c_lrsv6_hrsv6)}
    C_LR_TS_HR_TS <- sum(c_lrs) + sum(c_lrsv1) + sum(c_lrsv2) + sum(c_lrsv3) + sum(c_lrsv4) + sum(c_lrsv5) + sum(c_lrsv6)
    rm(c_lrs,c_lrsv1,c_lrsv2,c_lrsv3,c_lrsv4,c_lrsv5,c_lrsv6)
    
    #COV LR Spline / COV HR Spline Interacted
    {#t0 
      {c_lrs_hrs   <- as.vector(vcv[1+7,1+35])
      c_lrs_hrsv1 <- as.vector(vcv[1+7,2+35])
      c_lrs_hrsv2 <- as.vector(vcv[1+7,3+35])
      c_lrs_hrsv3 <- as.vector(vcv[1+7,4+35])
      c_lrs_hrsv4 <- as.vector(vcv[1+7,5+35])
      c_lrs_hrsv5 <- as.vector(vcv[1+7,6+35])
      c_lrs_hrsv6 <- as.vector(vcv[1+7,7+35])}
      
      c_lrs <- as.vector(c(c_lrs_hrs,c_lrs_hrsv1,c_lrs_hrsv2,c_lrs_hrsv3,c_lrs_hrsv4,c_lrs_hrsv5,c_lrs_hrsv6))
      rm(c_lrs_hrs,c_lrs_hrsv1,c_lrs_hrsv2,c_lrs_hrsv3,c_lrs_hrsv4,c_lrs_hrsv5,c_lrs_hrsv6)
      #t0_v1
      {c_lrsv1_hrs   <- as.vector(vcv[2+7,1+35])
        c_lrsv1_hrsv1 <- as.vector(vcv[2+7,2+35])
        c_lrsv1_hrsv2 <- as.vector(vcv[2+7,3+35])
        c_lrsv1_hrsv3 <- as.vector(vcv[2+7,4+35])
        c_lrsv1_hrsv4 <- as.vector(vcv[2+7,5+35])
        c_lrsv1_hrsv5 <- as.vector(vcv[2+7,6+35])
        c_lrsv1_hrsv6 <- as.vector(vcv[2+7,7+35])}
      
      c_lrsv1 <- as.vector(c(c_lrsv1_hrs, c_lrsv1_hrsv1, c_lrsv1_hrsv2, c_lrsv1_hrsv3, c_lrsv1_hrsv4, c_lrsv1_hrsv5, c_lrsv1_hrsv6))
      rm(c_lrsv1_hrs, c_lrsv1_hrsv1, c_lrsv1_hrsv2, c_lrsv1_hrsv3, c_lrsv1_hrsv4, c_lrsv1_hrsv5, c_lrsv1_hrsv6)
      
      #t0_v2
      {c_lrsv2_hrs   <- as.vector(vcv[3+7,1+35])
        c_lrsv2_hrsv1 <- as.vector(vcv[3+7,2+35])
        c_lrsv2_hrsv2 <- as.vector(vcv[3+7,3+35])
        c_lrsv2_hrsv3 <- as.vector(vcv[3+7,4+35])
        c_lrsv2_hrsv4 <- as.vector(vcv[3+7,5+35])
        c_lrsv2_hrsv5 <- as.vector(vcv[3+7,6+35])
        c_lrsv2_hrsv6 <- as.vector(vcv[3+7,7+35])}
      
      c_lrsv2 <- as.vector(c(c_lrsv2_hrs,c_lrsv2_hrsv1, c_lrsv2_hrsv2, c_lrsv2_hrsv3, c_lrsv2_hrsv4, c_lrsv2_hrsv5, c_lrsv2_hrsv6))
      rm(c_lrsv2_hrs,c_lrsv2_hrsv1, c_lrsv2_hrsv2, c_lrsv2_hrsv3, c_lrsv2_hrsv4, c_lrsv2_hrsv5, c_lrsv2_hrsv6)
      
      #t0_v3
      {c_lrsv3_hrs   <- as.vector(vcv[4+7,1+35])
        c_lrsv3_hrsv1 <- as.vector(vcv[4+7,2+35])
        c_lrsv3_hrsv2 <- as.vector(vcv[4+7,3+35])
        c_lrsv3_hrsv3 <- as.vector(vcv[4+7,4+35])
        c_lrsv3_hrsv4 <- as.vector(vcv[4+7,5+35])
        c_lrsv3_hrsv5 <- as.vector(vcv[4+7,6+35])
        c_lrsv3_hrsv6 <- as.vector(vcv[4+7,7+35])}
      
      c_lrsv3 <- as.vector(c(c_lrsv3_hrs,c_lrsv3_hrsv1, c_lrsv3_hrsv2, c_lrsv3_hrsv3, c_lrsv3_hrsv4, c_lrsv3_hrsv5, c_lrsv3_hrsv6))
      rm(c_lrsv3_hrs,c_lrsv3_hrsv1, c_lrsv3_hrsv2, c_lrsv3_hrsv3, c_lrsv3_hrsv4, c_lrsv3_hrsv5, c_lrsv3_hrsv6)
      
      #t0_v4
      {c_lrsv4_hrs   <- as.vector(vcv[5+7,1+35])
        c_lrsv4_hrsv1 <- as.vector(vcv[5+7,2+35])
        c_lrsv4_hrsv2 <- as.vector(vcv[5+7,3+35])
        c_lrsv4_hrsv3 <- as.vector(vcv[5+7,4+35])
        c_lrsv4_hrsv4 <- as.vector(vcv[5+7,5+35])
        c_lrsv4_hrsv5 <- as.vector(vcv[5+7,6+35])
        c_lrsv4_hrsv6 <- as.vector(vcv[5+7,7+35])}
      
      c_lrsv4 <- as.vector(c(c_lrsv4_hrs,c_lrsv4_hrsv1, c_lrsv4_hrsv2, c_lrsv4_hrsv3, c_lrsv4_hrsv4, c_lrsv4_hrsv5, c_lrsv4_hrsv6))
      rm(c_lrsv4_hrs,c_lrsv4_hrsv1, c_lrsv4_hrsv2, c_lrsv4_hrsv3, c_lrsv4_hrsv4, c_lrsv4_hrsv5, c_lrsv4_hrsv6)
      
      #t0_v5
      {c_lrsv5_hrs   <- as.vector(vcv[6+7,1+35])
        c_lrsv5_hrsv1 <- as.vector(vcv[6+7,2+35])
        c_lrsv5_hrsv2 <- as.vector(vcv[6+7,3+35])
        c_lrsv5_hrsv3 <- as.vector(vcv[6+7,4+35])
        c_lrsv5_hrsv4 <- as.vector(vcv[6+7,5+35])
        c_lrsv5_hrsv5 <- as.vector(vcv[6+7,6+35])
        c_lrsv5_hrsv6 <- as.vector(vcv[6+7,7+35])}
      
      c_lrsv5 <- as.vector(c(c_lrsv5_hrs,c_lrsv5_hrsv1, c_lrsv5_hrsv2, c_lrsv5_hrsv3, c_lrsv5_hrsv4, c_lrsv5_hrsv5, c_lrsv5_hrsv6))
      rm(c_lrsv5_hrs,c_lrsv5_hrsv1, c_lrsv5_hrsv2, c_lrsv5_hrsv3, c_lrsv5_hrsv4, c_lrsv5_hrsv5, c_lrsv5_hrsv6)
      
      #t0_v6
      {c_lrsv6_hrs   <- as.vector(vcv[7+7,1+35])
        c_lrsv6_hrsv1 <- as.vector(vcv[7+7,2+35])
        c_lrsv6_hrsv2 <- as.vector(vcv[7+7,3+35])
        c_lrsv6_hrsv3 <- as.vector(vcv[7+7,4+35])
        c_lrsv6_hrsv4 <- as.vector(vcv[7+7,5+35])
        c_lrsv6_hrsv5 <- as.vector(vcv[7+7,6+35])
        c_lrsv6_hrsv6 <- as.vector(vcv[7+7,7+35])}
      
      c_lrsv6 <- as.vector(c(c_lrsv6_hrs,c_lrsv6_hrsv1, c_lrsv6_hrsv2, c_lrsv6_hrsv3, c_lrsv6_hrsv4, c_lrsv6_hrsv5, c_lrsv6_hrsv6))
      rm(c_lrsv6_hrs,c_lrsv6_hrsv1, c_lrsv6_hrsv2, c_lrsv6_hrsv3, c_lrsv6_hrsv4, c_lrsv6_hrsv5, c_lrsv6_hrsv6)}
    C_LR_TS_HR_TS_G <- sum(c_lrs) + sum(c_lrsv1) + sum(c_lrsv2) + sum(c_lrsv3) + sum(c_lrsv4) + sum(c_lrsv5) + sum(c_lrsv6)
    rm(c_lrs,c_lrsv1,c_lrsv2,c_lrsv3,c_lrsv4,c_lrsv5,c_lrsv6)     
    
    #Cov HR Linear HR Spline
    {#t0 
      {c_hr_hrs   <- as.vector(vcv[1+14,1+28])
      c_hr_hrsv1 <- as.vector(vcv[1+14,2+28])
      c_hr_hrsv2 <- as.vector(vcv[1+14,3+28])
      c_hr_hrsv3 <- as.vector(vcv[1+14,4+28])
      c_hr_hrsv4 <- as.vector(vcv[1+14,5+28])
      c_hr_hrsv5 <- as.vector(vcv[1+14,6+28])
      c_hr_hrsv6 <- as.vector(vcv[1+14,7+28])}
      
      c_hr <- as.vector(c(c_hr_hrs,c_hr_hrsv1,c_hr_hrsv2,c_hr_hrsv3,c_hr_hrsv4,c_hr_hrsv5,c_hr_hrsv6))
      rm(c_hr_hrs,c_hr_hrsv1,c_hr_hrsv2,c_hr_hrsv3,c_hr_hrsv4,c_hr_hrsv5,c_hr_hrsv6)
      
      #t0_v1
      {c_hrv1_hrs   <- as.vector(vcv[2+14,1+28])
        c_hrv1_hrsv1 <- as.vector(vcv[2+14,2+28])
        c_hrv1_hrsv2 <- as.vector(vcv[2+14,3+28])
        c_hrv1_hrsv3 <- as.vector(vcv[2+14,4+28])
        c_hrv1_hrsv4 <- as.vector(vcv[2+14,5+28])
        c_hrv1_hrsv5 <- as.vector(vcv[2+14,6+28])
        c_hrv1_hrsv6 <- as.vector(vcv[2+14,7+28])}
      
      c_hrv1 <- as.vector(c(c_hrv1_hrs, c_hrv1_hrsv1, c_hrv1_hrsv2, c_hrv1_hrsv3, c_hrv1_hrsv4, c_hrv1_hrsv5, c_hrv1_hrsv6))
      rm(c_hrv1_hrs, c_hrv1_hrsv1, c_hrv1_hrsv2, c_hrv1_hrsv3, c_hrv1_hrsv4, c_hrv1_hrsv5, c_hrv1_hrsv6)
      
      #t0_v2
      {c_hrv2_hrs   <- as.vector(vcv[3+14,1+28])
        c_hrv2_hrsv1 <- as.vector(vcv[3+14,2+28])
        c_hrv2_hrsv2 <- as.vector(vcv[3+14,3+28])
        c_hrv2_hrsv3 <- as.vector(vcv[3+14,4+28])
        c_hrv2_hrsv4 <- as.vector(vcv[3+14,5+28])
        c_hrv2_hrsv5 <- as.vector(vcv[3+14,6+28])
        c_hrv2_hrsv6 <- as.vector(vcv[3+14,7+28])}
      
      c_hrv2 <- as.vector(c(c_hrv2_hrs,c_hrv2_hrsv1, c_hrv2_hrsv2, c_hrv2_hrsv3, c_hrv2_hrsv4, c_hrv2_hrsv5, c_hrv2_hrsv6))
      rm(c_hrv2_hrs,c_hrv2_hrsv1, c_hrv2_hrsv2, c_hrv2_hrsv3, c_hrv2_hrsv4, c_hrv2_hrsv5, c_hrv2_hrsv6)
      
      #t0_v3
      {c_hrv3_hrs   <- as.vector(vcv[4+14,1+28])
        c_hrv3_hrsv1 <- as.vector(vcv[4+14,2+28])
        c_hrv3_hrsv2 <- as.vector(vcv[4+14,3+28])
        c_hrv3_hrsv3 <- as.vector(vcv[4+14,4+28])
        c_hrv3_hrsv4 <- as.vector(vcv[4+14,5+28])
        c_hrv3_hrsv5 <- as.vector(vcv[4+14,6+28])
        c_hrv3_hrsv6 <- as.vector(vcv[4+14,7+28])}
      
      c_hrv3 <- as.vector(c(c_hrv3_hrs,c_hrv3_hrsv1, c_hrv3_hrsv2, c_hrv3_hrsv3, c_hrv3_hrsv4, c_hrv3_hrsv5, c_hrv3_hrsv6))
      rm(c_hrv3_hrs,c_hrv3_hrsv1, c_hrv3_hrsv2, c_hrv3_hrsv3, c_hrv3_hrsv4, c_hrv3_hrsv5, c_hrv3_hrsv6)
      
      #t0_v4
      {c_hrv4_hrs   <- as.vector(vcv[5+14,1+28])
        c_hrv4_hrsv1 <- as.vector(vcv[5+14,2+28])
        c_hrv4_hrsv2 <- as.vector(vcv[5+14,3+28])
        c_hrv4_hrsv3 <- as.vector(vcv[5+14,4+28])
        c_hrv4_hrsv4 <- as.vector(vcv[5+14,5+28])
        c_hrv4_hrsv5 <- as.vector(vcv[5+14,6+28])
        c_hrv4_hrsv6 <- as.vector(vcv[5+14,7+28])}
      
      c_hrv4 <- as.vector(c(c_hrv4_hrs,c_hrv4_hrsv1, c_hrv4_hrsv2, c_hrv4_hrsv3, c_hrv4_hrsv4, c_hrv4_hrsv5, c_hrv4_hrsv6))
      rm(c_hrv4_hrs,c_hrv4_hrsv1, c_hrv4_hrsv2, c_hrv4_hrsv3, c_hrv4_hrsv4, c_hrv4_hrsv5, c_hrv4_hrsv6)
      
      #t0_v5
      {c_hrv5_hrs   <- as.vector(vcv[6+14,1+28])
        c_hrv5_hrsv1 <- as.vector(vcv[6+14,2+28])
        c_hrv5_hrsv2 <- as.vector(vcv[6+14,3+28])
        c_hrv5_hrsv3 <- as.vector(vcv[6+14,4+28])
        c_hrv5_hrsv4 <- as.vector(vcv[6+14,5+28])
        c_hrv5_hrsv5 <- as.vector(vcv[6+14,6+28])
        c_hrv5_hrsv6 <- as.vector(vcv[6+14,7+28])}
      
      c_hrv5 <- as.vector(c(c_hrv5_hrs,c_hrv5_hrsv1, c_hrv5_hrsv2, c_hrv5_hrsv3, c_hrv5_hrsv4, c_hrv5_hrsv5, c_hrv5_hrsv6))
      rm(c_hrv5_hrs,c_hrv5_hrsv1, c_hrv5_hrsv2, c_hrv5_hrsv3, c_hrv5_hrsv4, c_hrv5_hrsv5, c_hrv5_hrsv6)
      
      #t0_v6
      {c_hrv6_hrs   <- as.vector(vcv[7+14,1+28])
        c_hrv6_hrsv1 <- as.vector(vcv[7+14,2+28])
        c_hrv6_hrsv2 <- as.vector(vcv[7+14,3+28])
        c_hrv6_hrsv3 <- as.vector(vcv[7+14,4+28])
        c_hrv6_hrsv4 <- as.vector(vcv[7+14,5+28])
        c_hrv6_hrsv5 <- as.vector(vcv[7+14,6+28])
        c_hrv6_hrsv6 <- as.vector(vcv[7+14,7+28])}
      
      c_hrv6 <- as.vector(c(c_hrv6_hrs,c_hrv6_hrsv1, c_hrv6_hrsv2, c_hrv6_hrsv3, c_hrv6_hrsv4, c_hrv6_hrsv5, c_hrv6_hrsv6))
      rm(c_hrv6_hrs,c_hrv6_hrsv1, c_hrv6_hrsv2, c_hrv6_hrsv3, c_hrv6_hrsv4, c_hrv6_hrsv5, c_hrv6_hrsv6)}
    C_HR_T_HR_TS <-  sum(c_hr) + sum(c_hrv1) + sum(c_hrv2) + sum(c_hrv3) + sum(c_hrv4) + sum(c_hrv5) + sum(c_hrv6)
    rm(c_hr,c_hrv1,c_hrv2,c_hrv3,c_hrv4,c_hrv5,c_hrv6)
    
    #Cov(HR Linear Interacted, HR Spline)
    {#t0 
      {c_hr_hrs   <- as.vector(vcv[1+21,1+28])
      c_hr_hrsv1 <- as.vector(vcv[1+21,2+28])
      c_hr_hrsv2 <- as.vector(vcv[1+21,3+28])
      c_hr_hrsv3 <- as.vector(vcv[1+21,4+28])
      c_hr_hrsv4 <- as.vector(vcv[1+21,5+28])
      c_hr_hrsv5 <- as.vector(vcv[1+21,6+28])
      c_hr_hrsv6 <- as.vector(vcv[1+21,7+28])}
      
      c_hr <- as.vector(c(c_hr_hrs,c_hr_hrsv1,c_hr_hrsv2,c_hr_hrsv3,c_hr_hrsv4,c_hr_hrsv5,c_hr_hrsv6))
      rm(c_hr_hrs,c_hr_hrsv1,c_hr_hrsv2,c_hr_hrsv3,c_hr_hrsv4,c_hr_hrsv5,c_hr_hrsv6)
      
      #t0_v1
      {c_hrv1_hrs   <- as.vector(vcv[2+21,1+28])
        c_hrv1_hrsv1 <- as.vector(vcv[2+21,2+28])
        c_hrv1_hrsv2 <- as.vector(vcv[2+21,3+28])
        c_hrv1_hrsv3 <- as.vector(vcv[2+21,4+28])
        c_hrv1_hrsv4 <- as.vector(vcv[2+21,5+28])
        c_hrv1_hrsv5 <- as.vector(vcv[2+21,6+28])
        c_hrv1_hrsv6 <- as.vector(vcv[2+21,7+28])}
      
      c_hrv1 <- as.vector(c(c_hrv1_hrs, c_hrv1_hrsv1, c_hrv1_hrsv2, c_hrv1_hrsv3, c_hrv1_hrsv4, c_hrv1_hrsv5, c_hrv1_hrsv6))
      rm(c_hrv1_hrs, c_hrv1_hrsv1, c_hrv1_hrsv2, c_hrv1_hrsv3, c_hrv1_hrsv4, c_hrv1_hrsv5, c_hrv1_hrsv6)
      
      #t0_v2
      {c_hrv2_hrs   <- as.vector(vcv[3+21,1+28])
        c_hrv2_hrsv1 <- as.vector(vcv[3+21,2+28])
        c_hrv2_hrsv2 <- as.vector(vcv[3+21,3+28])
        c_hrv2_hrsv3 <- as.vector(vcv[3+21,4+28])
        c_hrv2_hrsv4 <- as.vector(vcv[3+21,5+28])
        c_hrv2_hrsv5 <- as.vector(vcv[3+21,6+28])
        c_hrv2_hrsv6 <- as.vector(vcv[3+21,7+28])}
      
      c_hrv2 <- as.vector(c(c_hrv2_hrs,c_hrv2_hrsv1, c_hrv2_hrsv2, c_hrv2_hrsv3, c_hrv2_hrsv4, c_hrv2_hrsv5, c_hrv2_hrsv6))
      rm(c_hrv2_hrs,c_hrv2_hrsv1, c_hrv2_hrsv2, c_hrv2_hrsv3, c_hrv2_hrsv4, c_hrv2_hrsv5, c_hrv2_hrsv6)
      
      #t0_v3
      {c_hrv3_hrs   <- as.vector(vcv[4+21,1+28])
        c_hrv3_hrsv1 <- as.vector(vcv[4+21,2+28])
        c_hrv3_hrsv2 <- as.vector(vcv[4+21,3+28])
        c_hrv3_hrsv3 <- as.vector(vcv[4+21,4+28])
        c_hrv3_hrsv4 <- as.vector(vcv[4+21,5+28])
        c_hrv3_hrsv5 <- as.vector(vcv[4+21,6+28])
        c_hrv3_hrsv6 <- as.vector(vcv[4+21,7+28])}
      
      c_hrv3 <- as.vector(c(c_hrv3_hrs,c_hrv3_hrsv1, c_hrv3_hrsv2, c_hrv3_hrsv3, c_hrv3_hrsv4, c_hrv3_hrsv5, c_hrv3_hrsv6))
      rm(c_hrv3_hrs,c_hrv3_hrsv1, c_hrv3_hrsv2, c_hrv3_hrsv3, c_hrv3_hrsv4, c_hrv3_hrsv5, c_hrv3_hrsv6)
      
      #t0_v4
      {c_hrv4_hrs   <- as.vector(vcv[5+21,1+28])
        c_hrv4_hrsv1 <- as.vector(vcv[5+21,2+28])
        c_hrv4_hrsv2 <- as.vector(vcv[5+21,3+28])
        c_hrv4_hrsv3 <- as.vector(vcv[5+21,4+28])
        c_hrv4_hrsv4 <- as.vector(vcv[5+21,5+28])
        c_hrv4_hrsv5 <- as.vector(vcv[5+21,6+28])
        c_hrv4_hrsv6 <- as.vector(vcv[5+21,7+28])}
      
      c_hrv4 <- as.vector(c(c_hrv4_hrs,c_hrv4_hrsv1, c_hrv4_hrsv2, c_hrv4_hrsv3, c_hrv4_hrsv4, c_hrv4_hrsv5, c_hrv4_hrsv6))
      rm(c_hrv4_hrs,c_hrv4_hrsv1, c_hrv4_hrsv2, c_hrv4_hrsv3, c_hrv4_hrsv4, c_hrv4_hrsv5, c_hrv4_hrsv6)
      
      #t0_v5
      {c_hrv5_hrs   <- as.vector(vcv[6+21,1+28])
        c_hrv5_hrsv1 <- as.vector(vcv[6+21,2+28])
        c_hrv5_hrsv2 <- as.vector(vcv[6+21,3+28])
        c_hrv5_hrsv3 <- as.vector(vcv[6+21,4+28])
        c_hrv5_hrsv4 <- as.vector(vcv[6+21,5+28])
        c_hrv5_hrsv5 <- as.vector(vcv[6+21,6+28])
        c_hrv5_hrsv6 <- as.vector(vcv[6+21,7+28])}
      
      c_hrv5 <- as.vector(c(c_hrv5_hrs,c_hrv5_hrsv1, c_hrv5_hrsv2, c_hrv5_hrsv3, c_hrv5_hrsv4, c_hrv5_hrsv5, c_hrv5_hrsv6))
      rm(c_hrv5_hrs,c_hrv5_hrsv1, c_hrv5_hrsv2, c_hrv5_hrsv3, c_hrv5_hrsv4, c_hrv5_hrsv5, c_hrv5_hrsv6)
      
      #t0_v6
      {c_hrv6_hrs   <- as.vector(vcv[7+21,1+28])
        c_hrv6_hrsv1 <- as.vector(vcv[7+21,2+28])
        c_hrv6_hrsv2 <- as.vector(vcv[7+21,3+28])
        c_hrv6_hrsv3 <- as.vector(vcv[7+21,4+28])
        c_hrv6_hrsv4 <- as.vector(vcv[7+21,5+28])
        c_hrv6_hrsv5 <- as.vector(vcv[7+21,6+28])
        c_hrv6_hrsv6 <- as.vector(vcv[7+21,7+28])}
      
      c_hrv6 <- as.vector(c(c_hrv6_hrs,c_hrv6_hrsv1, c_hrv6_hrsv2, c_hrv6_hrsv3, c_hrv6_hrsv4, c_hrv6_hrsv5, c_hrv6_hrsv6))
      rm(c_hrv6_hrs,c_hrv6_hrsv1, c_hrv6_hrsv2, c_hrv6_hrsv3, c_hrv6_hrsv4, c_hrv6_hrsv5, c_hrv6_hrsv6)}
    C_HR_T_G_HR_TS <-  sum(c_hr) + sum(c_hrv1) + sum(c_hrv2) + sum(c_hrv3) + sum(c_hrv4) + sum(c_hrv5) + sum(c_hrv6)
    rm(c_hr,c_hrv1,c_hrv2,c_hrv3,c_hrv4,c_hrv5,c_hrv6)
    
    #Cov HR Linear HR Linear Interacted
    {#t0 
      {c_hr_hrg   <- as.vector(vcv[1+14,1+21])
      c_hr_hrgv1 <- as.vector(vcv[1+14,2+21])
      c_hr_hrgv2 <- as.vector(vcv[1+14,3+21])
      c_hr_hrgv3 <- as.vector(vcv[1+14,4+21])
      c_hr_hrgv4 <- as.vector(vcv[1+14,5+21])
      c_hr_hrgv5 <- as.vector(vcv[1+14,6+21])
      c_hr_hrgv6 <- as.vector(vcv[1+14,7+21])}
      
      c_hr <- as.vector(c(c_hr_hrg,c_hr_hrgv1,c_hr_hrgv2,c_hr_hrgv3,c_hr_hrgv4,c_hr_hrgv5,c_hr_hrgv6))
      rm(c_hr_hrg,c_hr_hrgv1,c_hr_hrgv2,c_hr_hrgv3,c_hr_hrgv4,c_hr_hrgv5,c_hr_hrgv6)
      
      #t0_v1
      {c_hrv1_hrg   <- as.vector(vcv[2+14,1+21])
        c_hrv1_hrgv1 <- as.vector(vcv[2+14,2+21])
        c_hrv1_hrgv2 <- as.vector(vcv[2+14,3+21])
        c_hrv1_hrgv3 <- as.vector(vcv[2+14,4+21])
        c_hrv1_hrgv4 <- as.vector(vcv[2+14,5+21])
        c_hrv1_hrgv5 <- as.vector(vcv[2+14,6+21])
        c_hrv1_hrgv6 <- as.vector(vcv[2+14,7+21])}
      
      c_hrv1 <- as.vector(c(c_hrv1_hrg, c_hrv1_hrgv1, c_hrv1_hrgv2, c_hrv1_hrgv3, c_hrv1_hrgv4, c_hrv1_hrgv5, c_hrv1_hrgv6))
      rm(c_hrv1_hrg, c_hrv1_hrgv1, c_hrv1_hrgv2, c_hrv1_hrgv3, c_hrv1_hrgv4, c_hrv1_hrgv5, c_hrv1_hrgv6)
      
      #t0_v2
      {c_hrv2_hrg   <- as.vector(vcv[3+14,1+21])
        c_hrv2_hrgv1 <- as.vector(vcv[3+14,2+21])
        c_hrv2_hrgv2 <- as.vector(vcv[3+14,3+21])
        c_hrv2_hrgv3 <- as.vector(vcv[3+14,4+21])
        c_hrv2_hrgv4 <- as.vector(vcv[3+14,5+21])
        c_hrv2_hrgv5 <- as.vector(vcv[3+14,6+21])
        c_hrv2_hrgv6 <- as.vector(vcv[3+14,7+21])}
      
      c_hrv2 <- as.vector(c(c_hrv2_hrg,c_hrv2_hrgv1, c_hrv2_hrgv2, c_hrv2_hrgv3, c_hrv2_hrgv4, c_hrv2_hrgv5, c_hrv2_hrgv6))
      rm(c_hrv2_hrg,c_hrv2_hrgv1, c_hrv2_hrgv2, c_hrv2_hrgv3, c_hrv2_hrgv4, c_hrv2_hrgv5, c_hrv2_hrgv6)
      
      #t0_v3
      {c_hrv3_hrg   <- as.vector(vcv[4+14,1+21])
        c_hrv3_hrgv1 <- as.vector(vcv[4+14,2+21])
        c_hrv3_hrgv2 <- as.vector(vcv[4+14,3+21])
        c_hrv3_hrgv3 <- as.vector(vcv[4+14,4+21])
        c_hrv3_hrgv4 <- as.vector(vcv[4+14,5+21])
        c_hrv3_hrgv5 <- as.vector(vcv[4+14,6+21])
        c_hrv3_hrgv6 <- as.vector(vcv[4+14,7+21])}
      
      c_hrv3 <- as.vector(c(c_hrv3_hrg,c_hrv3_hrgv1, c_hrv3_hrgv2, c_hrv3_hrgv3, c_hrv3_hrgv4, c_hrv3_hrgv5, c_hrv3_hrgv6))
      rm(c_hrv3_hrg,c_hrv3_hrgv1, c_hrv3_hrgv2, c_hrv3_hrgv3, c_hrv3_hrgv4, c_hrv3_hrgv5, c_hrv3_hrgv6)
      
      #t0_v4
      {c_hrv4_hrg   <- as.vector(vcv[5+14,1+21])
        c_hrv4_hrgv1 <- as.vector(vcv[5+14,2+21])
        c_hrv4_hrgv2 <- as.vector(vcv[5+14,3+21])
        c_hrv4_hrgv3 <- as.vector(vcv[5+14,4+21])
        c_hrv4_hrgv4 <- as.vector(vcv[5+14,5+21])
        c_hrv4_hrgv5 <- as.vector(vcv[5+14,6+21])
        c_hrv4_hrgv6 <- as.vector(vcv[5+14,7+21])}
      
      c_hrv4 <- as.vector(c(c_hrv4_hrg,c_hrv4_hrgv1, c_hrv4_hrgv2, c_hrv4_hrgv3, c_hrv4_hrgv4, c_hrv4_hrgv5, c_hrv4_hrgv6))
      rm(c_hrv4_hrg,c_hrv4_hrgv1, c_hrv4_hrgv2, c_hrv4_hrgv3, c_hrv4_hrgv4, c_hrv4_hrgv5, c_hrv4_hrgv6)
      
      #t0_v5
      {c_hrv5_hrg   <- as.vector(vcv[6+14,1+21])
        c_hrv5_hrgv1 <- as.vector(vcv[6+14,2+21])
        c_hrv5_hrgv2 <- as.vector(vcv[6+14,3+21])
        c_hrv5_hrgv3 <- as.vector(vcv[6+14,4+21])
        c_hrv5_hrgv4 <- as.vector(vcv[6+14,5+21])
        c_hrv5_hrgv5 <- as.vector(vcv[6+14,6+21])
        c_hrv5_hrgv6 <- as.vector(vcv[6+14,7+21])}
      
      c_hrv5 <- as.vector(c(c_hrv5_hrg,c_hrv5_hrgv1, c_hrv5_hrgv2, c_hrv5_hrgv3, c_hrv5_hrgv4, c_hrv5_hrgv5, c_hrv5_hrgv6))
      rm(c_hrv5_hrg,c_hrv5_hrgv1, c_hrv5_hrgv2, c_hrv5_hrgv3, c_hrv5_hrgv4, c_hrv5_hrgv5, c_hrv5_hrgv6)
      
      #t0_v6
      {c_hrv6_hrg   <- as.vector(vcv[7+14,1+21])
        c_hrv6_hrgv1 <- as.vector(vcv[7+14,2+21])
        c_hrv6_hrgv2 <- as.vector(vcv[7+14,3+21])
        c_hrv6_hrgv3 <- as.vector(vcv[7+14,4+21])
        c_hrv6_hrgv4 <- as.vector(vcv[7+14,5+21])
        c_hrv6_hrgv5 <- as.vector(vcv[7+14,6+21])
        c_hrv6_hrgv6 <- as.vector(vcv[7+14,7+21])}
      
      c_hrv6 <- as.vector(c(c_hrv6_hrg,c_hrv6_hrgv1, c_hrv6_hrgv2, c_hrv6_hrgv3, c_hrv6_hrgv4, c_hrv6_hrgv5, c_hrv6_hrgv6))
      rm(c_hrv6_hrg,c_hrv6_hrgv1, c_hrv6_hrgv2, c_hrv6_hrgv3, c_hrv6_hrgv4, c_hrv6_hrgv5, c_hrv6_hrgv6)}
    C_HR_T_HR_T_G<-  sum(c_hr) + sum(c_hrv1) + sum(c_hrv2) + sum(c_hrv3) + sum(c_hrv4) + sum(c_hrv5) + sum(c_hrv6)
    rm(c_hr,c_hrv1,c_hrv2,c_hrv3,c_hrv4,c_hrv5,c_hrv6)
    
    #Cov HR Linear HR Spline Interacted
    {#t0 
      {c_hr_hrs   <- as.vector(vcv[1+14,1+35])
      c_hr_hrsv1 <- as.vector(vcv[1+14,2+35])
      c_hr_hrsv2 <- as.vector(vcv[1+14,3+35])
      c_hr_hrsv3 <- as.vector(vcv[1+14,4+35])
      c_hr_hrsv4 <- as.vector(vcv[1+14,5+35])
      c_hr_hrsv5 <- as.vector(vcv[1+14,6+35])
      c_hr_hrsv6 <- as.vector(vcv[1+14,7+35])}
      
      c_hr <- as.vector(c(c_hr_hrs,c_hr_hrsv1,c_hr_hrsv2,c_hr_hrsv3,c_hr_hrsv4,c_hr_hrsv5,c_hr_hrsv6))
      rm(c_hr_hrs,c_hr_hrsv1,c_hr_hrsv2,c_hr_hrsv3,c_hr_hrsv4,c_hr_hrsv5,c_hr_hrsv6)
      
      #t0_v1
      {c_hrv1_hrs   <- as.vector(vcv[2+14,1+35])
        c_hrv1_hrsv1 <- as.vector(vcv[2+14,2+35])
        c_hrv1_hrsv2 <- as.vector(vcv[2+14,3+35])
        c_hrv1_hrsv3 <- as.vector(vcv[2+14,4+35])
        c_hrv1_hrsv4 <- as.vector(vcv[2+14,5+35])
        c_hrv1_hrsv5 <- as.vector(vcv[2+14,6+35])
        c_hrv1_hrsv6 <- as.vector(vcv[2+14,7+35])}
      
      c_hrv1 <- as.vector(c(c_hrv1_hrs, c_hrv1_hrsv1, c_hrv1_hrsv2, c_hrv1_hrsv3, c_hrv1_hrsv4, c_hrv1_hrsv5, c_hrv1_hrsv6))
      rm(c_hrv1_hrs, c_hrv1_hrsv1, c_hrv1_hrsv2, c_hrv1_hrsv3, c_hrv1_hrsv4, c_hrv1_hrsv5, c_hrv1_hrsv6)
      
      #t0_v2
      {c_hrv2_hrs   <- as.vector(vcv[3+14,1+35])
        c_hrv2_hrsv1 <- as.vector(vcv[3+14,2+35])
        c_hrv2_hrsv2 <- as.vector(vcv[3+14,3+35])
        c_hrv2_hrsv3 <- as.vector(vcv[3+14,4+35])
        c_hrv2_hrsv4 <- as.vector(vcv[3+14,5+35])
        c_hrv2_hrsv5 <- as.vector(vcv[3+14,6+35])
        c_hrv2_hrsv6 <- as.vector(vcv[3+14,7+35])}
      
      c_hrv2 <- as.vector(c(c_hrv2_hrs,c_hrv2_hrsv1, c_hrv2_hrsv2, c_hrv2_hrsv3, c_hrv2_hrsv4, c_hrv2_hrsv5, c_hrv2_hrsv6))
      rm(c_hrv2_hrs,c_hrv2_hrsv1, c_hrv2_hrsv2, c_hrv2_hrsv3, c_hrv2_hrsv4, c_hrv2_hrsv5, c_hrv2_hrsv6)
      
      #t0_v3
      {c_hrv3_hrs   <- as.vector(vcv[4+14,1+35])
        c_hrv3_hrsv1 <- as.vector(vcv[4+14,2+35])
        c_hrv3_hrsv2 <- as.vector(vcv[4+14,3+35])
        c_hrv3_hrsv3 <- as.vector(vcv[4+14,4+35])
        c_hrv3_hrsv4 <- as.vector(vcv[4+14,5+35])
        c_hrv3_hrsv5 <- as.vector(vcv[4+14,6+35])
        c_hrv3_hrsv6 <- as.vector(vcv[4+14,7+35])}
      
      c_hrv3 <- as.vector(c(c_hrv3_hrs,c_hrv3_hrsv1, c_hrv3_hrsv2, c_hrv3_hrsv3, c_hrv3_hrsv4, c_hrv3_hrsv5, c_hrv3_hrsv6))
      rm(c_hrv3_hrs,c_hrv3_hrsv1, c_hrv3_hrsv2, c_hrv3_hrsv3, c_hrv3_hrsv4, c_hrv3_hrsv5, c_hrv3_hrsv6)
      
      #t0_v4
      {c_hrv4_hrs   <- as.vector(vcv[5+14,1+35])
        c_hrv4_hrsv1 <- as.vector(vcv[5+14,2+35])
        c_hrv4_hrsv2 <- as.vector(vcv[5+14,3+35])
        c_hrv4_hrsv3 <- as.vector(vcv[5+14,4+35])
        c_hrv4_hrsv4 <- as.vector(vcv[5+14,5+35])
        c_hrv4_hrsv5 <- as.vector(vcv[5+14,6+35])
        c_hrv4_hrsv6 <- as.vector(vcv[5+14,7+35])}
      
      c_hrv4 <- as.vector(c(c_hrv4_hrs,c_hrv4_hrsv1, c_hrv4_hrsv2, c_hrv4_hrsv3, c_hrv4_hrsv4, c_hrv4_hrsv5, c_hrv4_hrsv6))
      rm(c_hrv4_hrs,c_hrv4_hrsv1, c_hrv4_hrsv2, c_hrv4_hrsv3, c_hrv4_hrsv4, c_hrv4_hrsv5, c_hrv4_hrsv6)
      
      #t0_v5
      {c_hrv5_hrs   <- as.vector(vcv[6+14,1+35])
        c_hrv5_hrsv1 <- as.vector(vcv[6+14,2+35])
        c_hrv5_hrsv2 <- as.vector(vcv[6+14,3+35])
        c_hrv5_hrsv3 <- as.vector(vcv[6+14,4+35])
        c_hrv5_hrsv4 <- as.vector(vcv[6+14,5+35])
        c_hrv5_hrsv5 <- as.vector(vcv[6+14,6+35])
        c_hrv5_hrsv6 <- as.vector(vcv[6+14,7+35])}
      
      c_hrv5 <- as.vector(c(c_hrv5_hrs,c_hrv5_hrsv1, c_hrv5_hrsv2, c_hrv5_hrsv3, c_hrv5_hrsv4, c_hrv5_hrsv5, c_hrv5_hrsv6))
      rm(c_hrv5_hrs,c_hrv5_hrsv1, c_hrv5_hrsv2, c_hrv5_hrsv3, c_hrv5_hrsv4, c_hrv5_hrsv5, c_hrv5_hrsv6)
      
      #t0_v6
      {c_hrv6_hrs   <- as.vector(vcv[7+14,1+35])
        c_hrv6_hrsv1 <- as.vector(vcv[7+14,2+35])
        c_hrv6_hrsv2 <- as.vector(vcv[7+14,3+35])
        c_hrv6_hrsv3 <- as.vector(vcv[7+14,4+35])
        c_hrv6_hrsv4 <- as.vector(vcv[7+14,5+35])
        c_hrv6_hrsv5 <- as.vector(vcv[7+14,6+35])
        c_hrv6_hrsv6 <- as.vector(vcv[7+14,7+35])}
      
      c_hrv6 <- as.vector(c(c_hrv6_hrs,c_hrv6_hrsv1, c_hrv6_hrsv2, c_hrv6_hrsv3, c_hrv6_hrsv4, c_hrv6_hrsv5, c_hrv6_hrsv6))
      rm(c_hrv6_hrs,c_hrv6_hrsv1, c_hrv6_hrsv2, c_hrv6_hrsv3, c_hrv6_hrsv4, c_hrv6_hrsv5, c_hrv6_hrsv6)}
    C_HR_T_HR_TS_G <-  sum(c_hr) + sum(c_hrv1) + sum(c_hrv2) + sum(c_hrv3) + sum(c_hrv4) + sum(c_hrv5) + sum(c_hrv6)
    rm(c_hr,c_hrv1,c_hrv2,c_hrv3,c_hrv4,c_hrv5,c_hrv6)
    
    #Cov(HR Linear Interacted, HR Spline Interacted)
    {#t0 
      {c_hr_hrs   <- as.vector(vcv[1+21,1+35])
      c_hr_hrsv1 <- as.vector(vcv[1+21,2+35])
      c_hr_hrsv2 <- as.vector(vcv[1+21,3+35])
      c_hr_hrsv3 <- as.vector(vcv[1+21,4+35])
      c_hr_hrsv4 <- as.vector(vcv[1+21,5+35])
      c_hr_hrsv5 <- as.vector(vcv[1+21,6+35])
      c_hr_hrsv6 <- as.vector(vcv[1+21,7+35])}
      
      c_hr <- as.vector(c(c_hr_hrs,c_hr_hrsv1,c_hr_hrsv2,c_hr_hrsv3,c_hr_hrsv4,c_hr_hrsv5,c_hr_hrsv6))
      rm(c_hr_hrs,c_hr_hrsv1,c_hr_hrsv2,c_hr_hrsv3,c_hr_hrsv4,c_hr_hrsv5,c_hr_hrsv6)
      
      #t0_v1
      {c_hrv1_hrs   <- as.vector(vcv[2+21,1+35])
        c_hrv1_hrsv1 <- as.vector(vcv[2+21,2+35])
        c_hrv1_hrsv2 <- as.vector(vcv[2+21,3+35])
        c_hrv1_hrsv3 <- as.vector(vcv[2+21,4+35])
        c_hrv1_hrsv4 <- as.vector(vcv[2+21,5+35])
        c_hrv1_hrsv5 <- as.vector(vcv[2+21,6+35])
        c_hrv1_hrsv6 <- as.vector(vcv[2+21,7+35])}
      
      c_hrv1 <- as.vector(c(c_hrv1_hrs, c_hrv1_hrsv1, c_hrv1_hrsv2, c_hrv1_hrsv3, c_hrv1_hrsv4, c_hrv1_hrsv5, c_hrv1_hrsv6))
      rm(c_hrv1_hrs, c_hrv1_hrsv1, c_hrv1_hrsv2, c_hrv1_hrsv3, c_hrv1_hrsv4, c_hrv1_hrsv5, c_hrv1_hrsv6)
      
      #t0_v2
      {c_hrv2_hrs   <- as.vector(vcv[3+21,1+35])
        c_hrv2_hrsv1 <- as.vector(vcv[3+21,2+35])
        c_hrv2_hrsv2 <- as.vector(vcv[3+21,3+35])
        c_hrv2_hrsv3 <- as.vector(vcv[3+21,4+35])
        c_hrv2_hrsv4 <- as.vector(vcv[3+21,5+35])
        c_hrv2_hrsv5 <- as.vector(vcv[3+21,6+35])
        c_hrv2_hrsv6 <- as.vector(vcv[3+21,7+35])}
      
      c_hrv2 <- as.vector(c(c_hrv2_hrs,c_hrv2_hrsv1, c_hrv2_hrsv2, c_hrv2_hrsv3, c_hrv2_hrsv4, c_hrv2_hrsv5, c_hrv2_hrsv6))
      rm(c_hrv2_hrs,c_hrv2_hrsv1, c_hrv2_hrsv2, c_hrv2_hrsv3, c_hrv2_hrsv4, c_hrv2_hrsv5, c_hrv2_hrsv6)
      
      #t0_v3
      {c_hrv3_hrs   <- as.vector(vcv[4+21,1+35])
        c_hrv3_hrsv1 <- as.vector(vcv[4+21,2+35])
        c_hrv3_hrsv2 <- as.vector(vcv[4+21,3+35])
        c_hrv3_hrsv3 <- as.vector(vcv[4+21,4+35])
        c_hrv3_hrsv4 <- as.vector(vcv[4+21,5+35])
        c_hrv3_hrsv5 <- as.vector(vcv[4+21,6+35])
        c_hrv3_hrsv6 <- as.vector(vcv[4+21,7+35])}
      
      c_hrv3 <- as.vector(c(c_hrv3_hrs,c_hrv3_hrsv1, c_hrv3_hrsv2, c_hrv3_hrsv3, c_hrv3_hrsv4, c_hrv3_hrsv5, c_hrv3_hrsv6))
      rm(c_hrv3_hrs,c_hrv3_hrsv1, c_hrv3_hrsv2, c_hrv3_hrsv3, c_hrv3_hrsv4, c_hrv3_hrsv5, c_hrv3_hrsv6)
      
      #t0_v4
      {c_hrv4_hrs   <- as.vector(vcv[5+21,1+35])
        c_hrv4_hrsv1 <- as.vector(vcv[5+21,2+35])
        c_hrv4_hrsv2 <- as.vector(vcv[5+21,3+35])
        c_hrv4_hrsv3 <- as.vector(vcv[5+21,4+35])
        c_hrv4_hrsv4 <- as.vector(vcv[5+21,5+35])
        c_hrv4_hrsv5 <- as.vector(vcv[5+21,6+35])
        c_hrv4_hrsv6 <- as.vector(vcv[5+21,7+35])}
      
      c_hrv4 <- as.vector(c(c_hrv4_hrs,c_hrv4_hrsv1, c_hrv4_hrsv2, c_hrv4_hrsv3, c_hrv4_hrsv4, c_hrv4_hrsv5, c_hrv4_hrsv6))
      rm(c_hrv4_hrs,c_hrv4_hrsv1, c_hrv4_hrsv2, c_hrv4_hrsv3, c_hrv4_hrsv4, c_hrv4_hrsv5, c_hrv4_hrsv6)
      
      #t0_v5
      {c_hrv5_hrs   <- as.vector(vcv[6+21,1+35])
        c_hrv5_hrsv1 <- as.vector(vcv[6+21,2+35])
        c_hrv5_hrsv2 <- as.vector(vcv[6+21,3+35])
        c_hrv5_hrsv3 <- as.vector(vcv[6+21,4+35])
        c_hrv5_hrsv4 <- as.vector(vcv[6+21,5+35])
        c_hrv5_hrsv5 <- as.vector(vcv[6+21,6+35])
        c_hrv5_hrsv6 <- as.vector(vcv[6+21,7+35])}
      
      c_hrv5 <- as.vector(c(c_hrv5_hrs,c_hrv5_hrsv1, c_hrv5_hrsv2, c_hrv5_hrsv3, c_hrv5_hrsv4, c_hrv5_hrsv5, c_hrv5_hrsv6))
      rm(c_hrv5_hrs,c_hrv5_hrsv1, c_hrv5_hrsv2, c_hrv5_hrsv3, c_hrv5_hrsv4, c_hrv5_hrsv5, c_hrv5_hrsv6)
      
      #t0_v6
      {c_hrv6_hrs   <- as.vector(vcv[7+21,1+35])
        c_hrv6_hrsv1 <- as.vector(vcv[7+21,2+35])
        c_hrv6_hrsv2 <- as.vector(vcv[7+21,3+35])
        c_hrv6_hrsv3 <- as.vector(vcv[7+21,4+35])
        c_hrv6_hrsv4 <- as.vector(vcv[7+21,5+35])
        c_hrv6_hrsv5 <- as.vector(vcv[7+21,6+35])
        c_hrv6_hrsv6 <- as.vector(vcv[7+21,7+35])}
      
      c_hrv6 <- as.vector(c(c_hrv6_hrs,c_hrv6_hrsv1, c_hrv6_hrsv2, c_hrv6_hrsv3, c_hrv6_hrsv4, c_hrv6_hrsv5, c_hrv6_hrsv6))
      rm(c_hrv6_hrs,c_hrv6_hrsv1, c_hrv6_hrsv2, c_hrv6_hrsv3, c_hrv6_hrsv4, c_hrv6_hrsv5, c_hrv6_hrsv6)}
    C_HR_T_G_HR_TS_G <-  sum(c_hr) + sum(c_hrv1) + sum(c_hrv2) + sum(c_hrv3) + sum(c_hrv4) + sum(c_hrv5) + sum(c_hrv6)
    rm(c_hr,c_hrv1,c_hrv2,c_hrv3,c_hrv4,c_hrv5,c_hrv6)
    
    #Cov(HR Spline, HR Spline Interacted)
    {#t0 
      {c_hrs_hrsg   <- as.vector(vcv[1+28,1+35])
      c_hrs_hrsgv1 <- as.vector(vcv[1+28,2+35])
      c_hrs_hrsgv2 <- as.vector(vcv[1+28,3+35])
      c_hrs_hrsgv3 <- as.vector(vcv[1+28,4+35])
      c_hrs_hrsgv4 <- as.vector(vcv[1+28,5+35])
      c_hrs_hrsgv5 <- as.vector(vcv[1+28,6+35])
      c_hrs_hrsgv6 <- as.vector(vcv[1+28,7+35])}
      
      c_hr <- as.vector(c(c_hrs_hrsg,c_hrs_hrsgv1,c_hrs_hrsgv2,c_hrs_hrsgv3,c_hrs_hrsgv4,c_hrs_hrsgv5,c_hrs_hrsgv6))
      rm(c_hrs_hrsg,c_hrs_hrsgv1,c_hrs_hrsgv2,c_hrs_hrsgv3,c_hrs_hrsgv4,c_hrs_hrsgv5,c_hrs_hrsgv6)
      
      #t0_v1
      {c_hrsv1_hrsg   <- as.vector(vcv[2+28,1+35])
        c_hrsv1_hrsgv1 <- as.vector(vcv[2+28,2+35])
        c_hrsv1_hrsgv2 <- as.vector(vcv[2+28,3+35])
        c_hrsv1_hrsgv3 <- as.vector(vcv[2+28,4+35])
        c_hrsv1_hrsgv4 <- as.vector(vcv[2+28,5+35])
        c_hrsv1_hrsgv5 <- as.vector(vcv[2+28,6+35])
        c_hrsv1_hrsgv6 <- as.vector(vcv[2+28,7+35])}
      
      c_hrsv1 <- as.vector(c(c_hrsv1_hrsg, c_hrsv1_hrsgv1, c_hrsv1_hrsgv2, c_hrsv1_hrsgv3, c_hrsv1_hrsgv4, c_hrsv1_hrsgv5, c_hrsv1_hrsgv6))
      rm(c_hrsv1_hrsg, c_hrsv1_hrsgv1, c_hrsv1_hrsgv2, c_hrsv1_hrsgv3, c_hrsv1_hrsgv4, c_hrsv1_hrsgv5, c_hrsv1_hrsgv6)
      
      #t0_v2
      {c_hrsv2_hrsg   <- as.vector(vcv[3+28,1+35])
        c_hrsv2_hrsgv1 <- as.vector(vcv[3+28,2+35])
        c_hrsv2_hrsgv2 <- as.vector(vcv[3+28,3+35])
        c_hrsv2_hrsgv3 <- as.vector(vcv[3+28,4+35])
        c_hrsv2_hrsgv4 <- as.vector(vcv[3+28,5+35])
        c_hrsv2_hrsgv5 <- as.vector(vcv[3+28,6+35])
        c_hrsv2_hrsgv6 <- as.vector(vcv[3+28,7+35])}
      
      c_hrsv2 <- as.vector(c(c_hrsv2_hrsg,c_hrsv2_hrsgv1, c_hrsv2_hrsgv2, c_hrsv2_hrsgv3, c_hrsv2_hrsgv4, c_hrsv2_hrsgv5, c_hrsv2_hrsgv6))
      rm(c_hrsv2_hrsg,c_hrsv2_hrsgv1, c_hrsv2_hrsgv2, c_hrsv2_hrsgv3, c_hrsv2_hrsgv4, c_hrsv2_hrsgv5, c_hrsv2_hrsgv6)
      
      #t0_v3
      {c_hrsv3_hrsg   <- as.vector(vcv[4+28,1+35])
        c_hrsv3_hrsgv1 <- as.vector(vcv[4+28,2+35])
        c_hrsv3_hrsgv2 <- as.vector(vcv[4+28,3+35])
        c_hrsv3_hrsgv3 <- as.vector(vcv[4+28,4+35])
        c_hrsv3_hrsgv4 <- as.vector(vcv[4+28,5+35])
        c_hrsv3_hrsgv5 <- as.vector(vcv[4+28,6+35])
        c_hrsv3_hrsgv6 <- as.vector(vcv[4+28,7+35])}
      
      c_hrsv3 <- as.vector(c(c_hrsv3_hrsg,c_hrsv3_hrsgv1, c_hrsv3_hrsgv2, c_hrsv3_hrsgv3, c_hrsv3_hrsgv4, c_hrsv3_hrsgv5, c_hrsv3_hrsgv6))
      rm(c_hrsv3_hrsg,c_hrsv3_hrsgv1, c_hrsv3_hrsgv2, c_hrsv3_hrsgv3, c_hrsv3_hrsgv4, c_hrsv3_hrsgv5, c_hrsv3_hrsgv6)
      
      #t0_v4
      {c_hrsv4_hrsg   <- as.vector(vcv[5+28,1+35])
        c_hrsv4_hrsgv1 <- as.vector(vcv[5+28,2+35])
        c_hrsv4_hrsgv2 <- as.vector(vcv[5+28,3+35])
        c_hrsv4_hrsgv3 <- as.vector(vcv[5+28,4+35])
        c_hrsv4_hrsgv4 <- as.vector(vcv[5+28,5+35])
        c_hrsv4_hrsgv5 <- as.vector(vcv[5+28,6+35])
        c_hrsv4_hrsgv6 <- as.vector(vcv[5+28,7+35])}
      
      c_hrsv4 <- as.vector(c(c_hrsv4_hrsg,c_hrsv4_hrsgv1, c_hrsv4_hrsgv2, c_hrsv4_hrsgv3, c_hrsv4_hrsgv4, c_hrsv4_hrsgv5, c_hrsv4_hrsgv6))
      rm(c_hrsv4_hrsg,c_hrsv4_hrsgv1, c_hrsv4_hrsgv2, c_hrsv4_hrsgv3, c_hrsv4_hrsgv4, c_hrsv4_hrsgv5, c_hrsv4_hrsgv6)
      
      #t0_v5
      {c_hrsv5_hrsg   <- as.vector(vcv[6+28,1+35])
        c_hrsv5_hrsgv1 <- as.vector(vcv[6+28,2+35])
        c_hrsv5_hrsgv2 <- as.vector(vcv[6+28,3+35])
        c_hrsv5_hrsgv3 <- as.vector(vcv[6+28,4+35])
        c_hrsv5_hrsgv4 <- as.vector(vcv[6+28,5+35])
        c_hrsv5_hrsgv5 <- as.vector(vcv[6+28,6+35])
        c_hrsv5_hrsgv6 <- as.vector(vcv[6+28,7+35])}
      
      c_hrsv5 <- as.vector(c(c_hrsv5_hrsg,c_hrsv5_hrsgv1, c_hrsv5_hrsgv2, c_hrsv5_hrsgv3, c_hrsv5_hrsgv4, c_hrsv5_hrsgv5, c_hrsv5_hrsgv6))
      rm(c_hrsv5_hrsg,c_hrsv5_hrsgv1, c_hrsv5_hrsgv2, c_hrsv5_hrsgv3, c_hrsv5_hrsgv4, c_hrsv5_hrsgv5, c_hrsv5_hrsgv6)
      
      #t0_v6
      {c_hrsv6_hrsg   <- as.vector(vcv[7+28,1+35])
        c_hrsv6_hrsgv1 <- as.vector(vcv[7+28,2+35])
        c_hrsv6_hrsgv2 <- as.vector(vcv[7+28,3+35])
        c_hrsv6_hrsgv3 <- as.vector(vcv[7+28,4+35])
        c_hrsv6_hrsgv4 <- as.vector(vcv[7+28,5+35])
        c_hrsv6_hrsgv5 <- as.vector(vcv[7+28,6+35])
        c_hrsv6_hrsgv6 <- as.vector(vcv[7+28,7+35])}
      
      c_hrsv6 <- as.vector(c(c_hrsv6_hrsg,c_hrsv6_hrsgv1, c_hrsv6_hrsgv2, c_hrsv6_hrsgv3, c_hrsv6_hrsgv4, c_hrsv6_hrsgv5, c_hrsv6_hrsgv6))
      rm(c_hrsv6_hrsg,c_hrsv6_hrsgv1, c_hrsv6_hrsgv2, c_hrsv6_hrsgv3, c_hrsv6_hrsgv4, c_hrsv6_hrsgv5, c_hrsv6_hrsgv6)}
    C_HR_TS_HR_TS_G <-  sum(c_hr) + sum(c_hrsv1) + sum(c_hrsv2) + sum(c_hrsv3) + sum(c_hrsv4) + sum(c_hrsv5) + sum(c_hrsv6)
    rm(c_hr,c_hrsv1,c_hrsv2,c_hrsv3,c_hrsv4,c_hrsv5,c_hrsv6)
    
    
    
  } else {
    
    
  }
}


