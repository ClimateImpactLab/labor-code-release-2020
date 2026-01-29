"""
This script takes the IR-aggregated GMFD v1.0 weather data from 
1950 to 2010 and calculates the day-of-year average for each region
across the years.

Current verrsion:
 - Daily maximum temperature
 - Tmax spline transformation (3knot spline with knots at 27, 28, 41)

Script mostly exists for documentation purposes. Must be run on hpc with lots of
memory allocated.
"""

import xarray as xr
import pandas as pd
import numpy as np

# Load the dataset and define output
zarr_path = "/project/cil/battuta_shares/gcp/estimation/labor/code_release_int_data/climate/final_27_28_41/IMPACT_REGIONS/new_20260127/global/daily/GMFD_IMPACT_REGIONS_tmax_splines_daily_global.zarr"
output_path = "/project/cil/gcp/climate/_spatial_data/impactregions/weather_data/csv_daily/GMDF_tmax_temp_and_spline_27_28_41_avg_year.csv"

# Aggregate data across years for each day/month/hierid
ds = xr.open_zarr(zarr_path)

print(f"===== aggregating =====\n")
ds_agg = ds.mean(dim='year')
df_agg = ds_agg.to_dataframe().reset_index()

df_agg = df_agg.rename(columns={
    'tmax_rcspline_3kn_27_28_41_term0': 'temp',
    'tmax_rcspline_3kn_27_28_41_term1': 'temp_s'
})

# Save to CSV
print(f"Aggregation complete. Saving to \n{output_path}")
df_agg.to_csv(output_path, index=False)
print("===== saved =====")
