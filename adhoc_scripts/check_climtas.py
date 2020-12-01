# compare bartlett vs mean, and 15-yr MA of GDP vs 30-yr MA

import xarray as xr
import pandas as pd

path_bartlett_30_gdp_30 = "/shares/gcp/outputs/labor/impacts-woodwork/uninteracted_splines_27_37_39_by_risk_empshare_noFE_test_bartlett/"
path_mean_30_gdp_30 = "/shares/gcp/outputs/labor/impacts-woodwork/test_rcc_copy/uninteracted_splines_27_37_39_by_risk_empshare_noFE_YearlyAverageDay/"
path_mean_30_gdp_15 = "/shares/gcp/outputs/labor/impacts-woodwork/uninteracted_splines_27_37_39_by_risk_empshare_noFE_test_15yr_income/"

cols = ['region','year','tas','climtas','climtas-poly-2','loggdppc']
d_mean_30_gdp_30 = pd.read_csv(path_mean_30_gdp_30 + "rcp85/CCSM4/high/SSP3/test_rcc_main_model_single_config-allcalcs-uninteracted_main_model.csv", skiprows = 26)[cols]
d_mean_30_gdp_15 = pd.read_csv(path_mean_30_gdp_15 + "rcp85/CCSM4/high/SSP3/uninteracted_main_model_test_15yr_income-allcalcs-uninteracted_main_model_test_15yr_income.csv", skiprows = 26)[cols]
d_bartlett_30_gdp_30 = pd.read_csv(path_bartlett_30_gdp_30 + "rcp85/CCSM4/high/SSP3/uninteracted_main_model_test_bartlett-allcalcs-uninteracted_main_model_test_bartlett.csv", skiprows = 26)[cols]

d_climtas = xr.open_dataset("/shares/gcp/outputs/temps/rcp85/CCSM4/climtas.nc4").to_dataframe().reset_index()