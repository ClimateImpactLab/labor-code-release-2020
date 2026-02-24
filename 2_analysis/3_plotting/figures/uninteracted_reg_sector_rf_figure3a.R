
################################################################################
# uninteracted_reg_sector_rf_figure3a.R
#
# PURPOSE:
#   Plot temperature response functions from the sector 3-group pooled model:
#     - All workers (comm)
#     - Low-risk sector (low)
#     - Agriculture (ag)
#     - Construction & Manufacturing (nonag)
#
#   Each panel includes:
#     - Estimated response function (yhat)
#     - Optional confidence interval (clipped or suppressed below -250)
#     - Temperature distribution histogram (fractional or raw)
#
# OPTIONS:
#   - FRACTION_HIST         : use fractional or raw histograms
#   - plot_CI_beyond_cap    : clip CI at -250 or suppress when below -250
#
# OUTPUT:
#   4-panel RF figure with aligned histograms and shared temperature axis.
#
################################################################################


#############
# INITIALIZE
#############

rm(list = ls())
library(dplyr)
library(tidyr)
library(ggplot2)
library(patchwork)
library(readr)
library(glue)
library(data.table)
library(parallel)


user <- Sys.info()[["user"]]
source(paste0("/project/cil/home_dirs/", user, "/repos/labor-code-release-2020/0_subroutines/paths.R"))
source(paste0("/project/cil/home_dirs/", user, "/repos/labor-code-release-2020/2_analysis/0_subroutines/functions.R"))


#################
# DEFINE OUTPATH
#################

outpath <- DIR_FIG
dir.create(outpath, showWarnings = FALSE, recursive = TRUE)

outname <- "uninteracted_reg_sector_figure3a"
format  <- "pdf"

#######################
# USER OPTIONS
#######################

FRACTION_HIST <- "YES"   # "YES" (default) or "NO"
FRACTION_HIST <- toupper(FRACTION_HIST)

plot_CI_beyond_cap <- "YES"  # "YES" (default: clip at -250) or "NO" (drop ribbon where < -250)
plot_CI_beyond_cap <- toupper(plot_CI_beyond_cap)

STOP_CI_AT <- -250       # lower bound for plotted CI
Y_TOP      <-  50        # upper bound for RF panel

ZERO_LINE_COLOR <- "grey40"  # dashed 0-line color

#############
# GET DATA
#############

rf <- read_csv(
  glue("{DIR_RF}/uninteracted_reg_comlohi/",
       "uninteracted_reg_comlohi_full_response_2026_272841_sector.csv"),
  show_col_types = FALSE
)

temp_dist <- read_csv(
  glue("{DIR_OUTPUT}/temp_dist/temp_dist_sector.csv"),
  show_col_types = FALSE
)

#############################
# RESHAPE FUNCTION
#############################

reshape <- function(name, df = rf, vars = c("yhat", "lowerci", "upperci")) {
  
  varlist <- c("temp")
  for (v in vars) {
    varlist <- c(varlist, glue("{v}_{name}"))
  }
  
  x <- df %>%
    dplyr::select(unlist(varlist)) %>%
    mutate(risk = glue("{name}"))
  
  names(x) <- c(c("temp", vars), "risk")
  return(x)
}

############################
# SAFE APPLY (PAR -> SERIAL)
############################

# safe_apply() to allow parallel reshaping with automatic serial fallback
safe_apply <- function(names, FUN, ..., mc.cores = 1) {
  
  if (mc.cores > 1) {
    out <- try(mclapply(names, FUN, ..., mc.cores = mc.cores), silent = TRUE)
    
    ok <- !inherits(out, "try-error") &&
      is.list(out) &&
      length(out) == length(names) &&
      all(vapply(out, is.data.frame, logical(1)))
    
    if (ok) return(out)
    
    warning("Parallel apply failed; falling back to serial lapply().")
  }
  
  lapply(names, FUN, ...)
}

####################################
# RESPONSE FUNCTION (SAFE + RESHAPE)
####################################

risk_list <- c("comm", "low", "ag", "nonag")

rf_list <- safe_apply(
  risk_list,
  FUN = function(nm, df) reshape(name = nm, df = df),
  df = rf,
  mc.cores = 4
)

rf_long <- rbindlist(rf_list, use.names = TRUE) %>%
  mutate(
    risk = factor(risk, levels = risk_list),
    lowerci_plot = case_when(
      plot_CI_beyond_cap == "YES" ~ pmax(lowerci, STOP_CI_AT), # plot CI if < -250 but clip at -250
      plot_CI_beyond_cap == "NO"  ~ ifelse(lowerci < STOP_CI_AT, NA, lowerci) # don't plot CI if CI beyond -250
    ),
    upperci_plot = case_when(
      plot_CI_beyond_cap == "YES" ~ upperci,   # plot CI if < -250 but clip at -250                          
      plot_CI_beyond_cap == "NO"  ~ ifelse(lowerci < STOP_CI_AT, NA, upperci) #don't plot CI if CI beyond -250
    )
  )

#############################
# HISTOGRAMS (SAFE + RESHAPE)
#############################

build_hist <- function(risks, df, vars, weight_col, mc.cores = length(risks)) {
  
  hist_list <- safe_apply(
    risks,
    FUN = function(nm, df, vars) reshape(name = nm, df = df, vars = vars),
    df = df,
    vars = vars,
    mc.cores = mc.cores
  )
  
  rbindlist(hist_list, use.names = TRUE) %>%
    mutate(weight = .data[[weight_col]],
           risk = factor(risk, levels = risk_list))
}

if (FRACTION_HIST == "YES") {
  
  # UNWEIGHTED: frac_no_wgt_{comm,low,ag,nonag}
  hist_no_wgt <- build_hist(
    risks      = risk_list,
    df         = temp_dist,
    vars       = c("frac_no_wgt"),
    weight_col = "frac_no_wgt",
    mc.cores   = 4
  )
  
  # WEIGHTED: comm uses frac_pop_wgt_comm; others use frac_risk_wgt_sector_{low,ag,nonag}
  hist_adj_wgt <- bind_rows(
    build_hist(
      risks      = c("comm"),
      df         = temp_dist,
      vars       = c("frac_pop_wgt"),
      weight_col = "frac_pop_wgt",
      mc.cores   = 1
    ),
    build_hist(
      risks      = c("low","ag","nonag"),
      df         = temp_dist,
      vars       = c("frac_risk_wgt_sector"),
      weight_col = "frac_risk_wgt_sector",
      mc.cores   = 3
    )
  ) %>% mutate(risk = factor(risk, levels = risk_list))
  
} else if (FRACTION_HIST == "NO") {
  
  # UNWEIGHTED: no_wgt_{comm,low,ag,nonag}
  hist_no_wgt <- build_hist(
    risks      = risk_list,
    df         = temp_dist,
    vars       = c("no_wgt"),
    weight_col = "no_wgt",
    mc.cores   = 4
  )
  
  # WEIGHTED: comm uses pop_wgt_comm; others use risk_wgt_sector_{low,ag,nonag}
  hist_adj_wgt <- bind_rows(
    build_hist(
      risks      = c("comm"),
      df         = temp_dist,
      vars       = c("pop_wgt"),
      weight_col = "pop_wgt",
      mc.cores   = 1
    ),
    build_hist(
      risks      = c("low","ag","nonag"),
      df         = temp_dist,
      vars       = c("risk_wgt_sector"),
      weight_col = "risk_wgt_sector",
      mc.cores   = 3
    )
  ) %>% mutate(risk = factor(risk, levels = risk_list))
  
} else {
  stop("FRACTION_HIST must be 'YES' or 'NO'.")
}

######################################
# PLOT (4 PANELS, SPACERS + TAG SHIFT)
######################################

plot_temp_panels_sector <- function(rf_long, hist_no_wgt, hist_adj_wgt, use_adj = TRUE) {
  
  risk_levels <- c("comm","low","ag","nonag")
  
  risk_labels <- c(
    comm  = "All workers",
    low   = "Low-risk workers",
    ag    = "Agriculture",
    nonag = "Construction &\nManufacturing"
  )
  
  hist_df <- if (use_adj) hist_adj_wgt else hist_no_wgt
  
  x_limits <- c(-24, 47)
  x_breaks <- seq(-20, 40, 10)
  
  hist_max <- max(hist_df$weight, na.rm = TRUE)
  
  make_strip <- function(r, is_leftmost = FALSE, tag_letter = "A") {
    
    d_sub <- dplyr::filter(rf_long, risk == r)
    h_sub <- dplyr::filter(hist_df, risk == r)
    
    rf_label_y <- STOP_CI_AT + 10
    rf_label_x <- x_limits[1] + 27
    
    tag_x <- if (is_leftmost) 0.09 else -0.03
    
    p <- ggplot(d_sub, aes(x = temp, y = yhat)) +
      geom_hline(yintercept = 0, linetype = "dashed",
                 linewidth = 0.5, color = ZERO_LINE_COLOR) +
      geom_line(linewidth = 1, colour = "#5E4987") +
      geom_ribbon(aes(ymin = lowerci_plot, ymax = upperci_plot),
                  alpha = 0.2, fill = "#5E4987", colour = NA) +
      annotate("text",
               x = rf_label_x, y = rf_label_y,
               label = risk_labels[[as.character(r)]],
               hjust = 0, vjust = 0,
               fontface = "bold", size = 3.8) +
      scale_y_continuous(limits = c(STOP_CI_AT, Y_TOP), expand = c(0, 0)) +
      scale_x_continuous(breaks = x_breaks, limits = x_limits,
                         expand = c(0, 0), minor_breaks = NULL) +
      labs(
        x   = NULL,
        y   = if (is_leftmost) "Minutes worked" else NULL,
        tag = tag_letter
      ) +
      theme_minimal(base_size = 12) +
      theme(
        panel.grid = element_blank(),
        legend.position = "none",
        
        plot.tag.position = c(tag_x, 0.98),
        plot.tag = element_text(size = 14, hjust = 0, vjust = 1, face = "bold"),
        
        axis.line = element_blank(),
        axis.line.y  = element_line(color = "black", linewidth = 0.4),
        axis.ticks.y = element_line(color = "black", linewidth = 0.4),
        axis.ticks.length = unit(3, "pt"),
        
        axis.text.x  = element_blank(),
        axis.ticks.x = element_blank(),
        
        axis.title.y = element_text(margin = margin(r = 8), face = "bold"),
        plot.margin  = margin(t = 2, r = 6, b = 0, l = 6)
      )
    
    gap <- plot_spacer() + theme(plot.margin = margin(0, 0, 0, 0))
    
    q <- ggplot(h_sub, aes(x = temp, y = weight)) +
      geom_col(fill = "grey50") +
      scale_y_continuous(limits = c(0, hist_max), expand = c(0, 0)) +
      scale_x_continuous(breaks = x_breaks, limits = x_limits,
                         expand = c(0, 0), minor_breaks = NULL) +
      labs(x = NULL, y = NULL) +
      theme_minimal(base_size = 12) +
      theme(
        panel.grid = element_blank(),
        legend.position = "none",
        
        axis.line = element_blank(),
        axis.line.y  = element_line(color = "black", linewidth = 0.4),
        axis.ticks = element_line(color = "black", linewidth = 0.4),
        axis.ticks.length = unit(3, "pt"),
        
        axis.text.y  = element_blank(),
        axis.ticks.y = element_blank(),
        
        plot.margin = margin(t = 0, r = 6, b = 0, l = 6)
      )
    
    (p / gap / q) + plot_layout(heights = c(2, 0.10, 1))
  }
  
  strips <- lapply(seq_along(risk_levels), function(i) {
    make_strip(
      r           = risk_levels[i],
      is_leftmost = (i == 1),
      tag_letter  = LETTERS[i]
    )
  })
  
  spacer_width <- 0.03
  
  (strips[[1]] | plot_spacer() | strips[[2]] | plot_spacer() | strips[[3]] | plot_spacer() | strips[[4]]) +
    plot_layout(widths = c(1, spacer_width, 1, spacer_width, 1, spacer_width, 1)) +
    plot_annotation(caption = "Temperature (°C)") &
    theme(
      plot.caption = element_text(
        hjust = 0.58, face = "bold", size = 12, margin = margin(t = 8)
      )
    )
}

# ---- Run & save ----
p <- plot_temp_panels_sector(rf_long, hist_no_wgt, hist_adj_wgt, use_adj = TRUE)

outfile <- glue("{outpath}/{outname}.{format}")
ggsave(outfile, plot = p, width = 13, height = 4.8)

print(p)
cat("Saved:", outfile, "\n")