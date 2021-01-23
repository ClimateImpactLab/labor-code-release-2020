########################
# Manual riskshare checks
########################

import pandas as pd
import xarray as xr

# Put parameters here.
region_dict = {
    'SDN.4.11.49.163' : 'Khartoum, SDN',
    'THA.3.R3edeff05b7928bfc' : 'Bangkok, THA', 
    'USA.5.221' : 'San Francisco, USA',
    'CAN.3.50.1276' : 'Winnipeg, CAN', 
    'CAN.2.33.913' : 'Vancouver, CAN', 
    'GBR.1.R7074136591e79d11' : 'London, GBR'
}


# function
def compare_riskshare(region, name) :

	# get values from single
	allcalcs = pd.read_csv("/shares/gcp/outputs/labor/impacts-woodwork/main_model_flat_edges_single/" +
	        "uninteracted_splines_27_37_39_by_risk_empshare_noFE_YearlyAverageDay/rcp85/CCSM4/high/SSP3/" +
	        "labor-climtasmaxclip-allcalcs-labor-climtasmaxclip.csv",
	        skiprows=22, usecols=['region', 'year', 'climtas', 'climtas^2', 'climtas^3', 'climtas^4', 'loggdppc'])

	# fulladapt

	log_inc = allcalcs.loc[(allcalcs.region == region) & (allcalcs.year == 2099)]['loggdppc'].iloc[0]
	t1 		= allcalcs.loc[(allcalcs.region == region) & (allcalcs.year == 2099)]['climtas'].iloc[0]
	t2 		= allcalcs.loc[(allcalcs.region == region) & (allcalcs.year == 2099)]['climtas^2'].iloc[0]
	t3 		= allcalcs.loc[(allcalcs.region == region) & (allcalcs.year == 2099)]['climtas^3'].iloc[0]
	t4 		= allcalcs.loc[(allcalcs.region == region) & (allcalcs.year == 2099)]['climtas^4'].iloc[0]

	risk_share_csvv =  2.3722374409202 -0.0081779717139058 * t1 -0.0015973225364699 * t2 +  5.86088469882e-05 * t3 -1.7980748713e-07 * t4 -0.178702997711924 * log_inc

	print(f"Predicted FULLADAPT high risk share (loginc = {log_inc}, LRT = {t1}) is : {risk_share_csvv}. \n")


	# histclim

	log_inc = allcalcs.loc[(allcalcs.region == region) & (allcalcs.year == 2099)]['loggdppc'].iloc[0]
	t1		= allcalcs.loc[(allcalcs.region == region) & (allcalcs.year == 2015)]['climtas'].iloc[0]
	t2 		= allcalcs.loc[(allcalcs.region == region) & (allcalcs.year == 2015)]['climtas^2'].iloc[0]
	t3 		= allcalcs.loc[(allcalcs.region == region) & (allcalcs.year == 2015)]['climtas^3'].iloc[0]
	t4 		= allcalcs.loc[(allcalcs.region == region) & (allcalcs.year == 2015)]['climtas^4'].iloc[0]


	risk_share_csvv =  2.3722374409202 -0.0081779717139058 * t1 -0.0015973225364699 * t2 +  5.86088469882e-05 * t3 -1.7980748713e-07 * t4 -0.178702997711924 * log_inc

	print(f"Predicted HISTCLIM high risk share (loginc = {log_inc}, LRT = {t1}) is : {risk_share_csvv}. \n")

	# noadapt

	log_inc = allcalcs.loc[(allcalcs.region == region) & (allcalcs.year == 2015)]['loggdppc'].iloc[0]
	t1		= allcalcs.loc[(allcalcs.region == region) & (allcalcs.year == 2015)]['climtas'].iloc[0]
	t2 		= allcalcs.loc[(allcalcs.region == region) & (allcalcs.year == 2015)]['climtas^2'].iloc[0]
	t3 		= allcalcs.loc[(allcalcs.region == region) & (allcalcs.year == 2015)]['climtas^3'].iloc[0]
	t4 		= allcalcs.loc[(allcalcs.region == region) & (allcalcs.year == 2015)]['climtas^4'].iloc[0]


	risk_share_csvv =  2.3722374409202 -0.0081779717139058 * t1 -0.0015973225364699 * t2 +  5.86088469882e-05 * t3 -1.7980748713e-07 * t4 -0.178702997711924 * log_inc

	print(f"Predicted NOADAPT high risk share (loginc = {log_inc}, LRT = {t1}) is : {risk_share_csvv}. \n")

	# projection system outputs

	fulladapt = xr.open_dataset("/shares/gcp/outputs/labor/impacts-woodwork/main_model_flat_edges_single_copy/" +
	        "uninteracted_splines_27_37_39_by_risk_empshare_noFE_YearlyAverageDay/rcp85/CCSM4/high/SSP3/" +
	        "labor-climtasmaxclip.nc4").to_dataframe().reset_index()

	histclim = xr.open_dataset("/shares/gcp/outputs/labor/impacts-woodwork/main_model_flat_edges_single_copy/" +
	        "uninteracted_splines_27_37_39_by_risk_empshare_noFE_YearlyAverageDay/rcp85/CCSM4/high/SSP3/" +
	        "labor-climtasmaxclip-histclim.nc4").to_dataframe().reset_index()

	incadapt = xr.open_dataset("/shares/gcp/outputs/labor/impacts-woodwork/main_model_flat_edges_single_copy/" +
	        "uninteracted_splines_27_37_39_by_risk_empshare_noFE_YearlyAverageDay/rcp85/CCSM4/high/SSP3/" +
	        "labor-climtasmaxclip-incadapt.nc4").to_dataframe().reset_index()

	noadapt = xr.open_dataset("/shares/gcp/outputs/labor/impacts-woodwork/main_model_flat_edges_single_copy/" +
	        "uninteracted_splines_27_37_39_by_risk_empshare_noFE_YearlyAverageDay/rcp85/CCSM4/high/SSP3/" +
	        "labor-climtasmaxclip-noadapt.nc4").to_dataframe().reset_index()

	FA_share = fulladapt.loc[(fulladapt.regions == region) & (fulladapt.year == 2099)]['clip'].iloc[0]
	H_share = histclim.loc[(histclim.regions == region) & (histclim.year == 2099)]['clip'].iloc[0]
	I_share = incadapt.loc[(incadapt.regions == region) & (incadapt.year == 2099)]['clip'].iloc[0]
	N_share = noadapt.loc[(noadapt.regions == region) & (noadapt.year == 2099)]['clip'].iloc[0]

	print(f"Projection system risk_share values are: {FA_share} (fulladapt), {H_share} (histclim), {I_share} (incadapt), {N_share} (noadapt).")

	return

print("RISK SHARE FORMULA")
print("risk_share_csvv =  2.3722374409202 -0.0081779717139058 * t1 -0.0015973225364699 * t2 +  5.86088469882e-05 * t3 -1.7980748713e-07 * t4 -0.178702997711924 * log_inc")
for region, name in zip(list(region_dict.keys()), list(region_dict.values())):
	print(f"\n *************************")
	print(f"COMPUTING {name} - {region} ....")
	compare_riskshare(region, name)