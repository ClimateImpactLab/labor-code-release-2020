import pandas as pd

histclim_csv = 'combined_uninteracted_spline_empshare_noFE-highriskimpacts-histclim.csv'
raw_csv = 'combined_uninteracted_spline_empshare_noFE-highriskimpacts-raw.csv'

main_folder = '/shares/gcp/outputs/labor/impacts-woodwork/combined_uninteracted_splines_27_37_39_by_risk_empshare_noFE_YearlyAverageDay/median/rcp85/CCSM4/high/SSP3/csv'
clipped_folder = '/shares/gcp/outputs/labor/impacts-woodwork/clipping_extrema/median/rcp85/CCSM4/high/SSP3/csv'

main_hist = pd.read_csv(f'{main_folder}/{histclim_csv}').rename(columns={'value':'main_hist'})
main_raw = pd.read_csv(f'{main_folder}/{raw_csv}').rename(columns={'value':'main_raw'})

main = main_hist.merge(main_raw,
				on=['region','year'])

clip_hist = pd.read_csv(f'{clipped_folder}/{histclim_csv}').rename(columns={'value':'clip_hist'})
clip_raw = pd.read_csv(f'{clipped_folder}/{raw_csv}').rename(columns={'value':'clip_raw'})

clip = clip_hist.merge(clip_raw,
				on=['region','year'])

clip['clipped_diff'] = clip.clip_raw - clip.clip_hist
main['main_diff'] = main.main_raw - main.main_hist

all = main.merge(clip,
				on=['region','year'])

all.to_csv('/home/kschwarz/repos/labor-code-release-2020/output/diagnostics/compare_clipped_extrema_main.csv')

chicago = all.loc[all.region == 'USA.14.608']

chicago.to_csv('/home/kschwarz/repos/labor-code-release-2020/output/diagnostics/USA.14.608.compare_clipped_extrema_main.csv')
