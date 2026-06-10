#==============================================================================#
#  3_table_6_xr.R
#  Sensitivity table: varying short-term wage flexibility (exr scaling).
#
#  Rows:
#    (1) Global avg hedonic value of thermal comfort    [% annual income]
#    (2) Labor disutility cost at 2099, RCP8.5          [% 2099 global GDP]
#    (3) Labor disutility cost at 2099, RCP4.5          [% 2099 global GDP]
#    (4) Partial SCC, RCP8.5, delta = 2%                [USD]
#    (5) Partial SCC, RCP4.5, delta = 2%                [USD]
#
#  Columns:
#    (1) Baseline: frisch_HR = frisch_LR = 0.5, no wage-flexibility adjustment
#    (2)-(5) Sensitivity: baseline × (1 − e·x·r)
#              e = 0.5 (share of labor income exposed)
#              r = 0.65 (share of that income at risk)
#              x = 0.5 / 1.5 / 3 / −0.67 (wage-change multiplier)
#    (6) Income-interaction model (independent source, no scaling)
#
#  Calculation logic:
#    - Col 1 baseline values come from pre-computed / hard-coded sources.
#    - Cols 2–5 are derived by scale_result(baseline, exr = e·x·r), which
#      multiplies mean and both CI bounds by (1 − exr).
#    - Col 6 is read independently from the interacted-model outputs.
#
#  Data sources:
#    Row 1  col 1   : table4_hedonic_value.tex
#    Row 1  col 2-5 : scale_result(base_row1, exr)
#    Row 1  col 6   : table4_hedonic_value_interacted.tex
#    Row 2  col 1   : run_disutility("rcp85", 0.5, 0.5)
#    Row 2  col 2-5 : scale_result(base_row2, exr)
#    Row 2  col 6   : SSP3-rcp85 GDP-aggregated CSV (interacted model)
#    Row 3  col 1   : run_disutility("rcp45", 0.5, 0.5)
#    Row 3  col 2-5 : scale_result(base_row3, exr)
#    Row 3  col 6   : SSP3-rcp45 GDP-aggregated CSV (interacted model)
#    Row 4-5 col 1  : hard-coded from prior run
#    Row 4-5 col 2-5: scale_result(base_rowX, exr)
#    Row 4-5 col 6  : hard-coded from prior run
#==============================================================================#

#==============================================================================#
# 0. Packages, paths, and source helper scripts ----
#==============================================================================#

packages <- c("data.table", "tidyverse", "glue", "Hmisc")
invisible(lapply(packages, function(pkg) {
  suppressPackageStartupMessages(library(pkg, character.only = TRUE))
}))
rm(packages)

USER <- Sys.getenv("USER")
source(glue('/project/cil/home_dirs/{USER}/repos/labor-code-release-2020-mq-latest/disutility_ext/3_table_6_utils.R'))

#==============================================================================#
# 1. Define EXR values and column sub-headers ----
#==============================================================================#

# Each entry: list(e = ..., x = ..., r = ...)
# exr = e * x * r is computed automatically; scaled = value * (1 - e*x*r)
# Set e = 0 for the baseline column (no scaling)
exr_cols <- list(
  col1 = list(e = 0.5,    x = 0,    r = 0),      # baseline, no scaling
  col2 = list(e = 0.5,   x = 0.5,   r = 0.65),   # <-- fill in e
  col3 = list(e = 0.5,   x = 1.5,   r = 0.65),   # <-- fill in e
  col4 = list(e = 0.5,   x = 3,     r = 0.65),   # <-- fill in e
  col5 = list(e = 0.5,   x = -2/3,  r = 0.65)    # <-- fill in e
)

#==============================================================================#
# 2. Compute baseline (frisch_HR = frisch_LR = 0.5) ----
#==============================================================================#

message("Reading baseline hedonic value from table4 tex ...")
base_row1 <- read_hedonic_tex("/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/output/tables/table4_hedonic_value.tex")

message("Computing baseline disutility RCP8.5 ...")
base_row2 <- run_disutility("rcp85", 0.5, 0.5)

message("Computing baseline disutility RCP4.5 ...")
base_row3 <- run_disutility("rcp45", 0.5, 0.5)

# Hard-coded baseline values for rows 4 & 5 (partial SCC, in USD)
base_row4 <- list(mean = 10.6, p5 = -0.3,  p95 = 56.1)
base_row5 <- list(mean = 6.6,  p5 = -3.4,  p95 = 41.5)

#==============================================================================#
# 3. Apply (1 - exr) scaling to each column ----
#==============================================================================#

scale_result <- function(base, exr) {
  # Normalise: run_disutility returns p17/p83; hedonic and SCC return p5/p95.
  p_lo <- if (!is.null(base$p17)) base$p17 else base$p5
  p_hi <- if (!is.null(base$p83)) base$p83 else base$p95
  if (is.null(exr) || is.na(exr)) return(list(mean = NA, p_lo = NA, p_hi = NA))
  list(
    mean = base$mean * (1 - exr),
    p_lo = p_lo      * (1 - exr),
    p_hi = p_hi      * (1 - exr)
  )
}

row1 <- lapply(exr_cols, function(e) scale_result(base_row1, e$e * e$x * e$r))
row2 <- lapply(exr_cols, function(e) scale_result(base_row2, e$e * e$x * e$r))
row3 <- lapply(exr_cols, function(e) scale_result(base_row3, e$e * e$x * e$r))
row4 <- lapply(exr_cols, function(e) scale_result(base_row4, e$e * e$x * e$r))
row5 <- lapply(exr_cols, function(e) scale_result(base_row5, e$e * e$x * e$r))

#==============================================================================#
# 4. Save raw results as a data frame (full precision) ----
#==============================================================================#

make_raw_df <- function(row_results, row_label) {
  do.call(rbind, lapply(names(row_results), function(col) {
    x <- row_results[[col]]
    e <- exr_cols[[col]]
    data.frame(
      row  = row_label,
      col  = col,
      e    = if (!is.null(e$e)   && !is.na(e$e))   e$e   else NA_real_,
      x    = if (!is.null(e$x)   && !is.na(e$x))   e$x   else NA_real_,
      r    = if (!is.null(e$r)   && !is.na(e$r))   e$r   else NA_real_,
      exr  = if (!is.null(e$e) && !is.null(e$x) && !is.null(e$r) &&
                 !is.na(e$e)  && !is.na(e$x)  && !is.na(e$r))
        e$e * e$x * e$r else NA_real_,
      mean = if (!is.null(x$mean))  x$mean  else NA_real_,
      p_lo = if (!is.null(x$p_lo)) x$p_lo  else NA_real_,
      p_hi = if (!is.null(x$p_hi)) x$p_hi  else NA_real_,
      stringsAsFactors = FALSE
    )
  }))
}

results_raw <- rbind(
  make_raw_df(row1, "hedonic"),
  make_raw_df(row2, "disutility_rcp85"),
  make_raw_df(row3, "disutility_rcp45"),
  make_raw_df(row4, "scc_rcp85"),
  make_raw_df(row5, "scc_rcp45")
)

print(results_raw)
# write.csv(results_raw, "table6b_results_raw.csv", row.names = FALSE)

#==============================================================================#
# 5. Format cell values ----
#==============================================================================#

fmt_cell_hedonic <- function(x) {
  if (is.na(x$mean)) return(c("", ""))
  c(glue("{round(x$mean, 1)}\\%"), glue("{{[{round(x$p_lo, 1)}\\%,{round(x$p_hi, 1)}\\%]}}"))
}

fmt_cell_disutility <- function(x) {
  if (is.na(x$mean)) return(c("", ""))
  # Costs are negative; display as absolute values with [smaller, larger] order.
  # p_lo (p17 / p5) is more negative → larger absolute value → upper bound.
  c(glue("{round(abs(x$mean), 1)}\\%"), glue("{{[{round(abs(x$p_hi), 1)}\\%,{round(abs(x$p_lo), 1)}\\%]}}"))
}

# Formatter for SCC rows: dollar values, 1 decimal place
# CI order follows sign convention: [low, high] in dollar terms
fmt_cell_scc <- function(x) {
  if (is.na(x$mean)) return(c("", ""))
  fmt_dollar <- function(v) {
    if (v < 0) glue("-\\${round(abs(v), 1)}") else glue("\\${round(v, 1)}")
  }
  lo <- min(x$p_lo, x$p_hi)
  hi <- max(x$p_lo, x$p_hi)
  c(fmt_dollar(x$mean), glue("{{[{fmt_dollar(lo)},{fmt_dollar(hi)}]}}"))
}

fmt_exr <- function(e) {
  if (is.na(e$x) || e$x == 0) return(c("", ""))
  # Format x: show as fraction if needed
  x_str <- ifelse(e$x == round(e$x), as.character(e$x), sprintf("%.2g", e$x))
  c(paste0("$x = ", x_str, "$"), paste0("$r = ", e$r, "$"))
}

cell <- function(lst, fmt_fn, line) sapply(lst, function(x) fmt_fn(x)[line])

exr_line1 <- paste(cell(exr_cols[2:5], fmt_exr, 1), collapse = " & ")
exr_line2 <- paste(cell(exr_cols[2:5], fmt_exr, 2), collapse = " & ")

r1l1 <- paste(cell(row1, fmt_cell_hedonic,    1), collapse = " & ")
r1l2 <- paste(cell(row1, fmt_cell_hedonic,    2), collapse = " & ")
r2l1 <- paste(cell(row2, fmt_cell_disutility, 1), collapse = " & ")
r2l2 <- paste(cell(row2, fmt_cell_disutility, 2), collapse = " & ")
r3l1 <- paste(cell(row3, fmt_cell_disutility, 1), collapse = " & ")
r3l2 <- paste(cell(row3, fmt_cell_disutility, 2), collapse = " & ")
r4l1 <- paste(cell(row4, fmt_cell_scc,        1), collapse = " & ")
r4l2 <- paste(cell(row4, fmt_cell_scc,        2), collapse = " & ")
r5l1 <- paste(cell(row5, fmt_cell_scc,        1), collapse = " & ")
r5l2 <- paste(cell(row5, fmt_cell_scc,        2), collapse = " & ")

# Column 6, row 1: interacted model hedonic value
# scale_result(..., 0) normalises p5/p95 -> p_lo/p_hi without changing values
col6_r1   <- scale_result(
  read_hedonic_tex("/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/output/tables/table4_hedonic_value_interacted.tex"),
  0
)
col6_r1l1 <- fmt_cell_hedonic(col6_r1)[1]
col6_r1l2 <- fmt_cell_hedonic(col6_r1)[2]

# Column 6, rows 2 & 3: interacted model disutility from GDP-aggregated CSVs
col6_r2   <- read_disutility_gdp_csv("/project/cil/gcp/outputs/labor/impacts-corpsepose/montecarlo/extracted/clim_interacted_model_agnonag_27_28_41/rcp85/high/SSP3/SSP3-rcp85_high_rebased_fulladapt-gdp-aggregated.csv")
col6_r2l1 <- fmt_cell_disutility(col6_r2)[1]
col6_r2l2 <- fmt_cell_disutility(col6_r2)[2]

col6_r3   <- read_disutility_gdp_csv("/project/cil/gcp/outputs/labor/impacts-corpsepose/montecarlo/extracted/clim_interacted_model_agnonag_27_28_41/rcp45/high/SSP3/SSP3-rcp45_high_rebased_fulladapt-gdp-aggregated.csv")
col6_r3l1 <- fmt_cell_disutility(col6_r3)[1]
col6_r3l2 <- fmt_cell_disutility(col6_r3)[2]

# Column 6: within risk group heterogeneity — hard-coded for rows 4-5 pending pipeline
col6_r4l1 <- "\\$27.6"
col6_r4l2 <- "{[\\$2.6,\\$126.0]}"
col6_r5l1 <- "\\$18.1"
col6_r5l2 <- "{[\\$0.7,\\$93.7]}"

#==============================================================================#
# 6. Write LaTeX table ----
#==============================================================================#

# Use paste0 instead of glue to avoid double-escaping of \ and &
NL  <- "\n"   # newline
CR  <- " \\\\"  # LaTeX row-end: space + double backslash

latex_table <- paste0(
  "\\begin{landscape}", NL,
  "\\begin{table}[p]", NL,
  "\\centering", NL,
  "\\resizebox{\\textheight}{!}{", NL,
  "\\begin{tabular}{llcccccc}", NL,
  "\\toprule", NL,
  "& & \\multicolumn{6}{c}{\\textbf{Sensitivity to assumptions}}", CR, NL,
  "\\cmidrule(lr){3-8}", NL,
  "& & Baseline & \\multicolumn{4}{c}{Short-term wage flexibility} & Within risk group", CR, NL,
  "& & model    & \\multicolumn{4}{c}{} & heterogeneity", CR, NL,
  "\\cmidrule(lr){3-3} \\cmidrule(lr){4-7} \\cmidrule(lr){8-8}", NL,
  "& \\textbf{Estimate} & (1) & (2) & (3) & (4) & (5) & (6)", CR, NL,
  "\\cmidrule(lr){3-3} \\cmidrule(lr){4-7} \\cmidrule(lr){8-8}", NL,
  "& & & ", exr_line1, " & ", CR, NL,
  "& & & ", exr_line2, " & ", CR, NL,
  "\\addlinespace", NL,
  "\\multirow{2}{*}{(1)}", NL,
  "& Global average value of thermal comfort", NL,
  "& ", r1l1, " & ", col6_r1l1, CR, NL,
  "& in a low-risk job (\\% annual income)", NL,
  "& ", r1l2, " & ", col6_r1l2, CR, NL,
  "\\addlinespace", NL,
  "\\multirow{2}{*}{(2)}", NL,
  "& Labor disutility cost of climate change", NL,
  "& ", r2l1, " & ", col6_r2l1, CR, NL,
  "& at 2099 (RCP8.5, \\% 2099 global GDP)", NL,
  "& ", r2l2, " & ", col6_r2l2, CR, NL,
  "\\addlinespace", NL,
  "\\multirow{2}{*}{(3)}", NL,
  "& Labor disutility cost of climate change", NL,
  "& ", r3l1, " & ", col6_r3l1, CR, NL,
  "& at 2099 (RCP4.5, \\% 2099 global GDP)", NL,
  "& ", r3l2, " & ", col6_r3l2, CR, NL,
  "\\addlinespace", NL,
  "\\multirow{2}{*}{(4)}", NL,
  "& Partial SCC (RCP8.5, $\\delta=2\\%$)", NL,
  "& ", r4l1, " & ", col6_r4l1, CR, NL,
  "& ", NL,
  "& ", r4l2, " & ", col6_r4l2, CR, NL,
  "\\addlinespace", NL,
  "\\multirow{2}{*}{(5)}", NL,
  "& Partial SCC (RCP4.5, $\\delta=2\\%$)", NL,
  "& ", r5l1, " & ", col6_r5l1, CR, NL,
  "& ", NL,
  "& ", r5l2, " & ", col6_r5l2, CR, NL,
  "\\bottomrule", NL,
  "\\end{tabular}", NL,
  "}", NL,
  "\\caption{\\textbf{Sensitivity of estimates to assumptions.}}", NL,
  "\\label{tab:sensitivity_exr}", NL,
  "\\end{table}", NL,
  "\\end{landscape}", NL
)

cat(latex_table)
writeLines(latex_table, "/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/output/tables/table6_sensitivity_xr.tex")