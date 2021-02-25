########################
# Manual riskshare checks
########################

import pandas as pd
import xarray as xr

region_dict ={
	'CHN.11.102.717' : 'Mohe, CHN', # max absolute difference in riskshare
	'KWT.3'	: 'Al Jahrah, KWT', # most negative diff in riskshare
	'MNG.14.214' : 'Tsagaannuur, MNG', # most positive diff in riskshare
	'MNG.9' : 'Dazavhan, MNG', # IR with temperature closest to 0.64 (LB)
	'IND.33.519.2087' : 'Sikandarabad, IND' # IR with temperature closest to 29.01 (UB)
}

# function
def compare_riskshare(region, name) :

	# get values from single
	allcalcs = pd.read_csv("/shares/gcp/outputs/labor/impacts-woodwork/test_rcc_copy/" +
	        "uninteracted_splines_27_37_39_by_risk_empshare_noFE_YearlyAverageDay/rcp85/CCSM4/high/SSP3/" +
	        "test_rcc_main_model_single_config-allcalcs-uninteracted_main_model.csv",
	        skiprows=26, usecols=['region', 'year', 'climtas', 'climtas-poly-2', 'climtas-poly-3', 'climtas-poly-4', 'loggdppc'])

# change the allcalcs file path for flat edges model (in main_model_flat_edges_single), 
# usecols and thus the ti variables to climtas^2, climtas^3, climtas^4, and skiprows to 22
# for the lrt^k model, allcalcs file is in the test_lrt_k folder, ti are climtas^k, and skiprows is 25

	# fulladapt

	log_inc = allcalcs.loc[(allcalcs.region == region) & (allcalcs.year == 2099)]['loggdppc'].iloc[0]
	t1 		= allcalcs.loc[(allcalcs.region == region) & (allcalcs.year == 2099)]['climtas'].iloc[0]
	t2 		= allcalcs.loc[(allcalcs.region == region) & (allcalcs.year == 2099)]['climtas-poly-2'].iloc[0]
	t3 		= allcalcs.loc[(allcalcs.region == region) & (allcalcs.year == 2099)]['climtas-poly-3'].iloc[0]
	t4 		= allcalcs.loc[(allcalcs.region == region) & (allcalcs.year == 2099)]['climtas-poly-4'].iloc[0]

	risk_share_csvv =  2.3722374409202 -0.0081779717139058 * t1 -0.0015973225364699 * t2 +  5.86088469882e-05 * t3 -1.7980748713e-07 * t4 -0.178702997711924 * log_inc

	print(f"Predicted FULLADAPT high risk share (loginc = {log_inc}, LRT = {t1}, {t2}, {t3}, {t4}) is : {risk_share_csvv}. \n")

	# projection system outputs

	fulladapt = xr.open_dataset("/shares/gcp/outputs/labor/impacts-woodwork/test_rcc_copy1/" +
	        "uninteracted_splines_27_37_39_by_risk_empshare_noFE_YearlyAverageDay/rcp85/CCSM4/high/SSP3/" +
	        "uninteracted_main_model.nc4").to_dataframe().reset_index()

	FA_share = fulladapt.loc[(fulladapt.regions == region) & (fulladapt.year == 2099)]['clip'].iloc[0]

	print(f"Projection system risk_share values are: {FA_share} (fulladapt).")

	return

print("RISK SHARE FORMULA")
print("risk_share_csvv =  2.3722374409202 -0.0081779717139058 * t1 -0.0015973225364699 * t2 +  5.86088469882e-05 * t3 -1.7980748713e-07 * t4 -0.178702997711924 * log_inc")
for region, name in zip(list(region_dict.keys()), list(region_dict.values())):
	print(f"\n *************************")
	print(f"COMPUTING {name} - {region} ....")
	compare_riskshare(region, name)