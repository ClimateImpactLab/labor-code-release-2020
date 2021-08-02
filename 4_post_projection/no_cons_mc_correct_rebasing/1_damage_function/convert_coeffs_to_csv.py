# import relevant packages
import xarray as xr 
import pandas as pd 


# convert the CE coefficients dataframe to same format as labour
df = pd.read_csv("/mnt/CIL_labor/6_ce/LABOR_betas_no_intercept.csv")
df['cons'] = 0

df = df.rename(columns={'anomaly' : 'beta1', 'np.power(anomaly, 2)' : 'beta2'})

for col in ['cons', 'beta1', 'beta2']:
    df[col] = df[col]/10**12

df = df[['year', 'cons', 'beta1', 'beta2']]

df.to_csv('/home/nsharma/repos/labor-code-release-2020/output/damage_function_no_cons/nocons_ce_df_coeffs_SSP3.csv')


# convert global consumption values to csv for SSP3
dt = xr.open_dataset("/mnt/CIL_labor/6_ce/adding_up_constant_model_collapsed_global_consumption.nc4")

df = dt.to_dataframe().reset_index()

# df = df.loc[df.ssp == "SSP3"]

df.to_csv('/home/nsharma/repos/labor-code-release-2020/output/damage_function_no_cons/global_consumption_all_SSPs.csv')
