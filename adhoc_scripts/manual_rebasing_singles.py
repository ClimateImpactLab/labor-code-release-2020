'''
Manual rebasing script for MCs

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
import pathlib
import time
import warnings
from glob import glob
warnings.filterwarnings("ignore")

username = getpass.getuser()

############
# PARAMETERS
############

# select: uninteracted_main_model, uninteracted_main_model_w_chn
model = 'uninteracted_main_model_w_chn'

# leave these if you want to rebase & combine for all scenarios
# empty string is for 'fulladapt'
scenarios = ['', '-histclim', '-incadapt', '-noadapt'] 

############
# PATHWAYS
############

if model == 'uninteracted_main_model_w_chn':
    
    proj_root = ('/shares/gcp/outputs/labor/impacts-woodwork/uninteracted_main_model_w_chn/' +
                 'uninteracted_splines_w_chn_21_37_41_by_risk_empshare_noFE_YearlyAverageDay/rcp85/CCSM4/high/SSP3')
    
    output_root = ('/shares/gcp/outputs/labor/impacts-woodwork/uninteracted_main_model_w_chn_copy/' +
                 'uninteracted_splines_w_chn_21_37_41_by_risk_empshare_noFE_YearlyAverageDay/rcp85/CCSM4/high/SSP3')
    
elif model == 'uninteracted_main_model':
    
    proj_root = ('/shares/gcp/outputs/labor/impacts-woodwork/test_rcc/' +
                 'uninteracted_splines_27_37_39_by_risk_empshare_noFE_YearlyAverageDay/rcp85/CCSM4/high/SSP3')
    
    output_root = ('/shares/gcp/outputs/labor/impacts-woodwork/test_rcc_copy/' +
                 'uninteracted_splines_27_37_39_by_risk_empshare_noFE_YearlyAverageDay/rcp85/CCSM4/high/SSP3')

else:

    sys.exit("Your model is unrecognized.")


# copy parent folder structure
# for dirpath, dirnames, filenames in os.walk(proj_root):
#     structure = os.path.join(output_root, dirpath[len(proj_root):])
#     if not os.path.isdir(structure):
#         os.mkdir(structure)
#     else:
#         print("Folder does already exits!")

###############################
# REBASE & COMBINE FUNCTION
###############################

def rebase_combine(file):
    
    dt = xr.open_dataset(file)

    # there is an inconsistency in naming between dimensions and coordinates
    # on the recommendation of Sir Ivan, we fix this
    dt = dt.rename({'regions': 'region'})
    dt = dt.assign_coords({'region': dt.region})

    # select years & columns needed for rebasing
    base = (dt.sel(
            {"year": slice(2001,2010)}
            )
            [['region','highriskimpacts', 'lowriskimpacts']]
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

    # yuck we need this 'regions' to extract with single.py!
    dt = dt.rename({'region': 'regions'})

    return dt


##############
# IMPLEMENT
##############

# in the ideal world, this will work *not* as a groddy old forloop.
# unfortunately we are pressed for time and this script will (hopefully)
# never be run again... so we are just bearing with it.
# It should take ~1 second per file if run on Bat, or else 2-4 seconds
# per file if run on Sac.

# an awkward way to grab the four scenarios we want
paths = glob(f'{proj_root}/{model}.nc4')
paths.extend(glob(f'{proj_root}/{model}-histclim.nc4'))
paths.extend(glob(f'{proj_root}/{model}-incadapt.nc4'))
paths.extend(glob(f'{proj_root}/{model}-noadapt.nc4'))

for file in paths:
    start = time.time()
    ds = rebase_combine(file)
    end = time.time()
    print(end - start)
    
    start = time.time()
    output = pathlib.Path(str(file).replace(proj_root, output_root))
    end = time.time()
    print(end - start)
    
    start = time.time() 
    ds.to_netcdf(output)
    end = time.time()
    print(end - start)
    
    print(output)