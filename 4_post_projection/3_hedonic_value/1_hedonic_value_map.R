#==============================================================================#
#'
#' This script calculates the hedonic value of a temperature controlled 
#' workplace for every impact region. Plots results on a map.
#' 
#==============================================================================#

#==============================================================================#
# 0. load packages and data ----

packages = c("data.table", "tidyverse", "sf", "scales", "glue", "Hmisc", "knitr", "kableExtra")

invisible(lapply(packages, function(pkg) {
  suppressPackageStartupMessages(library(pkg, character.only = TRUE))
}))
rm(packages)

USER = Sys.getenv("USER")
source(glue('/project/cil/home_dirs/{USER}/repos/labor-code-release-2020/0_subroutines/paths.R'))
source(glue('{DIR_REPO_LABOR}/4_post_projection/0_utils/mapping.R'))

# Define spec (cold/hot splits dmgs at 29C)
spec = "hot" # takes "cold", "hot", "main"
cutoff_temp = 29
output = glue("{DIR_FIG}/hedonic_value")
filename = "hedonic_value_map"

#==============================================================================#
# 1. Data Cleaning ----

# read in data
dfb = fread("/project/cil/gcp/climate/_spatial_data/impactregions/weather_data/csv_daily/GMDF_tmax_temp_and_spline_27_28_41_avg_year.csv") 

# ===== subset data depending on plot type ===== #
if (spec == "cold"){
  dfb = dfb %>% mutate(temp = ifelse(temp <= cutoff_temp, temp, NA),
                       temp_s= ifelse(temp <= cutoff_temp, temp_s, NA))
  suffix="_cold"
} else if (spec == "hot"){
  dfb = dfb %>% mutate(temp = ifelse(temp > cutoff_temp, temp, NA),
                       temp_s= ifelse(temp > cutoff_temp, temp_s, NA))
  suffix="_hot"
} else {
  suffix="_main"
}

# ===== Calculate 2010 wages ===== #
soc_ec = fread("/project/cil/sacagawea_shares/gcp/integration/float32/dscim_input_data/econvars/zarrs/integration-econ-bc39.csv") 

# subset
soc_ec = subset(soc_ec, year == 2010)
soc_ec = subset(soc_ec, model == "IIASA GDP") # low iam
soc_ec = subset(soc_ec, ssp == "SSP3")

gdp = subset(soc_ec, select = c(region, gdp, pop, gdppc))

soc_ec$wage = (soc_ec$gdppc * 0.6) / (250 * 6 * 60)

# ===== Calculate avg. daily minutes lost (long run values) ===== #
LR_temp = rep(0.0574303265122028, nrow(dfb))
LR_temp_s = rep(-0.018539409626495, nrow(dfb))
HR_temp = rep(4.71644124663339, nrow(dfb))
HR_temp_s = rep(-0.273863500208779, nrow(dfb))

dfb = cbind(dfb, LR_temp, LR_temp_s, HR_temp, HR_temp_s)

# Define temperatures which maximize our spline function for each worker sector (math was done on pen+paper)
opt_temp_l = 28.0163007177373
opt_temp_h = 30.6378578604641

#Predict LS based on temp for each group on actual temp realizations and the optimal temp
dfb$f_h = dfb$temp * dfb$HR_temp + dfb$temp_s * dfb$HR_temp_s
dfb$f_h_opt_h = opt_temp_h * dfb$HR_temp + ((opt_temp_h - 28)^3 - (opt_temp_h - 28)^3 * (41 - 27) / (41 - 28)) * dfb$HR_temp_s

dfb$f_l = dfb$temp * dfb$LR_temp + dfb$temp_s*dfb$LR_temp_s
dfb$f_l_opt_l = opt_temp_l * dfb$LR_temp + ((opt_temp_l - 28)^3 - (opt_temp_l-28)^3 * (41 - 27) / (41 - 28)) * dfb$LR_temp_s

#Calculate each group's daily decrease in LS  relative to its own optimum
dfb$d_h = dfb$f_h - dfb$f_h_opt_h
dfb$d_l = dfb$f_l - dfb$f_l_opt_l

dfb$diff = dfb$d_h - dfb$d_l

# Merge socioeconomics with main df
dfb = merge(dfb, soc_ec, by.x = "hierid", by.y = "region", all.x = TRUE, all.y = TRUE, allow.cartesian=TRUE)

# add countries to df
dfb = dfb %>% mutate(ISO = sapply(strsplit(as.character(hierid), ".", fixed = TRUE), `[`, 1))

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
# 2. Mapping ----

effects$diff_dis_p = ifelse(is.na(effects$diff_dis_p), 0, effects$diff_dis_p)

map.df = st_read("/project/cil/sacagawea_shares/gcp/regions/world_combo_201710_mockup/agglomerated-world-new-simp100.shp", stringsAsFactors = FALSE) %>%
  st_set_crs(4326) %>%
  st_transform(crs = "+proj=robin +lon_0=0 +x_0=0 +y_0=0 +ellps=WGS84 +datum=WGS84 +units=m +no_defs")

bar_title = switch(spec,
                   main = "Hedonic value of thermal comfort in a low-risk job (% 2010 Income)",
                   cold = "Hedonic value of thermal comfort in a low-risk job on days \u2264 29\u00b0C (% 2010 Income)",
                   hot = "Hedonic value of thermal comfort in a low-risk job on days > 29\u00b0C (% 2010 Income)",
                   stop("Unknown spec: ", spec))

ub = 70
lb = 0

rescale_val = c(0, 1/100, 1/15, 1/8, 1/3, 1/2, 3/4, 1)*ub
breaks_labels_val = c(0, ub/2, ub)

p = join.plot.map(map.df = map.df,
                  df = effects,
                  df.key = 'hierid',
                  plot.var = 'diff_dis_p',
                  topcode = TRUE,
                  topcode.lb = lb,
                  topcode.ub = ub,
                  color.scheme = 'seq',
                  colorbar.title = bar_title,
                  map.title = "",
                  rescale_val = rescale_val,
                  breaks_labels_val = breaks_labels_val,
                  bar.width = unit(130, units = "mm"),
                  plot.lakes = F)

#print(p)
ggsave(glue("{output}/{filename}{suffix}.pdf"), p, device = cairo_pdf, bg = "white", width = 8, height = 6)
