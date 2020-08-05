# Code to generate historical weather data for labor

## Dependencies?

 - the `climate_data_aggregation` repository. Clone it from [here](https://bitbucket.org/ClimateImpactLab/climate_data_aggregation/src/master/) first and switch to the branch `rcspline-labor`. Read the documentation that is in there.
 - specifically : 
 	- `climate_data_aggregation/gis/intersect_zonalstats_par.py`
 	- `climate_data_aggregation/aggregation/merge_transform_average.py`


## Directories? 

 - codes : `gcp-labor/1_preparation/weather` in `master` branch. I.e this repository.
 - shapefiles and pixel weights : `/shares/gcp/estimation/labor/spatial_data`
 - configuration files, raw and final data : `/shares/gcp/estimation/labor/climate_data`

## How to use ?

You either want to get new pixel-weights files or aggregate data using existing weights file.

If you want new weights : 

1. update `gis_config_lines` with new shapefiles info.
2. run `write_configs.py` to update the configuration files. 
3. run `do_weights()` in `generate_data.R`.
4. check your weights files at the directory given above.

If you want to aggregate data using existing weights : 

1. update `aggregation_confing_lines.csv` and `parameters_transforms_collapse_daily.csv` or `parameters_transforms_collapse_yearly.csv` depending on what you want. 
2. run `write_configs.py`.
3. run `do_aggregate()` in `generate_data.R`.
4. run `reshape_combine_data.R` to reshape, combine, and rename the variables of the raw data files produced in 3.
