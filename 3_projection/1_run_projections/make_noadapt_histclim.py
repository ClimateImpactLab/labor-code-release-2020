# Date Created: 02/17/2026
# Author: Elliot Grenier
# Description: Create a noadapt histclim specification or the labor uninteracted_main_model
#   sector, computes a rebased variable by combining histclim risk impacts weighted by
#   the noadapt clip variable:
#       rebased = highriskimpacts * clip + lowriskimpacts * (1 - clip)
#   Writes a new netcdf ({basename}-histclim-noadapt.nc4) containing rebased,
#   highriskimpacts, lowriskimpacts, and clip, preserving histclim file attributes.

import os
import sys
import numpy as np
import xarray as xr
from pathlib import Path
from multiprocessing import Pool
from itertools import product

# ==== Set parameters here ==== #

# file name + path
dir_labor = '/project/cil/gcp/outputs/labor/impacts-woodwork/montecarlo/uninteracted_main_model_agnonag_27_28_41'
basename = 'uninteracted_main_model_agnonag_27_28_41'

# specs
uncertainty = 'montecarlo'  # 'median' 'montecarlo'
iams = ['high', 'low'] # 'high' 'low'
rcps = ['rcp45', 'rcp85'] # 'rcp45' 'rcp85'
ssps = ['SSP2', 'SSP4'] # 'SSP2' 'SSP3' 'SSP4'

# batches
if uncertainty == 'montecarlo':
    batches = (next(os.walk(dir_labor))[1])
else:
    batches = ['median']

# ==== function ==== #
def process_labor(batch, rcp, model, iam, ssp):
    
    base_dir = os.path.join(dir_labor, batch, rcp, model, iam, ssp)
    histclim_path = os.path.join(base_dir, basename + '-histclim.nc4')
    noadapt_path = os.path.join(base_dir, basename + '-noadapt.nc4')

    print("[Processing:  ]")
    print(f"histclim: {histclim_path}")
    print(f"noadapt: {noadapt_path}")

    # --- Open histclim ---
    try:
        ds_histclim = xr.open_dataset(histclim_path)
    except Exception as e:
        print(f"Failed to open histclim file: {e}")
        return
    for var in ('lowriskimpacts', 'highriskimpacts', 'rebased', 'regions'):
        if var not in ds_histclim:
            print(f"Variable '{var}' not found in histclim file. Skipping.")
            ds_histclim.close()
            return

    # --- Open noadapt ---
    try:
        ds_noadapt = xr.open_dataset(noadapt_path)
    except Exception as e:
        print(f"Failed to open noadapt file: {e}")
        ds_histclim.close()
        return
    if 'clip' not in ds_noadapt:
        print(f"Variable 'clip' not found in noadapt file. Skipping.")
        ds_histclim.close()
        ds_noadapt.close()
        return

    # --- Promote 'regions' to a coordinate on the region dimension ---
    region_labels = ds_histclim['regions'].values
    ds_histclim = ds_histclim.assign_coords(region=('region', region_labels))
    ds_noadapt  = ds_noadapt.assign_coords(region=('region', region_labels))

    # --- Compute rebased ---
    low = ds_histclim['lowriskimpacts']
    high = ds_histclim['highriskimpacts']
    clip = ds_noadapt['clip']
    rebased = high * clip + low * (1 - clip)
    rebased.name = 'rebased'
    rebased.attrs = ds_histclim['rebased'].attrs.copy()

    # --- Build output dataset, preserving histclim global attrs ---
    ds_out = xr.Dataset(
        {
            'rebased': rebased,
            'highriskimpacts': high.assign_attrs(ds_histclim['highriskimpacts'].attrs),
            'lowriskimpacts': low.assign_attrs(ds_histclim['lowriskimpacts'].attrs),
            'clip': clip.assign_attrs(ds_noadapt['clip'].attrs),
            'regions': ds_histclim['regions'],
            'orderofoperations': ds_histclim['orderofoperations'],
        },
        attrs=ds_histclim.attrs
    )

    # --- Write output ---
    output_file = os.path.join(base_dir, basename + '-histclim-noadapt.nc4')
    print(f"[Writing:  ] {output_file}")
    ds_out.to_netcdf(output_file, unlimited_dims=['year'])

    ds_histclim.close()
    ds_noadapt.close()
    ds_out.close()

# ==== Run ==== #

if __name__ == '__main__':
    print("[Running:  ] Make noadapt histclim scenario")

    combos = [
        (batch, rcp, model, iam, ssp)
        for batch, rcp in product(batches, rcps)
        for model in next(os.walk(os.path.join(dir_labor, batch, rcp)))[1]
        for iam, ssp in product(iams, ssps)
    ]
    
    print(f"  Total jobs: {len(combos)}")

    with Pool(processes=os.cpu_count()) as pool:
        pool.starmap(process_labor, combos)

    print("[Done.  ]")
