#==============================================================================#
# Timeseries plot functions for labor
#
# Created by Nishka Sharma in 2026
#
# Description:
#
#   These functions plot the global timeseries of impacts from labor MCs in 
#   figures 8A, 8B, G.2A, and G.2B of the labor paper
#
#==============================================================================#

#==============================================================================#
# All functions have similar inputs, the superset of inputs are described below

# Input:
#   - input.path: path to input data. declared globally outside of functions
#   - model.name: the model being plotted the base map to use, it should be a 
#                 shape file of IR level polygons
#   - rcp: rcp the map is being made for. valid values are "rcp45" and "rcp85" 
#          used to read the file and assign title of the map. 
#   - ssp: ssp the map is being made for. valid values are "SSP1", "SSP2", 
#          "SSP3", "SSP4", "SSP5" used to read the file, assign legend titles, 
#          and output file name
#   - iam: iam the map is being made for. valid values are "high" and "low". 
#          used to read the file and assign the output file name
#   - adapt: adaptation scenario the map is being made for. valid values are 
#            "fulladapt", "incadapt", "noadapt". used to read the file, assign 
#            legend valus, and output file name
#   - impact: type of impact the map is being made for. used to read the file. 
#             valid values are: "clip" - this variable stores projected share of 
#                                        high risk workers
#                               "rebased" - this variable stores projected 
#                                           impacts in time spent working
#   - aggregation: applicable only if impact is "rebased". default values is "".
#                  used to read the file, assign y axis title, and output file 
#                  name. vaid values are:
#                  "" - impacts in minutes worked
#                  "-gdp-aggregated" - impacts as % of GDP
#                  "-pop-aggregated" - impacts in population weighted minutes
#                  "-wage-aggregated" - impacts in million dollars
#   - ir: impact regions for which density plot is being made. enter "global" 
#         for for global timeseries, else enter the region key
#   - output.folder: location of the plots
#   - year_begin: starting year for the timeseries. used to filter the data 
#   - year_end: last year of the timeseries. used to filter the data
#   - x_title: title of the x-axis 
#   - color_var: the variable by which the lines will be coloured 
#   - labs_color: legend title if lines have different colors
#   - fill_var: the variable by which the confidence intervals will be coloured 
#   - linetype_var: the variable that controls the type of line (solid, dashed etc)
#   - labs_linetype: legend title in case of different types of lines
#   - boxplot: TRUE/FALSE parameter to control whether boxplot is made or not
#   - yr:  the year for which boxplot is being made
#==============================================================================#

# load and filter data for the plots
load_df = function(input.path = input_path, rcp, adapt, model.name, ssp, iam, 
                   impact, aggregation, ir, year_begin = 2010, year_end = 2099){
  
  # assign adaptation scenario names that will appear in the legend
  if (adapt == "fulladapt") {
    adapt_col <- "with changing workforce composition \ndue to economic development \nand climate adaptation"
  } else if (adapt == "incadapt") {
    adapt_col <- "with changing workforce composition \ndue to economic development"
  } else if (adapt == "noadapt") {
    adapt_col <- "with fixed workforce composition"
  } else {
    print("wrong adaptation!")
    return()
  }
  
  # assign RCP names that will appear in the legend
  if (rcp == "rcp85") {
    rcp_t <- "RCP 8.5"
  } else if (rcp == "rcp45") {
    rcp_t <- "RCP 4.5"
  } else {
    print("wrong rcp!")
    return()
  }
  
  # read impacts data
  df = read_csv(glue('{input.path}/{model.name}/{rcp}/{iam}/{ssp}/{ssp}-{rcp}_{iam}_{impact}_{adapt}{aggregation}.csv'))
  df = df %>%
    mutate(mean = -100*mean, # multiply by -100 to convert to % and display results on positive y-axis
           region = ifelse(is.na(region), "global", region), # region name is blank for global impacts, replace with global to filter properly
           rcp = rcp_t, 
           adapt_scen = adapt_col) %>%
    filter(region == ir,
           year >= !!year_begin,
           year <= !!year_end)
  
  return(df)
}

# compare timeseries of adaptation scenario
plot.ts = function(model.name, rcp, ssp, iam, impact, ir, aggregation="", 
                   x_title, color_var, labs_color, output.folder){
  
  # create data frame containing all adaptation scenarios
  df = lapply(c("fulladapt", "incadapt", "noadapt"), function(adapt) {
    load_df(rcp = rcp, adapt = adapt, model.name = model.name,ssp = ssp, 
            iam = iam, impact = impact, aggregation = aggregation, ir = ir)
    }) %>% 
    bind_rows() %>%
    # set the order in which adaptation scenarios will be displayed in legend
    mutate(adapt_scen = factor(adapt_scen, levels = c(
      "with fixed workforce composition",
      "with changing workforce composition \ndue to economic development",
      "with changing workforce composition \ndue to economic development \nand climate adaptation"
    )))
  
  # rcp for legend title
  rcp_t = ifelse(rcp == "rcp85", "RCP 8.5", "RCP 4.5")
  
  # assign y label based on adaptation scenario
  if (aggregation == "-pop-aggregated") {
    y_title <- "Pop Weighted Impacts - Mins Worked"
    
  } else if (aggregation == "-gdp-aggregated") {
    y_title <- glue("Climate change-induced worker disutility (% of global GDP)")
    
  } else if (aggregation == "-wage-aggregated") {
    y_title <- glue("Climate change-induced worker disutility \n(million dollars)")
    
  } else if (aggregation == "") {
    y_title <- glue("Climate change-induced change in minutes worked per worker per day")
    
  } else {
    print("wrong aggregation!")
    return()
    
  }
  
  # plot
  p = df %>%
    ggplot(aes(x = year, y = mean)) +
    geom_hline(yintercept = 0, linewidth = 1, color="black") +
    geom_line(aes(color = .data[[color_var]]), linewidth = 1.5) +
    labs(x = x_title,
         y = y_title,
         color = glue("{labs_color}, ({rcp_t}, mean)")) +
    theme_classic() +
    theme(legend.position = "inside",
          legend.position.inside = c(0.10, 0.95),
          legend.justification = c("left", "top"),
          legend.key.spacing.y = unit(0.3, "cm") ,
          legend.key.width = unit(1.5, "cm"),
          axis.line = element_line(color = "black", linewidth = 1),
          axis.text = element_text(size = 14),
          axis.title = element_text(size = 14)) +
    scale_color_manual(values = c("#C5612D", "#DA9731", "#309B72")) +
    coord_cartesian(ylim = c(-0.5, 5), xlim = c(2010, 2110), 
                    expand = FALSE, clip = "off") +
    scale_x_continuous(breaks = c(2025, 2050, 2075, 2100)) +
    scale_y_continuous(breaks = seq(0, 5, by = 1))
  
  # save plot
  ggsave(glue("{output.folder}/{ssp}-{rcp}_{iam}_{impact}_{aggregation}_ts.png"), p, dpi = 300, width = 6)
} 

# compare timeseries of RCPs with confidence intervals 
plot.ts.ci.rcp = function(model.name, ssp, iam, impact, adapt, ir, aggregation="", 
                          fill_var, linetype_var, x_title, labs_linetype, 
                          boxplot, yr, output.folder){
  
  # read data for both RCPs
  df = lapply(c("rcp85", "rcp45"), function(rcp) {
    load_df(rcp = rcp, adapt = adapt, model.name = model.name, ssp = ssp, 
            iam = iam, impact = impact, aggregation = aggregation, ir = ir)
    }) %>% 
    bind_rows()
  
  # assign y label based on adaptation scenario
  if (aggregation == "-pop-aggregated") {
    y_title <- "Pop Weighted Impacts - Mins Worked"
    
  } else if (aggregation == "-gdp-aggregated") {
    y_title <- glue("Climate change-induced worker disutility (% of global GDP)")
    
  } else if (aggregation == "-wage-aggregated") {
    y_title <- glue("Climate change-induced worker disutility \n(million dollars)")
    
  } else if (aggregation == "") {
    y_title <- glue("Climate change-induced change in minutes worked per worker per day")
    
  } else {
    print("wrong aggregation!")
    return()
    
  }
  
  # plot
  p = df %>%
    ggplot(aes(x = year, y = mean)) +
    # multiply by -100 to convert to % and display results on positive y-axis
    geom_hline(yintercept = 0, linewidth = 1, color="black") +
    geom_line(aes(linetype = .data[[linetype_var]]), linewidth = 1.5, color = "black") +
    geom_ribbon(aes(ymin=-100*q5, ymax=-100*q95, fill = .data[[fill_var]]), alpha = 0.3) +
    labs(x = x_title,
         y = y_title,
         linetype = labs_linetype) +
    theme_classic() +
    theme(legend.position = "inside",
          legend.position.inside = c(0.10, 0.95),
          legend.justification = c("left", "top"),
          legend.key.spacing.y = unit(0.3, "cm") ,
          legend.key.width = unit(1.5, "cm"),
          axis.line = element_line(color = "black", linewidth = 1),
          axis.text = element_text(size = 14),
          axis.title = element_text(size = 14))
  
  # if boxplot parameter is TRUE, the output will contain boxplots to the right of
  # the timeseries plots
  if (boxplot) {
    df_box = df %>%
      filter(year == yr) %>%
      # multiply by -100 to convert to % and display results on positive y-axis
      mutate(across(c(q5, q10, q25, q75, q90, q95), ~ -100 * .x),
             x_pos = ifelse(rcp == "RCP 4.5", yr + 7, yr + 3))
    
    p = p +
      geom_errorbar(data = df_box,
                    aes(x = x_pos, ymin = q5, ymax = q95, 
                        group = rcp, color = rcp),
                    lty = "dotted", width = 0, linewidth = 0.5) +
      geom_boxplot(data = df_box,
                   aes(x = x_pos, ymin = q10, lower = q25, middle = mean,
                       upper = q75, ymax = q90, 
                       group = rcp, fill = rcp, color = rcp),
                   width = 2, linewidth = 0.5, stat = "identity", alpha = 1) +
      scale_color_manual(values = c("RCP 4.5" = "steelblue4", "RCP 8.5" = "tomato4")) +
      scale_fill_manual(values = c("RCP 4.5" = "steelblue2", "RCP 8.5" = "tomato2")) +
      scale_x_continuous(expand = c(0, 0), 
                         limits = c(2010, yr + 10),
                         breaks = c(2025, 2050, 2075, 2100)) +
      coord_cartesian(ylim = c(-0.5, 5), xlim = c(2010, yr + 10), 
                      expand = FALSE, clip = "off") +
      scale_y_continuous(breaks = seq(0, 5, by = 1)) +
      theme(plot.margin = margin(t = 5, r = 30, b = 5, l = 5)) +
      guides(fill = "none", color = "none")
  }
  else {
    p = p + 
      scale_fill_manual(values = c("RCP 4.5" = "steelblue2", "RCP 8.5" = "tomato2")) +
      coord_cartesian(ylim = c(-0.5, 5), xlim = c(2010, yr + 10), 
                      expand = FALSE, clip = "off") +
      scale_y_continuous(breaks = seq(0, 5, by = 1)) +
      guides(fill = "none")
  }
  
  ggsave(glue("{output.folder}/{ssp}_{iam}_{impact}_{adapt}{aggregation}_ts_ci_rcp.png"), p, dpi = 300, width = 6)
}

# compare timeseries of the main model and interacted model
plot.ts.ci.model = function(model.name, ssp, iam, impact, adapt, ir, 
                            aggregation="", fill_var, color_var, x_title, 
                            labs_color, output.folder){
  
  # assign y label based on adaptation scenario
  if (aggregation == "-pop-aggregated") {
    y_title <- "Pop Weighted Impacts - Mins Worked"
    
  } else if (aggregation == "-gdp-aggregated") {
    y_title <- glue("Climate change-induced worker disutility (% of global GDP)")
    
  } else if (aggregation == "-wage-aggregated") {
    y_title <- glue("Climate change-induced worker disutility \n(million dollars)")
    
  } else if (aggregation == "") {
    y_title <- glue("Climate change-induced change in minutes worked per worker per day")
    
  } else {
    print("wrong aggregation!")
    return()
    
  }
  
  # create a plot for each rcp
  plots = lapply(c("rcp85", "rcp45"), function(rcp) {
    
    # load data for main model
    df = load_df(rcp = rcp, adapt = adapt, model.name = model.name, 
                 ssp = ssp, iam = iam, impact = impact, 
                 aggregation = aggregation, ir = ir) %>%
      mutate(model_name = model.name)
    
    # load data for interacted model
    df_int = load_df(input.path = "/project/cil/gcp/outputs/labor/impacts-corpsepose/montecarlo/extracted/",
                     rcp = rcp, adapt = adapt, 
                     model.name = "clim_interacted_model_agnonag_27_28_41", 
                     ssp = ssp, iam = iam, impact = impact, 
                     aggregation = aggregation, ir = ir) %>%
      mutate(adapt_scen = gsub("and climate adaptation$",
                               "and climate adaptation \nand within risk group adaptation",
                               adapt_scen),
             model_name = model.name) %>%
      bind_rows(df)
    
    # rcp for legend title
    rcp_t = ifelse(rcp == "rcp85", "RCP 8.5", "RCP 4.5")
    
    plot
    ggplot(df_int, aes(x = year, y = mean)) +
      geom_hline(yintercept = 0, linewidth = 1, color = "black") +
      geom_line(aes(color = .data[[color_var]]), linewidth = 1.5) +
      # multiply by -100 to convert to % and display results on positive y-axis
      geom_ribbon(aes(ymin = -100*q5, ymax = -100*q95, fill = .data[[fill_var]]), alpha = 0.3) +
      labs(x = x_title,
           y = y_title,
           color = glue("{labs_color}, ({rcp_t}, mean)")) +
      theme_classic() +
      theme(legend.position = "inside",
            legend.position.inside = c(0.10, 0.95),
            legend.justification = c("left", "top"),
            legend.key.spacing.y = unit(0.3, "cm") ,
            legend.key.width = unit(1.5, "cm"),
            legend.text = element_text(size = 11),
            legend.title = element_text(size = 11),
            axis.line = element_line(color = "black", linewidth = 1),
            axis.text = element_text(size = 15),
            axis.title = element_text(size = 15),
            plot.margin = margin(t = 5, r = 20, b = 5, l = 5)) + # to ensure nothing gets cut off in plot_grid
      scale_color_manual(values = c("#C5612D", "#309B72")) +
      scale_fill_manual(values = c("#C5612D", "#309B72")) +
      coord_cartesian(ylim = c(-0.75, 10), xlim = c(2010, 2100), 
                      expand = FALSE, clip = "off") +
      guides(fill = "none")
  })
  
  # combine plots with cowplot
  p = cowplot::plot_grid(plotlist = plots, 
                         ncol = 2)
  # save
  ggsave(glue("{output.folder}/{ssp}_{iam}_{impact}_{adapt}{aggregation}_ts_ci_model.png"), p, dpi = 300, width = 12)
}