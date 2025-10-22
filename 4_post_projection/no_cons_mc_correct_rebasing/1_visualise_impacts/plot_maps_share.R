# main_timeseries_maps.R — calls join.plot.map() from mapping.R

rm(list = ls())

# Paths
source("/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/0_subroutines/paths.R")
source("/project/cil/home_dirs/maiqi/repos/post-projection-tools/mapping/imgcat.R")

# Packages
if (!require("pacman")) install.packages("pacman")
pacman::p_load(ggplot2, dplyr, readr, sf, glue, parallel)

# Load the helper
source(paste0(DIR_REPO_LABOR, "/4_post_projection/0_utils/mapping_ineq.R"))  # <-- the revised file above

# ---------- 1) Read/prepare the shapefile (sf) ----------
# Accepts either directory/basename or full .shp path. Here we pass the .shp explicitly.
MAP_SHP <- file.path("/project/cil/sacagawea_shares/gcp/regions/world_combo_201710_mockup/agglomerated-world-new-simp100.shp")

stopifnot(file.exists(MAP_SHP))
mymap <- sf::st_read(MAP_SHP, quiet = TRUE)
# DEFAULT_CRS <- "+proj=robin +lon_0=0 +x_0=0 +y_0=0 +ellps=WGS84 +datum=WGS84 +units=m +no_defs"

# # Check CRS
# if (is.na(st_crs(mymap))) {
#   cat("Warning: CRS is missing, setting to WGS84 (EPSG:4326)\n")
#   mymap <- mymap %>% st_transform(DEFAULT_CRS)  # WGS84
# } else {
#   cat("Current CRS:", st_crs(mymap)$input, "\n")
# }

# Ensure the join key the shapefile uses (commonly 'hierid') is character
# If your CSV 'region' actually matches ISO, change 'hierid' below to 'ISO'
mymap$hierid <- as.character(mymap$hierid)

# ---------- 2) Plot function wrapper ----------
plot_impact_map <- function(rcp, ssp, iam, adapt, year, risk,
                            aggregation = "", suffix = "",
                            output_folder = DIR_FIG, plot_lakes = TRUE) {
  
  # skip invalid SSP–RCP combos
  if ((ssp == "SSP1" && rcp == "rcp85") || (ssp == "SSP5" && rcp == "rcp45")) {
    message("Invalid SSP–RCP combination; skipping.")
    return(invisible(NULL))
  }
  
  # Read scenario CSV
  csv_path <- glue('{ROOT_INT_DATA}/projection_outputs/extracted_data_mc_figure/',
                   '{ssp}-{rcp}_{iam}_{risk}_{adapt}{aggregation}{suffix}_{year}_map.csv')
  df <- readr::read_csv(csv_path, show_col_types = FALSE)
  
  if ("lowshare" %in% names(df)) {
    df <- df %>% dplyr::rename(mean = lowshare)
  }
  if ("highshare" %in% names(df)) {
    df <- df %>% dplyr::rename(mean = highshare)
  }
  # Title + transform mean if needed
  if (aggregation == "-pop-levels") {
    plot_title <- "Pop Weighted Impacts - Mins Worked"
    df_plot <- df %>% dplyr::mutate(mean = -mean * 100)
    # Diverging scale setupa
    bound <- ceiling(max(abs(df_plot$mean), na.rm = TRUE)); if (!is.finite(bound) || bound == 0) bound <- 1
    scale_v <- c(-1, -0.2, -0.05, -0.005, 0, 0.005, 0.05, 0.2, 1)
    rescale_value <- -scale_v * bound
    ub <- max(rescale_value); lb <- -ub
    breaks_labels <- seq(-bound, bound, by = bound/3)
    color_scheme <- "div"
    
  } else if (aggregation == "-gdp-aggregated") {
    plot_title <- "Damages as Percentage of GDP"
    df_plot <- df %>% dplyr::mutate(mean = -mean * 100)
    bound <- floor(max(abs(df_plot$mean), na.rm = TRUE)); if (!is.finite(bound) || bound == 0) bound <- 1
    # change ceiling to floor to get the scale [-13,13], or it is [-14,14]
    scale_v <- c(-1, -0.2, -0.05, -0.005, 0, 0.005, 0.05, 0.2, 1)
    rescale_value <- scale_v * bound
    ub <- max(rescale_value, na.rm = TRUE); lb <- -ub
    breaks_labels <- seq(-bound, bound, length.out = 5)
    color_scheme <- "div"
    
  } else if (aggregation == "-wage-levels") {
    plot_title <- "Damages in Billion USD"
    df_plot <- df %>% dplyr::mutate(mean = -mean / 1e9)
    bound <- ceiling(max(abs(df_plot$mean), na.rm = TRUE)); if (!is.finite(bound) || bound == 0) bound <- 1
    scale_v <- c(-1, -0.2, -0.05, -0.005, 0, 0.005, 0.05, 0.2, 1)
    rescale_value <- scale_v * bound
    ub <- max(rescale_value, na.rm = TRUE); lb <- -ub
    breaks_labels <- seq(-bound, bound, length.out = 5)
    color_scheme <- "div"
    
  } else if (aggregation == "") {
    plot_title <- "Impacts in Minutes Worked per Worker"
    df_plot <- df
    bound <- 1
    scale_v <- c(-1, -0.2, -0.05, -0.005, 0, 0.005, 0.05, 0.2, 1)
    rescale_value <- -scale_v * bound
    ub <- max(rescale_value); lb <- -ub
    breaks_labels <- seq(-bound, bound, by = bound/3)
    color_scheme <- "div"
    
  } else {
    message("Unknown aggregation; skipping.")
    return(invisible(NULL))
  }
  
  if (risk == "riskshare") {
    rescale_value <- seq(0, 1, 0.2)
    ub <- 1; lb <- 0
    breaks_labels <- rescale_value
    color_scheme <- "seq"
  }
  
  # Ensure data-side key exists and matches type
  df_plot <- df_plot |>
    dplyr::mutate(region = as.character(region)) |>
    dplyr::filter(!is.na(region), region != "", region != "a0", region != 0)
  
  # Make sure output folder exists
  dir.create(output_folder, recursive = TRUE, showWarnings = FALSE)
  
  # Draw map via helper (map.key='hierid', df.key='region')
  p <- join.plot.map(
    map.df = mymap,
    df = df_plot,
    df.key = "region",
    map.key = "hierid",
    plot.var = "mean",
    topcode = TRUE,
    topcode.lb = lb,
    topcode.ub = ub,
    breaks_labels_val = breaks_labels,
    color.scheme = color_scheme,
    rescale_val = rescale_value,
    colorbar.title = plot_title,
    map.title = glue("{ssp}-{rcp}-{iam}-{risk}-{adapt}{aggregation}-{year}"),
    plot.lakes = plot_lakes
  )
  
  
  outfile <- glue("{output_folder}/{ssp}-{rcp}_{iam}_{risk}_{adapt}{aggregation}{suffix}_{year}_map.pdf")
  ggplot2::ggsave(outfile, p, width = 8, height = 5, units = "in")
  message(outfile, " saved.")
}

# ---------- 3) Run the small grid you need ----------
output_folder_mc <- file.path(DIR_FIG, "fig6_maps")
for (yr in c(2099)) {
#  plot_impact_map("rcp85","SSP3","high","fulladapt", yr, "highrisk",
#                  aggregation = "", suffix = "",
#                  output_folder = output_folder_mc, plot_lakes = TRUE)
  
#  plot_impact_map("rcp85","SSP3","high","fulladapt", yr, "lowrisk",
#                  aggregation = "", suffix = "",
#                  output_folder = output_folder_mc, plot_lakes = TRUE)
  plot_impact_map("rcp85","SSP3","low","fulladapt", yr, "lowshare",
                  aggregation = "-gdp-aggregated", suffix = "",
                  output_folder = output_folder_mc, plot_lakes = FALSE)
  
#  plot_impact_map("rcp85","SSP3","low","fulladapt", yr, "rebased",
 #                 aggregation = "-wage-levels", suffix = "",
  #                output_folder = output_folder_mc, plot_lakes = TRUE)
  
#   plot_impact_map("rcp85","SSP3","high","fulladapt", yr, "riskshare",
 #                  aggregation = "", suffix = "",
  #                 output_folder = output_folder_mc, plot_lakes = TRUE)
}

