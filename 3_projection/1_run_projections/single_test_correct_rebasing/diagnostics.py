# diagnose if james' rebasing correction matches our 
# manual rebasing

import xarray as xr 
import pandas as pd 

james =  "/shares/gcp/outputs/labor/impacts-woodwork/uninteracted_splines_27_37_39_by_risk_empshare_noFE_YearlyAverageDay_correct_rebasing/rcp85/CCSM4/high/SSP3/"
ours =  "/shares/gcp/outputs/labor/impacts-woodwork/projection_combined_uninteracted_splines_by_risk_empshare_noFE_YearlyAverageDay/rcp85/CCSM4/high/SSP3/"

dt_j = xr.open_dataset(james + "/uninteracted_main_model.nc4").to_dataframe().reset_index()
dt_o = xr.open_dataset(ours + "/combined_uninteracted_spline_empshare_noFE.nc4").to_dataframe().reset_index()


