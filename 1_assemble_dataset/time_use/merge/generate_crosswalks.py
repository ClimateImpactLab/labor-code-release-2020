# generate crosswalks from region identifiers in the climate data to location_id1, location_id2 for each country
# doing so by taking a crosswalk generated by tracing back Trin's cleaning code,
# then read climate data files, take the identifier columns, and match the two (pretty manually for some countries)

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

# we will fill these dictionaries with identifiers in each country's shapefiles and survey, and match them to get crosswalks
adm1_shp_identifiers = {}
adm2_shp_identifiers = {}
time_use_identifiers = {}




# read a csv file (compiled by Emile) that contains the paths to adm1 and adm2 shps
shp_list = pd.read_csv(paths.DIR_REPO_LABOR + "/1_assemble_dataset/weather/gis_config_lines.csv")

countries = shp_list.shp_id.unique()
shps = {}
cw = {}

# read adm1 and adm2 shapefiles for each country
for country in countries:
    shps[country] = {}
    country_shp = shp_list[shp_list.shp_id == country]
    country_adms = country_shp.admin_level.values
    for adm in country_adms:
      country_adm_shp = country_shp[country_shp.admin_level == adm]
      shps[country][adm] = gpd.read_file(country_adm_shp['shapefile_location'].values[0] + "/" + country_adm_shp['shapefile_name'].values[0] + ".shp" )


# CHN crosswalk (DONE)

# find names used in shapefiles, it turns out adm1 shapefile has exactly the same names as adm2, so we don't use it
#adm1_shp_identifiers['CHN'] = shps['CHN']['adm1'][['NAME_1']].drop_duplicates()
adm2_shp_identifiers['CHN'] = shps['CHN']['adm2'][['NAME_1','NAME_2']].drop_duplicates()
### test out chn adm3 shapefile
chn_adm3_shp = gpd.read_file("/shares/gcp/estimation/labor/spatial_data/CHN/gadm36_CHN_3.shp")

adm3_shp_identifiers = {}
adm3_shp_identifiers['CHN'] = chn_adm3_shp[['NAME_1','NAME_2','NAME_3','GID_3']]
adm3_shp_identifiers['CHN'][adm3_shp_identifiers['CHN'].NAME_1 == "Liaoning"]
adm3_shp_identifiers['CHN'][['NAME_1_lower','NAME_2_lower','NAME_3_lower']] = adm3_shp_identifiers['CHN'][['NAME_1','NAME_2','NAME_3']].apply(lambda x: x.str.lower())
# generate columns with lowercase names for easy matching

adm2_shp_identifiers['CHN'][['NAME_1_lower','NAME_2_lower']] = adm2_shp_identifiers['CHN'][['NAME_1','NAME_2']].apply(lambda x: x.str.lower())

# read commid used in time use data, drop duplicates and null values
time_use_identifiers['CHN'] = pd.DataFrame(pd.read_csv(time_use_data_folder + "/intermediate/CHN_CHNS_time_use_location_names.csv")['commid'].drop_duplicates()).dropna(how='all')

# match commid to string names using a lookup table from Vishan
CHNS_commid_lookup = pd.read_excel(paths.DB + "/Global ACP/labor/1_preparation/time_use/china/crosswalks/commid_调查点.xlsx", sheet_name='Sheet')[['Province_en','City_en','District_en','Commid']].dropna(how = "all")
CHNS_commid_lookup.columns = CHNS_commid_lookup.columns.str.lower()

# merge the two above to get commid + string names of those locations
time_use_identifiers['CHN'] = time_use_identifiers['CHN'].merge(CHNS_commid_lookup, on = "commid", how = "inner", indicator = False)
time_use_identifiers['CHN'][['province_en','city_en','district_en']] = time_use_identifiers['CHN'][['province_en','city_en','district_en']].apply(lambda x: x.str.lower())

# manually correct one mismatch
time_use_identifiers['CHN'].replace("qiannan buyi and miao","qiannan buyei and miao", inplace = True)


def clean_adm3_names(x):
    x['NAME_3_lower'] = re.sub(" manchu","",x['NAME_3_lower'])
    x['NAME_3_lower'] = re.sub(" shì"," shi",x['NAME_3_lower'])
    x['NAME_3_lower'] = re.sub(" xiàn"," xian",x['NAME_3_lower'])
    x['NAME_3_lower'] = re.sub(" qū"," qu",x['NAME_3_lower'])
    
    return x

adm3_shp_identifiers['CHN'] = adm3_shp_identifiers['CHN'].apply(lambda x: clean_adm3_names(x),axis = 1)

# merge shapefile identifiers and time use data identifier (commid)
# cw['CHN'] = time_use_identifiers['CHN'].merge(adm2_shp_identifiers['CHN'], 
#                    left_on =['province_en', 'city_en'], 
#                    right_on = ['NAME_1_lower', 'NAME_2_lower'],
#                    how = 'left', indicator = False)

cw['CHN'] = time_use_identifiers['CHN'].merge(adm3_shp_identifiers['CHN'], 
                   left_on =['province_en','district_en'], 
                   right_on = ['NAME_1_lower','NAME_3_lower'],
                   how = 'inner', indicator = False)

cw['CHN'] = cw['CHN'].merge(adm2_shp_identifiers['CHN'], 
                   on =['NAME_1_lower','NAME_2_lower','NAME_1','NAME_2'], 
                   how = 'inner', indicator = False)


#cw['CHN']._merge.value_counts()
#cw['CHN'][cw['CHN'].NAME_1_x != cw['CHN'].NAME_1_y]

#cw['CHN'][cw['CHN']._merge == 'left_only']
#adm3_shp_identifiers['CHN'][adm3_shp_identifiers['CHN'].NAME_1 == "Henan"].NAME_3_lower.unique()
#adm3_shp_identifiers['CHN'][adm3_shp_identifiers['CHN'].NAME_1 == "Hunan"][['NAME_2_lower','NAME_3_lower']]


# all merged

# NOTE: CHN ids are assigned differently because there's adm3
# assign adm1 adm2 ids, the rule is defined here 
# https://paper.dropbox.com/doc/Merging--AwTKcJn9~bmclVfFh1Ii5wvcAg-fVVqw0rteXfuybTElE850
cw['CHN']["adm0_id"] = 20000000 
cw['CHN']["iso"] = 'CHN' 
cw['CHN']["adm1_id"] = 20000000 + cw['CHN']['province_en'].astype('category').cat.codes.astype("int32") * 100000
cw['CHN']["adm2_id"] = cw['CHN']["adm1_id"] + cw['CHN']['city_en'].astype('category').cat.codes.astype("int32") * 100
cw['CHN']["adm3_id"] = cw['CHN']["adm2_id"] + cw['CHN']['district_en'].astype('category').cat.codes.astype("int32")
cw['CHN']["adm1_id_old"] = 20000000 + cw['CHN']['province_en'].astype('category').cat.codes.astype("int32") * 10000

cw['CHN'] = cw['CHN'][['iso','commid','NAME_1','NAME_2', 'NAME_3', 'GID_3', 'adm0_id', 'adm1_id','adm2_id','adm3_id','adm1_id_old']].drop_duplicates()

#cw['CHN'].to_csv("/shares/gcp/estimation/labor/time_use_data/intermediate/shapefile_to_timeuse_crosswalk_CHN.csv")



  
# BRA crosswalk (DONE)

# adm1 names are slightly different
adm1_shp_identifiers['BRA'] = shps['BRA']['adm1'][['NAME_1']].drop_duplicates()
adm2_shp_identifiers['BRA'] = shps['BRA']['adm2'][['NAME_1','NAME_2']].drop_duplicates()


# read the codes used in PME data and their corresponding region names
BRA_metropolitan_region_codes = pd.read_csv(time_use_data_folder + "/raw/BRA_PME/BRA_PME_metropolitan_region_codes.csv")
# manually change one entry for merging
BRA_metropolitan_region_codes.replace("São Paulo","So Paulo", inplace = True)

cw['BRA'] = BRA_metropolitan_region_codes.merge(adm2_shp_identifiers['BRA'], 
  left_on = 'metropolitan_region_name', right_on = 'NAME_2', 
  how = "inner", indicator = False)
# one value in the codes is not matched, but it wasn't in the time use data to begin with so we're ok

# change the name we manually changed back for correct reference
cw['BRA'].loc[cw['BRA'].metropolitan_region_name == 'So Paulo', 'NAME_1'] = "São Paulo"

cw['BRA'] = cw['BRA'].merge(adm1_shp_identifiers['BRA'], 
  left_on = 'NAME_1', right_on = 'NAME_1', 
  how = "inner", indicator = True)

cw['BRA']['NAME_1_adm1'] = cw['BRA']['NAME_1'] 
cw['BRA']['NAME_1_adm2'] = cw['BRA']['NAME_1'] 
cw['BRA'].loc[cw['BRA'].metropolitan_region_name == 'So Paulo', 'NAME_1_adm2'] = "So Paulo"

# assign adm1 adm2 ids
cw['BRA']["iso"] = 'BRA' 
cw['BRA']["adm0_id"] = 10000000
cw['BRA']["adm1_id"] = 10000000 + cw['BRA']['NAME_1'].astype('category').cat.codes.astype("int32") * 10000
cw['BRA']["adm2_id"] = cw['BRA']["adm1_id"] + cw['BRA']['NAME_2'].astype('category').cat.codes
cw['BRA'] = cw['BRA'][['iso','metropolitan_region_code','metropolitan_region_name','NAME_1_adm1','NAME_1_adm2','NAME_2','adm0_id','adm1_id','adm2_id']].drop_duplicates()




# IND crosswalk (DONE)

adm1_shp_identifiers['IND'] = shps['IND']['adm1'][['NAME_1']].drop_duplicates()
adm2_shp_identifiers['IND'] = shps['IND']['adm2'][['DIST91_ID','STATE_UT','NAME']].drop_duplicates().dropna(how='any')
time_use_identifiers['IND'] = pd.DataFrame(pd.read_csv(time_use_data_folder + "/intermediate/IND_ITUS_time_use_location_names.csv")[['st_name', 'district_name']].drop_duplicates()).dropna(how='all')

# a function that creates a new column for merging based on the old column
def add_col(x, col_new, col_old):
    x[col_new] = re.sub('[\W_]+', '', x[col_old].lower().replace("_", " "))
    return x

# create some new columns that are lower case and stripped of special characters for merging
adm2_shp_identifiers['IND'] = adm2_shp_identifiers['IND'].apply(lambda row: add_col(row, 'adm2_merge', 'NAME',), axis = 1)
adm2_shp_identifiers['IND'] = adm2_shp_identifiers['IND'].apply(lambda row: add_col(row, 'adm1_merge', 'STATE_UT',), axis = 1)
adm1_shp_identifiers['IND'] = adm1_shp_identifiers['IND'].apply(lambda row: add_col(row, 'adm1_merge', 'NAME_1',), axis = 1)
time_use_identifiers['IND'] = time_use_identifiers['IND'].apply(lambda row: add_col(row, 'adm2_merge', 'district_name',), axis = 1)
time_use_identifiers['IND'] = time_use_identifiers['IND'].apply(lambda row: add_col(row, 'adm1_merge', 'st_name',), axis = 1)


# merge on those columns and save (all merged)
cw['IND'] = time_use_identifiers['IND'].merge(adm1_shp_identifiers['IND'],
                  on = ["adm1_merge"], 
                  how = "left", indicator = False)

cw['IND'] = cw['IND'].merge(adm2_shp_identifiers['IND'],
                  on = ["adm1_merge","adm2_merge"], 
                  how = "left", indicator = False)

# assign adm1 adm2 ids
cw['IND']["iso"] = 'IND' 
cw['IND']["adm0_id"] = 60000000
cw['IND']["adm1_id"] = 60000000 + cw['IND']['adm1_merge'].astype('category').cat.codes.astype("int32") * 10000
cw['IND']["adm2_id"] = cw['IND']["adm1_id"] + cw['IND']['adm2_merge'].astype('category').cat.codes

cw['IND'] = cw['IND'][['iso','adm0_id', 'adm1_id','adm2_id','st_name','district_name','NAME_1','STATE_UT','NAME','DIST91_ID']].drop_duplicates()




# USA crosswalk (done) 

adm1_shp_identifiers['USA'] = shps['USA']['adm1']['NAME_1'].drop_duplicates()
# adm1 names are the same as adm1names in adm2 shapefile, so we don't use the one above at all

us_state_abbrev = {
    'AL': 'Alabama',
    'AK': 'Alaska',
    'AZ': 'Arizona',
    'AR': 'Arkansas',
    'CA': 'California',
    'CO': 'Colorado',
    'CT': 'Connecticut',
    'DE': 'Delaware',
    'FL': 'Florida',
    'GA': 'Georgia',
    'HI': 'Hawaii',
    'ID': 'Idaho',
    'IL': 'Illinois',
    'IN': 'Indiana',
    'IA': 'Iowa',
    'KS': 'Kansas',
    'KY': 'Kentucky',
    'LA': 'Louisiana',
    'ME': 'Maine',
    'MD': 'Maryland',
    'MA': 'Massachusetts',
    'MI': 'Michigan',
    'MN': 'Minnesota',
    'MS': 'Mississippi',
    'MO': 'Missouri',
    'MT': 'Montana',
    'NE': 'Nebraska',
    'NV': 'Nevada',
    'NH': 'New Hampshire',
    'NJ': 'New Jersey',
    'NM': 'New Mexico',
    'NY': 'New York',
    'NC': 'North Carolina',
    'ND': 'North Dakota',
    'OH': 'Ohio',
    'OK': 'Oklahoma',
    'OR': 'Oregon',
    'PA': 'Pennsylvania',
    'RI': 'Rhode Island',
    'SC': 'South Carolina',
    'SD': 'South Dakota',
    'TN': 'Tennessee',
    'TX': 'Texas',
    'UT': 'Utah',
    'VT': 'Vermont',
    'VA': 'Virginia',
    'WA': 'Washington',
    'WV': 'West Virginia',
    'WI': 'Wisconsin',
    'WY': 'Wyoming',
    'DC': 'District of Columbia'
}

# a regex to filter strings and keep only letters
regex_alphabet = re.compile('[^a-zA-Z]')

# generate a column in timeuse data for merging
def clean_timeuse_names(x):
  x['county_name_merge'] = regex_alphabet.sub("",x['master_county_name'].lower())
  x['state_name_merge'] = regex_alphabet.sub("", x['state_name'].lower())
  # get rid of the "county" "city" "parish" at the end of the county names
  if x['county_name_merge'].endswith("county"): 
    x['county_name_merge'] = re.sub("county","", x['county_name_merge'])
  else:
    state_name = x['state_name_merge']
    x['county_name_merge'] = re.sub(state_name, "", x['county_name_merge'], count = 1)
  if x['county_name_merge'].endswith("city"):
    x['county_name_merge'] = re.sub("city","", x['county_name_merge'])
  if x['county_name_merge'].endswith("parish"):
    x['county_name_merge'] = re.sub("parish","", x['county_name_merge'])
  return x

# clean the names in the shapefile
def clean_shp_names(x):
    x['county_name_merge'] = regex_alphabet.sub("",x['NAME_2'].lower())
    x['state_name_merge'] = regex_alphabet.sub("", x['NAME_1'].lower())
    # if name starts with saint, change to st
    if x['county_name_merge'].startswith("saint"):
      x['county_name_merge'] = re.sub("saint","st", x['county_name_merge'])
    return x


adm2_shp_identifiers['USA'] = shps['USA']['adm2'][['NAME_1','NAME_2']].drop_duplicates()
time_use_identifiers['USA'] = pd.DataFrame(pd.read_csv(time_use_data_folder + "/intermediate/USA_ATUS_time_use_location_names.csv")[['state', 'master_county_name']].drop_duplicates()).dropna(how='all')

# convert abbrevations to full names
time_use_identifiers['USA']['state_name'] = time_use_identifiers['USA']['state'].map(us_state_abbrev)

# apply the two cleaning functions defined above
time_use_identifiers['USA'] = time_use_identifiers['USA'].apply(lambda row: clean_timeuse_names(row), axis = 1)
adm2_shp_identifiers['USA'] = adm2_shp_identifiers['USA'].apply(lambda row: clean_shp_names(row), axis = 1)

# manually correct a few entries
time_use_identifiers['USA']['county_name_merge'].replace("","districtofcolumbia", inplace = True)
time_use_identifiers['USA']['county_name_merge'].replace("saintlucie","stlucie", inplace = True)
time_use_identifiers['USA']['county_name_merge'].replace("anchorageborough","anchorage", inplace = True)
time_use_identifiers['USA']['county_name_merge'].replace("saintlouis","stlouis", inplace = True)
time_use_identifiers['USA']['county_name_merge'].replace("beach","virginiabeach", inplace = True)

# merge and assign ids
cw['USA'] = time_use_identifiers['USA'].merge(adm2_shp_identifiers['USA'],
                            on = ['state_name_merge', 'county_name_merge'],
                            how = "inner",
                            indicator = False)

cw['USA']["adm0_id"] = 80000000
cw['USA']["iso"] = 'USA' 
cw['USA']["adm1_id"] = 80000000 + cw['USA']['state_name_merge'].astype('category').cat.codes.astype("int32") * 10000
cw['USA']["adm2_id"] = cw['USA']["adm1_id"] + cw['USA']['county_name_merge'].astype('category').cat.codes

cw['USA'] = cw['USA'][['iso','adm0_id', 'adm1_id','adm2_id','state','master_county_name','NAME_1','NAME_2']].drop_duplicates()



# MEX crosswalk (done)

adm1_shp_identifiers['MEX'] = shps['MEX']['adm1'][['NOM_ENT']].drop_duplicates()
adm2_shp_identifiers['MEX'] = shps['MEX']['adm2'][['NOM_ENT','NOM_MUN']].drop_duplicates()
time_use_identifiers['MEX'] = pd.DataFrame(pd.read_csv(time_use_data_folder + "/intermediate/MEX_ENOE_time_use_location_names.csv")[['state_name', 'municipality_name']].drop_duplicates()).dropna(how='all')

# manually correct a few entries
adm1_shp_identifiers['MEX']['NOM_ENT_merge'] = adm1_shp_identifiers['MEX']['NOM_ENT']
adm1_shp_identifiers['MEX']['NOM_ENT_merge'].replace("Mxico","México", inplace = True)
adm1_shp_identifiers['MEX']['NOM_ENT_merge'].replace("Michoacn de Ocampo","Michoacán de Ocampo", inplace = True)
adm1_shp_identifiers['MEX']['NOM_ENT_merge'].replace("Quertaro","Querétaro", inplace = True)
adm1_shp_identifiers['MEX']['NOM_ENT_merge'].replace("San Luis Potos","San Luis Potosí", inplace = True)
adm1_shp_identifiers['MEX']['NOM_ENT_merge'].replace("Nuevo Len","Nuevo León", inplace = True)
adm1_shp_identifiers['MEX']['NOM_ENT_merge'].replace("Yucatn","Yucatán", inplace = True)

cw['MEX'] = time_use_identifiers['MEX'].merge(adm1_shp_identifiers['MEX'], 
                              left_on = ["state_name"], 
                              right_on = ["NOM_ENT_merge"],
                              how = "inner",
                              indicator = False)
# all merged


cw['MEX'] = cw['MEX'].merge(adm2_shp_identifiers['MEX'], 
                              left_on = ["NOM_ENT_merge", "municipality_name"], 
                              right_on = ["NOM_ENT","NOM_MUN"],
                              how = "inner",
                              indicator = False)

# all both or left-only, which is what we want
# in adm1 shapefile, the column NOM_ENT doesn't have accents, but in adm2 shapefile the column NOM_ENT has
# we take the column with the accents

cw['MEX']["NOM_ENT_adm1"] = cw['MEX']['NOM_ENT_x']
cw['MEX']["NOM_ENT_adm2"] = cw['MEX']['NOM_ENT_y']

cw['MEX']["iso"] = "MEX"
cw['MEX']["adm0_id"] = 70000000
cw['MEX']["adm1_id"] = 70000000 + (cw['MEX']['state_name'].astype('category').cat.codes.astype("int32")) * 10000

cw['MEX']["adm2_id"] = cw['MEX']["adm1_id"] + cw['MEX']['municipality_name'].astype('category').cat.codes
cw['MEX'] = cw['MEX'][['iso','adm0_id', 'adm1_id','adm2_id','state_name','municipality_name','NOM_ENT_adm1','NOM_ENT_adm2','NOM_MUN']].drop_duplicates()


# WEU crosswalk (done)

adm1_shp_identifiers['FRA'] = shps['FRA']['adm1'][['NAME_1']].drop_duplicates()
adm1_shp_identifiers['ESP'] = shps['ESP']['adm1'][['NAME_1']].drop_duplicates()
adm1_shp_identifiers['GBR'] = shps['GBR']['adm1'][['ADMIN_NAME']].drop_duplicates()

time_use_identifiers['FRA'] = pd.DataFrame(pd.read_csv("/shares/gcp/estimation/labor/time_use_data/raw/WEU_MTUS/MUTS_region_codec_FRA.csv")[['region_name', 'region_code']])
time_use_identifiers['ESP'] = pd.DataFrame(pd.read_csv("/shares/gcp/estimation/labor/time_use_data/raw/WEU_MTUS/MUTS_region_codec_ESP.csv")[['region_name', 'region_code']])
time_use_identifiers['GBR'] = pd.DataFrame(pd.read_csv("/shares/gcp/estimation/labor/time_use_data/raw/WEU_MTUS/MUTS_region_codec_GBR.csv")[['region_name', 'region_code']])

# ESP 
# create a dictionary to manually transform shapefile entries
shp_to_region_dic_ESP = {"Andalucía":"Andalucia",
              "Aragón":"Aragon",
              "Cantabria":"Cantabria",
              "Castilla-La Mancha":"Castilla la Mancha",
              "Castilla y León":"Castilla y Leon",
              "Cataluña":"Catalonia",
              "Ceuta y Melilla":"Ceuta y Melilla",
              "Comunidad de Madrid":"Madrid (Comunidad de)",
              "Comunidad Foral de Navarra":"Navarra (Comunidad Foral de)",
              "Comunidad Valenciana":"Comunidad Valencia",
              "Extremadura":"Extremadura",
              "Galicia":"Galicia",
              "Islas Baleares":"Balears (Illes)",
              "Islas Canarias":"Canarias",
              "La Rioja":"Rioja (la)",
              "País Vasco":"Pais Vasco",
               "Principado de Asturias":"Asturias (Principado de)",
               "Región de Murcia":"Murcia (Region de)"
              }

cw['ESP'] = adm1_shp_identifiers['ESP']
cw['ESP']['region_name'] = cw['ESP']['NAME_1'].map(shp_to_region_dic_ESP)
cw['ESP'] = cw['ESP'].merge(time_use_identifiers['ESP'], on = 'region_name')

cw['ESP']["adm0_id"] = 30000000
cw['ESP']["iso"] = 'ESP' 
cw['ESP']["adm1_id"] = 30000000 + cw['ESP']['NAME_1'].astype('category').cat.codes.astype("int32") * 10000
cw['ESP']["adm2_id"] = cw['ESP']["adm1_id"] + 1
cw['ESP'] = cw['ESP'][['iso','adm0_id', 'adm1_id','adm2_id','region_name','region_code','NAME_1']].drop_duplicates()


# GBR

shp_to_region_code_dic_GBR = {"North West":"north",
               "North East":"North of England",
               "Yorkshire and the Humber":"North of England",
               "West Midlands":"English Midlands",
               "East Midlands":"English Midlands",
               "East of England":"East of England",
               "Northern Ireland":"Northern Ireland",
               "Scotland":"Scotland",
               "South East and London":"London and South East",
               "South West":"South West of England",
                "Wales":"Wales"
               }

# since the regions in the shapefile and the survey are not one-to-one, we assign some weights
# according to the population of the regions
# this weight is used in the code that transforms climate data using crosswalks
weight_dic_GBR = {"North West":0.474,
               "North East":0.178,
               "Yorkshire and the Humber":0.348,
               "West Midlands":0.442,
               "East Midlands":0.558,
               "East of England":1,
               "Northern Ireland":1,
               "Scotland":1,
               "South East and London":1,
               "South West":1,
                "Wales":1
                }
                
cw['GBR'] = adm1_shp_identifiers['GBR']
cw['GBR']['region_name'] = cw['GBR']['ADMIN_NAME'].map(shp_to_region_code_dic_GBR)
cw['GBR']['weight'] = cw['GBR']['ADMIN_NAME'].map(weight_dic_GBR)

cw['GBR'] = cw['GBR'].merge(time_use_identifiers['GBR'], on = 'region_name')
cw['GBR']["adm0_id"] = 50000000
cw['GBR']["iso"] = 'GBR' 
cw['GBR']["adm1_id"] = 50000000 + cw['GBR']['ADMIN_NAME'].astype('category').cat.codes.astype("int32") * 10000
cw['GBR']["adm2_id"] = cw['GBR']["adm1_id"] + 1
cw['GBR'] = cw['GBR'][['iso','adm0_id', 'adm1_id','adm2_id','region_name','region_code','ADMIN_NAME','weight']].drop_duplicates()


# FRA
cw['FRA'] = adm1_shp_identifiers['FRA']
cw['FRA']['region_name'] = cw['FRA']['NAME_1']
cw['FRA']['region_name'].replace("Île-de-France","Ile De France", inplace = True)
cw['FRA']['region_name'].replace("Poitou-Charentes","Poitou-Charente", inplace = True)
cw['FRA']['region_name'].replace("Champagne-Ardenne","Champagne-Ardennes", inplace = True)
cw['FRA']['region_name'].replace("Nord-Pas-de-Calais","Nord-Pas-De-Calais", inplace = True)

cw['FRA'] = cw['FRA'].merge(time_use_identifiers['FRA'], on = 'region_name', how = "inner")
cw['FRA']["adm0_id"] = 40000000 
cw['FRA']["iso"] = 'FRA' 
cw['FRA']["adm1_id"] = 40000000 + cw['FRA']['NAME_1'].astype('category').cat.codes.astype("int32") * 10000
cw['FRA']["adm2_id"] = cw['FRA']["adm1_id"] + 1
cw['FRA'] = cw['FRA'][['iso','adm0_id', 'adm1_id','adm2_id','region_name','region_code','NAME_1']].drop_duplicates()

for country in countries: 
    cw[country].to_csv("/shares/gcp/estimation/labor/time_use_data/intermediate/shapefile_to_timeuse_crosswalk_" + country +".csv")
    #cw[country].to_stata("/shares/gcp/estimation/labor/time_use_data/intermediate/shapefile_to_timeuse_crosswalk_" + country +".dta")

