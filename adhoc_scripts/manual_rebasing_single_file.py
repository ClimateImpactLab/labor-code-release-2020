
__author__ = 'Kit Schwarz'
__contact__ = 'csschwarz@uchicago.edu'
__version__ = '1.1'

############
# LIBRARIES
############

import xarray as xr
import numpy as np
import pandas as pd
import getpass
import sys
import os
import pathlib
import time
import warnings
warnings.filterwarnings("ignore")

username = getpass.getuser()

############
# PATHWAYS
############
# # 
# proj_root = f'/shares/gcp/outputs/labor/impacts-woodwork/labor_mc_aggregate_copy/labor_mc_aggregate_copy3/{str(sys.argv[1])}'
# output_root = f'/shares/gcp/outputs/labor/impacts-woodwork/labor_mc_aggregate_copy3/{str(sys.argv[1])}'
    
# copy parent folder structure
# for dirpath, dirnames, filenames in os.walk(proj_root):
#     structure = os.path.join(output_root, dirpath[len(proj_root):])
#     if not os.path.isdir(structure):
#         os.mkdir(structure)
#     else:
#         print("Folder exists.")

###############################
# REBASE & COMBINE FUNCTION
###############################

def rebase_combine(file):
    dt = xr.open_dataset(file)
    # select years & columns needed for rebasing
    base = (dt.sel(
            {"year": slice(2001,2010)}
            )
            [['regions','highriskimpacts', 'lowriskimpacts']]
           )
    # subtract off mean of base years -> rebasing!
    mean_base = base.mean(dim="year")
    rebased = dt - mean_base
    # calculate combined, rebased impact
    rebased['rebased_new'] = rebased.highriskimpacts * dt['clip'] + rebased.lowriskimpacts * (1 - dt['clip'])
    # add back onto dataframe
    dt['rebased_new'] = rebased.rebased_new
    # set its attributes
    dt.rebased_new.attrs = { 'long_title' : 'Rebased sum of results weighted on fractions of unity',
                           'units' : 'minutes worked by individual',
                           'source' : 'calculated as rebased_new = minlost_hi_rebased * riskshare_hi + minlost_lo_rebased * (1 - riskshare_hi)'}
    return dt




files = ["/shares/gcp/outputs/labor/impacts-woodwork/labor_mc_aggregate_copy3/batch5/rcp45/CESM1-BGC/high/SSP4/uninteracted_main_model-noadapt.nc4",
	"/shares/gcp/outputs/labor/impacts-woodwork/labor_mc_aggregate_copy3/batch2/rcp85/surrogate_GFDL-ESM2G_06/high/SSP2/uninteracted_main_model-incadapt.nc4",
	"/shares/gcp/outputs/labor/impacts-woodwork/labor_mc_aggregate_copy3/batch4/rcp45/BNU-ESM/high/SSP1/uninteracted_main_model-noadapt.nc4",
	"/shares/gcp/outputs/labor/impacts-woodwork/labor_mc_aggregate_copy3/batch4/rcp45/MIROC-ESM/low/SSP4/uninteracted_main_model-incadapt.nc4"]


for file in files:
	ds = rebase_combine(file)
	output = pathlib.Path(str(file).replace("copy3", "copy4"))
	output.parent.mkdir(parents=True, exist_ok=True)
	ds.to_netcdf(output)
	print(output)



