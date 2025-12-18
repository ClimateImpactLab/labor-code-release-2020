import pandas as pd

allcalcs = pd.read_csv("/shares/gcp/outputs/labor/impacts-woodwork/test_rcc_copy/" +
	        "uninteracted_splines_27_37_39_by_risk_empshare_noFE_YearlyAverageDay/rcp85/CCSM4/high/SSP3/" +
	        "test_rcc_main_model_single_config-allcalcs-uninteracted_main_model.csv",
	        skiprows=26, usecols=['region', 'year', 'climtas', 'climtas-poly-2', 'climtas-poly-3', 'climtas-poly-4', 'loggdppc'])

df =  allcalcs[(allcalcs['year']==2099)]
df = df[['region', 'year', 'climtas']]

# df = df[df['climtas'].between(0.64, 29.01)]
df = df[(df['climtas'] <= 0.64) | (df['climtas'] >= 29.01)]

df.to_csv('/mnt/CIL_labor/3_projection/impact_checks/clipping_lrclim/outside_1_99_LRT.csv', index = False)
