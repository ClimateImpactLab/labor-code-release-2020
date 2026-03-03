library(haven)
library(dplyr)
library(ggplot2)
library(patchwork)

# --------------------------------------------------
# 1. Load data
# --------------------------------------------------
df_raw <- read_dta(
  "/project/cil/battuta_shares/gcp/estimation/labor/code_release_int_data/regression_ready_data/labor_dataset_splines_nochn_tmax_chn_prev_week_no_ll_0_agnonag_272841_0218.dta"
)

# --------------------------------------------------
# 2. Adjust mins_worked by country (before any filtering)
# BRA and MEX: divide by 7
# All others:  divide by sqrt(7)
# --------------------------------------------------
df_raw <- df_raw %>%
  mutate(
    mins_worked = case_when(
      iso %in% c("BRA", "MEX") ~ mins_worked / 7,
      TRUE                     ~ mins_worked / sqrt(7)
    )
  )
df_raw <- df_raw %>% filter(mins_worked > 0)

# Two subsets: all samples and high-risk only
df_all  <- df_raw
df_hr   <- df_raw %>% filter(high_risk == 1)

# --------------------------------------------------
# 3. Loop over iso + GLOBAL
# --------------------------------------------------
iso_list <- c("GLOBAL", sort(unique(df_raw$iso)))

out_dir <- "/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/output/plots_agtime_monthly_mean"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

month_labs <- data.frame(
  month     = 1:12,
  month_lab = format(as.Date(sprintf("2001-%02d-01", 1:12)), "%b")
)

# Helper: compute weighted monthly stats from a dataframe
monthly_stats <- function(df_in, this_iso) {
  if (this_iso == "GLOBAL") {
    df_i <- df_in %>% filter(!is.na(mins_worked), !is.na(month), !is.na(year), !is.na(risk_adj_sample_wgt))
  } else {
    df_i <- df_in %>% filter(iso == this_iso, !is.na(mins_worked), !is.na(month), !is.na(year), !is.na(risk_adj_sample_wgt))
  }
  if (nrow(df_i) == 0) return(NULL)
  
  df_i %>%
    mutate(month = as.integer(month)) %>%
    filter(month >= 1, month <= 12) %>%
    group_by(month) %>%
    summarise(
      mean_mins = weighted.mean(mins_worked, w = risk_adj_sample_wgt, na.rm = TRUE),
      se        = sqrt(
        sum(risk_adj_sample_wgt * (mins_worked - weighted.mean(mins_worked, w = risk_adj_sample_wgt, na.rm = TRUE))^2, na.rm = TRUE) /
          sum(risk_adj_sample_wgt, na.rm = TRUE) / n()
      ),
      N         = n(),
      .groups   = "drop"
    ) %>%
    left_join(month_labs, by = "month") %>%
    mutate(month_fac = factor(month, levels = 1:12, labels = month_labs$month_lab))
}

for (this_iso in iso_list) {
  
  message("Plotting iso = ", this_iso)
  
  # Compute stats for both groups
  stats_all <- monthly_stats(df_all, this_iso)
  stats_hr  <- monthly_stats(df_hr,  this_iso)
  
  if (is.null(stats_all) & is.null(stats_hr)) {
    message("  -> Skip (no data) for ", this_iso)
    next
  }
  
  # Combine into one dataframe with a group label
  df_plot = bind_rows(
    stats_all %>% mutate(group = "All"),
    stats_hr  %>% mutate(group = "High risk")
  )
  
  label_iso <- ifelse(this_iso == "GLOBAL", "Global", this_iso)
  
  # ------------------
  # Plot: two lines with ribbons
  # ------------------
  p_mean <- ggplot(df_plot, aes(x = month_fac, y = mean_mins, color = group, group = group)) +
    geom_ribbon(
      aes(
        ymin = mean_mins - 1.96 * se,
        ymax = mean_mins + 1.96 * se,
        fill = group
      ),
      alpha = 0.15,
      color = NA
    ) +
    geom_line(linewidth = 0.8) +
    geom_point(size = 1.6) +
    scale_color_manual(values = c("All" = "steelblue", "High risk" = "firebrick"), name = NULL) +
    scale_fill_manual(values  = c("All" = "steelblue", "High risk" = "firebrick"), name = NULL) +
    labs(
      x        = "Month",
      y        = "Mean minutes worked",
      title    = paste0("Monthly mean minutes worked (", label_iso, ")"),
      subtitle = "Monthly means pooled across years; weighted by risk_adj_sample_wgt"
    ) +
    theme_bw() +
    theme(
      plot.title      = element_text(size = 12, face = "bold"),
      axis.title      = element_text(size = 10),
      legend.position = "bottom"
    )
  
  # ------------------
  # Sample size bars for both groups
  # ------------------
  p_n <- ggplot(df_plot, aes(x = month_fac, y = N, fill = group)) +
    geom_col(position = "dodge", alpha = 0.8) +
    scale_fill_manual(values = c("All" = "steelblue", "High risk" = "firebrick"), name = NULL) +
    labs(x = "Month", y = "Sample size (N)") +
    theme_bw() +
    theme(
      axis.title      = element_text(size = 10),
      legend.position = "none"
    )
  
  # ------------------
  # Combine & save
  # ------------------
  p_all <- p_mean / p_n + plot_layout(heights = c(4, 1))
  
  ggsave(
    filename = file.path(out_dir, paste0("mins_worked_monthly_mean_", this_iso, ".pdf")),
    plot     = p_all,
    width    = 8,
    height   = 6
  )
}