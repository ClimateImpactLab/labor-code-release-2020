#==============================================================================#
#'
#' SCRIPT 4: Generate Sensitivity Table (Table 6b) — EXR scaling
#'
#' This script generates a sensitivity table where column (1) is the baseline
#' (frisch_HR = frisch_LR = 0.5), and columns (2)-(5) apply a scaling factor
#' (1 - exr) to both the mean and the interval bounds. The exr values
#' correspond to different assumptions about the share of income at risk,
#' parameterised as x and r in the column sub-headers.
#'
#' Row layout:
#'   (1) Global average hedonic value of thermal comfort (% annual income)
#'   (2) Labor disutility cost at 2099, RCP8.5 (% 2099 global GDP)
#'   (3) Labor disutility cost at 2099, RCP4.5 (% 2099 global GDP)
#'
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
source(glue('/project/cil/home_dirs/{USER}/repos/labor-code-release-2020/0_subroutines/paths.R'))

source("/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/disutility_ext/3_table_6_e_row1.R")
source("/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/disutility_ext/3_table_6_e_row23.R")

#==============================================================================#
# 1. Define EXR values and column sub-headers ----
#==============================================================================#

# Each entry: list(e = ..., x = ..., r = ...)
# exr = e * x * r is computed automatically; scaled = value * (1 - e*x*r)
# Set e = 0 for the baseline column (no scaling)
exr_cols <- list(
  col1 = list(e = 0.5,    x = 0,    r = 0),      # baseline, no scaling
  col2 = list(e = 0.5,   x = 0.5,   r = 0.35),   # <-- fill in e
  col3 = list(e = 0.5,   x = 1.5,   r = 0.35),   # <-- fill in e
  col4 = list(e = 0.5,   x = 3,     r = 0.35),   # <-- fill in e
  col5 = list(e = 0.5,   x = -2/3,  r = 0.35)    # <-- fill in e
)

#==============================================================================#
# 2. Compute baseline (frisch_HR = frisch_LR = 0.5) ----
#==============================================================================#

message("Computing baseline hedonic value ...")
base_row1 <- run_hedonic(0.5, 0.5)

message("Computing baseline disutility RCP8.5 ...")
base_row2 <- run_disutility("rcp85", 0.5, 0.5)

message("Computing baseline disutility RCP4.5 ...")
base_row3 <- run_disutility("rcp45", 0.5, 0.5)

#==============================================================================#
# 3. Apply (1 - exr) scaling to each column ----
#==============================================================================#

scale_result <- function(base, exr) {
  if (is.null(exr) || is.na(exr)) return(list(mean = NA, p5 = NA, p95 = NA))
  list(
    mean = base$mean * (1 - exr),
    p5   = base$p5  * (1 - exr),
    p95  = base$p95 * (1 - exr)
  )
}

row1 <- lapply(exr_cols, function(e) scale_result(base_row1, e$e * e$x * e$r))
row2 <- lapply(exr_cols, function(e) scale_result(base_row2, e$e * e$x * e$r))
row3 <- lapply(exr_cols, function(e) scale_result(base_row3, e$e * e$x * e$r))

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
      mean = if (!is.null(x$mean)) x$mean else NA_real_,
      p5   = if (!is.null(x$p5))  x$p5   else NA_real_,
      p95  = if (!is.null(x$p95)) x$p95  else NA_real_,
      stringsAsFactors = FALSE
    )
  }))
}

results_raw <- rbind(
  make_raw_df(row1, "hedonic"),
  make_raw_df(row2, "disutility_rcp85"),
  make_raw_df(row3, "disutility_rcp45")
)

print(results_raw)
# write.csv(results_raw, "table6b_results_raw.csv", row.names = FALSE)

#==============================================================================#
# 5. Format cell values ----
#==============================================================================#

fmt_cell_hedonic <- function(x) {
  if (is.na(x$mean)) return(c("", ""))
  c(glue("{round(x$mean, 1)}\\%"), glue("[{round(x$p5, 1)}\\%,{round(x$p95, 1)}\\%]"))
}

fmt_cell_disutility <- function(x) {
  if (is.na(x$mean)) return(c("", ""))
  c(glue("{round(abs(x$mean), 2)}\\%"), glue("[{round(abs(x$p95), 2)}\\%,{round(abs(x$p5), 2)}\\%]"))
}

fmt_exr <- function(e) {
  if (is.na(e$x)) return(c("", ""))
  c(glue("$x = {e$x}$"), glue("$r = {e$r}$"))
}

cell <- function(lst, fmt_fn, line) sapply(lst, function(x) fmt_fn(x)[line])

exr_line1 <- paste(c("", "", cell(exr_cols[2:5], fmt_exr, 1), ""), collapse = " & ")
exr_line2 <- paste(c("", "", cell(exr_cols[2:5], fmt_exr, 2), ""), collapse = " & ")

r1l1 <- paste(c(cell(row1, fmt_cell_hedonic,    1), ""), collapse = " & ")
r1l2 <- paste(c(cell(row1, fmt_cell_hedonic,    2), ""), collapse = " & ")
r2l1 <- paste(c(cell(row2, fmt_cell_disutility, 1), ""), collapse = " & ")
r2l2 <- paste(c(cell(row2, fmt_cell_disutility, 2), ""), collapse = " & ")
r3l1 <- paste(c(cell(row3, fmt_cell_disutility, 1), ""), collapse = " & ")
r3l2 <- paste(c(cell(row3, fmt_cell_disutility, 2), ""), collapse = " & ")

#==============================================================================#
# 6. Write LaTeX table ----
#==============================================================================#

latex_table <- glue('
\\begin{{landscape}}
\\begin{{table}}[p]
\\centering
\\resizebox{{\\textheight}}{{!}}{{%
\\begin{{tabular}}{{llcccccc}}
\\toprule
& & \\multicolumn{{6}}{{c}}{{\\textbf{{Sensitivity to assumptions}}}} \\\\
\\cmidrule(lr){{3-8}}
& & Baseline  & \\multicolumn{{4}}{{c}}{{Short-term wage}} & Within risk group \\\\
& & model     & \\multicolumn{{4}}{{c}}{{flexibility}}     & heterogeneity \\\\
\\cmidrule(lr){{3-3}} \\cmidrule(lr){{4-7}} \\cmidrule(lr){{8-8}}
& \\textbf{{Estimate}} & (1) & (2) & (3) & (4) & (5) & (6) \\\\
\\cmidrule(lr){{3-3}} \\cmidrule(lr){{4-7}} \\cmidrule(lr){{8-8}}
& & & {exr_line1} \\\\
& & & {exr_line2} \\\\
\\addlinespace
\\multirow{{2}}{{*}}{{(1)}}
& Global average value of thermal comfort
& {r1l1} \\\\
& in a low-risk job (\\% annual income)
& {r1l2} \\\\
\\addlinespace
\\multirow{{2}}{{*}}{{(2)}}
& Labor disutility cost of climate change
& {r2l1} \\\\
& at 2099 (RCP8.5, \\% 2099 global GDP)
& {r2l2} \\\\
\\addlinespace
\\multirow{{2}}{{*}}{{(3)}}
& Labor disutility cost of climate change
& {r3l1} \\\\
& at 2099 (RCP4.5, \\% 2099 global GDP)
& {r3l2} \\\\
\\addlinespace
\\multirow{{2}}{{*}}{{(4)}}
& Partial social cost of carbon for
& & & & & & \\\\
& labor disutility (RCP8.5, $\\delta=2\\%$)
& & & & & & \\\\
\\addlinespace
\\multirow{{2}}{{*}}{{(5)}}
& Partial social cost of carbon for
& & & & & & \\\\
& labor disutility (RCP4.5, $\\delta=2\\%$)
& & & & & & \\\\
\\bottomrule
\\end{{tabular}}
}}
\\caption{{\\textbf{{Sensitivity of estimates to assumptions.}}}}
\\label{{tab:sensitivity_exr}}
\\end{{table}}
\\end{{landscape}}
')

cat(latex_table)
# writeLines(latex_table, "table6b_sensitivity.tex")