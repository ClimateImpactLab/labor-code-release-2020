#========================================================================================#
#' Labor Uninteracted Model MC Damage Function figures
#'
#' Created By: Nishka Sharma
#' Date Created: March 13 2026
#'
#' Produces:
#'   - Figure H.1A | Damage Function (2099 damages function in trillion USD, 
#'                   their spread, and GMST anomalies in 2100)
#'   - Figure H.1B | Damage Function (pre-2099, 2099, and post-2099 damage 
#'                   functions in trillion USD and GMST anomalies in 2200)
#'
#' How To Run:
#'   - Items under "change this section to customise plots" control what is plotted 
#=========================================================================================#

#==============================================================================#
packages = c("ggplot2", "dplyr", "magrittr", "readr", "RColorBrewer", 
             "glue", "scales", "parallel", "ncdf4", "patchwork")

message(" ---- loading packages ---- ")
invisible(lapply(packages, function(pkg) {
  suppressPackageStartupMessages(library(pkg, character.only = TRUE))
}))

rm(packages)

#==============================================================================#
# get user and source paths
USER = Sys.getenv("USER")
source(glue("/project/cil/home_dirs/{USER}/repos/labor-code-release-2020/0_subroutines/paths.R"))

# source labor utils/functions.
# Rfiles = Sys.glob(glue("{DIR_REPO_LABOR}", "/4_post_projection/0_utils/*.R"))
# Rfiles = Rfiles[!mapply(x=Rfiles, grepl, MoreArgs=list(pattern='load_utils'))]
# null = lapply(Rfiles, source)

#==================change this section to customise plots======================#
# toggles
# Part1 = TRUE # Impact Map
# Part2 = TRUE # Decile Plot
# Part3 = TRUE # Time Series
# Appendix = TRUE # Appendix F, G figures.

# damage scenario ('adding_up', 'risk_aversion')
damage_type = 'adding_up'

# discount type ('constant', 'euler_ramsey')
discount = 'constant'

# elasticity of marginal utility of consumption (denoted by eta (η))
eta = '2.0'

# pure rate of time preference (denoted by rho (ρ))
rho = '0.0'

# # Economic modeling scenario
# #   'low': "IIASA GDP"
# #  'high': "OECD Econ Growth"
# iam = 'OECD Econ Growth'
# 
# # SSP ('SSP2', 'SSP3', 'SSP4')
# ssp = 'SSP3'

# input path to temperature anomalies and damage functions
root = "/project/cil"
points_dir = "/gcp/outputs/labor/impacts-woodwork/montecarlo/extracted/uninteracted_main_model_agnonag_27_28_41/cloud"
damages_dir = "/battuta_shares/gcp/integration_replication/results/AR6_ssp/labor/2020"
temp_anom_dir = "/sacagawea_shares/gcp/integration/float32/dscim_input_data/climate"

#==============================================================================#
# read csv files
gmst_anomaly <- read_csv(glue(root, temp_anom_dir, "/GMTanom_all_temp_2001_2010_smooth.csv"))

# process scatter plot data
# RCP8.5
df_scatter_85 <- read_csv(glue(root, points_dir, "/SSP3-rcp85_high_rebased_fulladapt-wage-aggregated.csv"))

df_scatter_85 <- df_scatter_85 %>%
  mutate(region = ifelse(is.na(region), "global", region),
         rcp = "rcp85",
         value = as.numeric(value),
         damages = -value/1e12) %>% # convert value to damages in trillion USD
  filter(region == "global")

df_scatter_85 <- df_scatter_85 %>%
  inner_join(gmst_anomaly, by = c("gcm", "year", "rcp"))

# RCP4.5
df_scatter_45 <- read_csv(glue(root, points_dir, "/SSP3-rcp85_high_rebased_fulladapt-wage-aggregated.csv"))

df_scatter_45 <- df_scatter_45 %>%
  mutate(region = ifelse(is.na(region), "global", region),
         rcp = "rcp45",
         value = as.numeric(value),
         damages = -value/1e12) %>% # convert value to damages in trillion USD
  filter(region == "global")

df_scatter_45 <- df_scatter_45 %>%
  inner_join(gmst_anomaly, by = c("gcm", "year", "rcp"))

# process damage_fit netcdf file
nc <- nc_open(glue(root, damages_dir, "/{damage_type}_{discount}_eta{eta}_rho{rho}_damage_function_fit.nc4"))

# check dimensions order
nc$var$y_hat$dim # array is shaped [year=281, anomaly=100, model=2, ssp=3, discount_type=1]

# extract dimension values
year <- ncvar_get(nc, "year")      # length 281
anomaly <- ncvar_get(nc, "anomaly")   # length 100
model <- ncvar_get(nc, "model")     # "IIASA GDP" (low), "OECD Env-Growth" (high)
ssp <- ncvar_get(nc, "ssp")       # "SSP2", "SSP3", "SSP4"
discount_type <- ncvar_get(nc, "discount_type")  # "constant"

# find indices for .sel({'model': 'IIASA GDP', 'ssp': 'SSP3'})
model_idx <- which(model == "OECD Env-Growth")  # 1
ssp_idx <- which(ssp == "SSP3")        # 2

# pull the full variables then subset
# dim order in R: [year, anomaly, model, ssp, discount_type]
y_hat_raw <- ncvar_get(nc, "y_hat")
y_hat_sub <- y_hat_raw[, , model_idx, ssp_idx]  # shape: [281 x 100]

# y_hat_q05_raw <- ncvar_get(nc, "y_hat_q05")
# y_hat_q05_sub <- y_hat_q05_raw[, , model_idx, ssp_idx]
# 
# y_hat_q95_raw <- ncvar_get(nc, "y_hat_q95")
# y_hat_q95_sub <- y_hat_q95_raw[, , model_idx, ssp_idx]

nc_close(nc)

# build tidy dataframe 
df_fit <- expand.grid(year = year, anomaly = anomaly) %>%
  # convert damages to trillion USD
  mutate(y_hat = as.vector(y_hat_sub)/1e12,
         # ,
         # y_hat_q05 = as.vector(y_hat_q05_sub)/1e12,
         # y_hat_q95 = as.vector(y_hat_q95_sub)/1e12
         )

# --- Plot ---
# panel A
p_top <- ggplot() +
  # quantile band
  geom_ribbon(data = df_fit %>%
                filter(year == 2099,
                       anomaly <= 10),
              aes(x = anomaly, ymin = y_hat_q05, ymax = y_hat_q95,
                  fill = "5th - 95th percentile range"),
              alpha = 0.15, linewidth = 0) +
  # scatter: rcp85
  geom_point(data = df_scatter_85 ,
             aes(x = temp, y = damages), 
             color = "tomato2", fill = "tomato2",
             alpha = 0.8, size = 1.2, shape = 16) +
  # scatter: RCP 4.5
  geom_point(data = df_scatter_45,
             aes(x = temp, y = damages),
             color = "#4472C4", fill = "#4472C4",
             alpha = 0.8, size = 1.2, shape = 21) +
  # fit line
  geom_line(data = df_fit %>% 
              filter(year == 2099, 
                     anomaly <= 10),
            aes(x = anomaly, y = y_hat, color = "End of century damage function"),
            linewidth = 0.8) +
  # reference line
  geom_hline(yintercept = 0, linewidth = 0.2) +
  scale_color_manual(name = NULL,
                     values = c("End of century damage function" = "black")) +
  scale_fill_manual(name = NULL,
                    values = c("5th - 95th percentile range" = "gray50")) +
  coord_cartesian(xlim = c(0, 10), ylim = c(0,100)) +
  scale_x_continuous(breaks = 0:10) +
  scale_y_continuous(breaks = seq(0, 100, by = 10)) +
  labs(x = NULL,
       y = "Global damages (trillion USD)") +                                                                                  
  theme_classic() +
  theme(legend.position = "inside",
        legend.position.inside = c(0.10, 0.95),
        legend.justification = c("left", "top"),
        axis.text.x = element_blank(),
        axis.ticks.x = element_blank(),
        plot.margin = margin(5.5, 5.5, 0, 5.5)) 

p_bottom <- gmst_anomaly %>%
  filter(year >= 2080, year <= 2100, temp <= 10) %>%
  ggplot(aes(x = temp, color = rcp)) +
  geom_density(bw = 0.4, trim = TRUE) +
  scale_color_manual( values = c("rcp45" = "#4472C4", "rcp85" = "red"),
                      labels = c("rcp45" = "RCP 4.5", "rcp85" = "RCP 8.5")) +
  coord_cartesian(xlim = c(0, 10)) +
  scale_x_continuous(breaks = 0:10) +
  labs(x = "Global mean temperature rise \n(degrees above 2000-2010 levels)",
       y = NULL,
       color = NULL) +
  theme_classic() +
  theme(panel.background = element_rect(fill = "gray90"),
        axis.text.y = element_blank(),
        axis.ticks.y = element_blank(),
        plot.margin = margin(0, 5.5, 5.5, 5.5))

panel_A <- p_top / p_bottom + plot_layout(heights = c(3, 1))

# panel B
# remove unsupported observations
ref_anom <- gmst_anomaly %>%
  group_by(year) %>%
  summarise(min_anom = round(min(temp, na.rm = TRUE), 0.1),
            max_anom = round(max(temp, na.rm = TRUE), 0.1))
  
df_fit <- df_fit %>%
  left_join(ref_anom, by = c("year")) 

df_fit <- df_fit %>%
  mutate(y_hat = ifelse(year < 2100 & anomaly < min_anom | year < 2100 & anomaly > max_anom, NA, y_hat))

p_top <- ggplot() +
  # pre 2100 fit line
  geom_line(data = df_fit %>% 
              filter(year %in% seq(2015, 2099, by = 10),
                     anomaly <= 10),
            aes(x = anomaly, y = y_hat, group = year),
            color = "#e69138", linewidth = 1) +
  # ppst 2100 extrapolated fit line
  geom_line(data = df_fit %>% filter(year %in% c(2150, 2200, 2250, 2300),
                                     anomaly <= 10),
            aes(x = anomaly, y = y_hat, group = year),
            color = "gray70", linewidth = 1) +
  # 2100 line
  geom_line(data = df_fit %>% filter(year == 2100,
                                     anomaly <= 10),
            aes(x = anomaly, y = y_hat),
            color = "black", linewidth = 1) +
  # reference line
  geom_hline(yintercept = 0, linewidth = 0.2) +
  coord_cartesian(xlim = c(0, 10), ylim = c(0,100)) +
  scale_x_continuous(breaks = 0:10) +
  scale_y_continuous(breaks = seq(0, 100, by = 10)) +
  labs(x = NULL,
       y = "Global damages (trillion USD)") +                                                                                  
  theme_classic() +
  theme(axis.text.x = element_blank(),
        axis.ticks.x = element_blank(),
        plot.margin = margin(5.5, 5.5, 0, 5.5)) 

p_bottom <- gmst_anomaly %>%
  filter(year >= 2180, year <= 2200, temp <= 10) %>%
  ggplot(aes(x = temp, color = rcp)) +
  geom_density(bw = 0.4, trim = TRUE) +
  scale_color_manual( values = c("rcp45" = "#4472C4", "rcp85" = "red"),
                      labels = c("rcp45" = "RCP 4.5", "rcp85" = "RCP 8.5")) +
  coord_cartesian(xlim = c(0, 10)) +
  scale_x_continuous(breaks = 0:10) +
  labs(x = "Global mean temperature rise \n(degrees above 2000-2010 levels)",
       y = NULL,
       color = NULL) +
  theme_classic() +
  theme(panel.background = element_rect(fill = "gray90"),
        axis.text.y = element_blank(),
        axis.ticks.y = element_blank(),
        plot.margin = margin(0, 5.5, 5.5, 5.5))

panel_B <- p_top / p_bottom + plot_layout(heights = c(3, 1))
