# Pipeline for Running Bin Regressions

## 1. Constructing 3°C Temperature Bins

### Raw Data

The starting point is the 1°C temperature-bin dataset:

`labor_dataset_bins_tmax_chn_prev_week_no_ll_0.dta`

Location:

`/project/cil/battuta_shares/gcp/estimation/labor/code_release_int_data/regression_ready_data`

This file is approximately **23GB** and contains exposure counts in 1°C bins.

### Baseline 3°C Binning

For the functional-form comparison, we convert the raw 1°C bins into 3°C bins with collapsed tails:

- **Cold tail:** all temperatures below 0°C → `below0`
- **Interior bins:** 0–3, 3–6, …, 39–42
- **Hot tail:** all temperatures ≥ 42°C → `above42`

This transformation is implemented in:

`labor-code-release-2020/1_assemble_dataset/time_use/merge/transform_bins.do`

Output dataset:

`.../regression_ready_data/labor_dataset_bins_nochn_tmax_chn_prev_week_no_ll_0_0Cto42C_3Cbins_ag.dta`

This baseline dataset uses **index-based bin naming** (e.g., `b3C_14`, `b3C_22`, etc.), inherited from the original pipeline.

## 2. Change in High-Risk Definition

Following referee revisions, the definition of `high_risk` was modified.

**Old definition (`high_risk_old`):** - Agriculture  
- Construction & mining  
- Manufacturing

**New definition (`high_risk`):** - Agriculture only

Switching to the agriculture-only definition substantially altered the temperature exposure distribution for high-risk workers, particularly in the coldest bins.

Agricultural workers exhibit little to no exposure below ~9°C, unlike the broader previous high-risk group.

## 3. Temperature Support

To document how temperature exposure differs across risk definitions and bin structures, we compute weighted temperature-support distributions using:

`labor-code-release-2020/1_assemble_dataset/time_use/merge/temp_support_bins.do`

This script computes:

- Baseline 3°C support (old vs new high-risk)
- Alternative cold-tail bin structures

Outputs are saved in:

`labor-code-release-2020/output/temp_dist/temp_support_bins/`

## 4. Cold-Tail Bin Merging

Because the new agriculture-only high-risk group has minimal support in very cold bins, we merge the cold tail into a single bin.

Two alternative cutoffs were evaluated:

- Cold tail ≤ 9°C
- Cold tail ≤ 12°C

We ultimately adopt:

> **Cold tail ≤ 9°C**

The 12°C cutoff collapses too much variation and removes informative structure in the lower temperature range.

The cold-tail transformation is implemented in:

`labor-code-release-2020/1_assemble_dataset/time_use/merge/transform_bins_ag_coldtail.do`

This produces temperature-based bin variables:

- `below9`
- `b3C_9`, `b3C_12`, …, `b3C_39`
- `above42`

Output dataset saved in regression_ready_data/

`labor_dataset_bins_nochn_tmax_chn_prev_week_no_ll_0_coldle9_3Cbins_9to42_plusTails.dta`

## 5. Bin Regression Specifications

### Chosen Specification

The only regression specification retained is:

- High-risk definition: Agriculture only (`high_risk`)
- Cold tail: ≤ 9°C (`below9`)
- Interior bins: 9–12, 12–15, …, 39–42
- Upper tail: ≥ 42°C (`above42`)
- Reference bin: 27–30°C (also including option for previous reference bin: 24-27°C)

Implemented in: `labor-code-release-2020/2_analysis/1_regresssion/uninteracted_bins_coldtail_reg.do`

This specification is used Appendix D (Robustness to Alternative Functional Forms)

### Other Specifications

The repository also contains earlier specifications that are not used in the final paper but are kept for documentation:

1.  **Baseline 3°C bins with below0 cold tail**
    - Cold tail: \< 0°C
    - High-risk definition:
      - Old (`high_risk_old`)
      - New (`high_risk`)

Implemented in:

`uninteracted_bins.do`

These archived specifications document the evolution of the bin structure after redefining the high-risk group from (Agriculture + Construction + Manufacturing) to Agriculture only.

## 6. Extracting Bin Coefficients

Extraction scripts:

- `labor-code-release-2020/2_analysis/2_response_functions/bins/extract_bin_coef.do` (baseline 3°C bins: new & old risk)
- `labor-code-release-2020/2_analysis/2_response_functions/bins/extract_global_bin_coefs_merged.do` (cold-tail merged bins with alternative reference bins)

These scripts:

- Load regression `.ster` files
- Extract bin coefficients and standard errors
- Construct 95% confidence intervals
- Output plotting-ready `.csv` files

Outputs are saved to:

- `${DIR_RF}/uninteracted_bins/`

## 7. Plotting

Global bin figures are generated via a unified R script:

- `uninteracted_bins_figures.R`

Each figure includes:

- Top panel: bin coefficients (points + line + 95% CI)
- Bottom panel: weighted temperature distribution (histogram)
- Two columns: Low-risk \| High-risk

Main specification:

- Cold tail ≤ 9°C
- Reference bin: 27–30°C

Optional specifications: - Baseline 3°C bins (new risk) - Baseline 3°C bins (old risk) - Cold tail ≤ 9°C, reference 24–27°C

All plots are saved to:

- `${DIR_FIG}/uninteracted_bins_plot/`

# Pipeline Functional Forms Comparison (Appendix D)

Appendix D evaluates robustness of the labor supply–temperature response to alternative functional forms. It produces:

- **Figure D1**: Parametric response functions (poly2, poly3, poly4, RCS) overlaid on the binned benchmark, separately for low- and high-risk workers.
- **Table D1**: RMSE of each parametric specification relative to the binned benchmark, weighted by 2010 and 2090 temperature distributions.

## 1. Figure D1 (R)

**Script:** `labor-code-release-2020/2_analysis/3_plotting/figures/figure_D1_functional_form_comparison.R`

- Reads consolidated functional-form RF CSV.
- Reads bin-coefficient extract for overlay.
- Plots 2×4 panel figure:
  - Columns: 2nd poly \| 3rd poly \| 4th poly \| RCS  
  - Rows: Low-risk \| High-risk
- Optionally includes confidence intervals.

**Output:** `${DIR_FIG}/functional_form_comparison/figure_D1_functional_form.pdf`

## 2. Build functional-form comparison CSV (Stata)

**Script:** `labor-code-release-2020/2_analysis/2_response_functions/rf_functional_form_comparison.do`

- Evaluates all functional forms on a common temperature grid.

**Output**  
`${DIR_RF}/functional_form_comparison_2026.csv`

### 3. RMSE computation and Table D1 (Stata)

**Script:** `labor-code-release-2020/2_analysis/3_plotting/tables/rmse_functional_forms_tableD1.do`

- Uses consolidated RF CSV.
- Computes RMSE of each parametric RF relative to bins.
- Weights errors by:
  - 2010 population-temperature distribution  
  - 2090 population-temperature distribution  
- Exports LaTeX table.

**Output:**  
`${DIR_TABLE}/tableD1_rmse_functional_forms.tex`

## Execution order

1.  Run `rf_functional_form_comparison_ag_master.do`
2.  Run `figure_D1_functional_form_comparison.R`
3.  Run `rmse_functional_forms_tableD1.do`
