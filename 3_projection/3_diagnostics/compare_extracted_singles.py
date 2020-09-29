import pandas as pd

histclim_csv = 'combined_uninteracted_spline_empshare_noFE-highriskimpacts-histclim.csv'
raw_csv = 'combined_uninteracted_spline_empshare_noFE-highriskimpacts-raw.csv'

main_folder = '/shares/gcp/outputs/labor/impacts-woodwork/combined_uninteracted_splines_27_37_39_by_risk_empshare_noFE_YearlyAverageDay/median/rcp85/CCSM4/high/SSP3/csv'
clipped_folder = '/shares/gcp/outputs/labor/impacts-woodwork/clipping_extrema/median/rcp85/CCSM4/high/SSP3/csv'

main_histclim = pd.read_csv(f'{main_folder}/{histclim_csv}').rename(columns={'value':'main_histclim'})
main_fulladapt = pd.read_csv(f'{main_folder}/{raw_csv}').rename(columns={'value':'main_fulladapt'})

main = main_histclim.merge(main_fulladapt,
				on=['region','year'])

clip_histclim = pd.read_csv(f'{clipped_folder}/{histclim_csv}').rename(columns={'value':'clip_histclim'})
clip_fulladapt = pd.read_csv(f'{clipped_folder}/{raw_csv}').rename(columns={'value':'clip_fulladapt'})

clip = clip_histclim.merge(clip_fulladapt,
				on=['region','year'])

clip['clipped_diff'] = clip.clip_fulladapt - clip.clip_histclim
main['main_diff'] = main.main_fulladapt - main.main_histclim

all = main.merge(clip,
				on=['region','year'])

all.to_csv('/home/kschwarz/logs/compare_clipped_extrema_main.csv')

chicago = all.loc[all.region == 'USA.14.608']

chicago.to_csv('/home/kschwarz/repos/labor-code-release-2020/output/diagnostics/USA.14.608.compare_clipped_extrema_main.csv', index=False)
