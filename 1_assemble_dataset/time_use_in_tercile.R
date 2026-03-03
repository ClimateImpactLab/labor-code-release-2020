library(haven)
library(dplyr)
library(ggplot2)
library(patchwork)

# --------------------------------------------------
# 1. Load data
# --------------------------------------------------
df <- read_dta(
  "/project/cil/battuta_shares/gcp/estimation/labor/code_release_int_data/regression_ready_data/labor_dataset_splines_nochn_tmax_chn_prev_week_no_ll_0_agnonag_272841_0218.dta"
)

df = df %>%
  mutate(
    clim_t = case_when(
      lr_tmax_p1 < 22.98254 ~ 1,
      lr_tmax_p1 < 28.66771 ~ 2,
      TRUE                  ~ 3
    )
  )

df <- df %>% filter(high_risk == 1)

# --------------------------------------------------
# 2. Setup
# --------------------------------------------------
iso_list <- c("GLOBAL", sort(unique(df$iso)))

out_dir <- "/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/output/plots_agtime_monthly_mean_climt"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

month_labs <- data.frame(
  month     = 1:12,
  month_lab = format(as.Date(sprintf("2001-%02d-01", 1:12)), "%b")
)

# Colors for three terciles
clim_colors <- c("1" = "#2166ac", "2" = "#f4a582", "3" = "#d6604d")
clim_labels <- c("1" = "Cold", "2" = "Warm", "3" = "Hot")

# --------------------------------------------------
# 3. Loop over iso + GLOBAL
# --------------------------------------------------
for (this_iso in iso_list) {
  
  message("Plotting iso = ", this_iso)
  
  if (this_iso == "GLOBAL") {
    df_i      <- df %>% filter(!is.na(mins_worked), !is.na(month), !is.na(year), !is.na(clim_t))
    label_iso <- "Global"
    file_iso  <- "GLOBAL"
  } else {
    df_i      <- df %>% filter(iso == this_iso, !is.na(mins_worked), !is.na(month), !is.na(year), !is.na(clim_t))
    label_iso <- this_iso
    file_iso  <- this_iso
  }
  
  if (nrow(df_i) == 0) {
    message("  -> Skip (no data) for ", this_iso)
    next
  }
  
  # --------------------------------------------------
  # Monthly stats by clim_t
  # --------------------------------------------------
  df_mean_m <- df_i %>%
    mutate(
      month  = as.integer(month),
      clim_t = as.character(clim_t)
    ) %>%
    filter(month >= 1, month <= 12) %>%
    group_by(month, clim_t) %>%
    summarise(
      mean_mins = weighted.mean(mins_worked, w = risk_adj_sample_wgt, na.rm = TRUE),
      se        = sqrt(sum(risk_adj_sample_wgt * (mins_worked - weighted.mean(mins_worked, w = risk_adj_sample_wgt, na.rm = TRUE))^2, na.rm = TRUE) /
                         sum(risk_adj_sample_wgt, na.rm = TRUE) / n()),
      N         = n(),
      .groups   = "drop"
    ) %>%
    left_join(month_labs, by = "month") %>%
    mutate(
      month_fac = factor(month, levels = 1:12, labels = month_labs$month_lab)
    )
  
  # --------------------------------------------------
  # Plot: monthly mean lines by clim_t + 95% CI ribbons
  # --------------------------------------------------
  # Winter shading: Brazil (southern hemisphere) = Jun-Aug; everyone else = Dec-Feb
  if (this_iso == "BRA") {
    winter_xmin  <- 5.5   # left edge of June
    winter_xmax  <- 8.5   # right edge of August
    winter_xmin2 <- NA    # no second winter block needed
    winter_xmax2 <- NA
    winter_label <- "Brazil winter (Jun-Aug)"
  } else {
    winter_xmin  <- 0.5   # left edge of January
    winter_xmax  <- 2.5   # right edge of February
    winter_xmin2 <- 11.5  # left edge of December
    winter_xmax2 <- 12.5  # right edge of December
    winter_label <- "Winter (Dec-Feb)"
  }
  
  p_mean <- ggplot(df_mean_m, aes(x = month_fac, y = mean_mins, color = clim_t, group = clim_t)) +
    annotate("rect", xmin = winter_xmin, xmax = winter_xmax, ymin = -Inf, ymax = Inf,
             fill = "lightsteelblue", alpha = 0.3) +
    { if (!is.na(winter_xmin2))
      annotate("rect", xmin = winter_xmin2, xmax = winter_xmax2, ymin = -Inf, ymax = Inf,
               fill = "lightsteelblue", alpha = 0.3)
    } +
    geom_ribbon(
      aes(
        ymin = mean_mins - 1.96 * se,
        ymax = mean_mins + 1.96 * se,
        fill = clim_t
      ),
      alpha = 0.15,
      color = NA                          # no border on ribbon
    ) +
    geom_line(linewidth = 0.8) +
    geom_point(size = 1.6) +
    scale_color_manual(values = clim_colors, labels = clim_labels, name = "Climate tercile") +
    scale_fill_manual(values  = clim_colors, labels = clim_labels, name = "Climate tercile") +
    labs(
      x        = "Month",
      y        = "Mean minutes worked",
      title    = paste0("Monthly mean minutes worked by climate tercile (", label_iso, ")"),
      subtitle = paste0("Monthly means pooled across years; shading = 95% CI; blue background = ", winter_label)
    ) +
    theme_bw() +
    theme(
      plot.title   = element_text(size = 12, face = "bold"),
      axis.title   = element_text(size = 10),
      legend.position = "bottom"
    )
  
  # --------------------------------------------------
  # Sample size bars by clim_t
  # --------------------------------------------------
  p_n <- ggplot(df_mean_m, aes(x = month_fac, y = N, fill = clim_t)) +
    geom_col(position = "dodge", alpha = 0.8) +
    scale_fill_manual(values = clim_colors, labels = clim_labels, name = "Climate tercile") +
    labs(
      x = "Month",
      y = "Sample size (N)"
    ) +
    theme_bw() +
    theme(
      axis.title      = element_text(size = 10),
      legend.position = "none"            # legend already shown in top panel
    )
  
  # --------------------------------------------------
  # Combine & save
  # --------------------------------------------------
  p_all <- p_mean / p_n + plot_layout(heights = c(4, 1))
  
  ggsave(
    filename = file.path(out_dir, paste0("mins_worked_monthly_climt_", file_iso, ".pdf")),
    plot     = p_all,
    width    = 8,
    height   = 6
  )
}