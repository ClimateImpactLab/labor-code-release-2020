# clean cliamte data

import pandas as pd
import re
import cilpath
pd.set_option('display.max_columns', None)  # or 1000
pd.set_option('display.max_rows', None)  # or 1000
pd.set_option('display.max_colwidth', -1)  # or 199


paths = cilpath.Cilpath()
countries = ["BRA","GBR","MEX","ESP","FRA","IND","USA"]
dt = {}
cw = {}
merged = {}
merge_keys = {'FRA':'NAME_1',
             'GBR':'ADMIN_NAME',
             'ESP':'NAME_1',
             'BRA':['NAME_1','NAME_2'],
             'MEX':['NOM_ENT','NOM_MUN'],
             'USA':['NAME_1','NAME_2'], 
             'IND':'DIST91_ID'}

clim_var_cols = ["tmax_rcspline_term0","tmax_rcspline_term1","tmax_rcspline_term2"]
key_cols = ['iso','location_id1','location_id2', 'year','month','day']
keep_cols = key_cols + clim_var_cols

for iso in countries:
    dt[iso] = pd.read_stata(
        "/shares/gcp/estimation/Labor/Climate_data/time_use_newvars/outputs/merged/" 
        + iso + "/GMFD_spline_popwt_" + iso + ".dta")
    cw[iso] = pd.read_csv(paths.DB + "/Global ACP/labor/1_preparation/crosswalks/timeuse_climate_crosswalk_" + iso + ".csv"
                         ).drop(columns = ['location_name1','location_name2'])
    if iso == "GBR":
        merged[iso] = dt[iso].merge(cw[iso], on = merge_keys[iso], how = 'inner')[keep_cols + ['weight']]
        for col in clim_var_cols:
            merged[iso][col] = merged[iso][col] * merged[iso]['weight']
        merged[iso] = merged['GBR'].groupby(key_cols).sum().reset_index().drop(columns = 'weight')
    else:
        merged[iso] = dt[iso].merge(cw[iso], on = merge_keys[iso], how = 'inner')[keep_cols]
    merged[iso].to_stata("/shares/gcp/estimation/Labor/Climate_data/time_use_newvars/outputs/merged/" 
        + iso + "/GMFD_spline_popwt_" + iso + "_crosswalked.dta")


# china
clim = pd.read_stata("/shares/gcp/estimation/Labor/Climate_data/time_use_newvars/outputs/merged/CHN/GMFD_popwt_CHN.dta")
cw = pd.read_csv(paths.DB + "/Global ACP/labor/1_preparation/crosswalks/timeuse_climate_crosswalk_CHN.csv"
                )[['Commid','NAME_1','NAME_2']]

chns = pd.read_csv(paths.DB + "/Global ACP/labor/1_preparation/time_use/china/chn_time_use.csv",
                  parse_dates = ['interview_date'])

chns['year'] = chns['interview_date'].dt.year
chns['month'] = chns['interview_date'].dt.month
chns['day'] = chns['interview_date'].dt.day
chns['dow'] = chns['interview_date'].dt.dayofweek
merged_CHN = clim.merge(cw, on = ['NAME_1','NAME_2'], how = 'inner')
output_dir = "/shares/gcp/estimation/Labor/labor_merge_2019"
merged_CHN.to_stata(output_dir + "/CHN_climate.dta")
chns.to_stata(output_dir + "/CHN_chns.dta")