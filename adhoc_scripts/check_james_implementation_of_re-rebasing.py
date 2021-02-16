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
    dt['highriskimpacts_rebased'] = rebased.highriskimpacts
    dt['lowriskimpacts_rebased'] = rebased.lowriskimpacts
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


results_root = "/shares/gcp/outputs/labor/impacts-woodwork/"
single_foler = "/rcp85/CCSM4/high/SSP3/"
our_projection = results_root + "uninteracted_splines_27_37_39_by_risk_empshare_noFE_YearlyAverageDay_wrong_rebasing/" + single_foler
james_projection = results_root + "uninteracted_splines_27_37_39_by_risk_empshare_noFE_YearlyAverageDay_correct_rebasing/" + single_foler


ours_ds = rebase_combine(our_projection + "uninteracted_main_model.nc4").to_dataframe().reset_index()
james_ds = xr.open_dataset(james_projection + "uninteracted_main_model.nc4").to_dataframe().reset_index()

ours_ds = ours_ds[ours_ds.orderofoperations == "rebased"]
james_ds = james_ds[james_ds.orderofoperations == "rebased"]

old_view = ours_ds[['regions','year','clip','highriskimpacts','highriskimpacts_rebased','lowriskimpacts','lowriskimpacts_rebased','rebased','rebased_new']]
new_view = james_ds[['regions','year','clip','highriskimpacts','lowriskimpacts','rebased']]

old_view.to_csv(our_projection + "/impacts_for_mapping.csv")
new_view.to_csv(james_projection + "/impacts_for_mapping.csv")

