# Region Spline Search

This folder contains the region-level restricted cubic spline knot search for
EuropeUS, LatinAmerica, and SouthAsia.

On the RCC, shared inputs and outputs are stored under
`/project/cil/battuta_shares/gcp/estimation/labor/code_release_int_data`.
Region knot-search files are under `spline_search/region/`.

## Context

The region search uses the base dataset built by
`../global/01_build_global_base.do`. That file starts from
`temp/all_time_use_pop_merged_reweighted_clustered_holidays_dropped.dta`, the
last intermediate dataset before the final regression dataset construction merges
in the spline terms from the climate aggregation. It then adds the variables
needed to run the knot-search regressions.

This matters because the spline terms in the main regression dataset are not
built inside Stata. They come from the climate aggregation code, where the chosen
restricted cubic spline terms are computed at the pixel level before aggregation
to the admin unit level.

For the knot search, we need to try many possible knot triples. Re-running the
pixel-level climate aggregation for every candidate would be too expensive, so
this code starts from the admin-level temperature powers already built from the
climate data. For each candidate knot triple, it builds the spline terms from
those powers, runs the region regression, and ranks the candidates by within R2.

The selected region knots are used later when building the final regional
regression datasets.

## Region Support and Knot Candidates

The first step measures the temperature range covered by each region. The second
step uses that range to keep only knot triples that make sense for the data in
that region.

The region candidate lists are not the same size for every region. Wider or more
varied temperature ranges allow more candidate triples; narrower ranges allow
fewer. The current candidate counts are:

- EuropeUS: 120
- LatinAmerica: 60
- SouthAsia: 72

SouthAsia has an extra high-knot check because India has a hot upper tail.

## Running the Search

The Slurm scripts in `slurm/` call `03_run_region_knots_candidate.do`. Each Slurm
wrapper sets the region name and, where needed, splits the candidate list into
small chunks. The Stata script runs the regression for each knot triple in that
chunk and writes one small CSV row with the within R2.

The row-level CSVs are written to
`spline_search/region/r2_output/sidecars/`. The merge script combines those rows
and writes one ranked CSV per region under
`spline_search/region/r2_output/combined/`.

SouthAsia also writes a second set of sidecars using `adj_sample_wgt`. This is a
check against the main `risk_adj_sample_wgt` version.

## Files

### `01_temperature_support_region.do`

Computes the temperature support for each region from the global base dataset.
The output is written under `spline_search/region/temp_support/` and is used by
the next script to decide which knot triples are allowed for each region.

### `02_filter_knots_by_support_region.do`

Builds the region candidate lists. It starts from each region's temperature
support, creates possible low/middle/high knot values, drops triples outside the
observed temperature range, and keeps the list to a manageable size.

The outputs are written under `spline_search/region/knots_filter/`.

### `03_run_region_knots_candidate.do`

Runs the knot-search regressions for one region and one Slurm chunk. For each
candidate triple in that chunk, it builds the spline terms, merges them back to
the person-level rows, rebuilds the regression weights, runs the region
regression, and writes one row with the within R2.

This file is meant to be called by the Slurm scripts in `slurm/`.

### `04_merge_region_knots_outputs.R`

Combines the row-level sidecar CSVs, keeps one row per knot triple, ranks the
candidate triples by within R2, and writes one result file per region.

### `slurm/run_*_region_knots.sbatch`

Slurm wrappers for the three region searches. The EuropeUS search currently runs
as one task. LatinAmerica and SouthAsia are split into chunks so the candidates
can run in parallel.
