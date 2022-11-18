import xarray as xr 
import pandas as pd 

dt = xr.open_dataset("/mnt/CIL_labor/6_ce/risk_aversion_constant_model_collapsed_uncollapsed_sccs.nc4")

df = dt.to_dataframe().reset_index()

df = df.rename(columns={'__xarray_dataarray_variable__' : 'scc'})

df.to_csv('/mnt/CIL_labor/6_ce/risk_aversion_constant_model_collapsed_uncollapsed_sccs.csv')
