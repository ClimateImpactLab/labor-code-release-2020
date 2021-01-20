import xarray as xr
import numpy as np

test = "/shares/gcp/outputs/labor/impacts-woodwork/labor_mc_re-rebased/batch4/rcp45/ACCESS1-0/high/SSP1/uninteracted_main_model-incadapt-wage-aggregated.nc4"

d = xr.open_dataset(test).to_dataframe().reset_index()


d[d.rebased_new.isnull()]