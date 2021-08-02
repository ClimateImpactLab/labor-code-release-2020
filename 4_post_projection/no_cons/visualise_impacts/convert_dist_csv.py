import xarray as xr 
import pandas as pd 

dt = xr.open_dataset("/mnt/CIL_labor/6_ce/scc_distribution_with_uncertainty/labor_statisticaluncertainty_scc_allpricescenarios_v1.nc")

df = dt.to_dataframe().reset_index()

df = df.loc[(df.discrate == 0.02)]

# df = df.rename(columns={'__xarray_dataarray_variable__' : 'scc'})

df.to_csv('/mnt/CIL_labor/6_ce/scc_distribution_with_uncertainty/statisticaluncertainty.csv')
