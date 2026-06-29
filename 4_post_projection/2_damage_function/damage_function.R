#========================================================================================#
#' Labor Uninteracted Model MC Damage Function figures
#'
#' Created By: Nishka Sharma; Last change: Maiqi Yu (for 2025 $ adjustment)
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
#'
#' Note: All dollar values (trillion USD on y-axis) are in 2025 dollars.
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

#==================change this section to customise plots======================#
# toggles
# damage scenario ('adding_up', 'risk_aversion')
damage_type = 'adding_up'

# discount type ('constant', 'euler_ramsey')
discount = 'constant'

# elasticity of marginal utility of consumption (denoted by eta (η))
eta = '2.0'

# pure rate of time preference (denoted by rho (ρ))
rho = '0.0'

# Economic modeling scenario
#   'low': "IIASA GDP"
#  'high': "OECD Econ Growth"
iam_in = "high"

# SSP ('SSP2', 'SSP3', 'SSP4')
ssp_in = "SSP3"

# input path to temperature anomalies and damage functions
root = "/project/cil"
points_dir = "/gcp/outputs/labor/impacts-woodwork/montecarlo/extracted/uninteracted_main_model_agnonag_27_28_41/cloud"
damages_dir = "/home_dirs/scadavidsanchez/projects/dscim-labor-2025-update2026/results"
temp_anom_dir = "/sacagawea_shares/gcp/integration/float32/dscim_input_data/climate"
output_dir = "/home_dirs/maiqi/repos/labor-code-release-2020/output/figures/scc"

# CPI-U annual averages (BLS): 2019 = 255.657, 2025 = 319.797
# underlying damage data is in 2019 USD; multiply by this factor to convert to 2025 USD
cpi_2019_to_2025 <- 319.797 / 255.657

#==============================================================================#
# process scatter plot data
df_scatter <- function(rcp, ir){
  df <- read_csv(glue(root, points_dir, "/{ssp_in}-{rcp}_{iam_in}_rebased_fulladapt-wage-aggregated.csv"))
  
  df <- df %>%
    mutate(region = ifelse(is.na(region), "global", region),
           rcp = rcp,
           value = as.numeric(value),
           damages = -value/1e12 * cpi_2019_to_2025) %>% # convert value to damages in trillion 2025 USD
    filter(region == ir)
  
  df <- df %>%
    inner_join(temp_anomaly_2100, by = c("gcm", "year", "rcp"))
}

# process fit and conficence interval data
fit_ci_nc <- function(nc_type, ssp){
  
  # read nc4
  nc <- nc_open(glue(root, damages_dir, "/{nc_type}/AR6_ssp/labor/2020/unmasked/{damage_type}_{discount}_model_collapsed_eta{eta}_rho{rho}_damage_function_fit.nc4"))
  # pull the full variables
  y_hat_raw <- ncvar_get(nc, "y_hat")
  year <- ncvar_get(nc, "year")
  anomaly <- ncvar_get(nc, "anomaly")
  ssp_vals <- ncvar_get(nc, "ssp")
  if (nc_type == "scc_output_full_uncertainty") {
    q <- ncvar_get(nc, "q")
  }
  # close the nc4 file
  nc_close(nc)
  
  # select SSP
  ssp_idx <- which(ssp == ssp)
  
  if (nc_type == "scc_output") {
    # now subset
    y_hat_sub <- y_hat_raw[, , ssp_idx]  # shape: [281 x 100]
    
    # build tidy dataframe 
    df <- expand.grid(year = year, anomaly = anomaly) %>%
      mutate(y_hat = as.vector(y_hat_sub)/1e12 * cpi_2019_to_2025) # convert damages to trillion 2025 USD
    
  } else if (nc_type == "scc_output_full_uncertainty") {
    # select confidence interval quantiles
    q05_idx <- which(q == 0.05)
    q95_idx <- which(q == 0.95) 
    
    # now subset
    y_hat_q05_sub <- y_hat_raw[, q05_idx, , ssp_idx]
    y_hat_q95_sub <- y_hat_raw[, q95_idx, , ssp_idx]
    
    # build tidy dataframe 
    df <- expand.grid(year = year, anomaly = anomaly) %>%
      # convert damages to trillion 2025 USD
      mutate(y_hat_q05 = as.vector(y_hat_q05_sub)/1e12 * cpi_2019_to_2025,
             y_hat_q95 = as.vector(y_hat_q95_sub)/1e12 * cpi_2019_to_2025)
    
  } else {
    stop("specify nc_type")
  }
  
}
#==============================================================================#
# --- prep data ------
# 2100 scatter points
temp_anomaly_2100 <- read_csv(glue(root, temp_anom_dir, "/GMTanom_all_temp_2001_2010_smooth.csv"))

df_scatter_85 <- df_scatter("rcp85", "global")
df_scatter_45 <- df_scatter("rcp45", "global")

# 2200 scatter points
nc_fair <- nc_open(glue(root, "/gcp/integration/gmst_94k_2025p.nc4"))
# pull the full variables
fair_years <- ncvar_get(nc_fair, "year")
fair_rcps  <- ncvar_get(nc_fair, "rcp")
fair_temps_raw <- ncvar_get(nc_fair, "control_temperature")
# close the file
nc_close(nc_fair)

# select which years to keep
year_idx <- which(fair_years %in% c(2180:2200))
rcp45_idx <- which(fair_rcps == "rcp45")
rcp85_idx <- which(fair_rcps == "rcp85")

# FAIR temperatures are relative to preindustrial - convert to 2001-2010 baseline
# fair_temps_raw dimensions: [year, rcp, simulation]
# Compute mean over 2001-2010 for each simulation and RCP
baseline_year_idx <- which(fair_years >= 2001 & fair_years <= 2010)
cat("Baseline years (2001-2010): indices", min(baseline_year_idx), "-", max(baseline_year_idx), "\n")

# Compute baseline mean for each [rcp, simulation] combination
# Result: [rcp, simulation]
fair_baseline <- apply(fair_temps_raw[baseline_year_idx, , , drop = FALSE], c(2, 3), mean, na.rm = TRUE)
cat("Baseline shape: [", paste(dim(fair_baseline), collapse = ", "), "]\n")

# Subtract baseline from all years (broadcast over year dimension)
# fair_temps_raw is [year, rcp, simulation], fair_baseline is [rcp, simulation]
fair_temps <- sweep(fair_temps_raw, c(2, 3), fair_baseline, "-")

fair_2200_rcp45 <- as.vector(fair_temps[year_idx, rcp45_idx, ])
fair_2200_rcp85 <- as.vector(fair_temps[year_idx, rcp85_idx, ])
fair_2200_rcp45 <- fair_2200_rcp45[is.finite(fair_2200_rcp45)]
fair_2200_rcp85 <- fair_2200_rcp85[is.finite(fair_2200_rcp85)]

# create tidy dataframe
temp_anomaly_2200 <- bind_rows(
  tibble(temp = fair_2200_rcp45, rcp = "RCP4.5"),
  tibble(temp = fair_2200_rcp85, rcp = "RCP8.5")
)

# fit and uncertainty data
df_fit <- fit_ci_nc(nc_type = "scc_output", ssp = ssp_in)
df_ci <- fit_ci_nc(nc_type = "scc_output_full_uncertainty", ssp = ssp_in)

# --- plot ------
# panel A
p_top <- ggplot() +
  # quantile band
  geom_ribbon(data = df_ci %>%
                filter(year == 2099,
                       anomaly <= 10),
              aes(x = anomaly, ymin = y_hat_q05, ymax = y_hat_q95,
                  fill = "5th - 95th percentile range"),
              alpha = 0.15, linewidth = 0) +
  # scatter: rcp85
  geom_point(data = df_scatter_85 ,
             aes(x = temp, y = damages), 
             color = "#F30B0B", fill = "#F30B0B",
             alpha = 0.5, size = 0.6, shape = 16) +
  # scatter: RCP 4.5
  geom_point(data = df_scatter_45,
             aes(x = temp, y = damages),
             color = "#0587B5", fill = "#0587B5",
             alpha = 0.5, size = 0.6, shape = 21) +
  # fit line
  geom_line(data = df_fit %>% 
              filter(year == 2099, 
                     anomaly <= 10),
            aes(x = anomaly, y = y_hat, color = "End of century damage function"),
            linewidth = 1) +
  # reference line
  geom_hline(yintercept = 0, linewidth = 0.2) +
  scale_color_manual(name = NULL,
                     values = c("End of century damage function" = "black")) +
  scale_fill_manual(name = NULL,
                    values = c("5th - 95th percentile range" = "gray75")) +
  coord_cartesian(xlim = c(0, 10), ylim = c(0,50)) +
  scale_x_continuous(breaks = 0:10) +
  scale_y_continuous(breaks = seq(0, 50, by = 10)) +
  labs(x = NULL,
       y = "Global damages (trillion USD)") +                                                                                  
  theme_classic() +
  theme(legend.position = "inside",
        legend.position.inside = c(0.20, 0.95),
        legend.justification = c("left", "top"),
        legend.text = element_text(size = 12),
        legend.key.width = unit(1.5, "cm"),
        axis.text.x = element_blank(),
        axis.ticks.x = element_blank(),
        axis.text.y = element_text(size = 12),
        axis.title.y = element_text(size = 12),
        plot.margin = margin(5.5, 0, 0, 5.5)) # set right and bottom margin to zero
       

p_bottom <- temp_anomaly_2100 %>%
  filter(year >= 2080, year <= 2100, temp <= 10) %>%
  ggplot(aes(x = temp, color = rcp)) + 
  geom_density(bw = 0.4, trim = TRUE, kernel = "epanechnikov") + # add kernel = "epanechnikov" to replicate old plot exactly
  scale_color_manual( values = c("rcp45" = "#0587B5", "rcp85" = "#F30B0B"),
                      labels = c("rcp45" = "RCP 4.5", "rcp85" = "RCP 8.5")) +
  coord_cartesian(xlim = c(0, 10)) +
  scale_x_continuous(breaks = 0:10) +
  scale_y_continuous(expand = expansion(mult = c(0.3, 0.1))) + 
  # geom_hline(yintercept = 0, linewidth = 0.2) +
  labs(x = "Global mean temperature rise \n(degrees above 2000-2010 levels)",
       y = NULL,
       color = NULL) +
  theme_classic() +
  theme(panel.background = element_rect(fill = "gray93"),
        axis.text.y = element_blank(),
        axis.ticks.y = element_blank(),
        axis.text.x = element_text(size = 12),
        axis.title.x = element_text(size = 12),
        plot.margin = margin(0, 0, 5.5, 5.5)) + # set top and right margin to zero
  guides(color = "none")

panel_A <- p_top / p_bottom + plot_layout(heights = c(5, 1))

# panel B
# remove unsupported observations
ref_anom <- temp_anomaly_2100 %>%
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
            color = "#e69138", linewidth = 0.8) +
  # ppst 2100 extrapolated fit line
  geom_line(data = df_fit %>% filter(year %in% c(2150, 2200, 2250, 2300),
                                     anomaly <= 10),
            aes(x = anomaly, y = y_hat, group = year),
            color = "gray70", linewidth = 0.8) +
  # 2100 line
  geom_line(data = df_fit %>% filter(year == 2100,
                                     anomaly <= 10),
            aes(x = anomaly, y = y_hat),
            color = "black", linewidth = 1) +
  # reference line
  geom_hline(yintercept = 0, linewidth = 0.2) +
  coord_cartesian(xlim = c(0, 10), ylim = c(0,50)) +
  scale_x_continuous(breaks = 0:10) +
  scale_y_continuous(breaks = seq(0, 50, by = 10)) +
  labs(x = NULL,
       y = "Global damages (trillion USD)") +                                                                                  
  theme_classic() +
  theme(axis.text.x = element_blank(),
        axis.ticks.x = element_blank(),
        axis.text.y = element_text(size = 12),
        axis.title.y = element_text(size = 12),
        plot.margin = margin(5.5, 5.5, 0, 5.5)) # set bottom margin to zero

p_bottom <- temp_anomaly_2200 %>%
  # filter(year >= 2080, year <= 2100, temp <= 10) %>%
  ggplot(aes(x = temp, color = rcp)) +
  geom_density(bw = 0.4, trim = TRUE, kernel = "epanechnikov") + # add kernel = "epanechnikov" to replicate old plot exactly
  scale_color_manual( values = c("RCP4.5" = "#0587B5", "RCP8.5" = "#F30B0B"),
                      labels = c("RCP4.5" = "RCP 4.5", "RCP8.5" = "RCP 8.5")) +
  coord_cartesian(xlim = c(0, 10)) +
  scale_x_continuous(breaks = 0:10) +
  scale_y_continuous(expand = expansion(mult = c(0.3, 0.1))) + 
  # geom_hline(yintercept = 0, linewidth = 0.2) +
  labs(x = "Global mean temperature rise \n(degrees above 2000-2010 levels)",
       y = NULL,
       color = NULL) +
  theme_classic() +
  theme(panel.background = element_rect(fill = "gray93"),
        axis.text.y = element_blank(),
        axis.ticks.y = element_blank(),
        axis.text.x = element_text(size = 12),
        axis.title.x = element_text(size = 12),
        plot.margin = margin(0, 5.5, 5.5, 5.5)) + # set top margin to zero
  guides(color = "none")

panel_B <- p_top / p_bottom + plot_layout(heights = c(5, 1))

figH1 <- wrap_elements(panel_A) + wrap_elements(panel_B)

ggsave(glue(root, output_dir, "/damage_functions.png"), figH1, width = 12, height = 6, dpi = 300)
