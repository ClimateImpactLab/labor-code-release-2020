# Cleaning China time use data from CHNS
# Raw data located at /Global ACP/labor/1_preparation/time_use/china/CHNSRawData/original/
# By: Rae (liruixue@uchicago.edu)

import pandas as pd
import numpy as np
import cilpath


paths = cilpath.Cilpath()
data_folder = "/shares/gcp/estimation/labor/time_use_data/raw/CHN_CHNS/"

# index columns: idind, wave
file_jobs = pd.read_stata(data_folder + "jobs_00.dta")[['idind','wave','b2','b4','b8','b9','b13']]
file_jobs.columns = ['idind','wave','is_working','occupation_primary','hours_worked_primary','occupation_secondary','hours_worked_secondary' ]

# index columns: idind, wave
file_wages = pd.read_stata(data_folder + "wages_01.dta")[['idind','wave','job','c7']]
file_wages.columns = ['idind','wave','job','hours_worked_last_week']

# some people report two jobs at the same interview, we sum those hours
file_wages = file_wages.groupby(['idind','wave']).agg('sum').reset_index()[['idind','wave','hours_worked_last_week']]

# index: idind
file_mast = pd.read_stata(data_folder + "mast_pub_01.dta")[['idind','gender']]

# index: idind, wave
file_surveys = pd.read_stata(data_folder + "surveys_pub_01.dta")[['idind','hhid','wave','age','commid','t7']]
file_surveys.columns = ['idind','hhid','wave','age','commid','hhd_interview_date']


# index: hhid, wave
file_hhinc = pd.read_stata(data_folder + "hhinc_pub_00.dta")[['hhid','wave','hhsize']]

# merge the files
merged = file_surveys.merge(file_mast, on = ['idind'], how = "outer", indicator = False) 
merged = merged.merge(file_jobs, on = ['idind','wave'], how = "outer", indicator = False) 
merged = merged.merge(file_wages, on = ['idind','wave'], how = "outer", indicator = False)
merged = merged.merge(file_hhinc, on = ['hhid','wave'], how = "outer", indicator = False)

# create new variables and drop missing/extreme values
#chns_new_data = merged[merged.is_working == 1] # drop those who're not working
chns_new_data = merged # drop those who're not working

chns_new_data = chns_new_data.assign(male = 2 - chns_new_data['gender'] ) # generate male indicator
#chns_new_data = chns_new_data[chns_new_data.age >= 15] # remove those outside of our age range
#chns_new_data = chns_new_data[chns_new_data.age <= 65]
#chns_new_data = chns_new_data[chns_new_data.occupation_primary != -9]
#chns_new_data = chns_new_data[chns_new_data.occupation_primary.notna()]
#chns_new_data = chns_new_data[chns_new_data.hhd_interview_date.notna()]
chns_new_data['high_risk'] = np.where(chns_new_data.occupation_primary.isin([5, 9, 10, 6, 7]), 1, 0)
chns_new_data['sample_wgt'] = 1
chns_new_data = chns_new_data.assign(mins_worked = chns_new_data['hours_worked_last_week'] * 60 ) 
chns_new_data.idind = chns_new_data.idind.astype(int)
#chns_new_data = chns_new_data[chns_new_data.mins_worked > 0]

# high risk is defined as those who are:
# 5: farmer, fisherman, hunter
# 9: ordinary soldier, policeman
# 10: driver
# 6: skilled worker
# 7: non-skilled worker

def convert_date(x):
	if np.any(x[['hhd_interview_date']].isna()):
		return x
    x['year'] = int(x['hhd_interview_date']/10000)
    x['month'] = int((x['hhd_interview_date']% 10000) / 100)
    x['day'] = int(x['hhd_interview_date']% 100)
    return x

chns_new_data = chns_new_data.apply(lambda x: convert_date(x), axis = 1)

chns_new_data = chns_new_data[['commid','year','month','day','occupation_primary','idind','mins_worked','age','male','gender','high_risk','hhsize','sample_wgt']]
chns_new_data.columns = ['commid','year','month','day','occupation_primary','ind_id','mins_worked','age','male','gender','high_risk','hhsize','sample_wgt']

chns_new_data.to_csv("/shares/gcp/estimation/labor/time_use_data/check_missing/CHN_CHNS_time_use_w_missing.csv")
chns_new_data.to_stata("/shares/gcp/estimation/labor/time_use_data/check_missing/CHN_CHNS_time_use_w_missing.dta")



