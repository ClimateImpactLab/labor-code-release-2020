# diagnose if james' rebasing correction matches our 
# manual rebasing

import xarray as xr 
import pandas as pd 

james =  "/shares/gcp/outputs/labor/impacts-woodwork/uninteracted_splines_27_37_39_by_risk_empshare_noFE_YearlyAverageDay_correct_rebasing/rcp85/CCSM4/high/SSP3/"
ours =  "/shares/gcp/outputs/labor/impacts-woodwork/test_rcc_copy1/uninteracted_splines_27_37_39_by_risk_empshare_noFE_YearlyAverageDay/rcp85/CCSM4/high/SSP3"
ours_new = "/shares/gcp/outputs/labor/impacts-woodwork/uninteracted_splines_27_37_39_by_risk_empshare_noFE_YearlyAverageDay_wrong_rebasing/rcp85/CCSM4/high/SSP3"
dt_j = xr.open_dataset(james + "/uninteracted_main_model.nc4").to_dataframe().reset_index()
dt_o = xr.open_dataset(ours + "/uninteracted_main_model.nc4").to_dataframe().reset_index()
dt_o_new = xr.open_dataset(ours_new + "/uninteracted_main_model.nc4").to_dataframe().reset_index()

dt_j = dt_j[dt_j.orderofoperations == "rebased"]
dt_o = dt_o[dt_o.orderofoperations == "rebased"]
dt_o_new = dt_o_new[dt_o_new.orderofoperations == "rebased"]

dt_j.rebased.describe()
dt_o.rebased_new.describe()
dt_o_new.rebased