# Impacts by income deciles bar chart
# Modified to use test data directory

rm(list = ls())
library(RColorBrewer)

# Load required packages
if(!require("pacman")){install.packages(("pacman"))}
pacman::p_load(ggplot2, 
               dplyr,
               readr,
               glue,
               parallel)

source("/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/0_subroutines/paths.R")
source("/project/cil/home_dirs/maiqi/repos/post-projection-tools/mapping/imgcat.R")

# ========== TEST DATA DIRECTORY ==========
TEST_DATA_DIR <- "/project/cil/gcp/outputs/labor/impacts-woodwork/montecarlo/test"

# ========== OUTPUT DIRECTORY ==========
OUTPUT_DIR <- "/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/output/figures/fig7"
dir.create(OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)

# ========== DATA SOURCES ==========
DB_data <- '/project/cil/battuta_shares/gcp/estimation/labor/code_release_int_data/projection_outputs/covariates'

# ========== FUNCTION: Calculate income deciles ==========
# Takes equal population shares in each decile, ranked by income
get_deciles_logged <- function(df, year = 2015,
                               value_col = "loggdppc",     # ranking variable (can stay logged)
                               log_pop_col = "logpopop",   # logged population
                               pop_log_base = c("e","10","log1p")) {
  
  pop_log_base <- match.arg(pop_log_base)
  
  d <- df %>% filter(year == year)
  
  # Invert population log to levels
  d$pop <- switch(pop_log_base,
                  "e"     = exp(d[[log_pop_col]]),
                  "10"    = 10^(d[[log_pop_col]]),
                  "log1p" = expm1(d[[log_pop_col]]))
  
  d %>%
    filter(is.finite(.data[[value_col]]),
           is.finite(pop), pop > 0) %>%
    arrange(.data[[value_col]]) %>%
    mutate(cum_share = cumsum(pop) / sum(pop),
           decile   = pmin(10L, floor(cum_share * 10) + 1L)) %>%
    select(region, decile)
}

# ========== LOAD COVARIATE DATA (2015 INCOME & POPULATION) ==========
cat("Loading covariate data...\n")
df_covariates = read_csv(paste0(DB_data,  
                                '/covariates_region_loggdppc_climtasmax_logpopop.csv'))

# Find each Impact region's 2015 income decile
cat("Calculating income deciles...\n")
deciles = get_deciles_logged(df_covariates)

# ========== LOAD IMPACT DATA FROM TEST DIRECTORY ==========
# Read climate impact data (percentage of GDP)
cat("Loading impact data from:", TEST_DATA_DIR, "\n")
df_pct_gdp_impacts = read_csv(glue('{TEST_DATA_DIR}/SSP3-rcp85_low_rebased_fulladapt-gdp-levels_2099_map.csv')) %>%
  left_join(deciles, by = "region")

# Check if data loaded successfully
if (nrow(df_pct_gdp_impacts) == 0) {
  cat("WARNING: No data loaded from impact file. Check path and file existence.\n")
}

# ========== LOAD 2099 GDP DATA ==========
cat("Loading 2099 GDP data...\n")
df_gdp99 = read_csv(paste0(DB_data, '/SSP3-low-IR_level-gdppc-pop-2099.csv')) %>% 
  dplyr::select(region, gdp99)

# ========== JOIN DATASETS AND CALCULATE IMPACTS ==========
cat("Joining datasets and calculating impacts...\n")
df_pct_gdp_impacts = df_pct_gdp_impacts %>% 
  left_join(df_gdp99, by = "region") %>% 
  mutate(
    # Calculate absolute damage in GDP (percentage points * GDP)
    pct_x_gdp_mean = -mean * gdp99,
    pct_x_gdp_q1 = -q1 * gdp99,
    pct_x_gdp_q5 = -q5 * gdp99,
    pct_x_gdp_q10 = -q10 * gdp99,
    pct_x_gdp_q25 = -q25 * gdp99,
    pct_x_gdp_q50 = -q50 * gdp99,
    pct_x_gdp_q75 = -q75 * gdp99,
    pct_x_gdp_q90 = -q90 * gdp99,
    pct_x_gdp_q95 = -q95 * gdp99,
    pct_x_gdp_q99 = -q99 * gdp99) %>%
  dplyr::select(pct_x_gdp_mean,
                pct_x_gdp_q1,
                pct_x_gdp_q5,
                pct_x_gdp_q10,
                pct_x_gdp_q25,
                pct_x_gdp_q50,
                pct_x_gdp_q75,
                pct_x_gdp_q90,
                pct_x_gdp_q95,
                pct_x_gdp_q99,
                region, year, gdp99, decile)

# ========== COLLAPSE TO DECILE LEVEL ==========
# Sum damages across all impact regions within each income decile
cat("Aggregating to decile level...\n")
df_plot = df_pct_gdp_impacts %>% 
  group_by(decile) %>% 
  summarize(
    total_pct_x_gdp_2099_mean = sum(pct_x_gdp_mean, na.rm = TRUE), 
    total_pct_x_gdp_2099_q25 = sum(pct_x_gdp_q25, na.rm = TRUE), 
    total_pct_x_gdp_2099_q75 = sum(pct_x_gdp_q75, na.rm = TRUE), 
    total_pct_x_gdp_2099_q5 = sum(pct_x_gdp_q5, na.rm = TRUE), 
    total_pct_x_gdp_2099_q95 = sum(pct_x_gdp_q95, na.rm = TRUE), 
    total_pct_x_gdp_2099_q1 = sum(pct_x_gdp_q1, na.rm = TRUE), 
    total_pct_x_gdp_2099_q99 = sum(pct_x_gdp_q99, na.rm = TRUE), 
    total_pct_x_gdp_2099_q10 = sum(pct_x_gdp_q10, na.rm = TRUE), 
    total_pct_x_gdp_2099_q90 = sum(pct_x_gdp_q90, na.rm = TRUE), 
    total_pct_x_gdp_2099_q50 = sum(pct_x_gdp_q50, na.rm = TRUE), 
    total_gdp_2099 = sum(gdp99, na.rm = TRUE)) %>%
  # Convert to percentage of total decile GDP
  mutate(
    pct_gdp_mean = total_pct_x_gdp_2099_mean / total_gdp_2099 * 100,
    pct_gdp_q25 = total_pct_x_gdp_2099_q25 / total_gdp_2099 * 100,
    pct_gdp_q75 = total_pct_x_gdp_2099_q75 / total_gdp_2099 * 100,
    pct_gdp_q5 = total_pct_x_gdp_2099_q5 / total_gdp_2099 * 100,
    pct_gdp_q95 = total_pct_x_gdp_2099_q95 / total_gdp_2099 * 100,
    pct_gdp_q10 = total_pct_x_gdp_2099_q10 / total_gdp_2099 * 100,
    pct_gdp_q90 = total_pct_x_gdp_2099_q90 / total_gdp_2099 * 100,
    pct_gdp_q50 = total_pct_x_gdp_2099_q50 / total_gdp_2099 * 100,
    pct_gdp_q1 = total_pct_x_gdp_2099_q1 / total_gdp_2099 * 100,
    pct_gdp_q99 = total_pct_x_gdp_2099_q99 / total_gdp_2099 * 100)

# ========== PLOT 1: Simple Bar Chart ==========
cat("Creating simple bar chart...\n")
p1 = ggplot(data = df_plot) +
  geom_bar(aes(x = decile, y = pct_gdp_mean), 
           position = "dodge", stat = "identity", width = 0.8) + 
  theme_minimal() +
  ylab("Impact of Climate Change, Percentage GDP") +
  xlab("2015 Income Decile") +
  scale_x_discrete(limits = seq(1, 10)) +
  ggtitle("Decile %GDP Impact Bar Chart")

# Save simple bar chart
output_file_1 <- file.path(OUTPUT_DIR, "SSP3-rcp85_pct-gdp_by_inc_decile.pdf")
ggsave(p1, file = output_file_1, width = 8, height = 6)
cat("Saved:", output_file_1, "\n")

# ========== PLOT 2: Box Plot with Confidence Intervals ==========
cat("Creating box plot with confidence intervals...\n")
p2 = ggplot() + 
  # Error bars: 5th to 95th percentile
  geom_errorbar(
    data = df_plot,  
    aes(x = decile, ymin = pct_gdp_q5, ymax = pct_gdp_q95), 
    color = "dodgerblue4",
    lty = "solid",
    width = 0,
    alpha = 0.5,
    size = 0.5) +
  # Box plot: 10th to 90th percentile, with median line
  geom_boxplot(
    data = df_plot, 
    aes(group = decile, x = decile, 
        ymin = pct_gdp_q10, ymax = pct_gdp_q90, 
        lower = pct_gdp_q25, upper = pct_gdp_q75, middle = pct_gdp_q50), 
    fill = "dodgerblue4", 
    color = "white",
    size = 0.2, 
    stat = "identity") +
  # Mean point
  geom_point(
    data = df_plot, 
    aes(x = decile, y = pct_gdp_mean, group = 1), 
    size = 0.5, 
    color = "grey88", 
    alpha = 0.9) + 
  # Zero line reference
  geom_abline(intercept = 0, slope = 0, size = 0.1, alpha = 0.5) + 
  # Color scheme
  scale_fill_gradientn(colors = rev(brewer.pal(9, "RdGy"))) + 
  scale_color_gradientn(colors = rev(brewer.pal(9, "RdGy"))) + 
  scale_x_discrete(limits = seq(1, 10), breaks = seq(1, 10)) +
  # Theme
  theme_bw() +
  theme(
    panel.grid.major = element_blank(), 
    panel.grid.minor = element_blank(),
    panel.background = element_blank(),
    legend.position = "none",
    axis.line = element_line(colour = "black")) +
  xlab("2015 Income Decile") +
  ylab("Percent GDP") +
  ggtitle("Decile %GDP Impact with Confidence Intervals")

# Save box plot with CI
output_file_2 <- file.path(OUTPUT_DIR, "SSP3-rcp85_pct-gdp_by_inc_decile_with_CI.pdf")
ggsave(p2, file = output_file_2, width = 8, height = 6)
cat("Saved:", output_file_2, "\n")

cat("\n========== ANALYSIS COMPLETE ==========\n")
cat("Output directory:", OUTPUT_DIR, "\n")
cat("Sample size by decile:\n")
print(table(df_pct_gdp_impacts$decile))