# Overview

This folder contains the code used to estimate and project **high-risk
(agriculture) employment shares**.

In the revised version of the paper, **high-risk workers are defined as
agriculture only** (previously agriculture + manufacturing +
construction & mining).

# Files

## 01\_empshares\_reg\_predict.do

Main estimation and prediction script.

-   Loads IPUMS ADM1 employment shares dataset merged with income and
    climate covariates  
-   Defines the high-risk share:
    -   `ind_highrisk_share = industry_share10` (agriculture only)  
-   Restricts sample to last census year per ADM1 (≤ 2010)  
-   Estimates regression models relating employment shares to:
    -   log income  
    -   long-run temperature (polynomial terms)  
-   Stores estimation results as `.ster` files  
-   Builds prediction grids by manually constructing the prediction
    equation  
    (ensures evaluation on a synthetic grid, not the estimation sample)

**Outputs:** - `output/employment_shares/ster/`  
- `output/employment_shares/yhat_values/`

## 02\_empshares\_reg\_table\_E1.do *(Appendix)*

Produces Table E.1.

-   Reloads and cleans the dataset (self-contained)  
-   Re-defines the high-risk share (agriculture only)  
-   Estimates six specifications:
    -   1.  no FE  
    -   1.  year FE  
    -   1.  continent FE  
    -   1.  continent + year FE  
    -   1.  country FE  
    -   1.  country + year FE (1980–2010 panel)  
-   Writes a formatted LaTeX table

**Output:** -
`output/employment_shares/tables/table_E1_highrisk_newrisk.tex`

## 03\_empshare\_reg\_figure\_E1.R *(Appendix)*

Produces Figure E.1.

-   Fully self-contained (does not rely on `.ster` or prediction
    grids)  
-   Reloads and cleans the raw dataset  
-   Re-estimates all specifications in R  
-   Computes predicted values for each specification  
-   Compares predictions (spec (2) to (6)) relative to the baseline
    specification (1)

**Figure logic:** - Sample: last census year per ADM1  
- x-axis: baseline predictions  
- y-axis: alternative specifications (2) to (6) - 45-degree line
highlights deviations

**Output:** - `output/employment_shares/figures/fig_E1_replication.pdf`

## 04\_empshares\_pred\_figure5ab.R

Produces Figure 5, Panels A and B.

-   Reconstructs the estimation sample from raw data  
-   Loads prediction grids from `01_empshares_reg_predict.do`  
-   Plots:
    -   Panel A: employment share vs log income  
    -   Panel B: employment share vs temperature

Each panel combines: - raw data scatter  
- fitted prediction curve  
- confidence interval  
- histogram of the x-variable

**Output:** - `output/employment_shares/figures/figure5_panelA.pdf`  
- `output/employment_shares/figures/figure5_panelB.pdf`

## 05\_empshares\_map\_figure5.R

Produces Figure 5, Panels C and D.

-   Loads extracted projection outputs  
-   Filters to years 2020 and 2099 only
-   Joins data to the world shapefile  
-   Produces maps of high-risk employment share in 2020 and 2099 at IR
    level

Employment shares are based on Monte Carlo projection runs under
RCP8.5–SSP3-high, using climate-model-weighted averages.

**Output:** -
`output/employment_shares/maps/figure5c_map_ir_2020.{pdf,png}` -
`output/employment_shares/maps/figure5d_map_ir_2099.{pdf,png}`

## 01bis\_empshares\_diagnostics.do *(Optional)*

Diagnostic script

-   Loads `.ster` models from `01`  
-   Computes fitted values and residuals  
-   Produces:
    -   residual distributions  
    -   predicted vs actual plots  
    -   response curves by tercile

**Output:** - `output/employment_shares/diagnostics/`

# Notes

-   **Figure 5 contains the main results**  
-   **Table E.1 and Figure E.1 are robustness checks in Appendix E**
