# import relevant packages
import xarray as xr 
import pandas as pd 


# convert the CE coefficients dataframe to same format as labour
df = xr.open_dataset("/mnt/CIL_labor/6_ce/new_mc_nocons/risk_aversion_constant_model_collapsed_eta2_rho0_damage_function_coefficients.nc4").to_dataframe().reset_index()
df['cons'] = 0

df = df.rename(columns={'anomaly' : 'beta1', 'np.power(anomaly, 2)' : 'beta2'})

for col in ['cons', 'beta1', 'beta2']:
    df[col] = df[col]/10**12

df = df[['year', 'cons', 'beta1', 'beta2']].loc[(df['ssp'] == "SSP3")]

df.to_csv('/home/nsharma/repos/labor-code-release-2020/output/damage_function_no_cons_new_mc/SSP3/ce_betas_SSP3.csv')


# convert global consumption values to csv for SSPs 2, 3, 4
dt = xr.open_dataset("/mnt/CIL_labor/6_ce/new_mc_nocons/adding_up_constant_model_collapsed_eta2_rho0_global_consumption.nc4").to_dataframe().reset_index()
dt.to_csv('/home/nsharma/repos/labor-code-release-2020/output/damage_function_no_cons_new_mc/global_consumption_all_SSPs.csv')


# # checking that adding up coeffs from labour and integration match, no need to run again
# dt = pd.read_csv("~/repos/labor-code-release-2020/output/damage_function_no_cons_new_mc/SSP3/nocons_betas_SSP3.csv")
# dt = dt[['year', 'beta1', 'beta2']]
# dt 

# df = xr.open_dataset("/mnt/CIL_labor/6_ce/new_mc_nocons/adding_up_constant_model_collapsed_eta2_rho0_damage_function_coefficients.nc4").to_dataframe().reset_index()
# df = df.rename(columns={'anomaly' : 'beta1', 'np.power(anomaly, 2)' : 'beta2'})

# for col in ['beta1', 'beta2']:
#     df[col] = df[col]/10**12

# df = df[['year', 'beta1', 'beta2']].loc[(df['ssp'] == "SSP3")]
# df