# this file takes the cleaned survey data and match the region names to admin ids using crosswalks

import sys
sys.path.append('/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/0_subroutines/')
import paths
import pandas as pd
import re
import geopandas as gpd
from pandas import ExcelFile

pd.set_option('display.max_columns', 1000)
pd.set_option('display.max_rows', 1000)
pd.set_option('display.max_colwidth', 199)

time_use_data_folder = paths.ROOT_INT_DATA + "/surveys/cleaned_country_data/"

# --------------------------------------------------
# Read crosswalk config
# --------------------------------------------------

shp_list = pd.read_csv(paths.DIR_REPO_LABOR + "/1_assemble_dataset/time_use/weather/gis_config_lines.csv")
countries = shp_list.shp_id.unique()

cw = {}
for country in ['USA','FRA','GBR','ESP','MEX','BRA','IND']:
    print(country)
    cw[country] = pd.read_csv(
        paths.ROOT_INT_DATA + "/crosswalks/shapefile_to_timeuse_crosswalk_" + country + ".csv"
    )

# --------------------------------------------------
# Read cleaned surveys
# --------------------------------------------------

survey_names = [
    'USA_ATUS','BRA_PME','GBR_MTUS',
    'ESP_MTUS','FRA_MTUS','IND_ITUS','MEX_ENOE'
]

surveys = {}
for s in survey_names:
    surveys[s] = pd.read_csv(time_use_data_folder + s + "_time_use.csv")

# --------------------------------------------------
# Columns we want to keep
# --------------------------------------------------

columns_wanted = [
    'iso','adm0_id','adm1_id','adm2_id','adm3_id',
    'ind_id','year','month','day',
    'mins_worked','mins_agwork',
    'age','hhsize','high_risk',
    'self_emp','male','sample_wgt'
]

# --------------------------------------------------
# Helper: ensure mins_agwork exists
# --------------------------------------------------

def ensure_agwork(df):
    if "mins_agwork" not in df.columns:
        df["mins_agwork"] = df["mins_worked"]
    return df

# --------------------------------------------------
# ★ NEW: 对非印度国家，high_risk=1 时 mins_agwork = mins_worked
# --------------------------------------------------

def apply_highrisk_agwork(df, is_india=False):
    """
    对非印度国家：若 high_risk == 1，则 mins_agwork 覆盖为 mins_worked。
    印度保留原始的 mins_agwork 不变。
    """
    if not is_india:
        df.loc[df['high_risk'] == 1, 'mins_agwork'] = df.loc[df['high_risk'] == 1, 'mins_worked']
        df.loc[df['high_risk'] == 0, 'mins_agwork'] = None
    return df

# --------------------------------------------------
# Helper: merge + standardize
# --------------------------------------------------

def merge_and_standardize(df, merge_kwargs, is_india=False):  # ★ 新增 is_india 参数
    df = df.merge(**merge_kwargs)
    df = ensure_agwork(df)
    df = apply_highrisk_agwork(df, is_india=is_india)          # ★ 新增调用
    return df[columns_wanted]

# --------------------------------------------------
# Merge each country
# --------------------------------------------------

surveys['ESP_MTUS'] = merge_and_standardize(
    surveys['ESP_MTUS'],
    dict(right=cw['ESP'], on='region_code', how="inner")
)

surveys['FRA_MTUS'] = merge_and_standardize(
    surveys['FRA_MTUS'],
    dict(right=cw['FRA'], on='region_code', how="inner")
)

surveys['GBR_MTUS'] = merge_and_standardize(
    surveys['GBR_MTUS'],
    dict(right=cw['GBR'], on='region_code', how="inner")
)

surveys['USA_ATUS'] = merge_and_standardize(
    surveys['USA_ATUS'],
    dict(right=cw['USA'], on=['state','master_county_name'], how="inner")
)

surveys['IND_ITUS'] = merge_and_standardize(
    surveys['IND_ITUS'],
    dict(right=cw['IND'], on=['district_name','st_name'], how="inner"),
    is_india=True                                               # ★ 印度跳过覆盖逻辑
)

surveys['BRA_PME'] = merge_and_standardize(
    surveys['BRA_PME'],
    dict(right=cw['BRA'],
         left_on=['metropolitan_region'],
         right_on='metropolitan_region_code',
         how="inner")
)

surveys['MEX_ENOE'] = merge_and_standardize(
    surveys['MEX_ENOE'],
    dict(right=cw['MEX'],
         on=['state_name','municipality_name'],
         how="inner")
)

# --------------------------------------------------
# Combine all surveys
# --------------------------------------------------

all_surveys = pd.DataFrame()

for s in [
    'USA_ATUS','GBR_MTUS','ESP_MTUS',
    'FRA_MTUS','BRA_PME','IND_ITUS','MEX_ENOE'
]:
    print(s)
    all_surveys = pd.concat([all_surveys, surveys[s]], axis=0)

# --------------------------------------------------
# Save final combined file
# --------------------------------------------------

all_surveys.to_csv(
    paths.ROOT_INT_DATA + "/temp/all_time_use.csv",
    index=False
)

print("✓ all_time_use.csv successfully created with mins_agwork")