library(haven)
library(dplyr)
library(ggplot2)
library(patchwork) 

df <- read_dta(
  "/project/cil/battuta_shares/gcp/estimation/labor/code_release_int_data/regression_ready_data/labor_dataset_splines_nochn_tmax_chn_prev_week_no_ll_0_agnonag_272841_0129.dta"
)

p_box <- ggplot(df, aes(x = factor(month), y = mins_worked)) +
  geom_boxplot(
    outlier.alpha = 0.3,
    fill = "lightblue",
    color = "black"
  ) +
  labs(
    x = "Month",
    y = "Minutes worked",
    title = "Distribution of minutes worked by month"
  ) +
  theme_bw() +
  theme(
    plot.title = element_text(size = 11),
    axis.title = element_text(size = 10)
  )

df_n <- df %>%
  filter(!is.na(mins_worked), !is.na(month)) %>%
  group_by(month) %>%
  summarise(N = n())

p_n <- ggplot(df_n, aes(x = factor(month), y = N)) +
  geom_col(fill = "lightblue") +
  labs(
    x = "Month",
    y = "Sample size (N)",
    title = "Sample size by month"
  ) +
  theme_bw() +
  theme(
    plot.title = element_text(size = 11),
    axis.title = element_text(size = 10)
  )

p_box / p_n + plot_layout(heights = c(4, 1))

