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

out_dir <- "/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/output/plots_agtime_typical_year"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# --------------------------------------------------
# 3. Helper: month breaks on a 365-day axis (non-leap year)
# --------------------------------------------------
month_breaks <- tibble(
  month = 1:12,
  break_doy = as.integer(format(as.Date(sprintf("2001-%02d-01", 1:12)), "%j")),
  month_lab = format(as.Date(sprintf("2001-%02d-01", 1:12)), "%b")
)

for (this_iso in iso_list) {
  
  message("Plotting iso = ", this_iso)
  
  # ------------------
  # Subset data
  # ------------------
  if (this_iso == "GLOBAL") {
    df_i <- df %>%
      filter(!is.na(mins_worked), !is.na(month), !is.na(day), !is.na(year))
    label_iso <- "Global"
    file_iso  <- "GLOBAL"
  } else {
    df_i <- df %>%
      filter(iso == this_iso, !is.na(mins_worked), !is.na(month), !is.na(day), !is.na(year))
    label_iso <- this_iso
    file_iso  <- this_iso
  }
  
  if (nrow(df_i) == 0) {
    message("  -> Skip (no data) for ", this_iso)
    next
  }
  
  # ------------------
  # Build date & day-of-year (doy)
  #   - Use real year to handle leap days
  #   - Then drop Feb 29 so we get a clean 365-day axis
  # ------------------
  df_i <- df_i %>%
    mutate(
      date = as.Date(sprintf("%d-%02d-%02d", year, month, day)),
      doy  = as.integer(format(date, "%j")),
      is_leap_day = (format(date, "%m-%d") == "02-29")
    ) %>%
    filter(!is.na(date), !is.na(doy), !is_leap_day)
  
  if (nrow(df_i) == 0) {
    message("  -> Skip (all obs were leap day / invalid date) for ", this_iso)
    next
  }
  
  # ------------------
  # Typical-year daily stats: one point per doy (1..365)
  # ------------------
  df_mean <- df_i %>%
    group_by(doy) %>%
    summarise(
      mean_mins = mean(mins_worked),
      se = sd(mins_worked) / sqrt(n()),
      N = n(),
      .groups = "drop"
    )
  
  # ------------------
  # Plot: mean + 95% CI over 365 days, x-axis labeled by month
  # ------------------
  p_mean <- ggplot(df_mean, aes(x = doy, y = mean_mins)) +
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
      title = paste0("Typical-year daily minutes worked (", label_iso, ")"),
      subtitle = "Daily means pooled across years; Feb 29 dropped (365-day axis)"
    ) +
    scale_x_continuous(
      breaks = month_breaks$break_doy,
      labels = month_breaks$month_lab
    ) +
    theme_bw() +
    theme(
      plot.title = element_text(size = 12, face = "bold"),
      axis.title = element_text(size = 10)
    )
  
  # ------------------
  # Sample size line (daily N)
  # ------------------
  p_n <- ggplot(df_mean, aes(x = doy, y = N)) +
    geom_line(color = "steelblue", linewidth = 0.6, alpha = 0.8) +
    labs(
      x = "Month",
      y = "Sample size (N)"
    ) +
    scale_x_continuous(
      breaks = month_breaks$break_doy,
      labels = month_breaks$month_lab
    ) +
    theme_bw() +
    theme(
      axis.title = element_text(size = 10)
    )
  
  # ------------------
  # Combine & save
  # ------------------
  p_all <- p_mean / p_n + plot_layout(heights = c(4, 1))
  
  ggsave(
    filename = file.path(out_dir, paste0("mins_worked_by_month_mean_", file_iso, ".pdf")),
    plot = p_all,
    width = 8,
    height = 6
  )
}