'''
Manual rebasing script

Purpose: this script takes unrebased projection output and manually calculates the 'combined, rebased impact'
(correctly!) by enacting this equation:

combined_rebased_impact = minlost_hi_rebased * riskshare_hi + minlost_lo_rebased * (1 - riskshare_hi)

This is done for histclim and fulladapt scenarios. As per usual, the histclim value will then be subtracted
from the fulladapt value and we will get our final result.

Parameters:

@model     : the name of the model (and thus the name of folder that output is stored in)
@scenario  : the name of the scenario from which projection output is sourced

Outputs: a modified version of the original projection file that now includes a new column, 'rebased_new',
which has this correctly-calculated combined, rebased impact.

'''
__author__ = 'Kit Schwarz'
__contact__ = 'csschwarz@uchicago.edu'
__version__ = '1.0'

############
# LIBRARIES
############

from dask.distributed import Client
import multiprocessing
import xarray as xr
import numpy as np
import pandas as pd
import getpass
import sys
import pathlib



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
    
    output_root = ('/shares/gcp/outputs/labor/impacts-woodwork/uninteracted_main_model_w_chn_copy3/' +
                 'uninteracted_splines_w_chn_21_37_41_by_risk_empshare_noFE_YearlyAverageDay/rcp85/CCSM4/high/SSP3')
    
elif model == 'uninteracted_main_model':
    
    proj_root = ('/shares/gcp/outputs/labor/impacts-woodwork/test_rcc/' +
                 'uninteracted_splines_27_37_39_by_risk_empshare_noFE_YearlyAverageDay/rcp85/CCSM4/high/SSP3')
    
    output_root = ('/shares/gcp/outputs/labor/impacts-woodwork/test_rcc_copy/' +
                 'uninteracted_splines_27_37_39_by_risk_empshare_noFE_YearlyAverageDay/rcp85/CCSM4/high/SSP3')
else:
    sys.exit("Your model is unrecognized.")



path = pathlib.Path(output_root)
path.mkdir(parents=True, exist_ok=True)

###############
# DASK SETUP
###############

# change the link of the Client to the link in your Dask dashboard
# this will be visible on the left of your JupyterLab window, in the Dask tab
client = Client()
client



###############################
# REBASE & COMBINE FUNCTION
###############################

def rebase_combine(proj_root, model, scenario):
    dt = xr.open_dataset(f'{proj_root}/{model}{scenario}.nc4',
        chunks={'year': 1})
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

args_list = zip(np.repeat(proj_root, repeats=len(scenarios)),
                np.repeat(model, repeats=len(scenarios)),
                scenarios)



for proj_root, model, scenario in args_list:
    ds = rebase_combine(proj_root, model, scenario)
    ds.to_netcdf(f"{output_root}/{model}{scenario}.nc4")

