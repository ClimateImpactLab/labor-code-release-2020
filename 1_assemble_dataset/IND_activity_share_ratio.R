# Activity share over the year
# For each activity_code, compute its weighted time share on each calendar date.

library(tidyverse)
library(data.table)
library(glue)
library(lubridate)
library(readxl)

# ------------------------------------------------------------------ #
# 1. Construct a proper date column
# ------------------------------------------------------------------ #
source("/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/0_subroutines/paths.R")
final_dataset = fread(glue("{ROOT_INT_DATA}/surveys/cleaned_country_data/IND_ITUS_activity_person_day.csv"))

df = final_dataset %>%
  mutate(
    date = make_date(year, month, day)
  ) %>%
  filter(!is.na(date), !is.na(time_spent), !is.na(sample_wgt))

# ------------------------------------------------------------------ #
# 2. Compute weighted time share per (activity_code, date)
# ------------------------------------------------------------------ #

daily_total = df %>%
  group_by(date) %>%
  summarize(
    weighted_total = sum(sample_wgt * time_spent, na.rm = TRUE),
    .groups = "drop"
  )

activity_daily = df %>%
  group_by(activity_code, date) %>%
  summarize(
    weighted_time = sum(sample_wgt * time_spent, na.rm = TRUE),
    n_episodes    = n(),
    n_persons     = n_distinct(ind_id),
    .groups = "drop"
  )

activity_share = activity_daily %>%
  left_join(daily_total, by = "date") %>%
  mutate(
    share = weighted_time / weighted_total
  ) %>%
  arrange(activity_code, date)

# ------------------------------------------------------------------ #
# 3. Save CSV
# ------------------------------------------------------------------ #

write.csv(
  activity_share,
  glue("{ROOT_INT_DATA}/surveys/cleaned_country_data/activity_daily_share.csv"),
  row.names = FALSE
)

# ------------------------------------------------------------------ #
# 4. Merge activity labels
# ------------------------------------------------------------------ #

code_labels = read_excel("/project/cil/battuta_shares/gcp/estimation/labor/code_release_int_data/surveys/IND_ITUS/India_Categorization_Codes.xlsx") %>%
  rename(activity_code = Code, activity_label = `Activity Type`) %>%
  filter(!is.na(activity_code)) %>%
  dplyr::select(activity_code, activity_label) %>%
  distinct()

activity_share = activity_share %>%
  left_join(code_labels, by = "activity_code") %>%
  mutate(
    activity_label = ifelse(is.na(activity_label), as.character(activity_code), activity_label)
  )

# ------------------------------------------------------------------ #
# 5. Filter to high_risk2 = 1 activity codes only
# ------------------------------------------------------------------ #

high_risk2_codes = final_dataset %>%
  filter(high_risk2 == 1) %>%
  pull(activity_code) %>%
  unique()

active_codes = activity_share %>%
  filter(activity_code %in% high_risk2_codes) %>%
  pull(activity_code) %>%
  unique()

batch_size = 4
batches = split(active_codes, ceiling(seq_along(active_codes) / batch_size))

# ------------------------------------------------------------------ #
# 6. Build winter shading rectangles
# ------------------------------------------------------------------ #

date_range = range(activity_share$date, na.rm = TRUE)

winter_rects = tibble(
  xmin = as.Date(c("1997-12-01", "1998-12-01")),
  xmax = as.Date(c("1998-02-28", "1999-02-28"))
) %>%
  filter(xmax >= date_range[1], xmin <= date_range[2]) %>%
  mutate(
    xmin = pmax(xmin, date_range[1]),
    xmax = pmin(xmax, date_range[2])
  )

# ------------------------------------------------------------------ #
# 7. Plot loop
# ------------------------------------------------------------------ #

for (i in seq_along(batches)) {
  
  batch_data = activity_share %>%
    filter(activity_code %in% batches[[i]]) %>%
    mutate(activity_label = factor(activity_label))
  
  p = ggplot(batch_data, aes(x = date, y = share)) +
    geom_rect(
      data        = winter_rects,
      aes(xmin = xmin, xmax = xmax, ymin = -Inf, ymax = Inf),
      inherit.aes = FALSE,
      fill        = "lightsteelblue",
      alpha       = 0.3
    ) +
    geom_line(color = "steelblue", linewidth = 0.4, alpha = 0.7) +
    geom_smooth(
      method = "loess", span = 0.3, se = TRUE,
      color = "firebrick", fill = "firebrick", alpha = 0.15, linewidth = 0.8
    ) +
    scale_y_continuous(labels = scales::percent_format(accuracy = 0.1)) +
    scale_x_date(date_breaks = "2 months", date_labels = "%b %Y") +
    facet_wrap(~ activity_label, scales = "free_y", ncol = 4,
               labeller = label_wrap_gen(width = 60))  +
    labs(
      title    = glue("Daily Weighted Time Share by Activity (Batch {i}/{length(batches)})"),
      subtitle = "LOESS smoother in red; shaded area = India winter (Dec-Feb); high-risk activities only",
      x        = "Date",
      y        = "Weighted time share",
      caption  = "Share = weighted time on this activity / total weighted time across all activities that day"
    ) +
    theme_bw(base_size = 10) +
    theme(
      strip.text       = element_text(size = 7, face = "bold"),
      axis.text.x      = element_text(angle = 45, hjust = 1, size = 7),
      panel.grid.minor = element_blank()
    )
  
  ggsave(
    glue("{ROOT_INT_DATA}/surveys/cleaned_country_data/ag_activity_daily_share_batch{i}.png"),
    plot = p, width = 16, height = 6, dpi = 150
  )
}

message(glue("Done. {length(active_codes)} activity codes across {length(batches)} plots."))