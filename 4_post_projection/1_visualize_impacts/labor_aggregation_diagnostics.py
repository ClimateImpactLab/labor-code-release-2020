# labor aggregation diagnostics
import xarray as xr
root = "/shares/gcp/outputs/labor/impacts-woodwork/combined_uninteracted_splines_27_37_39_by_risk_empshare_noFE_YearlyAverageDay"

folder = "/median/rcp85/surrogate_GFDL-ESM2G_01/low/SSP4/"

dt = xr.open_dataset("combined_uninteracted_spline_empshare_noFE.nc4")
df = dt.to_dataframe()