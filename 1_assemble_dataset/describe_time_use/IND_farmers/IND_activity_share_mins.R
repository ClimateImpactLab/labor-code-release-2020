# Activity average minutes over the year
# For each activity_code, compute weighted average minutes per person per day.

library(tidyverse)
library(data.table)
library(glue)
library(lubridate)
library(readxl)

# ------------------------------------------------------------------ #
# 1. Construct a proper date column
# ------------------------------------------------------------------ #
source("/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/0_subroutines/paths.R")
final_dataset = fread(glue("{ROOT_INT_DATA}/surveys/cleaned_country_data/IND_farmers_activities/IND_ITUS_activity_person_day_ag_worker.csv"))

df = final_dataset %>%
  mutate(
    date = make_date(year, month, day)
  ) %>%
  filter(!is.na(date), !is.na(time_spent), !is.na(sample_wgt))

# ------------------------------------------------------------------ #
# 2. Compute weighted average minutes per (activity_code, date)
# ------------------------------------------------------------------ #

# weighted.mean(time_spent, w = sample_wgt):
# average minutes spent on this activity across all people who did it that day,
# weighted by their survey weight
activity_daily = df %>%
  group_by(activity_code, date) %>%
  summarize(
    avg_mins   = weighted.mean(time_spent, w = sample_wgt),  # weighted average minutes
    n_episodes = n(),
    n_persons  = n_distinct(ind_id),
    .groups = "drop"
  )

# ------------------------------------------------------------------ #
# 3. Save CSV
# ------------------------------------------------------------------ #

write.csv(
  activity_daily,
  glue("{ROOT_INT_DATA}/surveys/cleaned_country_data/activity_daily_mins.csv"),
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

activity_daily = activity_daily %>%
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

active_codes = activity_daily %>%
  filter(activity_code %in% high_risk2_codes) %>%
  pull(activity_code) %>%
  unique()

batch_size = 4
batches = split(active_codes, ceiling(seq_along(active_codes) / batch_size))

# ------------------------------------------------------------------ #
# 6. Build winter shading rectangles
# ------------------------------------------------------------------ #

date_range = range(activity_daily$date, na.rm = TRUE)

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
  
  batch_data = activity_daily %>%
    filter(activity_code %in% batches[[i]]) %>%
    mutate(activity_label = factor(activity_label))
  
  p = ggplot(batch_data, aes(x = date, y = avg_mins)) +  # y axis: avg_mins
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
    scale_y_continuous() +  # plain numbers, no percent formatting
    scale_x_date(date_breaks = "2 months", date_labels = "%b %Y") +
    facet_wrap(~ activity_label, scales = "free_y", ncol = 4,
               labeller = label_wrap_gen(width = 60)) +
    labs(
      title    = glue("Daily Weighted Average Minutes by Activity (Batch {i}/{length(batches)})"),
      subtitle = "LOESS smoother in red; shaded area = India winter (Dec-Feb); high-risk activities only",
      x        = "Date",
      y        = "Weighted average minutes",
      caption  = "Average minutes spent on this activity per person, weighted by sample weight"
    ) +
    theme_bw(base_size = 10) +
    theme(
      strip.text       = element_text(size = 7, face = "bold"),
      axis.text.x      = element_text(angle = 45, hjust = 1, size = 7),
      panel.grid.minor = element_blank()
    )
  
  ggsave(
    glue("{ROOT_INT_DATA}/surveys/cleaned_country_data/ag_activity_daily_mins_batch{i}.png"),
    plot = p, width = 16, height = 6, dpi = 150
  )
}

message(glue("Done. {length(active_codes)} activity codes across {length(batches)} plots."))


  #------------------------------------------------------------------ #
  # 8. Total high-risk minutes per person per day
  #
  # For each person on each day, sum up all time_spent where high_risk2 == 1.
  # Then take the weighted average across people for each date.
  # ------------------------------------------------------------------ #
  
  total_highrisk_daily = df %>%
  filter(high_risk2 == 1) %>%                        # keep only high-risk activities
  group_by(ind_id, date, sample_wgt) %>%              # group by person-day
  summarize(
    total_highrisk_mins = sum(time_spent, na.rm = TRUE),  # sum all high-risk mins for this person on this day
    .groups = "drop"
  ) %>%
  group_by(date) %>%                                  # then average across people within each day
  summarize(
    avg_total_highrisk_mins = weighted.mean(total_highrisk_mins, w = sample_wgt),
    n_persons = n_distinct(ind_id),
    .groups = "drop"
  )

# Plot
p_total = ggplot(total_highrisk_daily, aes(x = date, y = avg_total_highrisk_mins)) +
  geom_rect(
    data        = winter_rects,
    aes(xmin = xmin, xmax = xmax, ymin = -Inf, ymax = Inf),
    inherit.aes = FALSE,
    fill        = "lightsteelblue",
    alpha       = 0.3
  ) +
  geom_line(color = "steelblue", linewidth = 0.4, alpha = 0.7) +
  geom_smooth(ruguo
    method = "loess", span = 0.3, se = TRUE,
    color = "firebrick", fill = "firebrick", alpha = 0.15, linewidth = 0.8
  ) +
  scale_x_date(date_breaks = "2 months", date_labels = "%b %Y") +
  scale_y_continuous() +
  labs(
    title    = "Daily Weighted Average Total High-Risk Minutes per Person",
    subtitle = "LOESS smoother in red; shaded area = India winter (Dec-Feb)",
    x        = "Date",
    y        = "Weighted average minutes",
    caption  = "Sum of all high-risk2 == 1 activity minutes per person, then weighted average across persons by sample weight"
  ) +
  theme_bw(base_size = 10) +
  theme(
    axis.text.x      = element_text(angle = 45, hjust = 1, size = 7),
    panel.grid.minor = element_blank()
  )

ggsave(
  glue("{ROOT_INT_DATA}/surveys/cleaned_country_data/ag_total_highrisk_daily_mins.png"),
  plot = p_total, width = 12, height = 5, dpi = 150
)

message("Total high-risk minutes plot saved.")



# ------------------------------------------------------------------ #
# 9. Monthly average minutes by activity (correct weighting)
#
# Step 1: sum time_spent per person per month per activity  (person-month level)
# Step 2: weighted average across persons within each month
# This ensures sample_wgt is used only once per person per month.
# ------------------------------------------------------------------ #

activity_monthly = df %>%
  filter(activity_code %in% high_risk2_codes) %>%        # high-risk activities only
  group_by(activity_code, ind_id, year, month, sample_wgt) %>%
  summarize(
    total_mins = sum(time_spent, na.rm = TRUE),           # total mins this person spent on this activity this month
    .groups = "drop"
  ) %>%
  group_by(activity_code, year, month) %>%
  summarize(
    avg_mins  = weighted.mean(total_mins, w = sample_wgt), # weighted average across persons
    n_persons = n_distinct(ind_id),
    .groups = "drop"
  ) %>%
  mutate(date = make_date(year, month, 1)) %>%
  left_join(code_labels, by = "activity_code") %>%
  mutate(
    activity_label = ifelse(is.na(activity_label), as.character(activity_code), activity_label)
  )

# Build winter shading for monthly plots
date_range_m = range(activity_monthly$date, na.rm = TRUE)

winter_rects_m = tibble(
  xmin = as.Date(c("1997-12-01", "1998-12-01")),
  xmax = as.Date(c("1998-02-28", "1999-02-28"))
) %>%
  filter(xmax >= date_range_m[1], xmin <= date_range_m[2]) %>%
  mutate(
    xmin = pmax(xmin, date_range_m[1]),
    xmax = pmin(xmax, date_range_m[2])
  )

# Batch setup
active_codes_m = activity_monthly %>%
  pull(activity_code) %>%
  unique()

batches_m = split(active_codes_m, ceiling(seq_along(active_codes_m) / batch_size))

# Plot loop: one panel per activity
for (i in seq_along(batches_m)) {
  
  batch_data = activity_monthly %>%
    filter(activity_code %in% batches_m[[i]]) %>%
    mutate(activity_label = factor(activity_label))
  
  p = ggplot(batch_data, aes(x = date, y = avg_mins)) +
    geom_rect(
      data        = winter_rects_m,
      aes(xmin = xmin, xmax = xmax, ymin = -Inf, ymax = Inf),
      inherit.aes = FALSE,
      fill        = "lightsteelblue",
      alpha       = 0.3
    ) +
    geom_line(color = "steelblue", linewidth = 0.6) +
    geom_point(color = "steelblue", size = 2) +
    scale_y_continuous() +
    scale_x_date(date_breaks = "2 months", date_labels = "%b %Y") +
    facet_wrap(~ activity_label, scales = "free_y", ncol = 4,
               labeller = label_wrap_gen(width = 60)) +
    labs(
      title    = glue("Monthly Weighted Average Minutes by Activity (Batch {i}/{length(batches_m)})"),
      subtitle = "Shaded area = India winter (Dec-Feb); high-risk activities only",
      x        = "Month",
      y        = "Weighted average minutes",
      caption  = "Total mins per person per month, then weighted average across persons by sample weight"
    ) +
    theme_bw(base_size = 10) +
    theme(
      strip.text       = element_text(size = 7, face = "bold"),
      axis.text.x      = element_text(angle = 45, hjust = 1, size = 7),
      panel.grid.minor = element_blank()
    )
  
  ggsave(
    glue("{ROOT_INT_DATA}/surveys/cleaned_country_data/ag_activity_monthly_mins_batch{i}.png"),
    plot = p, width = 16, height = 6, dpi = 150
  )
}

message(glue("Done. {length(active_codes_m)} activity codes across {length(batches_m)} plots."))

# ------------------------------------------------------------------ #
# 10. Total high-risk minutes per person per month (correct weighting)
#
# Step 1: sum ALL high-risk activity mins per person per month
# Step 2: weighted average across persons within each month
# ------------------------------------------------------------------ #

total_highrisk_monthly = df %>%
  filter(high_risk2 == 1) %>%
  group_by(ind_id, year, month, sample_wgt) %>%
  summarize(
    total_highrisk_mins = sum(time_spent, na.rm = TRUE),  # total high-risk mins this person this month
    .groups = "drop"
  ) %>%
  group_by(year, month) %>%
  summarize(
    avg_total_highrisk_mins = weighted.mean(total_highrisk_mins, w = sample_wgt),
    n_persons = n_distinct(ind_id),
    .groups = "drop"
  ) %>%
  mutate(date = make_date(year, month, 1))

# Plot: total high-risk minutes per month
p_total_m = ggplot(total_highrisk_monthly, aes(x = date, y = avg_total_highrisk_mins)) +
  geom_rect(
    data        = winter_rects_m,
    aes(xmin = xmin, xmax = xmax, ymin = -Inf, ymax = Inf),
    inherit.aes = FALSE,
    fill        = "lightsteelblue",
    alpha       = 0.3
  ) +
  geom_line(color = "steelblue", linewidth = 0.6) +
  geom_point(color = "steelblue", size = 2) +
  scale_x_date(date_breaks = "2 months", date_labels = "%b %Y") +
  scale_y_continuous() +
  labs(
    title    = "Monthly Weighted Average Total High-Risk Minutes per Person",
    subtitle = "Shaded area = India winter (Dec-Feb)",
    x        = "Month",
    y        = "Weighted average minutes",
    caption  = "Sum of all high-risk2 == 1 activity minutes per person per month, then weighted average across persons by sample weight"
  ) +
  theme_bw(base_size = 10) +
  theme(
    axis.text.x      = element_text(angle = 45, hjust = 1, size = 7),
    panel.grid.minor = element_blank()
  )

ggsave(
  glue("{ROOT_INT_DATA}/surveys/cleaned_country_data/ag_total_highrisk_monthly_mins.png"),
  plot = p_total_m, width = 12, height = 5, dpi = 150
)

message("Total high-risk monthly minutes plot saved.")


