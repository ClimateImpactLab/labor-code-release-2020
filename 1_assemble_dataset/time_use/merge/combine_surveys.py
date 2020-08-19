# this file takes the cleaned survey data and match the region names to admin ids using crosswalks

import sys
sys.path.insert(0, '/home/liruixue/repos/labor-code-release-2020/0_subroutines') 
import paths
import pandas as pd
import re
import cilpath
import geopandas as gpd
from pandas import ExcelFile

pd.set_option('display.max_columns', None)  # or 1000
pd.set_option('display.max_rows', None)  # or 1000
pd.set_option('display.max_colwidth', -1)  # or 199

time_use_data_folder = paths.ROOT_INT_DATA + "/surveys/cleaned_country_data/"

adm1_shp_identifiers = {}
adm2_shp_identifiers = {}
time_use_identifiers = {}

# read a csv file that contains the paths to adm1 and adm2 shps
shp_list = pd.read_csv(paths.DIR_REPO_LABOR + "/1_assemble_dataset/time_use/weather/gis_config_lines.csv")

#shp_list = pd.read_csv("/shares/gcp/estimation/labor/climate_data/config/gis_config_lines.csv")
countries = shp_list.shp_id.unique()
cw = {}

# for country in countries: 
for country in ['USA','MEX','BRA','FRA','GBR','ESP','IND']:
    print(country)
    cw[country] = pd.read_csv(paths.ROOT_INT_DATA + "/crosswalks/shapefile_to_timeuse_crosswalk_" + country +".csv")

# survey_names = ['USA_ATUS','CHN_CHNS','BRA_PME','GBR_MTUS','ESP_MTUS','FRA_MTUS','IND_ITUS','MEX_ENOE']
survey_names = ['USA_ATUS','BRA_PME','GBR_MTUS','ESP_MTUS','FRA_MTUS' ,'IND_ITUS','MEX_ENOE']
surveys = {}
for s in survey_names:
  surveys[s] = pd.read_csv(time_use_data_folder + s + "_time_use.csv")

columns_wanted = ['iso','adm0_id','adm1_id','adm2_id','adm3_id','ind_id','year','month','day','mins_worked','age','hhsize','high_risk','male','sample_wgt']

surveys['ESP_MTUS'] = surveys['ESP_MTUS'].merge(
  cw['ESP'],
  on = 'region_code',
  how = "inner",
  indicator = False )[columns_wanted] 


surveys['FRA_MTUS'] = surveys['FRA_MTUS'].merge(
  cw['FRA'],
  on = 'region_code',
  how = "inner",
  indicator = False )[columns_wanted] 

surveys['GBR_MTUS'] = surveys['GBR_MTUS'].merge(
  cw['GBR'],
  on = 'region_code',
  how = "inner",
  indicator = False )[columns_wanted] 


surveys['USA_ATUS'] = surveys['USA_ATUS'].merge(
  cw['USA'],
  on = ['state','master_county_name'],
  how = "inner",
  indicator = False )[columns_wanted] 


surveys['CHN_CHNS'] = surveys['CHN_CHNS'].merge(
  cw['CHN'],
  on = ['commid'],
  how = "inner",
  indicator = False )[columns_wanted] 

surveys['IND_ITUS'] = surveys['IND_ITUS'].merge(
  cw['IND'],
  on = ['district_name','st_name'],
  how = "inner",
  indicator = False )[columns_wanted] 


surveys['BRA_PME'] = surveys['BRA_PME'].merge(
  cw['BRA'],
  left_on = ['metropolitan_region'],
  right_on = 'metropolitan_region_code',
  how = "inner",
  indicator = False )[columns_wanted] 

surveys['MEX_ENOE'] = surveys['MEX_ENOE'].merge(
  cw['MEX'],
  on = ['state_name','municipality_name'],
  how = "inner",
  indicator = False )[columns_wanted] 

all_surveys = pd.DataFrame()
# for s in ['USA_ATUS','CHN_CHNS','BRA_PME','GBR_MTUS','ESP_MTUS','FRA_MTUS','IND_ITUS','MEX_ENOE']:
for s in ['USA_ATUS','BRA_PME','GBR_MTUS','ESP_MTUS','FRA_MTUS','IND_ITUS','MEX_ENOE']:
  print(s)
  all_surveys = pd.concat([all_surveys,surveys[s]], axis = 0)


all_surveys.to_csv(paths.ROOT_INT_DATA + "/temp/all_time_use.csv", index = False)

