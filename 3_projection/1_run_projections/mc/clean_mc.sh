# set some paths and parameters
# RCC
# output_root="/project2/mgreenst/outputs/labor/montecarlos/"
# SAC
output_root="/shares/gcp/outputs/labor/impacts-woodwork/labor_mc_202009/"
output_dir="batch0" 

# the size of files above which we consider complete
# look at the completed output files to determine this size
output_file_size_above=5

mode="delete"
mode="print"
cd "${output_root}/${output_dir}"
find . -name "status-generate.txt" -${mode}
find . -name "*.nc4" -size -${output_file_size_above}M -${mode}
find . -name "*.nc4" -exec ncdump -h {} \; -print |& grep HDF | awk '{ gsub(/:/, ""); print } ' | xargs rm