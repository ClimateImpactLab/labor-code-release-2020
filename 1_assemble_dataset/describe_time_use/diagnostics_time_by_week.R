library(haven)
library(dplyr)
library(ggplot2)
library(patchwork)

# --------------------------------------------------
# 1. Load data
# --------------------------------------------------
df <- read_dta(
  "/project/cil/battuta_shares/gcp/estimation/labor/code_release_int_data/regression_ready_data/labor_dataset_splines_nochn_tmax_chn_prev_week_no_ll_0_agnonag_272841_0129.dta"
)

# High-risk only
df <- df %>% filter(high_risk == 1)

# --------------------------------------------------
# 2. Loop over iso + GLOBAL
# --------------------------------------------------
iso_list <- c("GLOBAL", sort(unique(df$iso)))

out_dir <- "/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/output/plots_agtime_weekly_mean_month_x"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# --------------------------------------------------
# 3. Month breaks on a 365-day axis (non-leap year)
#    We'll map each week to the month of its "midpoint day"
# --------------------------------------------------
month_breaks <- tibble(
  month = 1:12,
  break_doy = as.integer(format(as.Date(sprintf("2001-%02d-01", 1:12)), "%j")),
  month_lab = format(as.Date(sprintf("2001-%02d-01", 1:12)), "%b")
)

# helper: for each month, find the first week whose midpoint doy is >= month start doy
# (computed later once we know max week)
get_month_break_weeks <- function(max_week) {
  week_tbl <- tibble(
    week = 1:max_week,
    week_mid_doy = (week - 1) * 7 + 4
  )
  out <- month_breaks %>%
    rowwise() %>%
    mutate(
      break_week = min(week_tbl$week[week_tbl$week_mid_doy >= break_doy], na.rm = TRUE)
    ) %>%
    ungroup() %>%
    mutate(break_week = ifelse(is.infinite(break_week), NA_integer_, break_week)) %>%
    filter(!is.na(break_week))
  out
}

for (this_iso in iso_list) {
  
  message("Plotting iso = ", this_iso)
  
  # ------------------
  # Subset data
  # ------------------
  if (this_iso == "GLOBAL") {
    df_i <- df %>%
      filter(!is.na(mins_worked), !is.na(year), !is.na(month), !is.na(day))
    label_iso <- "Global"
    file_iso  <- "GLOBAL"
  } else {
    df_i <- df %>%
      filter(iso == this_iso, !is.na(mins_worked), !is.na(year), !is.na(month), !is.na(day))
    label_iso <- this_iso
    file_iso  <- this_iso
  }
  
  if (nrow(df_i) == 0) {
    message("  -> Skip (no data) for ", this_iso)
    next
  }
  
  # ------------------
  # Build date -> doy; drop Feb 29; define week-of-year (1..53)
  # ------------------
  df_i <- df_i %>%
    mutate(
      date = as.Date(sprintf("%d-%02d-%02d", year, month, day)),
      doy  = as.integer(format(date, "%j")),
      is_leap_day = (format(date, "%m-%d") == "02-29")
    ) %>%
    filter(!is.na(date), !is.na(doy), !is_leap_day) %>%
    mutate(
      week = as.integer(floor((doy - 1) / 7) + 1)
    )
  
  if (nrow(df_i) == 0) {
    message("  -> Skip (all obs were leap day / invalid date) for ", this_iso)
    next
  }
  
  # ------------------
  # Weekly stats pooled across years
  # ------------------
  df_week <- df_i %>%
    group_by(week) %>%
    summarise(
      mean_mins = mean(mins_worked),
      se = sd(mins_worked) / sqrt(n()),
      N = n(),
      .groups = "drop"
    ) %>%
    arrange(week)
  
  max_week <- max(df_week$week, na.rm = TRUE)
  month_break_weeks <- get_month_break_weeks(max_week)
  
  # ------------------
  # Plot: weekly mean + 95% CI, x-axis labeled by month
  # ------------------
  p_mean <- ggplot(df_week, aes(x = week, y = mean_mins)) +
    geom_ribbon(
      aes(
        ymin = mean_mins - 1.96 * se,
        ymax = mean_mins + 1.96 * se
      ),
      fill = "lightblue",
      alpha = 0.3
    ) +
    geom_line(color = "steelblue", linewidth = 0.8) +
    labs(
      x = "Month",
      y = "Mean minutes worked",
      title = paste0("Weekly mean minutes worked (", label_iso, ")"),
      subtitle = "Weekly means pooled across years; weeks defined by day-of-year; Feb 29 dropped"
    ) +
    scale_x_continuous(
      breaks = month_break_weeks$break_week,
      labels = month_break_weeks$month_lab,
      limits = c(1, max_week)
    ) +
    theme_bw() +
    theme(
      plot.title = element_text(size = 12, face = "bold"),
      axis.title = element_text(size = 10)
    )
  
  # ------------------
  # Sample size line (weekly N)
  # ------------------
  p_n <- ggplot(df_week, aes(x = week, y = N)) +
    geom_line(color = "steelblue", linewidth = 0.6, alpha = 0.8) +
    labs(
      x = "Month",
      y = "Sample size (N)"
    ) +
    scale_x_continuous(
      breaks = month_break_weeks$break_week,
      labels = month_break_weeks$month_lab,
      limits = c(1, max_week)
    ) +
    theme_bw() +
    theme(axis.title = element_text(size = 10))
  
  # ------------------
  # Combine & save
  # ------------------
  p_all <- p_mean / p_n + plot_layout(heights = c(4, 1))
  
  ggsave(
    filename = file.path(out_dir, paste0("mins_worked_weekly_mean_monthx_", file_iso, ".pdf")),
    plot = p_all,
    width = 8,
    height = 6
  )