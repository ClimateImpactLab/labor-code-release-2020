# extract, re-rebase and plot
import xarray as xr
import numpy as np
import pandas as pd
import getpass
import sys
import os
import pathlib
import time
import warnings
import matplotlib.pyplot as plt

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
    rebased['rebased_new'] = rebased.highriskimpacts * dt['clip'] + rebased.lowriskimpacts * (1 - dt['clip'])
    # add back onto dataframe
    dt['rebased_new'] = rebased['rebased_new']
    return dt

proj_root = "/shares/gcp/outputs/labor/impacts-woodwork/uninteracted_splines_27_37_39_by_risk_empshare_noFE_test_15yr_income/rcp85/CCSM4/high/SSP3/"
basename = "uninteracted_main_model_test_15yr_income"

df = pd.DataFrame()

for adapt in ["fulladapt","incadapt","histclim","noadapt"]:
    if adapt == "fulladapt" :
        infix = ""
    else:
        infix = "-" + adapt     
    nc4 = rebase_combine(proj_root + basename + infix + "-pop-aggregated.nc4").to_dataframe().reset_index()
    df[adapt] = nc4['rebased_new']
    if adapt == "fulladapt" : 
        df["year"] = nc4["year"]
        df["regions"] = nc4["regions"]
        
   
df_plot = df[df.regions == ""]



