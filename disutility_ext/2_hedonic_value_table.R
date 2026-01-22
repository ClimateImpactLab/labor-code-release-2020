library(data.table)
library(dplyr)
library(tidyr)
library(ggplot2)
library(sf)
library(scales)
library(purrr)
library(glue)

regions = c("BRA.25.5212.R3fd4ed07b36dfd9c", "IND.10.121.371", "USA.14.608", "NOR.12.288", "IRQ.10.55")
spec = ""

dfb = fread("/project/cil/gcp/climate/_spatial_data/impactregions/weather_data/csv_daily/GMDF_tmax_temp_and_spline_27_28_41_avg_year_approx.csv") 

if (spec == "cold"){
  dfb = dfb %>% filter(temp <= 29)
  suffix="_cold"
} else if (spec == "hot"){
  dfb = dfb %>% filter(temp > 29)  
  suffix="_hot"
} else {
  dfb = dfb
  suffix=""
}

# Calculate 2010 wages
soc_ec = fread("/project/cil/sacagawea_shares/gcp/integration/float32/dscim_input_data/econvars/zarrs/integration-econ-bc39.csv") 
soc_ec = subset(soc_ec, year == 2010)
soc_ec = subset(soc_ec, model == "OECD Env-Growth") # HIGH
soc_ec = subset(soc_ec, ssp == "SSP3")
soc_ec$wage = (soc_ec$gdppc*0.6)/(250*6*60)
soc_ec = subset(soc_ec, select = c(region, wage, gdppc, pop))

# Optimal temps for low risk and high risk workers. 
T_opt_HR = 33.6877376456275
T_opt_LR = 30.1497495086988

dfb$th = dfb$temp - T_opt_HR
dfb$sh = dfb$temp_s - ( (T_opt_HR-28)^3 )
dfb$tl = dfb$temp - T_opt_LR
dfb$sl = dfb$temp_s - ( (T_opt_LR-28)^3 )

dfb = aggregate(cbind(th,sh,tl,sl) ~ hierid, data = dfb, FUN = sum)

# # PULL THESE VALUES FROM CSVV
LR_temp = rep(0.0522168777193601, nrow(dfb))
LR_temp_s = rep(-0.003766291485155, nrow(dfb))
HR_temp = rep(3.31519849251338, nrow(dfb))
HR_temp_s = rep(-0.0341593163222949, nrow(dfb))

V_LR_t = rep(0.0438613090107921, nrow(dfb))
V_LR_s = rep(0.00000690949913838, nrow(dfb))
V_HR_t = rep(2.75376849894228, nrow(dfb))
V_HR_s = rep(0.0001099308320096, nrow(dfb))

C_LR_t_LR_s = rep(-0.0003132970165292, nrow(dfb))
C_HR_s_LR_s = rep(-0.00000330331414617, nrow(dfb))
C_HR_s_LR_t = rep(0.0000197294086379, nrow(dfb))
C_HR_t_LR_s = rep(0.0003146757223405, nrow(dfb))
C_HR_t_LR_t = rep(-0.0012173483103553, nrow(dfb))
C_HR_t_HR_s = rep(-0.0122266319261831, nrow(dfb))

dfb = cbind(dfb,LR_temp,LR_temp_s,HR_temp,HR_temp_s,V_LR_t,V_LR_s,V_HR_t,V_HR_s,C_LR_t_LR_s,C_HR_s_LR_s,C_HR_s_LR_t,C_HR_t_LR_s,C_HR_t_LR_t,C_HR_t_HR_s)

countries = data.frame(do.call("rbind", strsplit(as.character(dfb$hierid), ".", fixed = TRUE)))
dfb = cbind(dfb, countries$X1)
dfb = dfb %>% rename("adm0" = "countries$X1")

dfb = merge(dfb, soc_ec, by.x = "hierid", by.y = "region", all.x = TRUE, all.y = FALSE,allow.cartesian=TRUE)

dfb$a = ((dfb$wage / 0.5) * dfb$th) * (100 / dfb$gdppc)
dfb$b = ((dfb$wage / 0.5) * dfb$sh) * (100 / dfb$gdppc)
dfb$c = ((dfb$wage / 0.5) * dfb$tl * (-1)) * (100 / dfb$gdppc)
dfb$d = ((dfb$wage / 0.5) * dfb$sl * (-1)) * (100 / dfb$gdppc)

dfb$Var = (dfb$a^2)*V_HR_t + (dfb$b^2)*V_HR_s + (dfb$c^2)*V_LR_t + (dfb$d^2)*V_LR_s + 2*dfb$a*dfb$b*C_HR_t_HR_s + 2*dfb$a*dfb$c*C_HR_t_LR_t + 2*dfb$a*dfb$d*C_HR_t_LR_s + 2*dfb$b*dfb$c*C_HR_s_LR_t + 2*dfb$b*dfb$d*C_HR_s_LR_s + 2*dfb$c*dfb$d*C_LR_t_LR_s
dfb$SE = (dfb$Var)^(0.5)
regs = subset(dfb, select = c(hierid,SE))
paper_regs = subset(regs, hierid %in% regions)
sd_val = round(mean(dfb$SE, na.rm = TRUE),1)
