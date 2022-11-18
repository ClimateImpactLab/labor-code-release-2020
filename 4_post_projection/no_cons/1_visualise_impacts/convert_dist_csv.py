import xarray as xr 
import pandas as pd 

# FULL UNCERTAINTY
dt = xr.open_dataset("/mnt/CIL_labor/6_ce/scc_distribution_with_uncertainty/labor_fulluncertainty_scc_filtered_allpricescenarios_v1.nc")

df = dt.to_dataframe().reset_index()

full_sum = df.groupby(["discrate", "rcp"])["scc"].mean().reset_index().rename(columns = {"scc" : "mean_scc"})
full_sum.to_csv("/home/nsharma/repos/labor-code-release-2020/output/figures/scc_distribution_plots/full_uncertainty_mean_scc.csv", index=False)

df = df.loc[(df.discrate == 0.02)]
df.to_csv('/mnt/CIL_labor/6_ce/scc_distribution_with_uncertainty/fulluncertainty.csv')


# CLIMATE UNCERTAINTY
dt = xr.open_dataset("/mnt/CIL_labor/6_ce/scc_distribution_with_uncertainty/labor_climateuncertainty_scc_filtered_allpricescenarios_v1.nc")

df = dt.to_dataframe().reset_index()

df = df.loc[(df.discrate == 0.02)]

df.to_csv('/mnt/CIL_labor/6_ce/scc_distribution_with_uncertainty/climateuncertainty.csv')


# STATISTICAL UNCERTAINTY
dt = xr.open_dataset("/mnt/CIL_labor/6_ce/scc_distribution_with_uncertainty/labor_statisticaluncertainty_scc_allpricescenarios_v1.nc")

df = dt.to_dataframe().reset_index()

df = df.loc[(df.discrate == 0.02)]

df.to_csv('/mnt/CIL_labor/6_ce/scc_distribution_with_uncertainty/statisticaluncertainty.csv')

