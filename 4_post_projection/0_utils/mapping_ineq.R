# mapping.R — robust join.plot.map() helper (sf workflow, lakes supported)
# Notes:
# - Works with an sf shapefile (impact regions).
# - Data frame `df` must have ONE row per region.
# - Use explicit df.key / map.key to join (e.g., df.key = "region", map.key = "hierid").

suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
  library(magrittr)
  library(sf)
  library(RColorBrewer)
  library(scales)          # for scales::rescale
  library(rnaturalearth)   # lakes
  library(rnaturalearthdata)
  library(maps)            # world.cities (optional)
})

# Robinson CRS used across CIL maps
DEFAULT_CRS <- "+proj=robin +lon_0=0 +x_0=0 +y_0=0 +ellps=WGS84 +datum=WGS84 +units=m +no_defs"

join.plot.map <- function(
  map.df, df, 
  df.key = "region", map.key = "hierid",
  plot.var,
  topcode = FALSE, topcode.ub = NULL, topcode.lb = NULL,
  round.minmax = 4,
  color.scheme = c("div","seq","cat")[1],
  rescale_val = NULL,
  limits_val = NULL, breaks_labels_val = NULL,
  breaks_labels_val_cat = NULL,
  bar.width = grid::unit(100, "mm"),
  lakes.color = "white",
  colorbar.title = NULL, map.title = NULL, na.color = "grey85",
  color.values = NULL, minval = NULL, maxval = NULL, avgval = NULL,
  plot.lakes = TRUE, crosshatch = FALSE,
  map.crs = DEFAULT_CRS
){
  # --- 0) Input hygiene -------------------------------------------------------
  stopifnot(inherits(map.df, "sf"))
  stopifnot(is.character(df.key), is.character(map.key), is.character(plot.var))
  if (!df.key %in% names(df)) stop("df.key '", df.key, "' not found in df.")
  if (!map.key %in% names(map.df)) stop("map.key '", map.key, "' not found in map.df.")
  if (!plot.var %in% names(df)) stop("plot.var '", plot.var, "' not found in df.")
  
  # make join keys character to avoid factor/number mismatches
  df[[df.key]]     <- as.character(df[[df.key]])
  map.df[[map.key]]<- as.character(map.df[[map.key]])
  
  # --- 1) Prepare map + data --------------------------------------------------
  # Transform to plotting CRS and drop Antarctica / Caspian etc.
  map.df = map.df %>% 
    st_transform(DEFAULT_CRS) %>% 
    filter(!(hierid %in% c("CA-", "USA.23.1273", "USA.14.642",
                           "USA.50.3082", "USA.50.3083", "USA.23.1275",
                           "USA.15.740", "USA.24.1355", "USA.33.1855",
                           "USA.36.2089", "USA.23.1272", "UGA.32.80.484",
                           "UGA.31.79.483.2760", "UGA.32.80.484.2761",
                           "TZA.13.59.1169", "TZA.5.26.564", "TZA.17.86.1759",
                           "ATA", "PER.8.71.705", "PER.7.67.677",
                           "ARM.7", "USA.23.1274", "TZA.8.37.779")))
  
  message(sprintf("Joining data to world shapefile by: %s (map) ~ %s (data).", map.key, df.key))
  shp_plot <- dplyr::left_join(map.df, df, by = setNames(nm = map.key, df.key))
  
  # Main plotting variable (vector assignment, avoids df→vector warning)
  shp_plot$mainvar <- shp_plot[[plot.var]]
  
  na.df  <- dplyr::filter(shp_plot, is.na(mainvar))
  neg.df <- dplyr::filter(shp_plot, !is.na(mainvar) & mainvar < 0)
  
  # --- 2) Limits & breaks -----------------------------------------------------
  if (isTRUE(topcode)) {
    if (is.null(topcode.ub)) stop("topcode.ub must be provided when topcode=TRUE.")
    if (is.null(topcode.lb)) topcode.lb <- -topcode.ub
    message("Plotting TOPCODED map (also inspect a non-topcoded version).")
    
    shp_plot$mainvar_lim <- scales::squish(shp_plot$mainvar, c(topcode.lb, topcode.ub))
    limits_val <- c(topcode.lb, topcode.ub)
    if (is.null(breaks_labels_val)) {
      step <- abs(topcode.ub - topcode.lb)/5
      breaks_labels_val <- seq(topcode.lb, topcode.ub, by = step)
    }
  } else {
    shp_plot$mainvar_lim <- shp_plot$mainvar
    
    maxi <- max(shp_plot$mainvar, na.rm = TRUE)
    mini <- min(shp_plot$mainvar, na.rm = TRUE)
    
    # natural symmetric bound if signs differ; otherwise half-open
    topcode.ub <- ifelse(maxi >= 1, ceiling(maxi), maxi)
    topcode.lb <- ifelse(mini <= -1, floor(mini),  mini)
    bound <- max(abs(topcode.ub), abs(topcode.lb))
    
    if (sign(topcode.ub) == sign(topcode.lb) || topcode.ub == 0 || topcode.lb == 0) {
      limits_val <- if (topcode.ub > 0) c(0, bound) else c(-bound, 0)
      if (is.null(breaks_labels_val)) {
        step <- bound/5
        breaks_labels_val <- if (topcode.ub > 0) seq(0, bound, by = step) else seq(-bound, 0, by = step)
      }
    } else {
      limits_val <- round(c(-bound, bound), round.minmax)
      if (is.null(breaks_labels_val)) {
        breaks_labels_val <- round(seq(-bound, bound, length.out = 5), round.minmax)
      }
    }
  }
  
  # Caption stats
  if (is.null(minval)) minval <- round(min(shp_plot$mainvar, na.rm = TRUE), round.minmax)
  if (is.null(maxval)) maxval <- round(max(shp_plot$mainvar, na.rm = TRUE), round.minmax)
  if (!is.null(avgval)) avgval <- round(avgval, round.minmax)
  
  caption_val <- if (!is.null(avgval)) {
    sprintf("Min: %s   Avg: %s   Max: %s", minval, avgval, maxval)
  } else {
    sprintf("Min: %s   Max: %s", minval, maxval)
  }
  
  # --- 3) Color palette & positions ------------------------------------------
  color.scheme <- match.arg(color.scheme, c("div","seq","cat"))
  
  if (color.scheme == "div") {
    if (is.null(color.values)) {
      color.values <- c("#d7191c","#fec980","#ffedaa","grey95","#e7f8f8","#9dcfe4","#2c7bb6")[7:1]
    }
    if (is.null(rescale_val)) rescale_val <- c(limits_val[1], 0, limits_val[2])
  } else if (color.scheme == "seq") {
    if (is.null(color.values)) {
      color.values <- rev(c("#c92116","#ec603f","#fd9b64","#fdc370","#fee69b","#fef7d1","#f0f7d9"))
    }
    if (is.null(rescale_val)) rescale_val <- limits_val
  } else { # categorical
    if (is.null(color.values)) color.values <- RColorBrewer::brewer.pal(6, "Set1")
    if (is.null(breaks_labels_val_cat)) breaks_labels_val_cat <- levels(as.factor(shp_plot$mainvar_lim))
    shp_plot$mainvar_lim <- as.factor(shp_plot$mainvar_lim)
  }
  
  if (is.null(limits_val)) limits_val <- round(c(minval, maxval), round.minmax)
  if (is.null(breaks_labels_val)) {
    breaks_labels_val <- round(seq(minval, maxval, length.out = 11), round.minmax)
  }
  
  # --- 4) Base map ------------------------------------------------------------
  p.map <- ggplot(shp_plot) +
    geom_sf(aes(fill = mainvar_lim), linewidth = 0.05, color = NA) +
    geom_sf(data = na.df, fill = na.color, color = NA) +
    theme_bw() +
    theme(
      plot.title   = element_text(hjust = 0.5, size = 10),
      plot.caption = element_text(hjust = 0.5, size = 7),
      legend.title = element_text(hjust = 0.5, size = 10),
      legend.position = "bottom",
      legend.text  = element_text(size = 7),
      axis.title   = element_blank(),
      axis.text    = element_blank(),
      axis.ticks   = element_blank(),
      panel.grid   = element_blank(),
      panel.border = element_blank()
    ) +
    labs(title = map.title, caption = caption_val)
  
  # --- 5) Lakes overlay (no vsicurl; uses package data; falls back gracefully)-
  if (isTRUE(plot.lakes)) {
    lakes_sf <- NULL
    pkg_shp <- system.file("shapes/ne_110m_lakes.shp", package = "rnaturalearthdata")
    if (nzchar(pkg_shp) && file.exists(pkg_shp)) {
      lakes_sf <- sf::st_read(pkg_shp, quiet = TRUE)
    } else {
      lakes_sf <- try(
        rnaturalearth::ne_download(scale = 110, type = "lakes", category = "physical",
                                   returnclass = "sf"),
        silent = TRUE
      )
      if (inherits(lakes_sf, "try-error")) lakes_sf <- NULL
    }
    if (!is.null(lakes_sf)) {
      lakes_sf <- lakes_sf |>
        sf::st_make_valid() |>
        sf::st_transform(map.crs)
      p.map <- p.map + geom_sf(data = lakes_sf, fill = lakes.color, color = NA)
    } else {
      warning("Lakes overlay unavailable (no local copy and remote download failed).")
    }
  }
  
  # --- 6) Colorbar ------------------------------------------------------------
  if (color.scheme %in% c("div","seq")) {
    p.map <- p.map + scale_fill_gradientn(
      colors = color.values,
      values = scales::rescale(rescale_val),  # explicit to avoid masking by other packages
      na.value = na.color,
      limits = limits_val,
      breaks = breaks_labels_val,
      labels = breaks_labels_val,
      guide = guide_colorbar(
        title = colorbar.title, direction = "horizontal",
        barheight = grid::unit(4, "mm"), barwidth = bar.width,
        draw.ulim = FALSE, title.position = "top",
        title.hjust = 0.5, label.hjust = 0.5
      )
    )
  } else { # categorical
    p.map <- p.map + scale_fill_manual(
      values = color.values, name = colorbar.title,
      na.value = na.color, breaks = levels(shp_plot$mainvar_lim),
      labels = breaks_labels_val_cat
    ) + labs(caption = NULL)
  }
  
  rm(shp_plot, na.df, neg.df)
  return(p.map)
}

