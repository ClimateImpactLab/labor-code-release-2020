#==============================================================================#
#'
#' This script calculates the disutility associated with a high-risk job in each IR then
#' calculates summary statistics for a table
#' 
#==============================================================================#

#==============================================================================#
# 0. load packages and data ----

packages = c("tidyverse", "data.table", "sf", "scales", "glue", "Hmisc", "knitr", "kableExtra")

invisible(lapply(packages, function(pkg) {
  suppressPackageStartupMessages(library(pkg, character.only = TRUE))
}))
rm(packages)

source('/project/cil/home_dirs/egrenier/repos/labor-code-release-2020/0_subroutines/paths.R')
source(glue('{DIR_REPO_LABOR}/4_post_projection/0_utils/mapping.R'))

# Define spec (cold/hot splits dmgs at 30C)
spec = "main" # takes "cold", "hot", "main"
boxes = F # do we want boxes on the plot? this should prob be deprecated

df = fread('/project/cil/battuta_shares/gcp/estimation/labor/code_release_int_data/climate/final_27_28_41/IMPACT_REGIONS/global/daily/GMFD_IMPACT_REGIONS_tmax_splines_daily_global.csv')
# get main dataset
dfb = fread("/project/cil/gcp/climate/_spatial_data/impactregions/weather_data/csv_daily/GMDF_tmax_temp_and_spline_27_28_41_avg_year.csv") 
dfa = fread("/project/cil/gcp/climate/_spatial_data/impactregions/weather_data/csv_daily/GMDF_tmax_temp_and_spline_avg_year.csv") 
#==============================================================================#
# Data Cleaning ----

if (spec == "cold"){
  dfb = dfb %>% filter(temp <= 30)
  suffix="_cold"
} else if (spec == "hot"){
  dfb = dfb %>% filter(temp > 30)  
  suffix="_hot"
} else {
  dfb = dfb
  suffix=""
}

# FOR WIP - THIS PART OF THE SCRIPT SHOULD BE MUCH BETTER
#   use csvv to extract real coefficients, calculate optimal temp dynamically using quadratic equation?
#   
# These are hardcoded values for the betas from the main uninteracted model (NOW UPDATED!)

# ===== Calculate avg. daily minutes lost (long run values) ===== #
LR_temp = rep(0.0522168777193601, nrow(dfb))
LR_temp_s = rep(-0.003766291485155, nrow(dfb))
HR_temp = rep(3.31519849251338, nrow(dfb))
HR_temp_s = rep(-0.0341593163222949, nrow(dfb))

dfb = cbind(dfb, LR_temp, LR_temp_s, HR_temp, HR_temp_s)

# Define temperatures which maximize our spline function for each worker sector (math was done on pen+paper)
opt_temp_l = 30.1497495086988
opt_temp_h = 33.6877376456275

# # SHIFT THE LR CURVE UPWARDS BY THE DIFF BETWEEN CURVES AT HIGH RISK OPTIMAL TEMP
f_h_t_opt_h = opt_temp_h * HR_temp[1] + ((opt_temp_h - 28)^3 - (opt_temp_h - 28)^3 * (41 - 27) / (41 - 28)) * HR_temp_s[1]
f_l_t_opt_h = opt_temp_h * LR_temp[1] + ((opt_temp_h - 28)^3 - (opt_temp_h - 28)^3 * (41 - 27) / (41 - 28)) * LR_temp_s[1] 
const = f_h_t_opt_h - f_l_t_opt_h

#Predict LS based on temp for each group on actual temp realizations and the optimal temp
dfb$f_h = dfb$temp * dfb$HR_temp + dfb$temp_s * dfb$HR_temp_s
dfb$f_h_opt_h = opt_temp_h * dfb$HR_temp + ((opt_temp_h - 28)^3 - (opt_temp_h - 28)^3 * (41 - 27) / (41 - 28)) * dfb$HR_temp_s

dfb$f_l = dfb$temp * dfb$LR_temp + dfb$temp_s*dfb$LR_temp_s
dfb$f_l_opt_l = opt_temp_l * dfb$LR_temp + ((opt_temp_l - 28)^3 - (opt_temp_l-28)^3 * (41 - 27) / (41 - 28)) * dfb$LR_temp_s

dfb$f_l = dfb$temp * dfb$LR_temp + dfb$temp_s*dfb$LR_temp_s + const 
dfb$f_l_opt_l = opt_temp_h * dfb$LR_temp + ((opt_temp_h - 28)^3 - (opt_temp_h-28)^3 * (41 - 27) / (41 - 28)) * dfb$LR_temp_s + const # shift low risk curve upwards, 

#Calculate each group's daily decrease in LS  relative to its own optimum
dfb$d_h = dfb$f_h - dfb$f_h_opt_h
dfb$d_l = dfb$f_l - dfb$f_l_opt_l

dfb$diff = dfb$d_h - dfb$d_l

# ===== Calculate 2010 wages ===== #
soc_ec = fread("/project/cil/sacagawea_shares/gcp/integration/float32/dscim_input_data/econvars/zarrs/integration-econ-bc39.csv") 

# subset
soc_ec = subset(soc_ec, year == 2010)
soc_ec = subset(soc_ec, model == "OECD Env-Growth") # 'high' iam
soc_ec = subset(soc_ec, ssp == "SSP3")

gdp = subset(soc_ec, select = c(region, gdp, pop, gdppc))

soc_ec$wage = (soc_ec$gdppc * 0.6) / (250 * 6 * 60)

# Merge back into main dataframe
dfb = merge(dfb, soc_ec, by.x = "hierid", by.y = "region", all.x = TRUE, all.y = TRUE, allow.cartesian=TRUE)

# ===== add countries to df ===== #
countries = data.frame(do.call("rbind", strsplit(as.character(dfb$hierid), ".", fixed = TRUE)))
dfb = cbind(dfb, countries$X1)
dfb = dfb %>% rename("ISO" = "countries$X1")
dfb = dfb %>% rename("ISO" = "V2")

# =====  calculate monetized impacts ===== #
dfb$diff_dis = (-1) * (dfb$diff * dfb$wage) / 0.5
dfb$h_dis = (-1) * (dfb$d_h * dfb$wage) / 0.5
dfb$l_dis = (-1) * (dfb$d_l * dfb$wage) / 0.5

# =====  add up results over the full year ===== #
effects = aggregate(cbind(diff, d_h, d_l,diff_dis,h_dis, l_dis) ~ ISO + hierid, data = dfb, FUN = sum)
effects = merge(effects, soc_ec, by.x="hierid", by.y="region", all.x=TRUE, all.y=TRUE, allow.cartesian=TRUE)

# ===== calculate disultility as % of 2010 GDP ===== #
effects$diff_dis_p = ifelse(effects$gdppc != 0, (effects$diff_dis / effects$gdppc) * 100, 0)
effects$h_dis_p = ifelse(effects$gdppc != 0, (effects$h_dis / effects$gdppc) * 100, 0)
effects$l_dis_p = ifelse(effects$gdppc != 0, (effects$l_dis / effects$gdppc) * 100, 0)

#==============================================================================#
# Mapping ----
effects = effects %>% mutate(diff_dis_p = as.numeric(diff_dis_p)) %>% filter(!is.na(diff_dis_p))

map.df = st_read("/project/cil/sacagawea_shares/gcp/regions/world_combo_201710_mockup/agglomerated-world-new-simp100.shp", stringsAsFactors = FALSE) %>%
  st_set_crs(4326) %>%
  st_transform(crs = "+proj=robin +lon_0=0 +x_0=0 +y_0=0 +ellps=WGS84 +datum=WGS84 +units=m +no_defs")

ub = 70
lb = -ub

rescale_val = c(c(1, 3/4, 1/2, 1/3, 1/8, 1/15, 1/100)*lb, 0, c(1/100, 1/15, 1/8, 1/3, 1/2, 3/4, 1)*ub)
#rescale_val = c(0, 1/100, 1/15, 1/8, 1/3, 1/2, 3/4, 1)*ub

breaks_labels_val = c(lb, lb/2, 0, ub/2, ub)
#breaks_labels_val = c(0, ub/2, ub)

p = join.plot.map(map.df = map.df,
                  df = effects,
                  df.key = 'hierid',
                  plot.var = 'diff_dis_p',
                  topcode = TRUE,
                  topcode.lb = lb,
                  topcode.ub = ub,
                  color.scheme = 'div',
                  colorbar.title = "Hedonic value of thermal comfort in a low-risk job (% 2010 Income)",
                  map.title = "",
                  rescale_val = rescale_val,
                  breaks_labels_val = breaks_labels_val,
                  bar.width = unit(130, units = "mm"),
                  plot.lakes = F)

if (boxes){
  p = p +
    # BOXES (comment which regions these are for if I ever run)
    geom_rect(aes(xmin = -88.893717 , xmax = -86.893717 , ymin = 40.813365 , ymax = 42.813365), color = "black", fill = NA, size =0.01)  +
    geom_rect(aes(xmin = 9.716375 , xmax = 11.716375 , ymin = 58.970345 , ymax = 60.970345), color = "black", fill = NA, size =0.01)  +
    geom_rect(aes(xmin = -47.582095 , xmax = -45.582095 , ymin = -24.60702 , ymax = -22.60702), color = "black", fill = NA, size =0.01)  +
    geom_rect(aes(xmin = 115.33405 , xmax = 117.33405 , ymin = 38.954685 , ymax = 40.954685), color = "black", fill = NA, size =0.01)  +
    geom_rect(aes(xmin = 76.08533 , xmax = 78.08533 , ymin = 27.87319 , ymax = 29.87319), color = "black", fill = NA, size =0.01)  +
    geom_rect(aes(xmin = 2.404933 , xmax = 4.404933 , ymin = 5.482383 , ymax = 7.482383), color = "black", fill = NA, size =0.01) 
}

print(p)
ggsave(glue("/project/cil/home_dirs/egrenier/repos/labor-code-release-2020/disutility_ext/outputs/Value_LR_job_map_ag_nonag{suffix}.pdf"), p, bg = "white", width = 8, height = 6)

#==============================================================================#
# Histogram + descriptive stats ----

hist = ggplot(effects, aes(x = diff_dis_p)) +
  geom_hline(yintercept = 0, linetype = 1, linewidth = 0.5) +
  geom_vline(xintercept = 0, linetype = 1, linewidth = 0.5) +
  geom_histogram(fill = "firebrick1", alpha = 0.8, color = "black", bins=50) +
  labs(title = "Histogram of Hedonic values (new estimates)",
       x = "Hedonic value of thermal comfort in a low-risk job (% 2010 Income)",
       y = "Count") +
  theme_bw() +
  theme(panel.grid = element_blank())
print(hist)
ggsave('/project/cil/home_dirs/egrenier/misc/labor/outputs/hedonic_values_histogram_new.pdf', hist)

#==============================================================================#
# Table 4 ----

quants = as.matrix(
  Hmisc::wtd.quantile(x = effects$diff_dis_p, 
                      weights = effects$pop, 
                      probs = c(0.05, 0.1, 0.25,0.5,0.75,0.90, 0.95), 
                      na.rm = TRUE)
)

percs = c("5th", "10th", "25th", "50th", "75th", "90th", "95th")

pw_quants = as.data.frame(cbind(percs,quants))

city_map = c(
  "USA.14.608" = "Chicago",
  "USA.5.221" = "San Francisco",
  "USA.22.1228" = "Boston",
  "DEU.3.12.141" = "Berlin",
  "FRA.11.75" = "France",
  "CHN.6.46.280" = "Guangzhou",
  "CHN.2.18.78" = "Beijing",
  "BGD.3.9.18.132" = "Dhaka",
  "IND.10.121.371" = "Delhi",
  "BRA.25.5212.R3fd4ed07b36dfd9c" = "Sao Paulo",
  "NGA.25.510" = "Lagos",
  "NOR.12.288" = "Oslo",
  "USA.3.101" = "Phoenix (Maricopa County)",
  "IRQ.10.55" = "Baghdad"
)

key_irs = effects %>%
  mutate(city = city_map[hierid]) %>%
  filter(!is.na(city)) %>%
  dplyr::select(city, diff_dis_p, h_dis_p, l_dis_p)

# Mean
mean_val = round(weighted.mean(effects$diff_dis_p, effects$pop, na.rm = TRUE),1)
sd_val = round(sd(effects$diff_dis_p), 1)
percentiles = pw_quants$V2[2:6]
cities = key_irs %>% 
  filter(city %in% c("Sao Paulo", "Delhi", "Chicago", "Oslo", "Baghdad")) %>%
  arrange(factor(city, levels = c("Sao Paulo", "Delhi", "Chicago", "Oslo", "Baghdad")))

table_data = data.frame(row_name = c("Mean", "10th percentile", "25th percentile", "50th percentile", 
                                     "75th percentile", "90th percentile", "São Paulo", "Delhi", 
                                     "Chicago", "Oslo", "Baghdad"),
                        value = c(mean_val, as.numeric(percentiles), cities$diff_dis_p))

kable(table_data, format = "latex", digits = 1, 
      col.names = c("", "Difference"),
      booktabs = TRUE) %>%
  pack_rows("", 1, 6) %>%
  pack_rows("", 7, 11)

