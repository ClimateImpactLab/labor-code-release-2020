#==============================================================================#
#  
#  Sensitivity table: varying Frisch elasticity (εH, εL).
#
# Created by: Maiqi Yu
#
#  Rows:
#    (1) Global avg hedonic value of thermal comfort    [% annual income]
#    (2) Labor disutility cost at 2099, RCP4.5          [% 2099 global GDP]
#    (3) Labor disutility cost at 2099, RCP8.5          [% 2099 global GDP]
#    (4) Partial SCC, RCP4.5, delta = 2%                [USD]
#    (5) Partial SCC, RCP8.5, delta = 2%                [USD]
#
#  Columns:
#    (1) Baseline: εH = εL = 0.5
#    (2) εH = εL = 0.37
#    (3) εH = εL = 0.70
#    (4) εH = 0.70, εL = 0.37
#    (5) εH = 0.37, εL = 0.70
#
#  Calculation logic:
#    - Each column recomputes independently with its own (εH, εL) pair;
#      no multiplicative scaling is applied between columns.
#    - Col 1 row 1 reads from a pre-computed tex file (same baseline as xr table).
#    - Cols 2–5 row 1 call run_hedonic(εH, εL) directly.
#    - All columns rows 2–3 call run_disutility(rcp, εH, εL); col 1 uses
#      (0.5, 0.5) and therefore matches the xr table baseline exactly.
#    - Rows 4–5 are hard-coded: cols 1-3 model collapsed, cols 4-5 OECD only.
#
#  Data sources:
#    Row 1  col 1   : table4_hedonic_value.tex
#    Row 1  col 2-5 : run_hedonic(εH, εL)
#    Row 2  col 1-5 : run_disutility("rcp45", εH, εL)
#    Row 3  col 1-5 : run_disutility("rcp85", εH, εL)
#    Row 4-5 col 1-5: hard-coded from final SCC pipeline output (SSP3)
#==============================================================================#

#==============================================================================#
# 0. Packages, paths, shared functions ----
#==============================================================================#

packages <- c("data.table", "tidyverse", "glue", "Hmisc")
invisible(lapply(packages, function(pkg) {
  suppressPackageStartupMessages(library(pkg, character.only = TRUE))
}))
rm(packages)

USER <- Sys.getenv("USER")
source(glue('/project/cil/home_dirs/{USER}/repos/labor-code-release-2020/0_subroutines/paths.R'))
source(glue('/project/cil/home_dirs/{USER}/repos/labor-code-release-2020/4_post_projection/5_sensitivity_table/table_6_utils.R'))

# Underlying SCC values (rows 4-5) are in 2019 USD; convert to 2025 USD for reporting.
# Matches CPI factor used in 4_post_projection/2_damage_function/damage_function.R.
CPI_2019_TO_2025 <- 321.943 / 255.657  # BLS CPI-U annual average, 2019 -> 2025

#==============================================================================#
# 1. Define Frisch elasticity combinations ----
#==============================================================================#

frisch_cols <- list(
  col1 = c(0.5,  0.5),    # baseline
  col2 = c(0.37, 0.37),
  col3 = c(0.7,  0.7),
  col4 = c(0.7,  0.37),
  col5 = c(0.37, 0.7)
)

#==============================================================================#
# 2. Rows 1–3: compute across all columns ----
#==============================================================================#

message("Reading Row 1, col 1: baseline hedonic value from table4 tex ...")
message("Computing Row 1, cols 2-5: hedonic value ...")
row1 <- c(
  list(col1 = read_hedonic_tex(file.path(DIR_TABLE, "table4_hedonic_value.tex"))),
  lapply(frisch_cols[-1], function(f) {
    if (any(is.na(f))) return(list(mean = NA, p5 = NA, p95 = NA))
    run_hedonic(f[1], f[2])
  })
)

message("Computing Row 2: disutility RCP4.5 ...")
row2 <- lapply(frisch_cols, function(f) {
  if (any(is.na(f))) return(list(mean = NA, se = NA, p5 = NA, p95 = NA))
  run_disutility("rcp45", f[1], f[2])
})

message("Computing Row 3: disutility RCP8.5 ...")
row3 <- lapply(frisch_cols, function(f) {
  if (any(is.na(f))) return(list(mean = NA, se = NA, p5 = NA, p95 = NA))
  run_disutility("rcp85", f[1], f[2])
})

#==============================================================================#
# 3. Rows 4–5: partial SCC — hard-coded from final SCC pipeline output ----
#==============================================================================#

# col1 (baseline) uses full-precision values, same source as table_6_xr.R base_row4/5.
# cols 2-5 are separate hard-coded runs (frisch elasticity variants); full-precision
# source for these has not been verified/located, so they remain at 1dp.
row4 <- list(
  col1 = list(mean =  6.592657, p_lo = -3.375662,  p_hi = 41.528585),
  col2 = list(mean =  8.9, p_lo = -4.6,  p_hi = 56.1),
  col3 = list(mean =  4.7, p_lo = -2.4,  p_hi = 29.7),
  col4 = list(mean =  8.1, p_lo = -3.1,  p_hi = 46.0),
  col5 = list(mean =  6.6, p_lo = -4.3,  p_hi = 48.9)
)

row5 <- list(
  col1 = list(mean = 10.647199, p_lo = -0.325399,  p_hi = 56.093764),
  col2 = list(mean = 14.4, p_lo = -0.4,  p_hi = 75.8),
  col3 = list(mean =  7.6, p_lo = -0.2,  p_hi = 40.1),
  col4 = list(mean = 11.7, p_lo = -0.4,  p_hi = 59.5),
  col5 = list(mean = 12.4, p_lo = -0.7,  p_hi = 70.5)
)

#==============================================================================#
# 4. Save raw results as a data frame (full precision) ----
#==============================================================================#

make_raw_df_frisch <- function(row_results, row_label) {
  do.call(rbind, lapply(names(row_results), function(col) {
    x <- row_results[[col]]
    f <- frisch_cols[[col]]
    data.frame(
      row       = row_label,
      col       = col,
      frisch_HR = if (!is.null(f) && length(f) >= 1 && !is.na(f[1])) f[1] else NA_real_,
      frisch_LR = if (!is.null(f) && length(f) >= 2 && !is.na(f[2])) f[2] else NA_real_,
      mean      = if (!is.null(x$mean)) x$mean else NA_real_,
      p5_or_lo  = if (!is.null(x$p5))  x$p5   else if (!is.null(x$p_lo)) x$p_lo else NA_real_,
      p95_or_hi = if (!is.null(x$p95)) x$p95  else if (!is.null(x$p_hi)) x$p_hi else NA_real_,
      stringsAsFactors = FALSE
    )
  }))
}

results_raw <- rbind(
  make_raw_df_frisch(row1, "hedonic"),
  make_raw_df_frisch(row2, "disutility_rcp45"),
  make_raw_df_frisch(row3, "disutility_rcp85"),
  make_raw_df_frisch(row4, "scc_rcp45"),
  make_raw_df_frisch(row5, "scc_rcp85")
)

print(results_raw)
# write.csv(results_raw, "table6e_results_raw.csv", row.names = FALSE)

#==============================================================================#
# 5. Format cell values ----
#==============================================================================#

fmt_cell_hedonic <- function(x) {
  if (is.na(x$mean)) return(c("", ""))
  c(glue("{round(x$mean, 1)}\\%"),
    glue("{{[{round(x$p5, 1)}\\%,{round(x$p95, 1)}\\%]}}"))
}

fmt_cell_disutility <- function(x) {
  if (is.na(x$mean)) return(c("", ""))
  # p5 is the 5th pctile of the (negative) distribution -> largest absolute value -> upper bound
  c(glue("{round(abs(x$mean), 1)}\\%"),
    glue("{{[{round(abs(x$p95), 1)}\\%,{round(abs(x$p5), 1)}\\%]}}"))
}

# Values are converted from 2019 USD to 2025 USD via CPI_2019_TO_2025.
fmt_cell_scc <- function(x) {
  if (is.null(x$mean) || is.na(x$mean)) return(c("", ""))
  fmt_dollar <- function(v) {
    if (v < 0) glue("-\\${round(abs(v), 1)}") else glue("\\${round(v, 1)}")
  }
  mean_2025 <- x$mean * CPI_2019_TO_2025
  lo <- min(x$p_lo, x$p_hi) * CPI_2019_TO_2025
  hi <- max(x$p_lo, x$p_hi) * CPI_2019_TO_2025
  c(fmt_dollar(mean_2025), glue("[{fmt_dollar(lo)},{fmt_dollar(hi)}]"))
}

fmt_frisch <- function(f) {
  if (any(is.na(f))) return(c("", ""))
  c(glue("$\\epsilon^h = {f[1]}$"), glue("$\\epsilon^l = {f[2]}$"))
}

cell <- function(lst, fmt_fn, line) sapply(lst, function(x) fmt_fn(x)[line])

# Sub-header rows: col1 is baseline (label in column header, not sub-header row)
frisch_line1 <- paste(cell(frisch_cols, fmt_frisch, 1), collapse = " & ")
frisch_line2 <- paste(cell(frisch_cols, fmt_frisch, 2), collapse = " & ")

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

#==============================================================================#
# 6. Write LaTeX table ----
#==============================================================================#

NL   <- "\n"
CR   <- " \\\\"
ALS  <- "\\addlinespace"  # booktabs spacer between row groups

latex_table <- paste0(
  "\\begin{sidewaystable}[!htbp]", NL,
  "\\centering", NL,
  "\\footnotesize", NL,
  "%\\resizebox{\\linewidth}{!}{%", NL,
  "\\begin{tabular}{llccccc}", NL,
  "\\toprule", NL,
  "& & \\multicolumn{5}{c}{\\textbf{Sensitivity to alternative Frisch elasticity values}}", CR, " \\cmidrule(lr){3-7}", NL,
  "& & Baseline & \\multicolumn{4}{c}{Alternative Frisch elasticity values}", CR, NL,
  "\\cmidrule(lr){3-3} \\cmidrule(lr){4-7}", NL,
  "& \\textbf{Estimate} & (1) & (2) & (3) & (4) & (5)", CR, NL,
  "\\cmidrule(lr){3-3} \\cmidrule(lr){4-7}", NL,
  "& & ", frisch_line1, CR, NL,
  "& & ", frisch_line2, CR, NL,
  ALS, NL,
  "\\multirow{2}{*}{(1)}", NL,
  "& Global average value of thermal comfort", NL,
  "& ", r1l1, CR, NL,
  "& in a low-risk job (\\% annual income)", NL,
  "& ", r1l2, CR, NL,
  ALS, NL,
  "\\multirow{2}{*}{(2)}", NL,
  "& Labor disutility cost of climate change", NL,
  "& ", r2l1, CR, NL,
  "& at 2099 (RCP4.5, \\% 2099 global GDP)", NL,
  "& ", r2l2, CR, NL,
  ALS, NL,
  "\\multirow{2}{*}{(3)}", NL,
  "& Labor disutility cost of climate change", NL,
  "& ", r3l1, CR, NL,
  "& at 2099 (RCP8.5, \\% 2099 global GDP)", NL,
  "& ", r3l2, CR, NL,
  ALS, NL,
  "\\multirow{2}{*}{(4)}", NL,
  "& Partial SCC for labor disutility (RCP4.5, $\\delta=2\\%$)", NL,
  "& ", r4l1, CR, NL,
  "& ", NL,
  "& ", r4l2, CR, NL,
  ALS, NL,
  "\\multirow{2}{*}{(5)}", NL,
  "& Partial SCC for labor disutility (RCP8.5, $\\delta=2\\%$)", NL,
  "& ", r5l1, CR, NL,
  "& ", NL,
  "& ", r5l2, CR, NL,
  "\\bottomrule", NL,
  "\\end{tabular}%}", NL,
  "\\caption{\\textbf{Sensitivity of estimates to alternative Frisch elasticity values.}\\label{tab:epsilonsensitivity}}", NL,
  "\\end{sidewaystable}", NL
)

cat(latex_table)
writeLines(latex_table, file.path(DIR_TABLE, "table6_sensitivity_e.tex"))
