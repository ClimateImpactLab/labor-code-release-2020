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
	allcalcs = pd.read_csv("/shares/gcp/outputs/labor/impacts-woodwork/test_rcc_copy/" +
	        "uninteracted_splines_27_37_39_by_risk_empshare_noFE_YearlyAverageDay/rcp85/CCSM4/high/SSP3/" +
	        "test_rcc_main_model_single_config-allcalcs-uninteracted_main_model.csv",
	        skiprows=26, usecols=['region', 'year', 'climtas', 'loggdppc'])

	# fulladapt

	log_inc = allcalcs.loc[(allcalcs.region == region) & (allcalcs.year == 2099)]['loggdppc'].iloc[0]
	t 		= allcalcs.loc[(allcalcs.region == region) & (allcalcs.year == 2099)]['climtas'].iloc[0]

	risk_share_csvv =  2.3722374409202 -0.0081779717139058 * t**1 -0.0015973225364699 * t**2 +  5.86088469882e-05 * t**3 -1.7980748713e-07 * t**4 -0.178702997711924 * log_inc

	print(f"Predicted FULLADAPT high risk share (loginc = {log_inc}, LRT = {t}) is : {risk_share_csvv}. \n")


	# histclim

	log_inc = allcalcs.loc[(allcalcs.region == region) & (allcalcs.year == 2099)]['loggdppc'].iloc[0]
	t 		= allcalcs.loc[(allcalcs.region == region) & (allcalcs.year == 2015)]['climtas'].iloc[0]

	risk_share_csvv =  2.3722374409202 -0.0081779717139058 * t**1 -0.0015973225364699 * t**2 +  5.86088469882e-05 * t**3 -1.7980748713e-07 * t**4 -0.178702997711924 * log_inc

	print(f"Predicted HISTCLIM high risk share (loginc = {log_inc}, LRT = {t}) is : {risk_share_csvv}. \n")

	# projection system outputs

	fulladapt = xr.open_dataset("/shares/gcp/outputs/labor/impacts-woodwork/test_rcc_copy/" +
	        "uninteracted_splines_27_37_39_by_risk_empshare_noFE_YearlyAverageDay/rcp85/CCSM4/high/SSP3/" +
	        "uninteracted_main_model.nc4").to_dataframe().reset_index()

	histclim = xr.open_dataset("/shares/gcp/outputs/labor/impacts-woodwork/test_rcc_copy/" +
	        "uninteracted_splines_27_37_39_by_risk_empshare_noFE_YearlyAverageDay/rcp85/CCSM4/high/SSP3/" +
	        "uninteracted_main_model-histclim.nc4").to_dataframe().reset_index()

	incadapt = xr.open_dataset("/shares/gcp/outputs/labor/impacts-woodwork/test_rcc_copy/" +
	        "uninteracted_splines_27_37_39_by_risk_empshare_noFE_YearlyAverageDay/rcp85/CCSM4/high/SSP3/" +
	        "uninteracted_main_model-incadapt.nc4").to_dataframe().reset_index()

	FA_share = fulladapt.loc[(fulladapt.regions == region) & (fulladapt.year == 2099)]['clip'].iloc[0]
	H_share = histclim.loc[(histclim.regions == region) & (histclim.year == 2099)]['clip'].iloc[0]
	I_share = incadapt.loc[(incadapt.regions == region) & (incadapt.year == 2099)]['clip'].iloc[0]

	print(f"Projection system risk_share values are: {FA_share} (fulladapt), {H_share} (histclim), {I_share} (incadapt).")

	return

print("RISK SHARE FORMULA")
print("risk_share_csvv =  2.3722374409202 -0.0081779717139058 * t**1 -0.0015973225364699 * t**2 +  5.86088469882e-05 * t**3 -1.7980748713e-07 * t**4 -0.178702997711924 * log_inc")
for region, name in zip(list(region_dict.keys()), list(region_dict.values())):
	print(f"\n *************************")
	print(f"COMPUTING {name} - {region} ....")
	compare_riskshare(region, name)