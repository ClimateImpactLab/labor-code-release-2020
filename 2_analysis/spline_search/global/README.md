# Global Spline Search

This folder contains the global restricted cubic spline knot search.

On the RCC, shared inputs and outputs are stored under
`/project/cil/battuta_shares/gcp/estimation/labor/code_release_int_data`.

## Context

This code is based on the dataset-building logic in
`1_assemble_dataset/time_use/merge/master.do` and the old knot-search logic in
`1_assemble_dataset/time_use/merge/master_knots.do`.

In the main regression datasets, the temperature spline variables come from the
climate aggregation code: temperature powers and the selected restricted cubic
spline terms are computed at the pixel level before aggregation to the admin unit level.

For the knot search, we need to try many candidate knot triples. Re-running the
full pixel-level climate aggregation for every candidate would be too expensive,
so this code starts from the already aggregated admin-level temperature
polynomials (`tmax_p1`-`tmax_p3`). For each candidate knot triple, it constructs
the corresponding spline terms from those polynomial variables, runs the main
regression, and ranks the candidates by within R2.

The best-performing knot triple from this search is 27-28-41 based on R2. 
This is the knot triple used for the pixel-level spline terms in the main regression dataset.

## Knot Candidates

The search tests 320 possible knot triples listed in `within_R2_original.csv`.
This list comes from the grid built in `master_knots.do`, using low, middle,
and high knot values over the temperature range.

The old `master_knots.do` also included 16 hand-picked triples. Those are not used here.

## Files

### `01_build_global_base.do`

Builds the base dataset used by the knot search. It starts from
`temp/all_time_use_pop_merged_reweighted_clustered_holidays_dropped.dta`, the last
intermediate dataset before the final regression dataset construction merges in
the spline terms from the climate aggregation. The script then adds the variables
needed to run the search regressions.

The output is saved as
`regression_ready_data/global_base_polys_tmax_nochn_no_ll_0_MASTER.dta`. The
region knot-search code also uses this file, so this step should be run before
either the global or region knot search.

### `02_run_global_knots_candidate.do`

Runs the regression for one candidate 3-knot specification. The script reads one
row from the candidate-knot CSV in the shared battuta data folder, builds the
corresponding spline terms from the temperature powers, merges those terms to the
survey rows, and runs the main high-risk/low-risk regression.

This file is meant to be called by `slurm/run_global_knots.sbatch`. The Slurm
array splits the search into separate jobs: one array task runs one knot
triple, so the 320 candidate knot triples can run in parallel. In practice each
regression takes about 2 hours. Each task writes one `full_run_row*.csv` file
with the within R2 and saves the Stata estimates for that knot triple. These
files are written under `spline_search/global/`.

### `03_merge_global_knots_outputs.R`

Combines the row-level CSV outputs from the knot-search jobs. It stacks the
results, keeps one row per knot triple, ranks the candidates by within R2, and
writes `global_knots_r2_comparison.csv` under
`spline_search/global/comparison/`.

### `slurm/run_global_knots.sbatch`

Slurm wrapper for `02_run_global_knots_candidate.do`. The array index is passed to
Stata as the knot-grid row number.
