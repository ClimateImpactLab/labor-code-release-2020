#!/bin/bash
# this is a piece of code that helps us check the completeness of aggregation output
# can be run from anywhere, just set the correct paths



# combined_uninteracted_spline_empshare_noFE-gdp-aggregated.nc4
# 314 complete, 166 incomplete, total 480/520 files
# incadapt:
# combined_uninteracted_spline_empshare_noFE-incadapt-gdp-aggregated.nc4
# 366 complete, 0 incomplete, total 366/520 files
# noadapt:
# combined_uninteracted_spline_empshare_noFE-noadapt-gdp-aggregated.nc4
# 432 complete, 0 incomplete, total 432/520 files
# histclim:
# combined_uninteracted_spline_empshare_noFE-histclim-gdp-aggregated.nc4
# 313 complete, 167 incomplete, total 480/520 files


# set some paths and parameters
output_root="/shares/gcp/outputs/labor/impacts-woodwork/labor_mc_aggregate"
output_dir="batch0" 

aggregation_scenario="-wage"


# the size of files above which we consider complete
# look at the completed output files to determine this size
levels_file_size_above=40
aggregated_file_size_above=5
# 130 for one SSP3
n_folders_total=520

filename_stem="uninteracted_main_model"

cd "${output_root}/${output_dir}"

# check number of status-aggregate.txt files
n=$(find . -name "status-aggregate.txt" | wc -l)
echo "Number of status-aggregate.txt files: ${n}"


# check the files for each adaptation scenario
# if the file size is large enough, consider it complete
# otherwise consider it incomplete
for file_type in aggregated levels; 
do 
	# choose file size criteria based on 
	# if we're looking at aggregated or levels files
	if [ ${file_type} = "aggregated" ];
	then 
		output_file_size_above=${aggregated_file_size_above}
		file_type_suffix="-aggregated"
	else
		output_file_size_above=${levels_file_size_above}
		file_type_suffix="-levels"
	fi

	printf "=============================================\n"
	printf "Checking ${file_type} files: \n"

	for scenario in fulladapt incadapt noadapt histclim; 
	do 
		if [ ${scenario} = "fulladapt" ];
		then 
			filename_suffix=""
		else
			filename_suffix="-${scenario}"
		fi
		# echo "${filename_stem}${filename_suffix}-${aggregation_scenario}${file_type_suffix}"
		n_complete=$(find . -name "${filename_stem}${filename_suffix}${aggregation_scenario}${file_type_suffix}.nc4" -size +${output_file_size_above}M| wc -l)
		n_incomplete=$(find . -name "${filename_stem}${filename_suffix}${aggregation_scenario}${file_type_suffix}.nc4" -size -${output_file_size_above}M | wc -l)
		# find . -name "${filename_stem}${filename_suffix}${aggregation_scenario}${file_type_suffix}.nc4" -size -${output_file_size_above}M
		n_total=$(find . -name "${filename_stem}${filename_suffix}${aggregation_scenario}${file_type_suffix}.nc4" | wc -l)
		
		printf "${scenario}: \n"
		echo "${filename_stem}${filename_suffix}${aggregation_scenario}${file_type_suffix}.nc4"
		echo "${n_complete} complete, ${n_incomplete} incomplete, total ${n_total}/${n_folders_total} files"
	done
done


# uncomment to look for files with HDF error
# printf "\nFiles with HDF errors:"
# HDF_errors=$(find . -name "*.nc4" -exec ncdump -h {} \; -print |& grep HDF)
# echo "${HDF_errors}"

# # if needed, modify the following command to find folders that doesn't contain a certain file
# find . -mindepth 4  -type d  '!' -exec test -e "{}/${filename_stem}-gdp-aggregated.nc4" ';' -print

