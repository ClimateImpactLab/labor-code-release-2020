# Cleaning China time use data from CHNS
# Raw data located at/shares/gcp/estimation/labor/time_use_data/raw/CHN_CHNS/
# By: Rae (liruixue@uchicago.edu)

import sys
sys.path.insert(0, '/home/liruixue/repos/labor-code-release-2020/0_subroutines') 
import paths


import pandas as pd
import numpy as np
import cilpath
import time
import datetime

data_folder = DIR_INT_DATA + "/surveys/CHNS/"


# read a few files that contain variables we want, then combine them 
# index columns: idind, wave
file_jobs = pd.read_stata(data_folder + "jobs_00.dta")[['idind','wave','b2','b4','b8','b9','b13']]
file_jobs.columns = ['idind','wave','is_working','occupation_primary','hours_worked_primary','occupation_secondary','hours_worked_secondary' ]

# index columns: idind, wave
file_wages = pd.read_stata(data_folder + "wages_01.dta")[['idind','wave','job','c7']]
file_wages.columns = ['idind','wave','job','hours_worked_last_week']
file_wages = file_wages[file_wages['hours_worked_last_week'] > 0]
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
merged = file_surveys.merge(file_mast, on = ['idind'], how = "inner", indicator = False) 
merged = merged.merge(file_jobs, on = ['idind','wave'], how = "inner", indicator = False) 
merged = merged.merge(file_wages, on = ['idind','wave'], how = "inner", indicator = False)
merged = merged.merge(file_hhinc, on = ['hhid','wave'], how = "inner", indicator = False)

# create new variables and drop missing/extreme values
chns_new_data = merged[merged.is_working == 1] # drop those who're not working
chns_new_data = chns_new_data.assign(male = 2 - chns_new_data['gender'] ) # generate male indicator
chns_new_data = chns_new_data[chns_new_data.age >= 15] # remove those outside of our age range
chns_new_data = chns_new_data[chns_new_data.age <= 65]
chns_new_data = chns_new_data[chns_new_data.occupation_primary != -9] # drop missing occupation
chns_new_data = chns_new_data[chns_new_data.occupation_primary.notna()] # also drop missing occupation
chns_new_data = chns_new_data[chns_new_data.hhd_interview_date.notna()] # drop missing interview date


# high risk is defined as those who are:
# 5: farmer, fisherman, hunter
# 9: ordinary soldier, policeman
# 10: driver
# 6: skilled worker
# 7: non-skilled worker 

chns_new_data['high_risk'] = np.where(chns_new_data.occupation_primary.isin([5, 9, 10, 6, 7]), 1, 0) # assign high risk
chns_new_data['sample_wgt'] = 1 # there's no sample weight, so we assign 1
chns_new_data = chns_new_data.assign(mins_worked = chns_new_data['hours_worked_last_week'] * 60 ) # convert to minutes
chns_new_data.idind = chns_new_data.idind.astype(int) # individual ID
chns_new_data = chns_new_data[chns_new_data.mins_worked > 0] # drop working hour <= 0


# a function that separate the interview date (a string) into year month day
def convert_date(x):
    yr = int(x['hhd_interview_date']/10000)
    mt = int((x['hhd_interview_date']% 10000) / 100)
    d = int(x['hhd_interview_date']% 100)
    interview_date = datetime.datetime(year = yr, month = mt, day = d)
    #dow = interview_date.weekday() + 1  # convert Mon-0 ---> Mon - 1
    #sun = interview_date - datetime.timedelta(dow)
    #x['year'] = sun.year
    #x['month'] = sun.month
    #x['day'] = sun.day
    #x['interview_year'] = interview_date.year
    #x['interview_month'] = interview_date.month
    #x['interview_day'] = interview_date.day
    x['year'] = interview_date.year
    x['month'] = interview_date.month
    x['day'] = interview_date.day
    return x

chns_new_data = chns_new_data.apply(lambda x: convert_date(x), axis = 1)

# select only the columns we need, rename columns, and save
chns_new_data = chns_new_data[['commid','year','month','day','idind','mins_worked','age','male','high_risk','hhsize','sample_wgt']]
chns_new_data.columns = ['commid','year','month','day','ind_id','mins_worked','age','male','high_risk','hhsize','sample_wgt']

chns_new_data.to_csv("/shares/gcp/estimation/labor/time_use_data/intermediate/CHN_CHNS_time_use.csv")
chns_new_data.to_stata("/shares/gcp/estimation/labor/time_use_data/intermediate/CHN_CHNS_time_use.dta")
chns_new_data[['commid']].to_csv("/shares/gcp/estimation/labor/time_use_data/intermediate/CHN_CHNS_time_use_location_names.csv")


#chns_new_data[['commid','year','month','day','idind','interview_year','interview_month','interview_day']].to_csv("/shares/gcp/estimation/labor/time_use_data/intermediate/CHN_CHNS_time_use_interview_dates.csv")

