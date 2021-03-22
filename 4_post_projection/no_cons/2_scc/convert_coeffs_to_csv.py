import pandas as pd 

df = pd.read_csv("/mnt/CIL_labor/6_ce/LABOR_betas_no_intercept.csv")
df['cons'] = 0

df = df.rename(columns={'anomaly' : 'beta1', 'np.power(anomaly, 2)' : 'beta2'})

for col in ['cons', 'beta1', 'beta2']:
    df[col] = df[col]/10**12

df = df[['year', 'cons', 'beta1', 'beta2']]

df.to_csv('/home/nsharma/repos/labor-code-release-2020/output/damage_function_no_cons/nocons_ce_df_coeffs_SSP3.csv')

