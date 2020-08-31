#!/bin/bash

# need to extract
# impacts for low and high workers at 2099, and overall impact
# share of high risk workers at 2020 and 2099
# time series of overall impact (full adapt and no adapt)

cd "/home/liruixue/repos/impact-calculations"
conda activate risingverse
./aggregate.sh ../labor-code-release-2020/3_projection/1_run_projections/aggregation_gdp.yml

./aggregate.sh ../labor-code-release-2020/3_projection/1_run_projections/aggregation_gdp.yml

cd "/home/liruixue/repos/prospectus-tools/gcp/extract"
basename=combined_uninteracted_spline_empshare_noFE
python -i quantiles.py /home/liruixue/repos/labor-code-release-2020/3_projection/2_extract_projection_outputs/extraction_configs/median_mean_hi_unrebased.yml --suffix=_combined_impact ${basename} -${basename}-histclim


python -i quantiles.py /home/liruixue/repos/labor-code-release-2020/3_projection/2_extract_projection_outputs/extraction_configs/median_mean_hi_unrebased.yml --suffix=_test_aggregated ${basename}-pop-aggregated -${basename}-histclim-pop-aggregated