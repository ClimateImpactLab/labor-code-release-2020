# calculate_popop.py
# second script to calculate popop (population-weighted population density, or perceived population density). 
# This comes after the qgis step executed in get_popop.py. Run get_popop.py before running this script. 
# Author: Simon Greenhill, sgreenhill@uchicago.edu
# Date: 5/31/2019

# setup 
import numpy as np
import pandas as pd
import os
import getpass

# toggle for admin level 
adm_lev = "geolev1"

# set up directories 
if getpass.getuser() == 'simongreenhill':
    in_dir = '/Users/simongreenhill/Dropbox/Global ACP/labor/1_preparation/IPUMS/data/popop/'

df = pd.read_csv("{}/popop_{}.csv".format(in_dir, adm_lev))

# make popop
df["popop"] = df["pop2_mean"] / df["pop_mean"]

# write csv
df.to_csv("{}/popop_{}.csv".format(in_dir, adm_lev))
