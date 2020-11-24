
import pandas as pd
import xarray as xr
import os.path
from os import path

# df = xr.open_dataset("/mnt/sacagawea_shares/gcp/outputs/temps/rcp85/CCSM4/climtas.nc4").to_dataframe().reset_index()

# print("CCSM4 Max climate in 2099 is ", df.loc[(df.year == 2099) & (df.covars == 'climtas')]['averaged'].max())
# print("CCSM4 Min climate in 2099 is ", df.loc[(df.year == 2099) & (df.covars == 'climtas')]['averaged'].min())

# df = xr.open_dataset("/mnt/sacagawea_shares/gcp/outputs/temps/rcp85/surrogate_GFDL-CM3_99/climtas.nc4").to_dataframe().reset_index()

# print("surrogate_GFDL-CM3_99 Max climate in 2099 is ", df.loc[(df.year == 2099) & (df.covars == 'climtas')]['averaged'].max())
# print("surrogate_GFDL-CM3_99 Min climate in 2099 is ", df.loc[(df.year == 2099) & (df.covars == 'climtas')]['averaged'].min())


# df = pd.read_csv("/shares/gcp/outputs/labor/impacts-woodwork/test_rcc_copy/" +
# 	"uninteracted_splines_27_37_39_by_risk_empshare_noFE_YearlyAverageDay/rcp85/CCSM4/high/SSP3/" +
# 	"test_rcc_main_model_single_config-allcalcs-uninteracted_main_model.csv",
# 	skiprows=26, usecols=['region', 'year', 'climtas', 'loggdppc'])

# print("Max loggdppc in 2099 is ", df.loc[(df.year == 2099)]['loggdppc'].max())
# print("Min loggdppc in 2099 is ", df.loc[(df.year == 2099)]['loggdppc'].min())

def get_climtas(model, method):
    
    df = xr.open_dataset(f"/shares/gcp/outputs/temps/rcp85/{model}/climtas.nc4").to_dataframe().reset_index()
    
    if method == 'max' :
        climtas = df['averaged'].max()
    elif method == 'min' :
        climtas = df['averaged'].min()
    else:
        print("Method not recognized.")
        exit()
    
    return climtas

gcms = [
        'ACCESS1-0', 'CCSM4', 'GFDL-CM3', 'IPSL-CM5A-LR', 'MIROC-ESM-CHEM',
        'bcc-csm1-1', 'CESM1-BGC', 'GFDL-ESM2G', 'IPSL-CM5A-MR', 'MPI-ESM-LR',
        'BNU-ESM', 'CNRM-CM5', 'GFDL-ESM2M', 'MIROC5', 'MPI-ESM-MR', 'CanESM2',
        'CSIRO-Mk3-6-0', 'inmcm4', 'MIROC-ESM', 'MRI-CGCM3', 'NorESM1-M',
        'surrogate_GFDL-CM3_89', 'surrogate_GFDL-ESM2G-_11',
        'surrogate_CanESM2_99', 'surrogate_GFDL-ESM2G_01',
        'surrogate_MRI-CGCM3_11', 'surrogate_CanESM2_89',
        'surrogate_GFDL-CM3_94', 'surrogate_MRI-CGCM3_01',
        'surrogate_CanESM2_94', 'surrogate_GFDL-CM3_99',
        'surrogate_MRI-CGCM3_06', 'surrogate_GFDL-ESM2G_06',
        'surrogate_GFDL-ESM2G_11'
    ]

results = pd.DataFrame(columns=['GCM' , 'max_climtas', 'min_climtas'])

for gcm in gcms:
    
    if path.exists(f"/shares/gcp/outputs/temps/rcp85/{gcm}/climtas.nc4"):
        results = results.append({
            'GCM' : gcm,
            'max_climtas' : get_climtas(gcm, 'max'),
            'min_climtas' : get_climtas(gcm, 'min')
        }, ignore_index=True
        )
    else:
        continue
    
print(results)

print("Max LRT across all GCMs in rcp85 is ", results.max_climtas.max(), "from GCM ", results.loc[results.max_climtas == results.max_climtas.max()]['GCM'])

print("Min LRT across all GCMs in rcp85 is ", results.min_climtas.min(), "from GCM ", results.loc[results.min_climtas == results.min_climtas.min()]['GCM'])
