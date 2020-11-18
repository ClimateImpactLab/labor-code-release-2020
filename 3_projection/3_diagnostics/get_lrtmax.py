
import pandas as pd
import xarray as xr

df = xr.open_dataset("/mnt/sacagawea_shares/gcp/outputs/temps/rcp85/CCSM4/climtas.nc4").to_dataframe().reset_index()

print("CCSM4 Max climate in 2099 is ", df.loc[(df.year == 2099) & (df.covars == 'climtas')]['averaged'].max())
print("CCSM4 Min climate in 2099 is ", df.loc[(df.year == 2099) & (df.covars == 'climtas')]['averaged'].min())

df = xr.open_dataset("/mnt/sacagawea_shares/gcp/outputs/temps/rcp85/surrogate_GFDL-CM3_99/climtas.nc4").to_dataframe().reset_index()

print("surrogate_GFDL-CM3_99 Max climate in 2099 is ", df.loc[(df.year == 2099) & (df.covars == 'climtas')]['averaged'].max())
print("surrogate_GFDL-CM3_99 Min climate in 2099 is ", df.loc[(df.year == 2099) & (df.covars == 'climtas')]['averaged'].min())


df = pd.read_csv("/shares/gcp/outputs/labor/impacts-woodwork/test_rcc_copy/" +
	"uninteracted_splines_27_37_39_by_risk_empshare_noFE_YearlyAverageDay/rcp85/CCSM4/high/SSP3/" +
	"test_rcc_main_model_single_config-allcalcs-uninteracted_main_model.csv",
	skiprows=26, usecols=['region', 'year', 'climtas', 'loggdppc'])

print("Max loggdppc in 2099 is ", df.loc[(df.year == 2099)]['loggdppc'].max())
print("Min loggdppc in 2099 is ", df.loc[(df.year == 2099)]['loggdppc'].min())

