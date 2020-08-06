


from labor-code-release-2020.0_subroutimes import setup_paths_python

import pandas
import os
import sys

os.chdir(paths.REPO + "/gcp-labor/1_preparation/weather")




lines = pandas.read_csv(r"aggregation_config_lines.csv", skipinitialspace=True)

daily = pandas.read_csv(r"parameters_transforms_collapse_daily.csv", skipinitialspace=True)

yearly = pandas.read_csv(r"parameters_transforms_collapse_yearly.csv", skipinitialspace=True)


for i in range(0, len(lines),1):
	os.chdir("/shares/gcp/estimation/labor/climate_data/config/")
	country = lines.loc[i]["country"]
	if os.path.isdir(country)==False:
		os.mkdir(country)
	os.chdir(country)
	collapse_to = lines.loc[i]["collapse_to"]
	admin_level = lines.loc[i]["admin_level"]
	collapse_to = collapse_to.strip()
	input_file = lines.loc[i]["input_file"]
	input_file = input_file.strip()
	output_dir = "/shares/gcp/estimation/labor/climate_data/raw/" + country + "/" + admin_level
	region_columns = lines.loc[i]["region_columns"]
	region_columns = region_columns.strip()
	weight_columns = lines.loc[i]["weight_columns"]
	weight_columns = weight_columns.strip()
	climate_source = lines.loc[i]["climate_source"]
	climate_source = climate_source.strip()
	first_year = str(lines.loc[i]["start_year"])
	last_year = str(lines.loc[i]["last_year"])
	if collapse_to=="day":
		for j in range(0, len(daily), 1):
			parameters = daily.loc[j]["parameters"]
			transforms = daily.loc[j]["transforms"]
			collapse_as = daily.loc[j]["collapse_as"]
			prefix_config = daily.loc[j]["prefix_config"]
			name_config = prefix_config +  "_aggregation_daily_" + country + "_" + climate_source + "_" + admin_level + ".txt"
			file = open(name_config, "w")
			file.write("{")
			file.write("\n")
			file.write("'run_location': 'sacagawea',")
			file.write("\n")
			file.write("'input_file': '" + input_file + "',")
			file.write("\n")
			file.write("'output_dir': '" + output_dir + "',")
			file.write("\n")
			file.write("'region_columns': [" + region_columns + "],")
			file.write("\n")
			file.write("'group_by_column': None,")
			file.write("\n")
			file.write("'weight_columns': ['" + weight_columns + "'],")
			file.write("\n")
			file.write("'climate_source': ['" + climate_source + "'],")
			file.write("\n")
			file.write("'parameters': ['" + parameters + "'],")
			file.write("\n")
			file.write("'transforms': {" + transforms + "},")
			file.write("\n")
			file.write("'collapse_to': '" + collapse_to + "',")
			file.write("\n")
			file.write("'collapse_as': '" + collapse_as + "',")
			file.write("\n")
			file.write("'first_year': " + first_year + ",")
			file.write("\n")
			file.write("'last_year': " + last_year + "")
			file.write("\n")
			file.write("}")
			file.close()
	elif collapse_to.strip()=="year":
		for j in range(0, len(yearly), 1):
			parameters = yearly.loc[j]["parameters"]
			transforms = yearly.loc[j]["transforms"]
			collapse_as = yearly.loc[j]["collapse_as"]
			prefix_config = yearly.loc[j]["prefix_config"]
			name_config = prefix_config +  "_aggregation_yearly_" + country + "_" + climate_source + "_" + admin_level + ".txt"
			file = open(name_config, "w")
			file.write("{")
			file.write("\n")
			file.write("'run_location': 'sacagawea',")
			file.write("\n")
			file.write("'input_file': '" + input_file + "',")
			file.write("\n")
			file.write("'output_dir': '" + output_dir + "',")
			file.write("\n")
			file.write("'region_columns': [" + region_columns + "],")
			file.write("\n")
			file.write("'group_by_column': None,")
			file.write("\n")
			file.write("'weight_columns': ['" + weight_columns + "'],")
			file.write("\n")
			file.write("'climate_source': ['" + climate_source + "'],")
			file.write("\n")
			file.write("'parameters': ['" + parameters + "'],")
			file.write("\n")
			file.write("'transforms': {" + transforms + "},")
			file.write("\n")
			file.write("'collapse_to': '" + collapse_to + "',")
			file.write("\n")
			file.write("'collapse_as': '" + collapse_as + "',")
			file.write("\n")
			file.write("'first_year': " + first_year + ",")
			file.write("\n")
			file.write("'last_year': " + last_year + "")
			file.write("\n")
			file.write("}")
			file.close()









os.chdir(paths.REPO + "/gcp-labor/1_preparation/weather")
lines = pandas.read_csv("gis_config_lines.csv")





for i in range(0, len(lines),1):
	os.chdir("/shares/gcp/estimation/labor/climate_data/config/")
	country = lines.loc[i]["country"]
	if os.path.isdir(country)==False:
		os.mkdir(country)
	os.chdir(country)
	clim = lines.loc[i]["clim"]
	clim = clim.strip()
	shapefile_location = lines.loc[i]["shapefile_location"]
	shapefile_location = shapefile_location.strip() 
	shapefile_name = lines.loc[i]["shapefile_name"]
	shapefile_name = shapefile_name.strip() 
	country = lines.loc[i]["country"]
	country = country.strip() 
	string_id_fields = lines.loc[i]["string_id_fields"]
	string_id_fields = string_id_fields.strip()
	weightlist = lines.loc[i]["weightlist"]
	weightlist = weightlist.strip()
	admin_level = lines.loc[i]["admin_level"]
	admin_level = admin_level.strip()
	name_config = "gis_" + country + "_" + clim + "_" + admin_level + ".txt"
	file = open(name_config, "w")
	file.write("{")
	file.write("\n")
	file.write("'run_location': 'sacagawea',")
	file.write("\n")
	file.write("'n_jobs': 12,")
	file.write("\n")
	file.write("'verbose': 2,")
	file.write("\n")
	file.write("'clim': '" + clim + "',")
	file.write("\n")
	file.write("'shapefile_location': '" + shapefile_location + "',")
	file.write("\n")
	file.write("'shapefile_name': '" + shapefile_name + "',")
	file.write("\n")
	file.write("'shp_id': '" + country + "',")
	file.write("\n")
	file.write("'numeric_id_fields': [],")
	file.write("\n")
	file.write("'string_id_fields': [" + string_id_fields + "],")
	file.write("\n")
	file.write("'weightlist': ['" + weightlist + "'],")
	file.write("\n")
	file.write("'use_existing_segment_shp': False,")
	file.write("\n")
	file.write("'filter_ocean_pixels': False,")
	file.write("\n")
	file.write("'keep_features': None,")
	file.write("\n")
	file.write("'drop_features': None,")
	file.write("\n")
	file.write("}")
	file.close()



