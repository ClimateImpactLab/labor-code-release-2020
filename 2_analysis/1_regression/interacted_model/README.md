# Interacted Models

These scripts produce the interacted-model results for Appendix G.

The main labor regressions allow temperature effects to differ between low-risk
and high-risk workers. High-risk workers are in agriculture, forestry, and
fishing. Low-risk workers are all other workers.

The interacted models test whether these temperature responses also vary within
each risk group with:

- local income, measured by log GDP per capita
- local climate, measured by long-run average daily maximum temperature (`TMEAN`
  in the paper)

Earlier versions used income in the 1-factor model. The current 1-factor model
uses climate only. With the agriculture dummy, climate is the interaction that
matters most.

The 2-factor model includes income and climate in the same regression.

## Files

- Regression scripts: `2_analysis/1_regression/interacted_model/`
- Response scripts: `2_analysis/2_response_functions/interacted_model/`
- Marginal effects table scripts: `2_analysis/3_plotting/tables/interacted_model/`
- Figure scripts: `2_analysis/3_plotting/figures/interacted_model/`
- Archived scripts: `2_analysis/z_old/interacted_model_legacy/`

## Model Choices

- Dataset:
  `${ROOT_INT_DATA}/regression_ready_data/labor_dataset_splines_nochn_tmax_chn_prev_week_no_ll_0_agnonag_272841_0814.dta`
- Knots: `27 28 41`
- Reference temperature: `27`
- Fixed effects: `${fe_adm0_wk}` by risk group
- Weight: `rep_unit_year_sample_wgt`
- Cluster: `cluster_adm1yymm`

The 1-factor climate model uses `risk_adj_sample_wgt` for low-risk workers and
`rep_unit_year_sample_wgt` for high-risk workers.

## Run Order

### 1-factor climate

1. `2_analysis/1_regression/interacted_model/run_1factor_climate.do`
2. `2_analysis/2_response_functions/interacted_model/rf_1factor_climate.do`
3. `2_analysis/3_plotting/tables/interacted_model/table_1factor_climate.do`
4. `2_analysis/3_plotting/figures/interacted_model/plot_1factor_climate.do`

The table script makes the marginal effects table for the high-risk long-run
temperature term. The figure shows the high-risk temperature response at the
three climate terciles.

### 2-factor

1. `2_analysis/1_regression/interacted_model/run_2factor.do`
2. `2_analysis/2_response_functions/interacted_model/rf_2factor.do`
3. `2_analysis/3_plotting/tables/interacted_model/table_2factor.do`

The table script makes the marginal effects table and reports F-tests for the
GDP and long-run temperature terms.

## Output Folders

- Estimates: `${DIR_STER}/interacted_model`
- Response CSVs: `${DIR_RF}/interacted_model`
- Plot data: `${DIR_FIG}/interacted_appendix_g_2026/data`
- Tables: `${DIR_TABLE}/interacted_model`
- Figures: `${DIR_FIG}/interacted_appendix_g_2026`
