import xarray as xr 

dt = xr.open_dataset("/mnt/CIL_labor/6_ce/global_consuption_all_ssps_pc_ext.nc4")

df = dt.to_dataframe().reset_index()

df = df.loc[df.ssp == "SSP3"]

df.to_csv('/home/nsharma/repos/labor-code-release-2020/output/damage_function_no_cons/unmodified_betas/global_consumption_new.csv')
