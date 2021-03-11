import xarray as xr 
import pandas as pd 

dt = xr.open_dataset("/mnt/CIL_labor/6_ce/risk_constant_all_ssp_betas.nc4")
df = dt.to_dataframe().loc['constant', 'SSP3', :].reset_index()
df = df.rename(columns={'beta_1' : 'beta1', 'beta_2' : 'beta2'})

for col in ['cons', 'beta1', 'beta2']:
    df[col] = df[col]/10**12
 
# df['cons'] = df['cons']/1000000000000
# df['beta1'] = df['beta1']/1000000000000
# df['beta2'] = df['beta2']/1000000000000

df.to_csv('/home/nsharma/repos/labor-code-release-2020/output/ce/ce_df_coeffs_SSP3.csv')

