import pandas as pd
import csv
# import glob
# from pathlib import Path

# Put parameters here.
region_dict = {
	'NGA.25.510' : 'Lagos, Nigeria',
	'IND.10.121.371' : 'Delhi, India',
	'CHN.2.18.78' : 'Beijing, China',
	'BRA.25.5212.R3fd4ed07b36dfd9c' : 'Sao Paulo, Brazil',
	'USA.14.608' : 'Chicago, USA',
	'NOR.12.288' : 'Oslo, Norway' 
	# "BRA.19.3634.Rf31287f7cff5d3a1" # rio
    # 'SDN.4.11.49.163' : 'Khartoum, SDN',
    # 'THA.3.R3edeff05b7928bfc' : 'Bangkok, THA', 
    # 'USA.5.221' : 'San Francisco, USA',
    # 'CAN.3.50.1276' : 'Winnipeg, CAN', 
    # 'CAN.2.33.913' : 'Vancouver, CAN', 
    # 'GBR.1.R7074136591e79d11' : 'London, GBR'
}

# iams
iams = ['high', 'low']
# rcps
rcps = ['rcp45', 'rcp85']
# ssps
ssps = ['SSP2', 'SSP3', 'SSP4']

for ssp in ssps:
	for rcp in rcps:
		for iam in iams:
			for region, name in zip(list(region_dict.keys()), list(region_dict.values())):
				df = pd.read_csv(f"/mnt/sacagawea_shares/gcp/estimation/labor/code_release_int_data/projection_outputs/extracted_data_mc_correct_rebasing_for_integration/{ssp}-{rcp}_{iam}_riskshare_fulladapt_2099_map.csv")
				FA_riskshare = df.loc[(df.region == region)]['mean'].iloc[0]
				print(f"\n *************************")
				print(f"{ssp} - {rcp} - {iam}")
				print(f"COMPUTING {name} - {region} ....")
				print(f"risk_share values are: {FA_riskshare} (fulladapt).")


# sample = pd.DataFrame([{ssp}, {rcp}, {iam}, {name}, {FA_riskshare}], columns=['SSP', 'RCP', 'IAM', 'Region', 'Riskshare'])
# print(sample)

# with open("/home/nsharma/repos/labor-code-release-2020/output/figures/sanity_checks_for_integration_newMC/riskshares.csv", 'w', newline='') as file:
# writer = csv.writer(file)
# writer.writerow()
# writer.writerows({'SSP': {ssp}, 'RCP': {rcp}, 'IAM': {iam}, 'Region': {name}, 'Riskshare': {FA_riskshare}})

				






