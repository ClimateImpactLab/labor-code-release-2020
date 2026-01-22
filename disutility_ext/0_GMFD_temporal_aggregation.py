"""
This script takes the temperature realizations from 1950 to 2010 and
calculates the average for every day of the year

Script exists for documentation purposes. Must be run on server with lots of
memory allocated. Takes a super long time to run and requires lots of RAM
"""

import xarray as xr
import pandas as pd
import numpy as np

# Load the dataset and define output
zarr_path = "/project/cil/battuta_shares/gcp/estimation/labor/code_release_int_data/climate/final_27_28_41/IMPACT_REGIONS/global/daily/GMFD_IMPACT_REGIONS_tmax_splines_daily_global.zarr"
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
