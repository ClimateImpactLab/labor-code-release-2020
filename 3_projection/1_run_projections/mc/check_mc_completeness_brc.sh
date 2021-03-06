#!/bin/bash
# this is a piece of code that helps us check the completeness of projection output
# can be run from anywhere, just set the correct paths

# set some paths and parameters
output_root="/global/scratch/liruixue/outputs/labor/impacts-woodwork/"
# output_root="/shares/gcp/outputs/labor/impacts-woodwork/labor_mc_202009/"
output_dir="" 

# the size of files above which we consider complete
# look at the completed output files to determine this size
output_file_size_above=45

# 130 for one SSP
n_folders_total=520

cd "${output_root}/${output_dir}"

filename_stem="uninteracted_main_model"

# check number of status-*.txt files
for type in global generate; 
do
	n=$(find . -name "status-${type}.txt" | wc -l)
	echo "Number of status-${type}.txt files: ${n}"
done

# check the files for each adaptation scenario
# if the file size is large enough, consider it complete
# otherwise consider it incomplete
for scenario in fulladapt incadapt noadapt histclim; 
do 
	if [ ${scenario} = "fulladapt" ];
	then 
		filename_suffix=""
	else
		filename_suffix="-${scenario}"
	fi
	n_complete=$(find . -name "${filename_stem}${filename_suffix}.nc4" -size +${output_file_size_above}M| wc -l)
	echo "find . -name ${filename_stem}${filename_suffix}.nc4 -size +${output_file_size_above}M| wc -l"
	n_incomplete=$(find . -name "${filename_stem}${filename_suffix}.nc4" -size -${output_file_size_above}M | wc -l)
	n_total=$(find . -name "${filename_stem}${filename_suffix}.nc4" | wc -l)
	
	printf "${scenario}: \n"
	echo "${n_complete} complete, ${n_incomplete} incomplete, total ${n_total}/${n_folders_total} files"
done

# uncomment to look for files with HDF error
# printf "\nFiles with HDF errors:"
# HDF_errors=$(find . -name "*.nc4" -exec ncdump -h {} \; -print |& grep HDF)
# echo "${HDF_errors}"

# if needed, modify the following command to find folders that doesn't contain a certain file
# find . -mindepth 5 -type d  '!' -exec test -e "{}/${filename_stem}.nc4" ';' -print

# use the following command to view the folders and their sizes
# du --separate-dirs -h . |sort -h
