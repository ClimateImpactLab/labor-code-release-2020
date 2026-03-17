#==============================================================================#
#'
#' SCRIPT 3: Generate Sensitivity Table (Table 6)
#'
#' This script sources Scripts 1 and 2 to obtain run_hedonic() and
#' run_disutility(), then calls them across multiple Frisch elasticity
#' combinations to fill the sensitivity table.
#'
#' Column layout: each column corresponds to a (frisch_HR, frisch_LR) pair.
#'
#' Row layout:
#'   (1) Global average hedonic value of thermal comfort (% annual income)
#'       from run_hedonic() — reported as mean [p5%, p95%]
#'   (2) Labor disutility cost at 2099, RCP8.5 (% 2099 global GDP)
#'   (3) Same as Row (2) but for RCP4.5
#'   (4) SCC
#'   (5) SCC
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

# Source helper scripts — only loads run_hedonic() and run_disutility()
source("/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/disutility_ext/3_table_6_e_row1.R")
source("/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/disutility_ext/3_table_6_e_row23.R")

#==============================================================================#
# 1. Define Frisch elasticity combinations ----
#==============================================================================#

# Each entry is c(frisch_HR, frisch_LR); NA = column left blank
frisch_cols <- list(
  col1 = c(0.5, 0.5),   # baseline
  col2 = c(0.4,  0.5),    # <-- fill in
  col3 = c(NA,  NA),    # <-- fill in
  col4 = c(NA,  NA),    # <-- fill in
  col5 = c(NA,  NA)     # <-- fill in
)

#==============================================================================#
# 2. Run computations across all columns ----
#==============================================================================#

message("Computing Row 1: hedonic value ...")
row1 <- lapply(frisch_cols, function(f) {
  if (any(is.na(f))) return(list(mean = NA, p5 = NA, p95 = NA))
  run_hedonic(f[1], f[2])
})

message("Computing Row 2: disutility RCP8.5 ...")
row2 <- lapply(frisch_cols, function(f) {
  if (any(is.na(f))) return(list(mean = NA, se = NA))
  run_disutility("rcp85", f[1], f[2])
})

message("Computing Row 3: disutility RCP4.5 ...")
row3 <- lapply(frisch_cols, function(f) {
  if (any(is.na(f))) return(list(mean = NA, se = NA))
  run_disutility("rcp45", f[1], f[2])
})

#==============================================================================#
# 3. Save raw results as a data frame (full precision) ----
#==============================================================================#

make_raw_df <- function(row_results, row_label) {
  do.call(rbind, lapply(names(row_results), function(col) {
    x <- row_results[[col]]
    f <- frisch_cols[[col]]
    data.frame(
      row       = row_label,
      col       = col,
      frisch_HR = if (length(f) >= 1 && !is.na(f[1])) f[1] else NA_real_,
      frisch_LR = if (length(f) >= 2 && !is.na(f[2])) f[2] else NA_real_,
      mean      = if (!is.null(x$mean)) x$mean else NA_real_,
      p5        = if (!is.null(x$p5))  x$p5  else NA_real_,
      p95       = if (!is.null(x$p95)) x$p95 else NA_real_,
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
# write.csv(results_raw, "table6_results_raw.csv", row.names = FALSE)

#==============================================================================#
# 4. Format cell values ----
#==============================================================================#

# Row 1 (hedonic): mean is positive, p5 < p95 as expected
fmt_cell_hedonic <- function(x) {
  if (is.na(x$mean)) return(c("", ""))
  c(glue("{x$mean}\\%"), glue("[{x$p5}\\%,{x$p95}\\%]"))
}

# Rows 2-3 (disutility): values are negative before abs(); after abs(), 
# original p95 becomes the lower bound and p5 becomes the upper bound
fmt_cell_disutility <- function(x) {
  if (is.na(x$mean)) return(c("", ""))
  c(glue("{abs(x$mean)}\\%"), glue("[{abs(x$p95)}\\%,{abs(x$p5)}\\%]"))
}

# Frisch sub-header lines for columns 2-5
fmt_frisch <- function(f) {
  if (any(is.na(f))) return(c("", ""))
  c(glue("$\\varepsilon_H = {f[1]}$"), glue("$\\varepsilon_L = {f[2]}$"))
}

cell <- function(lst, fmt_fn, line) sapply(lst, function(x) fmt_fn(x)[line])

frisch_line1 <- paste(c("", "", cell(frisch_cols[2:5], fmt_frisch, 1), ""), collapse = " & ")
frisch_line2 <- paste(c("", "", cell(frisch_cols[2:5], fmt_frisch, 2), ""), collapse = " & ")

r1l1 <- paste(c(cell(row1, fmt_cell_hedonic,    1), ""), collapse = " & ")
r1l2 <- paste(c(cell(row1, fmt_cell_hedonic,    2), ""), collapse = " & ")
r2l1 <- paste(c(cell(row2, fmt_cell_disutility, 1), ""), collapse = " & ")
r2l2 <- paste(c(cell(row2, fmt_cell_disutility, 2), ""), collapse = " & ")
r3l1 <- paste(c(cell(row3, fmt_cell_disutility, 1), ""), collapse = " & ")
r3l2 <- paste(c(cell(row3, fmt_cell_disutility, 2), ""), collapse = " & ")

#==============================================================================#
# 4. Write LaTeX table ----
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
& & & {frisch_line1} \\\\
& & & {frisch_line2} \\\\
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
\\label{{tab:sensitivity}}
\\end{{table}}
\\end{{landscape}}
')

cat(latex_table)
# writeLines(latex_table, "table6_sensitivity.tex")