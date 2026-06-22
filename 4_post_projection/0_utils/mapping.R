#==============================================================================#
# Mapping functions for labor
#
# Original join.plot.map function by Trinetta Chong circa 2019, plot.impact.map 
# by Ruixue Li in 2020, updated by Kate Champion for inequality, last edits from 
# Elliot Grenier in 2025, and Nishka Sharma in 2026
#
# Description:
#
#   These functions together plots the maps in the labor paper.
#
#==============================================================================#

#==============================================================================#
# join.plot.map() documentation ----

# Input:
#   - map.df: the base map to use, it should be a shape file of IR level polygons
#   - df: your data, it should have only one observation per impact region(dataframe with <=24378 rows)
#   - df.key: variable in your dataframe that identifies each spatial unit 
#             this is the columnn that will join df to map.df (string character, default: "region")
#   - map.key: variable in shapefile df that identifies each spatial unit 
#              this is the columnn that will join df to map.df (string character, default: "id")
#   - plot.var: variable to be plotted in map (string character)
#   - topcode: limit color bar and mapping to a specified range of values (default: F)
#   - topcode.ub: value of upper limit on color bar  (numeric,e.g. 0.005 default: NULL)
#   - round.minmax: number of digits to round your minimum/maximum value to (in the caption) (default: 4)
#   - color.scheme: "div" - diverging e.g. negative values in blue to lightgrey for zero to 
#                           positive values in red  (string character, default: blue to grey to red) 
#                   "seq" - sequential, e.g. minimum value in light blue to maximum value in
#                           dark blue (string character, default: blues)
#                   "cat" - categorical e.g. blue for category 1, red for category 2
#                           (string character, default: 2 categories, one in blue, one in red )
#                   "rev" - div but inversed
#                   "revseq" - seq but reversed, colors are shades of green
#   - colorbar.title: title of colorbar (string character)
#   - map.title: title of map (string character)

# Optional Input:
#   - barwidth: how wide the color bar will be (default: 100mm)
#   - topcode.lb: value of lower limit on color bar (numeric, default: -topcode.ub)
#   - rescale_val: scale values for color bar (numeric vector)
#                 "div" - default: `c(topcode.lb, 0, topcode.ub)` middle color takes on the value of zero 
#                 "seq" or "cat" - default: NULL
#   - breaks_labels_val (only for "div" or "seq"): set frequency of ticks on color bar
#                                                  numeric vector, default: `seq(topcode.lb, topcode.ub, topcode.ub/5)`
#   - breaks_labels_val_cat (only for "cat"): label of each factor on color legend string vector, 
#                                             e.g. `c("Group1", "Group2", Group3")` 
#                                             default: `levels(shp_plot$mainvar_lim)`
#   - color.values: colors on color bar
#                   "div" - string vector, default: rev(c("#d7191c", "#fec980", "#ffedaa","grey95", "#e7f8f8", "#9dcfe4", "#2c7bb6"))
#                   "seq" - string vector, default: `c("#2c7bb6", "#d7191c")` ()
#                   "cat" - string vector default: `c("#2c7bb6", "purple4") because Barney
#   - na.color: color of IRs with NA values (string character, default: "grey85")
#   - lakes.color: color of waterbodies on map (string character, default: "white")
#   - minval: a minimum value of the plot variable to be displayed in the caption
#             If no value is provided it will take the minimum of plot.var
#   - minval: a maximum value of the plot variable to be displayed in the caption
#             If no value is provided it will take the maximum of plot.var
#   - avgval: an average value to be displayed in the caption
#             If not inputted will be calculated and displayed.
#==============================================================================#

#==============================================================================#
# plot.impact.map() documentation ----

# Input:
#   - model.name: the model being plotted the base map to use, it should be a shape file of IR level polygons
#   - rcp: rcp the map is being made for. valid values are "rcp45" and "rcp85." 
#          used to read the file and assign title of the map. 
#   - ssp: ssp the map is being made for. valid values are "SSP1", "SSP2", "SSP3", "SSP4", "SSP5".
#          used to read the file and assign title of the map
#   - iam: iam the map is being made for. valid values are "high" and "low". 
#          used to read the file and assign title of the map
#   - adapt: adaptation scenario the map is being made for. valid values are "fulladapt", "incadapt", "noadapt". 
#            used to read the file and assign title of the map
#   - impact: type of impact the map is being made for. used to read the file. 
#             valid values are: "clip" - this variable stores projected share of high risk workers
#                               "rebased" - this variable stores projected impacts in time spent working
#   - aggregation: applicable only if impact is "rebased". default values is "" 
#                  "" - impacts in minutes worked
#                  "-gdp-levels" - impacts as % of GDP
#                  "-pop-levels" - impacts in population weighted minutes
#                  "-wage-levels" - impacts in million dollars
#   - year: the year for which map is being made. used to filter the data and assign title of the map
#   - output.folder: location of the maps
#==============================================================================#

# The CRS needed for the shape files we use
DEFAULT_CRS = glue("+proj=robin +lon_0=0 +x_0=0 +y_0=0 +ellps=WGS84",
                   " +datum=WGS84 +units=m +no_defs")

no_pop_irs = c('ARG.8.244', 'ATA', 'ATF.R3ad2a7b0834665e6', 'AUS.1.1', 'AUS.10.1145',
               'AUS.11.1345', 'AUS.3.112', 'AUS.5.387', 'AUS.5.400', 'AUS.6.687',
               'AUS.7.989', 'AUS.7.995', 'BRA.8.836.1993', 'BRA.8.837.1994', 'BVT',
               'CAN.11.269.4448', 'CAN.2.42.1074', 'CAN.3.58.1374',
               'CAN.9.148.Rd02357429ca755ba', 'CHN.21.226.1500',
               'CHN.30.318.2210.R55b41404d256c30a',
               'CHN.30.318.2210.Rdb1a80fb7e65ef11', 'CL-', 'COL.26.852', 'DOM.19.91',
               'ESP.6.27.191.4867', 'ESP.6.27.192.4868', 'GRL.1.2', 'GRL.2.9',
               'GRL.3.18', 'HMD', 'IDN.14.203', 'IND.12.129.431', 'IND.12.129.432',
               'IND.12.132.460', 'IND.12.134.487', 'IND.2.17.134', 'IND.2.17.135',
               'IND.2.17.136', 'IND.2.17.138', 'IND.2.17.142', 'IND.2.17.143', 'IOT',
               'JPN.37.1512', 'MRT.12.38', 'NZL.10.42.253', 'PER.21.169.1647', 'SGS',
               'SJM.1', 'SP-', 'TWN.2.2', 'ZAF.9.313')

# create plot data
join.plot.map = function(
  map.df = NULL, df = NULL, df.key = "region", map.key = 'hierid',  
  plot.var = NULL, topcode = F, topcode.ub = NULL, topcode.lb = NULL, 
  round.minmax = 4,  color.scheme = NULL, rescale_val = NULL,
  limits_val = NULL, breaks_labels_val = NULL, cities.plot = NULL,
  breaks_labels_val_cat = levels(shp_plot$mainvar_lim), 
  bar.width = unit(100, units = "mm"), lakes.color = "white",
  colorbar.title = NULL, map.title = NULL, na.color = "grey85",
  color.values = NULL, minval = NULL, maxval = NULL, avgval = NULL,
  plot.lakes = F, crosshatch = F, map.crs = DEFAULT_CRS){
  
  df = df %>%
    rename(mainvar = !!sym(plot.var))
  
  map.df = map.df %>% 
    # setting the projection that the ggplot will use
    st_transform(DEFAULT_CRS) %>% 
    # Filtering out Antarctica and Caspian sea because we don't want to plot these IRs
    filter(!(!!sym(map.key) %in% c("CA-", "USA.23.1273", "USA.14.642",
                                   "USA.50.3082", "USA.50.3083", "USA.23.1275",
                                   "USA.15.740", "USA.24.1355", "USA.33.1855",
                                   "USA.36.2089", "USA.23.1272", "UGA.32.80.484",
                                   "UGA.31.79.483.2760", "UGA.32.80.484.2761",
                                   "TZA.13.59.1169", "TZA.5.26.564", "TZA.17.86.1759",
                                   "ATA", "PER.8.71.705", "PER.7.67.677",
                                   "ARM.7", "USA.23.1274", "TZA.8.37.779")))

  df = df %>% mutate(mainvar = ifelse(!!sym(map.key) %in% no_pop_irs, NA, mainvar))
  
  message(glue("Joining data to world shapefile by: {map.key} and {df.key}."))
  shp_plot = left_join(map.df, df, by = setNames(nm = map.key, df.key))
  
  #identify IRs that don't have values
  na.df = dplyr::filter(shp_plot, is.na(mainvar))
  
  #identify IRs with negative values
  neg.df = dplyr::filter(shp_plot, mainvar < 0)
  
  message("setting parameters for plotting...")
  
  #recode limits so it takes max color if it exceeds +-value
  if (topcode) { 
    
    message(glue("plotting topcoded map... Remember to also look at a",
                 "non-topcoded version! Just set topcode=FALSE to do so."))
    
    #if user didn't specify topcode.lb value, set default
    if (is.null(topcode.lb))
      topcode.lb = -topcode.ub
    
    shp_plot$mainvar_lim = squish(
      shp_plot$mainvar, c(topcode.lb, topcode.ub))
    
    limits_val = c(topcode.lb, topcode.ub)
    
    if (is.null(breaks_labels_val))
      breaks_labels_val = seq(
        topcode.lb,
        topcode.ub,
        abs(topcode.ub-topcode.lb)/5)
    
  } else { 
    
    shp_plot$mainvar_lim = shp_plot$mainvar
    
    maxi = max(max(shp_plot$mainvar, na.rm=TRUE))
    mini = min(min(shp_plot$mainvar, na.rm=TRUE))
    
    topcode.ub = ifelse(maxi >= 1, ceiling(maxi), maxi)
    topcode.lb = ifelse(mini <= -1, floor(mini), mini)
    
    bound = max(abs(topcode.ub), abs(topcode.lb))
    
    if (sign(topcode.ub) == sign(topcode.lb) |
        topcode.ub == 0 |
        topcode.lb == 0) {
      
      limits_val = ifelse(
        topcode.ub > 0,
        yes=list(c(0, bound)),
        no=list(c(-bound, 0)))[[1]]
      
      if(is.null(breaks_labels_val))
        breaks_labels_val = ifelse(
          topcode.ub > 0,
          list(seq(0, bound, bound/5)),
          list(seq(-bound, 0, bound/5)))[[1]]
      
    } else {
      limits_val = round(c(-bound, bound), round.minmax)
      
      if (is.null(breaks_labels_val))
        breaks_labels_val = round(
          seq(-bound, bound, 2*bound/5),
          round.minmax)
      
    }     
  }
  
  #set min and max value for caption
  if (is.null(minval))
    minval = round(min(shp_plot$mainvar, na.rm = T), digits = round.minmax) 
  
  if (is.null(maxval))
    maxval = round(max(shp_plot$mainvar, na.rm = T), digits = round.minmax) 
  
  if (is.null(avgval)) {
    avgval = round(mean(shp_plot$mainvar, na.rm = T), digits = round.minmax)
    sdval = round(sd(shp_plot$mainvar, na.rm = T), digits = round.minmax)}
  
  caption_val = if (!is.null(avgval)) {
    glue("Min: {minval}   Avg: {avgval}   SD: {sdval}   Max: {maxval}")} else {
      glue("Min: {minval}   Max: {maxval}")
    }
  
  if (color.scheme=="div") {
    
    #scale value for color bar, middle color "grey95" takes on value ~0  
    if (is.null(color.values))
      color.values = rev(c("#d7191c", "#fec980", "#ffedaa",
                           "grey95", "#e7f8f8", "#9dcfe4", "#2c7bb6"))
    
  } else if (color.scheme=="seq") {
    
    if (is.null(color.values))
      color.values = rev(c("#c92116", "#ec603f", "#fd9b64",
                           "#fdc370", "#fee69b","#fef7d1", "#f0f7d9"))
    
  } else if (color.scheme=="rev") {
    
    color.values = c("#d7191c", "#fec980", "#ffedaa",
                     "grey95", "#e7f8f8", "#9dcfe4", "#2c7bb6")
    
  } else if (color.scheme=="revseq") {
    
    if (is.null(color.values))
      color.values = c("#0d5e0d", "#2d8f2d", "#5cb85c",
                       "#8dd18d", "#b8e6b8", "#ddf3dd", "#f0f9f0")
    
  } else {
    
    if (is.null(color.values))
      color.values = brewer.pal(6, "Set1")
    
    shp_plot$mainvar_lim = as.factor(shp_plot$mainvar_lim)
  }
  
  if (is.null(limits_val))
    limits_val = round(c(minval, maxval), round.minmax)
  
  if (is.null(breaks_labels_val))
    breaks_labels_val = round(
      seq(minval, maxval, abs(maxval)/10),
      round.minmax)
  
  message("Plotting map...")
  
  # Plot map
  p.map = ggplot(data = shp_plot) +
    geom_sf(aes(fill=mainvar_lim), lwd = 0.05, color = NA) + #color = NA removes the borders
    geom_sf(data = na.df, fill = na.color, color = NA) +
    theme_bw() +     
    theme(plot.title = element_text(hjust=0.5, size = 10), 
          plot.caption = element_text(hjust=0.5, size = 7), 
          legend.title = element_text(hjust=0.5, size = 10), 
          legend.position = "bottom",
          legend.text = element_text(size = 7),
          axis.title= element_blank(), 
          axis.text = element_blank(),
          axis.ticks = element_blank(),
          panel.grid = element_blank(),
          panel.border = element_blank()) +   
    labs(title = map.title, caption = caption_val) 
  
  # This feature came with the function
  # We never used it in inequality and when I was swapping to the correct shape file
  # I didn't want to deal with it
  # So I am sorry if you now need it because you'll have to fix it yourself
  # if (crosshatch){
  #   
  #   p.map = p.map +
  #     geom_polygon_pattern(data=neg.df, aes(group=group), pattern='stripe', fill=NA, color=NA,
  #                          pattern_fill=NA, pattern_color="black", size=.01, pattern_density=.01, pattern_spacing=.025, alpha=.2)
  # }
  
  if (plot.lakes){
    
    lakes = ne_download(
      scale = 110,
      type = 'lakes',
      category = 'physical') %>% 
      st_as_sf(map.crs)
    
    p.map = p.map +
      geom_sf(data = lakes, fill = lakes.color, color = NA)
  }
  
  if(color.scheme=="div" | color.scheme=="seq" | color.scheme=="rev" | color.scheme=="revseq"){ 
    p.map = p.map + scale_fill_gradientn(
      colors = color.values,
      values=rescale(rescale_val),
      na.value = na.color,
      limits = limits_val, #center color scale so white is at 0
      breaks = breaks_labels_val, 
      labels = breaks_labels_val, #set freq of tick labels
      guide = guide_colorbar(title = colorbar.title,
                             direction = "horizontal",
                             barheight = unit(4, units = "mm"),
                             barwidth = bar.width,
                             draw.ulim = F,
                             title.position = 'top',
                             title.hjust = 0.5,
                             label.hjust = 0.5))
    
  } else { #color.scheme=="cat"
    
    p.map = p.map + scale_fill_manual( 
      values = color.values,
      name = colorbar.title,
      na.value = na.color, 
      breaks = levels(shp_plot$mainvar_lim), 
      labels = breaks_labels_val_cat) +   
      labs(caption = NULL)  
    
  } 
  
  rm(shp_plot)
  return(p.map)
  
}

# map of overall impact in a year
plot.impact.map = function(model.name, rcp, ssp, iam, adapt, impact, aggregation="", year, output.folder){
  
  if ((ssp=="SSP1" & rcp=="rcp85") | (ssp=="SSP5" & rcp=="rcp45")) {
    print("invalid ssp and rcp combination")
    return()
  }
  
  # browser()
  df= read_csv(glue('{input_path}/{model.name}/{rcp}/{iam}/{ssp}/{ssp}-{rcp}_{iam}_{impact}_{adapt}{aggregation}.csv')) %>%
    filter(year == !!year)
  
  # load shapefile
  mymap = st_read(glue("{ROOT_INT_DATA}/shapefiles/world-combo-new-nytimes/new_shapefile.shp"))
  
  # set rcp for color bar title
  if (rcp == "rcp85"){
    rcp_t <- "RCP8.5"
    
  } else if (rcp == "rcp45") {
    rcp_t <- "RCP4.5"
    
  } else {
    print("enter correct rcp value")
    return()
    
  }
  
  
  if (aggregation == "-pop-levels") {
    plot_title <- "Pop Weighted Impacts - Mins Worked"
    
  } else if (aggregation == "-gdp-levels") {
    plot_title <- glue("Worker disutility costs of climate change (% of {year} GDP, {ssp}-{rcp_t})")
    df_plot <- df %>% dplyr::mutate(mean = -mean * 100) # multiplying by 100 to show impacts as damages in percent of global GDP     
    
    bound = ceiling(max(abs(df_plot$mean), na.rm=TRUE))
    scale_v = c(-1, -0.2, -0.05, -0.005, 0, 0.005, 0.05, 0.2, 1)
    rescale_value <- scale_v*bound
    ub = max(rescale_value,na.rm = TRUE)
    lb = -ub
    # browser()
    breaks_labels = seq(-bound, bound, bound/4)
    color_scheme = "div"
    
  } else if (aggregation == "-wage-levels") {
    plot_title <- glue("Worker disutility costs of climate change in million dollars ({year}, {ssp}-{rcp_t}")
    df_plot <- df %>% dplyr::mutate(mean = -mean/1000000) # multiplying by -1/1000000 to show impacts as damages in million dollars 
    
    bound = ceiling(max(abs(df_plot$mean)))
    scale_v = c(-1, -0.2, -0.05, -0.005, 0, 0.005, 0.05, 0.2, 1)
    rescale_value <- scale_v*bound
    ub = max(rescale_value,na.rm = TRUE)
    lb = -ub
    breaks_labels = seq(-bound, bound, bound/4)
    color_scheme = "div"
    
  } else if (aggregation == "") {
    plot_title <- glue("Change in minutes worked per worker per day due to climate change ({year}, {ssp}-{rcp_t})")
    bound = 30
    df_plot <- df 
    scale_v = c(-1, -0.2, -0.05, -0.005, 0, 0.005, 0.05, 0.2, 1)
    rescale_value <- -scale_v*bound
    ub = max(rescale_value)
    lb = -ub
    breaks_labels = seq(-bound, bound, bound/3)
    color_scheme = "div"
    
  } else {
    print("wrong aggregation!")
    return()
    
  }
  
  if (impact == "clip") {
    plot_title <- "Share of High Risk Workers"
    rescale_value <- seq(0,1,0.2)
    ub = 1
    lb = 0
    breaks_labels = rescale_value
    color_scheme = "seq"
  }
  
  p = join.plot.map(map.df = mymap, 
                    df = df_plot, 
                    df.key = "region", 
                    plot.var = "mean", 
                    topcode = T, 
                    topcode.lb = lb,
                    topcode.ub = ub,
                    breaks_labels_val = breaks_labels,
                    color.scheme = color_scheme, 
                    rescale_val = rescale_value,
                    colorbar.title = plot_title, 
                    map.title = glue("{model.name} \n{ssp}-{rcp}-{iam}-{adapt}-{year}"))
  
  ggsave(glue("{output.folder}/{ssp}-{rcp}_{iam}_{impact}_{adapt}{aggregation}_{year}_map.png"), p, dpi = 300)
  
}
