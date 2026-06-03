#!/bin/bash
# This bash script is a wrapper that calls quantiles.py. 
# First, check that extract config is correctly specified.
# Allocate ~6 GB of memory per process if running in parallel, otherwise OOM errors will kill processes
# In command line, run:
#   1. module load python
#   2. source activate risingverse-py27
#   3. bash extract_main_model.sh

show_output="FALSE" # if FALSE parallelizes using run_bg below
aggregated="TRUE" # For aggregated files
levels="FALSE" # for IR-level valuation outputs (from aggregation)

varlist=( rebased ) # rebased highriskimpacts lowriskimpacts clip 
ssplist=( SSP3 ) # SSP2 SSP3 SSP4
rcplist=( rcp45 rcp85 ) # rcp45 rcp85
iamlist=( low high ) # low high
scnlist=( fulladapt histclim ) # noadapt incadapt fulladapt
processes=12 #set number of processes so that extraction will not use more than this 

# quantiles.py, extraction config and output locations 
script=/project/cil/home_dirs/egrenier/repos/prospectus-tools/gcp/extract/quantiles.py
config=/project/cil/home_dirs/egrenier/repos/labor-code-release-2020/3_projection/2_extract_projections/extraction_configs/extract_median.yml # <- check before running
output=/project/cil/gcp/outputs/labor/impacts-woodwork/median/extracted/

# define basename (no quotes)
basename=uninteracted_main_model_agnonag_27_28_41

#declaring some more arrays to fill information
declare -A ADAPTS #adaptation scenario suffix in the netcdf.  

ADAPTS[fulladapt]=''
ADAPTS[noadapt]=-noadapt
ADAPTS[incadapt]=-incadapt
ADAPTS[histclim]=-histclim

if [ "$levels" == "TRUE" ]; then
    suffix_list=( "-pop-levels" "-gdp-levels" "-wage-levels" )
elif [ "$aggregated" == "TRUE" ]; then
    suffix_list=( "-gdp-aggregated"  ) # "-pop-aggregated" "-wage-aggregated"
else
    suffix_list=( "" )
fi

# Run in background
run_bg() {
  "$@" &
  while [ "$(jobs -rp | wc -l)" -ge "$processes" ]; do
    sleep 1
  done
}

for rcp in ${rcplist[@]} ;do
	for iam in ${iamlist[@]};do
		for ssp in ${ssplist[@]} ;do
			for v in ${varlist[@]}; do
				for scn in ${scnlist[@]};do 
                    for suffix_aggregated in "${suffix_list[@]}" ; do

                        out=${output}/special_case_extractions/${basename}/${rcp}/${iam}/${ssp}
                        mkdir -p ${out}

    					if [ "${scn}" != "noadapt" ] && [ "${scn}" != "histclim" ] && [ "${v}" != "clip" ];then
    						file="${basename}${ADAPTS[${scn}]}${suffix_aggregated}" #  -${basename}-histclim${suffix_aggregated}this is to subtract hisctlim if not noadapt!  
    					else
    						file="${basename}${ADAPTS[${scn}]}${suffix_aggregated}" #  -${basename}-histclim-noadapt${suffix_aggregated} otherwise we just take the raw impacts (if histclim or noadapt)
                        fi 

    					if [ $show_output == "FALSE" ];then 
    						run_bg nohup python ${script} ${config} --column=${v} --only-rcp=${rcp} --only-iam=${iam} --only-ssp=${ssp} --output-dir=${out} --suffix=_${iam}_${v}_${scn}${suffix_aggregated}  ${file} > /dev/null				
    					else
                            python ${script} ${config} --column=${v} --only-rcp=${rcp} --only-iam=${iam} --only-ssp=${ssp} --output-dir=${out} --suffix=_${iam}_${v}_${scn}${suffix_aggregated}  ${file}	 
    					fi
                    done
				done
			done
		done
	done
done 

wait
