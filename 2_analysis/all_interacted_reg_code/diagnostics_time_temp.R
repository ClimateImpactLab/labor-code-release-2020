library(haven)
library(dplyr)
library(ggplot2)
library(patchwork)

# --------------------------------------------------
# 0. User settings
# --------------------------------------------------
infile <- "/project/cil/battuta_shares/gcp/estimation/labor/code_release_int_data/regression_ready_data/labor_dataset_splines_nochn_tmax_chn_prev_week_no_ll_0_agnonag_272841_0129.dta"

out_dir <- "/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/output/plots_agtime_daily_by_year"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# --------------------------------------------------
# 1. Load data
# --------------------------------------------------
df <- read_dta(infile)

# Basic checks
needed_vars <- c(
  "iso", "year", "month", "day",
  "mins_worked", "high_risk",
  "real_temperature", "rep_unit_sample_wgt"
)
missing_vars <- setdiff(needed_vars, names(df))
if (length(missing_vars) > 0) {
  stop("Missing required variables: ", paste(missing_vars, collapse = ", "))
}

# High-risk only
df <- df %>%
  filter(high_risk == 1)

# --------------------------------------------------
# 2. Build ISO list (+ GLOBAL)
# --------------------------------------------------
iso_list <- c("GLOBAL", sort(unique(df$iso)))

# --------------------------------------------------
# 3. Loop over ISO / GLOBAL and plot
# --------------------------------------------------
for (this_iso in iso_list) {
  
  message("Plotting: ", this_iso)
  
  # ------------------
  # Subset data
  # ------------------
  if (this_iso == "GLOBAL") {
    df_i <- df
    label_iso <- "Global"
    file_iso  <- "GLOBAL"
  } else {
    df_i <- df %>% filter(iso == this_iso)
    label_iso <- this_iso
    file_iso  <- this_iso
  }
  
  # Keep only valid obs
  df_i <- df_i %>%
    filter(
      !is.na(mins_worked),
      !is.na(year),
      !is.na(month),
      !is.na(day)
    ) %>%
    mutate(
      date = as.Date(sprintf("%d-%02d-%02d", year, month, day))
    ) %>%
    filter(!is.na(date))
  
  if (nrow(df_i) == 0) {
    message("  -> Skip (no valid data): ", this_iso)
    next
  }
  
  # ------------------
  # Daily statistics within each year
  #   One point per (year, date)
  #   - mins_worked: unweighted mean + SE
  #   - temperature: weighted mean using rep_unit_sample_wgt
  # ------------------
  df_daily <- df_i %>%
    group_by(year, date) %>%
    summarise(
      mean_mins = mean(mins_worked),
      se_mins   = sd(mins_worked) / sqrt(n()),
      n         = n(),
      avg_temp  = weighted.mean(
        real_temperature,
        w = rep_unit_sample_wgt,
        na.rm = TRUE
      ),
      .groups = "drop"
    )
  
  # Create year-specific date for clean monthly x-axis in facets
  df_daily <- df_daily %>%
    mutate(
      year_date = as.Date(sprintf(
        "%d-%02d-%02d",
        year,
        as.integer(format(date, "%m")),
        as.integer(format(date, "%d"))
      ))
    )
  
  # ------------------
  # Build a linear mapping so temp can be plotted on the same panel
  # left axis: minutes; right axis: temperature
  # ------------------
  mins_rng <- range(df_daily$mean_mins, na.rm = TRUE)
  temp_rng <- range(df_daily$avg_temp,  na.rm = TRUE)
  
  # Guard against degenerate range (avoid division by zero)
  if (diff(temp_rng) == 0) {
    a <- 0
    b <- mean(mins_rng, na.rm = TRUE)
  } else {
    a <- diff(mins_rng) / diff(temp_rng)
    b <- mins_rng[1] - a * temp_rng[1]
  }
  
  df_daily <- df_daily %>%
    mutate(temp_on_mins_scale = a * avg_temp + b)
  
  # ------------------
  # Plot: daily mins (with CI) + daily avg temp (weighted) on same panel
  # ------------------
  p_daily <- ggplot(df_daily, aes(x = year_date)) +
    # mins_worked ribbon + line
    geom_ribbon(
      aes(
        ymin = mean_mins - 1.96 * se_mins,
        ymax = mean_mins + 1.96 * se_mins
      ),
      alpha = 0.2
    ) +
    geom_line(aes(y = mean_mins), linewidth = 0.6) +
    
    # temperature line (mapped onto minutes axis)
    geom_line(aes(y = temp_on_mins_scale), linewidth = 0.6, color = "red") +
    
    scale_x_date(
      date_breaks = "1 month",
      date_labels = "%b"
    ) +
    scale_y_continuous(
      name = "Daily mean minutes worked",
      sec.axis = sec_axis(
        trans = ~ (. - b) / a,
        name = "Daily avg real temperature (weighted)"
      )
    ) +
    facet_wrap(~ year, scales = "free_x", ncol = 3) +
    labs(
      x = "Month",
      title = paste0("Daily minutes worked + temperature (", label_iso, ")"),
      subtitle = paste0(
        "High-risk only. Black = minutes (mean ± 1.96×SE). ",
        "Red = pop-weighted avg temperature (weights: rep_unit_sample_wgt)."
      )
    ) +
    theme_bw() +
    theme(
      plot.title = element_text(size = 12, face = "bold"),
      plot.subtitle = element_text(size = 10),
      axis.title = element_text(size = 10),
      strip.text = element_text(size = 9)
    )
  
  # ------------------
  # Daily N panel (unchanged)
  # ------------------
  p_n <- ggplot(df_daily, aes(x = year_date, y = n, group = 1)) +
    geom_line(linewidth = 0.4, alpha = 0.7) +
    scale_x_date(
      date_breaks = "1 month",
      date_labels = "%b"
    ) +
    facet_wrap(~ year, scales = "free_x", ncol = 3) +
    labs(
      x = "Month",
      y = "Daily N"
    ) +
    theme_bw() +
    theme(
      axis.title = element_text(size = 10),
      strip.text = element_text(size = 9)
    )
  
  # Combine & save
  p_all <- p_daily / p_n + plot_layout(heights = c(3, 1))
  
  outfile <- file.path(out_dir, paste0("mins_worked_temp_daily_by_year_", file_iso, ".pdf"))
  ggsave(outfile, p_all, width = 12, height = 18)
  
  message("  -> Saved: ", outfile)
}