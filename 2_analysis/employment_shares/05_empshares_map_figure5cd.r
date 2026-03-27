#===============================================================================
# FILE:    05_empshares_map_figure5cd.R
#
# PURPOSE:
#   Produce Figure 5, Panels C and D: maps of high-risk worker shares
#   for 2020 and 2099.
#   Employment shares are based on Monte Carlo projection runs under
#   RCP8.5–SSP3-high, using climate-model-weighted averages across 33 models.
#
# INPUT:
#   - Extracted projection CSV:
#       /project/cil/gcp/outputs/labor/impacts-woodwork/montecarlo/extracted/
#       uninteracted_main_model_agnonag_27_28_41/extracted_clip/rcp85/high/
#       SSP3/SSP3-rcp85_high_clip_fulladapt.csv
#   - World shapefile
#
# OUTPUT:
#   - output/employment_shares/figures/
#       figure5c_map_ir_2020.{pdf,png}
#       figure5d_map_ir_2099.{pdf,png}
#===============================================================================

rm(list = ls())

#===============================================================================
# 0) SETUP: PATHS, UTILITIES, PACKAGES
#===============================================================================

user <- Sys.info()[["user"]]

source(paste0(
  "/project/cil/home_dirs/", user,
  "/repos/labor-code-release-2020/0_subroutines/paths.R"
))

source(paste0(
  "/project/cil/home_dirs/", user,
  "/repos/post-projection-tools/mapping/imgcat.R"
))

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(glue)
  library(sf)
  library(scales)
  library(RColorBrewer)
  library(grid)
  library(ggplot2)
})

source(paste0(DIR_REPO_LABOR, "/4_post_projection/0_utils/mapping.R"))

#===============================================================================
# 1) CONFIG
#===============================================================================

# Extracted projection file used for the Figure 5 employment-share maps
in_csv <- paste0(
  "/project/cil/gcp/outputs/labor/impacts-woodwork/montecarlo/extracted/",
  "uninteracted_main_model_agnonag_27_28_41/extracted_clip/rcp85/high/",
  "SSP3/SSP3-rcp85_high_clip_fulladapt.csv"
)

# Output directory inside the labor repo
out_dir <- file.path(DIR_REPO_LABOR, "output", "employment_shares", "figures")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# Figure years corresponding to panels C and D
years_to_plot <- c(2020, 2099)

# Export size
width  <- 8.3
height <- 6.0

#===============================================================================
# 2) LOAD MAP GEOMETRY
#===============================================================================

# Load the standard shapefile used in mapping workflow
mymap <- st_read(
  paste0(ROOT_INT_DATA, "/shapefiles/world-combo-new-nytimes/new_shapefile.shp"),
  quiet = TRUE
)

# Drop Antarctica for presentation purposes
# We do this by filtering out polygons whose representative point is below -60.
lat_pt <- st_coordinates(st_point_on_surface(st_geometry(mymap)))[, 2]
mymap <- mymap[lat_pt > -60, ]

#===============================================================================
# 3) LOAD AND PREPARE EXTRACTED DATA
#===============================================================================

stopifnot(file.exists(in_csv))

df <- read_csv(in_csv, show_col_types = FALSE)

# Required columns from the extracted projection output
stopifnot(all(c("region", "year", "mean") %in% names(df)))

df <- df %>%
  transmute(
    region = as.character(region),
    year   = as.integer(year),
    mean   = as.numeric(mean)
  ) %>%
  filter(year %in% years_to_plot) %>%
  filter(is.finite(mean))

# Some extracted files may store shares as 0-100 rather than 0-1
# If so, convert to proportions for mapping
if (max(df$mean, na.rm = TRUE) > 1.2) {
  df <- df %>%
    mutate(mean = mean / 100)
}

#===============================================================================
# 4) MAP STYLE SETTINGS
#===============================================================================

# Hard bounds for mapped worker shares
bound_share <- 1

# Legend breakpoints shown on the color bar
breaks_share <- c(0, 0.2, 0.4, 0.6, 0.8, 1)

# Nonlinear rescaling used in the legacy map style
rescale_share <- c(0, 0.02, 0.10, 0.25, 0.50, 0.75, 0.90, 0.98, 1.00)

# palette for high-risk share: 
pal_old <- brewer.pal(9, "YlOrRd")

#===============================================================================
# 5) MAP FUNCTION
#===============================================================================

make_map <- function(year0, panel_letter) {
  
  
  
  # Keep one year only and clamp values into the feasible share range [0, 1]
  df_plot <- df %>%
    filter(year == year0) %>%
    transmute(
      region = region,
      mean   = pmin(pmax(mean, 0), 1)
    )
  
  # Build base map using the repo's standard join.plot.map() helper
  p <- join.plot.map(
    map.df = mymap,
    df = df_plot,
    df.key = "region",
    plot.var = "mean",
    topcode = TRUE,
    topcode.lb = 0,
    topcode.ub = bound_share,
    breaks_labels_val = breaks_share,
    color.scheme = "rev",
    rescale_val = rescale_share,
    colorbar.title = "Share of high-risk workers",
    plot.lakes = FALSE,
    map.title = glue("Share of high-risk workers: {year0}")
  ) +
    # Override fill scale to match the old palette / legend style used for
    # this figure. Also keep legend horizontal at the bottom.
    scale_fill_gradientn(
      colours = pal_old,
      limits = c(0, 1),
      oob = squish,
      breaks = breaks_share,
      labels = c("0", "0.2", "0.4", "0.6", "0.8", "1"),
      name = "Share of high-risk workers",
      guide = guide_colorbar(
        direction = "horizontal",
        title.position = "top",
        title.hjust = 0.5,
        barwidth = unit(12, "cm"),
        barheight = unit(0.45, "cm")
      )
    ) +
    # Remove the default caption line with Min/Avg/Var/Max summary stats
    labs(caption = NULL) +
    theme(
      plot.title = element_text(
        face = "bold",
        size = 20,
        hjust = 0.5,
        color = "black"
      ),
      legend.position = "bottom",
      legend.title = element_text(size = 11, color = "black"),
      legend.text = element_text(size = 9, color = "black"),
      plot.caption = element_blank()
    )
  
  # Export both pdf and png versions: 
  out_pdf <- file.path(out_dir, glue("figure5{panel_letter}_map_ir_{year0}.pdf"))
  out_png <- file.path(out_dir, glue("figure5{panel_letter}_map_ir_{year0}.png"))
  
  ggsave(out_pdf, p, width = width, height = height, units = "in")
  ggsave(out_png, p, width = width, height = height, units = "in", dpi = 300)
  
  message(glue("Saved: {out_pdf}"))
  message(glue("Saved: {out_png}"))
}

#===============================================================================
# 6) MAKE FIGURE 5 MAPS
#===============================================================================

make_map(2020, "c")
make_map(2099, "d")

message(glue("Done. Outputs in: {out_dir}"))