#!/bin/bash

# need to extract
# impacts for low and high workers at 2099, and overall impact
# share of high risk workers at 2020 and 2099
# time series of overall impact (full adapt and no adapt)

# cd "/home/liruixue/repos/impact-calculations"
# conda activate risingverse
# ./aggregate.sh ../labor-code-release-2020/3_projection/1_run_projections/aggregation_gdp.yml
# cd "~/repos/impact-calculations"
# conda activate risingverse
# ./aggregate.sh ../labor-code-release-2020/3_projection/1_run_projections/aggregation_gdp.yml

# ./aggregate.sh ../labor-code-release-2020/3_projection/1_run_projections/aggregation_gdp.yml


conda activate risingverse-py27
cd "/home/liruixue/repos/prospectus-tools/gcp/extract"


# extract fulladapt
basename=combined_uninteracted_spline_empshare_noFE

python -u quantiles.py /home/liruixue/repos/labor-code-release-2020/3_projection/2_extract_projection_outputs/extraction_configs/median_mean_hi_unrebased.yml --suffix=_high_fulladapt_map ${basename} -${basename}-histclim
python -u quantiles.py /home/liruixue/repos/labor-code-release-2020/3_projection/2_extract_projection_outputs/extraction_configs/median_mean_hi_unrebased.yml --suffix=_high_fulladapt_timeseries ${basename}-pop-allvars-aggregated -${basename}-histclim-pop-allvars-aggregated

python -u quantiles.py /home/liruixue/repos/labor-code-release-2020/3_projection/2_extract_projection_outputs/extraction_configs/median_mean_lo_unrebased.yml --suffix=_low_fulladapt_map ${basename} -${basename}-histclim
python -u quantiles.py /home/liruixue/repos/labor-code-release-2020/3_projection/2_extract_projection_outputs/extraction_configs/median_mean_lo_unrebased.yml --suffix=_low_fulladapt_timeseries ${basename}-pop-allvars-aggregated -${basename}-histclim-pop-allvars-aggregated

python -u quantiles.py /home/liruixue/repos/labor-code-release-2020/3_projection/2_extract_projection_outputs/extraction_configs/median_mean_hilo_rebased.yml --suffix=_highlow_fulladapt_map ${basename} -${basename}-histclim
python -u quantiles.py /home/liruixue/repos/labor-code-release-2020/3_projection/2_extract_projection_outputs/extraction_configs/median_mean_hilo_rebased.yml --suffix=_highlow_fulladapt_timeseries ${basename}-pop-allvars-aggregated -${basename}-histclim-pop-allvars-aggregated

# extract noadapt
basename=combined_uninteracted_spline_empshare_noFE-noadapt

# python -u quantiles.py /home/liruixue/repos/labor-code-release-2020/3_projection/2_extract_projection_outputs/extraction_configs/median_mean_hi_unrebased.yml --suffix=_high_noadapt_map ${basename} 
# python -u quantiles.py /home/liruixue/repos/labor-code-release-2020/3_projection/2_extract_projection_outputs/extraction_configs/median_mean_hi_unrebased.yml --suffix=_high_noadapt_timeseries ${basename}-pop-allvars-aggregated 

# python -u quantiles.py /home/liruixue/repos/labor-code-release-2020/3_projection/2_extract_projection_outputs/extraction_configs/median_mean_lo_unrebased.yml --suffix=_low_noadapt_map ${basename} 
# python -u quantiles.py /home/liruixue/repos/labor-code-release-2020/3_projection/2_extract_projection_outputs/extraction_configs/median_mean_lo_unrebased.yml --suffix=_low_noadapt_timeseries ${basename}-pop-allvars-aggregated 

# python -u quantiles.py /home/liruixue/repos/labor-code-release-2020/3_projection/2_extract_projection_outputs/extraction_configs/median_mean_hilo_rebased.yml --suffix=_highlow_noadapt_map ${basename} 
python -u quantiles.py /home/liruixue/repos/labor-code-release-2020/3_projection/2_extract_projection_outputs/extraction_configs/median_mean_hilo_rebased.yml --suffix=_highlow_noadapt_timeseries ${basename}-pop-allvars-aggregated 

