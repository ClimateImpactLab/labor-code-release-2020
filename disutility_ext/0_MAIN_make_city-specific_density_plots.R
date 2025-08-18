library(data.table)
library(dplyr)
library(tidyr)
library(ggplot2)
library(sf)
library(scales)
library(purrr)
library(glue)

regions <- c("BRA.25.5212.R3fd4ed07b36dfd9c", "IND.10.121.371", "USA.14.608", "NOR.12.288", "IRQ.10.55")
spec = "hot"

dfb <- fread("/project/cil/gcp/climate/_spatial_data/impactregions/weather_data/csv_daily/GMDF_tmax_temp_and_spline_avg_year.csv")
dfb <- dfb %>% rename("temp" = "value.x")
dfb <- dfb %>% rename("temp_s" = "value.y")

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
soc_ec <- fread("/project/cil/sacagawea_shares/gcp/integration/float32/dscim_input_data/econvars/zarrs/integration-econ-bc39.csv") 
soc_ec <- subset(soc_ec, year == 2010)
soc_ec <- subset(soc_ec, model == "OECD Env-Growth") # HIGH
soc_ec <- subset(soc_ec, ssp == "SSP3")
soc_ec$wage <- (soc_ec$gdppc*0.6)/(250*6*60)
soc_ec <- subset(soc_ec, select = c(region, wage, gdppc, pop))

# Optimal temps for low risk and high risk workers. 
T_opt_HR <- rep(30.604584663960, nrow(dfb))
T_opt_LR <- rep(29.405891622251, nrow(dfb))

dfb <- cbind(dfb,T_opt_HR,T_opt_LR)

dfb$th <- dfb$temp-dfb$T_opt_HR
dfb$sh <- dfb$temp_s-((dfb$T_opt_HR-27)^3)
dfb$tl <- dfb$temp-dfb$T_opt_LR
dfb$sl <- dfb$temp_s-((dfb$T_opt_LR-27)^3)

dfb <- aggregate(cbind(th,sh,tl,sl) ~ hierid, data = dfb, FUN = sum)

# PULL THESE VALUES FROM CSVV
LR_temp <- rep(0.0535578064558118, nrow(dfb))
LR_temp_s <- rep(-0.0030842488185556, nrow(dfb))
HR_temp <- rep(0.728253378606103, nrow(dfb))
HR_temp_s <- rep(-0.0186831797508809, nrow(dfb))

V_LR_t <- rep(0.0819918449958277, nrow(dfb))
V_LR_s <- rep(0.000012640062144, nrow(dfb))
V_HR_t <- rep(0.502099116740306, nrow(dfb))
V_HR_s <- rep(0.0000455130571283, nrow(dfb))

C_LR_t_LR_s <- rep(-0.0005305917063716, nrow(dfb)) 
C_HR_s_LR_s <- rep(-0.00000192407947997, nrow(dfb))
C_HR_s_LR_t <- rep(0.000013739181147, nrow(dfb))
C_HR_t_LR_s <- rep(-0.000000642546312612, nrow(dfb))
C_HR_t_LR_t <- rep(-0.0005588025662431, nrow(dfb))
C_HR_t_HR_s <- rep(-0.0024133632687671, nrow(dfb))

dfb <- cbind(dfb,LR_temp,LR_temp_s,HR_temp,HR_temp_s,V_LR_t,V_LR_s,V_HR_t,V_HR_s,C_LR_t_LR_s,C_HR_s_LR_s,C_HR_s_LR_t,C_HR_t_LR_s,C_HR_t_LR_t,C_HR_t_HR_s)

countries <- data.frame(do.call("rbind", strsplit(as.character(dfb$hierid), ".", fixed = TRUE)))
dfb <- cbind(dfb, countries$X1)
dfb <- dfb %>% rename("adm0" = "countries$X1")

dfb <- merge(dfb, soc_ec, by.x = "hierid", by.y = "region", all.x = TRUE, all.y = FALSE,allow.cartesian=TRUE)

dfb$a <- ((dfb$wage/0.5)*dfb$th)*(100/dfb$gdppc)
dfb$b <- ((dfb$wage/0.5)*dfb$sh)*(100/dfb$gdppc)
dfb$c <- ((dfb$wage/0.5)*dfb$tl*(-1))*(100/dfb$gdppc)
dfb$d <- ((dfb$wage/0.5)*dfb$sl*(-1))*(100/dfb$gdppc)

dfb$Var <- (dfb$a^2)*V_HR_t + (dfb$b^2)*V_HR_s + (dfb$c^2)*V_LR_t + (dfb$d^2)*V_LR_s + 2*dfb$a*dfb$b*C_HR_t_HR_s + 2*dfb$a*dfb$c*C_HR_t_LR_t + 2*dfb$a*dfb$d*C_HR_t_LR_s + 2*dfb$b*dfb$c*C_HR_s_LR_t + 2*dfb$b*dfb$d*C_HR_s_LR_s + 2*dfb$c*dfb$d*C_LR_t_LR_s
dfb$SE <- (dfb$Var)^(0.5)
regs <- subset(dfb, select = c(hierid,SE))
paper_regs <- subset(regs, hierid %in% regions)

regs$mean <- rep(0, 6)
regs$mean <- ifelse(regs$hierid=="USA.14.608", 4.811770702,regs$mean)
regs$mean <- ifelse(regs$hierid=="NOR.12.288", 6.752073404,regs$mean)
regs$mean <- ifelse(regs$hierid=="BRA.25.5212.R3fd4ed07b36dfd9c", 1.487337269,regs$mean)
regs$mean <- ifelse(regs$hierid=="CHN.2.18.78", 4.084650078,regs$mean)
regs$mean <- ifelse(regs$hierid=="IND.10.121.371", 3.34651299,regs$mean)
regs$mean <- ifelse(regs$hierid=="NGA.25.510", 0.867838715,regs$mean)
#São Paulo
city <- "NGA.25.510"
city_name <- "Lagos"

frame <- subset(regs,hierid == city)
ir_sd <- frame$SE[1]
ir_mean <- frame$mean[1]
set.seed(1)
dense <- as.matrix(rnorm(10000000, mean = ir_mean, sd = ir_sd))
ir_fin_density <- data.frame(density(dense)[c("x", "y")])
kd.color ="grey50"

x_max = 55
x_min = -55


ggplot(ir_fin_density, aes(x, y)) +
  geom_area(fill = kd.color, alpha = .9) + #full distribution #grey
  geom_area(data = subset(ir_fin_density, x < (ir_mean - ir_sd)), fill = "white", alpha = .3) + #1 sd below
  geom_area(data = subset(ir_fin_density, x < (ir_mean - (2*ir_sd))), fill = "white", alpha = .4) + #2 sd below
  geom_area(data = subset(ir_fin_density, x > (ir_mean + ir_sd)), fill = "white", alpha = .3) + #1 sd above
  geom_area(data = subset(ir_fin_density, x > (ir_mean + (2*ir_sd))), fill = "white", alpha = .4) + #2 sd above
  geom_hline(yintercept=0, size=.2, alpha = 0.5) + #zeroline
  geom_vline(xintercept = ir_mean, size=.9, alpha = 1, lty = "solid", color = "white") + #mean line
  #scale_x_continuous(expand=c(0, 0)) +
  theme_bw() +
  theme(panel.grid.major = element_blank(), 
        panel.grid.minor = element_blank(),
        panel.background = element_blank(), 
        axis.line = element_line(colour = "grey80", size = 0.2),
        plot.title = element_text(hjust=0.5, size = 10), 
        plot.caption = element_text(hjust=0.5, size = 7),
        axis.text.x = element_text(size=7, hjust=.5, vjust=.5, face="plain")) +
  xlim(x_min,x_max) +
  ylim(0,0.6) +
  xlab("Disutility Difference - %GDP") + ylab("Density") +
  labs(title = paste0("Kernel Density Plot ", city_name))

ggsave(paste0("/home/rfrost/repos/labor-code-release-2020/disutility_ext/density_",city_name,".png"),width = 7, height = 7)
