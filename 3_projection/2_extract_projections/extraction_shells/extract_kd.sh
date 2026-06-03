#!/bin/bash
# This bash script is a wrapper that calls quantiles.py.
# In command line, run:
#   1. module load python
#   2. source activate risingverse-py27
#   3. bash extract_kd.sh

show_output="FALSE"
aggregated="FALSE" 
levels="TRUE"

varlist=( rebased ) # rebased highriskimpacts lowriskimpacts clip 
ssplist=( SSP3 ) # SSP2 SSP3 SSP4
rcplist=( rcp85 ) # rcp45 rcp85
iamlist=( high ) # low high
scnlist=( fulladapt ) # noadapt incadapt fulladapt
rgnlist=( "NGA.25.510" "IND.10.121.371" "CHN.2.18.78" "BRA.25.5212.R3fd4ed07b36dfd9c" "USA.14.608" "NOR.12.288" )
processes=6

# quantiles.py and extraction config locations 
script=/project/cil/home_dirs/egrenier/repos/prospectus-tools/gcp/extract/quantiles.py
config=/project/cil/home_dirs/egrenier/repos/labor-code-release-2020/3_projection/2_extract_projections/extraction_configs/extract_kd.yml
output=/project/cil/gcp/outputs/labor/impacts-woodwork/montecarlo/extracted

# define basename (no quotations)
basename=uninteracted_main_model_agnonag_27_28_41

#declaring some more arrays to fill information
declare -A ADAPTS #adaptation scenario suffix in the netcdf.  

ADAPTS[fulladapt]=''
ADAPTS[noadapt]=-noadapt
ADAPTS[incadapt]=-incadapt
ADAPTS[histclim]=-histclim

if [ "$levels" == "TRUE" ]; then
    suffix_list=( "-gdp-levels" )
elif [ "$aggregated" == "TRUE" ]; then
    suffix_list=( "-pop-aggregated" "-gdp-aggregated" "-wage-aggregated" )
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

for rcp in "${rcplist[@]}" ; do
    for iam in "${iamlist[@]}" ; do
        for ssp in "${ssplist[@]}" ; do
            for v in "${varlist[@]}" ; do
                for scn in "${scnlist[@]}" ; do
                    for suffix_aggregated in "${suffix_list[@]}" ; do
                        for ir in "${rgnlist[@]}" ; do

                            out=${output}/${basename}/kernel_density
                            mkdir -p ${out}
                        
                            if [ "${scn}" != "noadapt" ] && [ "${scn}" != "histclim" ] && [ "${v}" != "clip" ] ; then
                                # subtract histclim only if scn isn't “noadapt” or “histclim”
                                file="${basename}${ADAPTS[${scn}]}${suffix_aggregated} -${basename}-histclim${suffix_aggregated}"
                            else
                                file="${basename}${ADAPTS[${scn}]}${suffix_aggregated} -${basename}-histclim-noadapt${suffix_aggregated}"
                            fi
                              
                            if [ "$show_output" == "FALSE" ] ; then
                                run_bg nohup python ${script} ${config} --column=${v} --only-rcp=${rcp} --only-iam=${iam} --only-ssp=${ssp} --region=${ir} --output-dir=${out} --suffix="_${iam}_${v}_${scn}${suffix_aggregated}-${ir}"  ${file} > /dev/null
                            else
                                python ${script} ${config} --column=${v} --only-rcp=${rcp} --only-iam=${iam} --only-ssp=${ssp} --region=${ir} --output-dir=${out} --suffix="_${iam}_${v}_${scn}${suffix_aggregated}-${ir}"  ${file} > /dev/null
                            fi
                        done
                    done
                done
            done
        done
    done
done

wait