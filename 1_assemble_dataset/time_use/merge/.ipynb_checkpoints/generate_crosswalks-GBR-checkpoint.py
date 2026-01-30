import sys
sys.path.insert(0, '/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/0_subroutines')
import paths

import pandas as pd
import re
import geopandas as gpd

pd.set_option('display.max_columns', None)
pd.set_option('display.max_rows', None)
pd.set_option('display.max_colwidth', None)

time_use_data_folder = paths.ROOT_INT_DATA + "/surveys/cleaned_country_data/"

# dictionaries to store identifiers and crosswalks
adm1_shp_identifiers = {}
time_use_identifiers = {}
shps = {}
cw = {}

# 1. Read shapefile path list and keep only GBR
shp_list = pd.read_csv(
    paths.DIR_REPO_LABOR + "/1_assemble_dataset/time_use/weather/gis_config_lines.csv"
)

# only keep GBR rows
shp_list_gbr = shp_list[shp_list.shp_id == "GBR"]

# 2. Read shapefiles for GBR (only adm1 is used later)
shps["GBR"] = {}
country_shp = shp_list_gbr
country_adms = country_shp.admin_level.values

for adm in country_adms:
    country_adm_shp = country_shp[country_shp.admin_level == adm]
    shp_path = (
        country_adm_shp["shapefile_location"].values[0]
        + "/"
        + country_adm_shp["shapefile_name"].values[0]
        + ".shp"
    )
    shps["GBR"][adm] = gpd.read_file(shp_path)

# 3. WEU – GBR crosswalk

# adm1 identifiers from shapefile
adm1_shp_identifiers["GBR"] = shps["GBR"]["adm1"][["ADMIN_NAME"]].drop_duplicates()

# read MTUS region codes for GBR
time_use_identifiers["GBR"] = pd.DataFrame(
    pd.read_csv(
        paths.ROOT_INT_DATA + "/surveys/WEU_MTUS/MUTS_region_codec_GBR.csv"
    )[["region_name", "region_code"]]
)

# mapping from shapefile ADM1 names to survey region_name
shp_to_region_code_dic_GBR = {
    "North West": "North of England",
    "North East": "North of England",
    "Yorkshire and the Humber": "North of England",
    "West Midlands": "English Midlands",
    "East Midlands": "English Midlands",
    "East of England": "East of England",
    "Northern Ireland": "Northern Ireland",
    "Scotland": "Scotland",
    "South East and London": "London and South East",
    "South West": "South West of England",
    "Wales": "Wales",
}

# weights for splitting non–one-to-one regions
weight_dic_GBR = {
    "North West": 0.474,
    "North East": 0.178,
    "Yorkshire and the Humber": 0.348,
    "West Midlands": 0.442,
    "East Midlands": 0.558,
    "East of England": 1,
    "Northern Ireland": 1,
    "Scotland": 1,
    "South East and London": 1,
    "South West": 1,
    "Wales": 1,
}

# build crosswalk for GBR
cw["GBR"] = adm1_shp_identifiers["GBR"].copy()
cw["GBR"]["region_name"] = cw["GBR"]["ADMIN_NAME"].map(shp_to_region_code_dic_GBR)
cw["GBR"]["weight"] = cw["GBR"]["ADMIN_NAME"].map(weight_dic_GBR)

cw["GBR"] = cw["GBR"].merge(
    time_use_identifiers["GBR"], on="region_name"
)

cw["GBR"]["adm0_id"] = 50000000
cw["GBR"]["iso"] = "GBR"
cw["GBR"]["adm1_id"] = (
    50000000
    + cw["GBR"]["ADMIN_NAME"].astype("category").cat.codes.astype("int32") * 10000
)
cw["GBR"]["adm2_id"] = cw["GBR"]["adm1_id"] + 1
cw["GBR"]["adm3_id"] = cw["GBR"]["adm2_id"]

cw["GBR"] = cw["GBR"][
    ["iso", "adm0_id", "adm1_id", "adm2_id", "adm3_id",
     "region_name", "region_code", "ADMIN_NAME", "weight"]
].drop_duplicates()

# 4. Save GBR crosswalk
cw["GBR"].to_csv(
    paths.ROOT_INT_DATA + "/crosswalks/shapefile_to_timeuse_crosswalk_GBR_new.csv",
    index=False,
)
cw["GBR"].to_stata(
    paths.ROOT_INT_DATA + "/crosswalks/shapefile_to_timeuse_crosswalk_GBR_new.dta",
    write_index=False,
)
