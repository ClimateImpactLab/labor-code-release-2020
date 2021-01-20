'''
Manual rebasing script for point estimate

Purpose: this script takes unrebased projection output and manually calculates the 'combined, rebased impact'
(correctly!) by enacting this equation:

combined_rebased_impact = minlost_hi_rebased * riskshare_hi + minlost_lo_rebased * (1 - riskshare_hi)

This is done for histclim and fulladapt scenarios. As per usual, the histclim value will then be subtracted
from the fulladapt value and we will get our final result.

Parameters:

@batchno : pass the batch as an argument run from the shell script line, for example:
        
        python parallel_MC_output.py batch7

Outputs: a copy of the original MC folder (and everything inside) with the `rebased_new` column added to every
        single netcdf4.

'''
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
# proj_root = f'/shares/gcp/outputs/labor/impacts-woodwork/labor_mc_aggregate_copy/labor_mc_re-rebased/{str(sys.argv[1])}'
# output_root = f'/shares/gcp/outputs/labor/impacts-woodwork/labor_mc_re-rebased/{str(sys.argv[1])}'
    
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


##############
# IMPLEMENT
##############

# in the ideal world, this will work *not* as a groddy old forloop.
# unfortunately we are pressed for time and this script will (hopefully)
# never be run again... so we are just bearing with it.
# It should take ~1 second per file if run on Bat, or else 2-4 seconds
# per file if run on Sac.



proj_root = '/shares/gcp/outputs/labor/impacts-woodwork/point_estimate_google'
output_root = '/shares/gcp/outputs/labor/impacts-woodwork/point_estimate_google_rebased'

paths = list(pathlib.Path(proj_root).rglob('*.nc4'))

# import pathlib

for file in paths:
    start = time.time()
    ds = rebase_combine(file)
    end = time.time()
    print(end - start)
    
    start = time.time()
    output = pathlib.Path(str(file).replace(proj_root, output_root))

    output_path = pathlib.Path(output)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    end = time.time()
    print(end - start)
    
    start = time.time() 
    ds.to_netcdf(output)
    end = time.time()
    print(end - start)
    
    print(output)




# file = "/shares/gcp/outputs/labor/impacts-woodwork/labor_mc_re-rebased/batch5/rcp45/CESM1-BGC/high/SSP4/uninteracted_main_model-noadapt.nc4"
# # start = time.time()
# ds = rebase_combine(file)
# # end = time.time()
# # print(end - start)

# # start = time.time()
# output = "/shares/gcp/outputs/labor/impacts-woodwork/labor_mc_aggregate_copy4/batch5/rcp45/CESM1-BGC/high/SSP4/uninteracted_main_model-noadapt.nc4"

# output_path = pathlib.Path(output)
# output_path.parent.mkdir(parents=True, exist_ok=True)

# # end = time.time()
# # print(end - start)

# # start = time.time() 
# ds.to_netcdf(output)
# # end = time.time()
# # print(end - start)

# print(output)