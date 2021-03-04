import pandas as pd
from functools import reduce

# set the output folder and the special regions we want to check out

output_folder = '/shares/gcp/estimation/labor/code_release_int_data/projection_outputs/diagnostics'
expect_unclipped = 'SDN.6.16.75.230'
expect_clipped = 'USA.14.608'

# Select output folders of the models we're interested in

main_folder = '/shares/gcp/outputs/labor/impacts-woodwork/z_old_combined_uninteracted_splines_27_37_39_by_risk_empshare_noFE_YearlyAverageDay_duplicates/median/rcp85/CCSM4/high/SSP3/csv'
clipped_folder = '/shares/gcp/outputs/labor/impacts-woodwork/clipping_extrema/combined_mixed_splines_27_37_39_by_risk_empshare_noFE_YearlyAverageDay/rcp85/CCSM4/high/SSP3/csv'
unclipped_folder = '/shares/gcp/outputs/labor/impacts-woodwork/unclipped_mixed_model/combined_mixed_splines_27_37_39_by_risk_empshare_noFE_YearlyAverageDay/rcp85/CCSM4/high/SSP3/csv'

# Define a function to get the comparative data we want

def extract_data(folder, prefix, name, risk) :

	histclim_csv = f'{prefix}-{risk}-histclim.csv'
	fulladapt_csv = f'{prefix}-{risk}-fulladapt.csv'

	histclim = pd.read_csv(f'{folder}/{histclim_csv}').rename(columns={'value':f'{name}_histclim'})
	fulladapt = pd.read_csv(f'{folder}/{fulladapt_csv}').rename(columns={'value':f'{name}_fulladapt'})

	df = histclim.merge(fulladapt,
				on=['region','year'])

	df[f'{name}_diff'] = df[f'{name}_fulladapt'] - df[f'{name}_histclim']

	return(df)


folders = [main_folder, clipped_folder, unclipped_folder]
prefixes = ['combined_uninteracted_spline_empshare_noFE', 'combined_mixed_model_splines_empshare_noFE', 'combined_mixed_model_splines_empshare_noFE']
names = ['main', 'clipped', 'unclipped']

datasets = [extract_data(folder, prefix, name, 'highriskimpacts') for folder, prefix, name in zip(folders, prefixes, names)]

all = reduce(
			lambda x, y: pd.merge(
			x, y, on = ['region','year']), datasets)


all.to_csv(f'{output_folder}/mixed_model_unclipped_clipped.csv')

special = all.loc[(all.region == expect_unclipped) | (all.region == expect_clipped)]

special.to_csv('/home/kschwarz/repos/labor-code-release-2020/output/diagnostics/special_regions_mixed_model_unclipped_clipped.csv', index=False)
