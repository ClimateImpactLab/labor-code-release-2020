'''
Separately rebase high and low impacts

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
from p_tqdm import p_uimap, p_umap
from functools import partial

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

def rebase_high_and_low(input_path):
    input_dir = "mc_correct_rebasing_for_integration"
    output_dir = "mc_correct_rebasing_for_integration_high_low_separate"
    
    dt = xr.open_dataset(input_path)

    # select years & columns needed for rebasing
    base = (dt.sel(
            {"year": slice(2001,2010)}
            )
            [['regions','highriskimpacts', 'lowriskimpacts']]
           )

    # subtract off mean of base years -> rebasing!
    mean_base = base.mean(dim="year")
    rebased = dt - mean_base

    # add back onto dataframe
    dt['high_rebased'] = rebased.highriskimpacts
    dt['low_rebased'] = rebased.lowriskimpacts

    # set its attributes

    dt.high_rebased.attrs = { 'long_title' : 'Rebased high risk impact',
                           'units' : 'minutes worked by individual',}
    dt.low_rebased.attrs = { 'long_title' : 'Rebased low risk impact',
                           'units' : 'minutes worked by individual',}
    
    output_path = pathlib.Path(input_path.replace(input_dir, output_dir))

    output_path = pathlib.Path(output)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    dt.to_netcdf(output_path)
    dt.close()



##############
# IMPLEMENT
##############

# root = "/shares/gcp/outputs/labor/impacts-woodwork/"
# input_dir = "mc_correct_rebasing_for_integration"
# output_dir = "mc_correct_rebasing_for_integration_high_low_separate"

# paths = list(pathlib.Path(f"{root}/{input_dir}").rglob("*.nc4"))

# p_umap(rebase_high_and_low, paths, num_cpus = 2)


# in the ideal world, this will work *not* as a groddy old forloop.
# unfortunately we are pressed for time and this script will (hopefully)
# never be run again... so we are just bearing with it.
# It should take ~1 second per file if run on Bat, or else 2-4 seconds
# per file if run on Sac.


# for batchno in range(0,15) :

    # proj_root = '/shares/gcp/outputs/labor/impacts-woodwork/labor_mc_re-rebased/batch{}/rcp85/bcc-csm1-1/'.format(batchno)
    # output_root = '/shares/gcp/outputs/labor/impacts-woodwork/labor_mc_aggregate_copy4/batch{}/rcp85/bcc-csm1-1/'.format(batchno)

#     paths = list(pathlib.Path(proj_root).rglob('*.nc4'))

#     # import pathlib

#     for file in paths:
#         start = time.time()
#         ds = rebase_combine(file)
#         end = time.time()
#         print(end - start)
        
#         start = time.time()
#         output = pathlib.Path(str(file).replace(proj_root, output_root))

#         output_path = pathlib.Path(output)
#         output_path.parent.mkdir(parents=True, exist_ok=True)

#         end = time.time()
#         print(end - start)
        
#         start = time.time() 
#         ds.to_netcdf(output)
#         end = time.time()
#         print(end - start)
        
#         print(output)




file = "/shares/gcp/outputs/labor/impacts-woodwork/labor_mc_re-rebased/batch0/rcp45/ACCESS1-0/high/SSP3/uninteracted_main_model.nc4"
start = time.time()
ds = rebase_high_and_low(file)
end = time.time()
print(end - start)

