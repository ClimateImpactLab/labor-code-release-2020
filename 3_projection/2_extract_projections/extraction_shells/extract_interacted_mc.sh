#!/bin/bash
# This bash script is a wrapper that calls quantiles.py.
# In command line, run:
#   1. module load python
#   2. source activate risingverse-py27
#   3. bash extract_main_model.sh


output_root=/project/cil/gcp/outputs/labor/impacts-corpsepose/montecarlo/extracted/clim_interacted_model_agnonag_27_28_41/extracted


show_output="FALSE" # if FALSE parallelizes using run_bg below
aggregated="TRUE" 
levels="FALSE"

varlist=( rebased ) # rebased highriskimpacts lowriskimpacts clip 
ssplist=( SSP3 ) # SSP2 SSP3 SSP4
rcplist=( rcp45 rcp85 ) # rcp45 rcp85
iamlist=( high ) # low high
scnlist=( fulladapt ) # noadapt incadapt fulladapt
processes=8 #set number of processes so that extraction will not use more than this 


# quantiles.py and extraction config locations 
script=/project/cil/home_dirs/mdefranciosi/repos/prospectus-tools/gcp/extract/quantiles.py
config=/project/cil/home_dirs/mdefranciosi/repos/labor-code-release-2020/3_projection/2_extract_projections/extraction_configs/extract_interacted_model_mc.yml

# define basename (no quotations)
basename=clim_interacted_model_agnonag_27_28_41_riskshare_lo

#declaring some more arrays to fill information
declare -A ADAPTS #adaptation scenario suffix in the netcdf.  

ADAPTS[fulladapt]=''
ADAPTS[noadapt]=-noadapt
ADAPTS[incadapt]=-incadapt
ADAPTS[histclim]=-histclim

if [ "$levels" == "TRUE" ]; then
    suffix_list=( "-gdp-levels" )
elif [ "$aggregated" == "TRUE" ]; then
    suffix_list=( "-gdp-aggregated" )
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

                        outdir="${output_root}/${basename}/${rcp}/${iam}/${ssp}"
                        mkdir -p "${outdir}"

                        
                        if [ "${scn}" != "noadapt" ] && [ "${scn}" != "histclim" ] && [ "${v}" != "clip" ] ; then
                            # subtract histclim only if scn isn't “noadapt” or “histclim”
                            file="${basename}${ADAPTS[${scn}]}${suffix_aggregated} -${basename}-histclim${suffix_aggregated}"
                        else
                            file="${basename}${ADAPTS[${scn}]}${suffix_aggregated}"
                        fi

                        if [ "$show_output" == "FALSE" ] ; then
                            run_bg nohup python2 "${script}" "${config}" --column="${v}" --only-rcp="${rcp}" --only-iam="${iam}" --only-ssp="${ssp}" --suffix="_${iam}_${v}_${scn}${suffix_aggregated}" --verbose=TRUE  ${file} > /dev/null
                        else
                            python2 "${script}" ${config} --column="${v}" --only-rcp="${rcp}" --only-iam="${iam}" --only-ssp="${ssp}" --suffix="_${iam}_${v}_${scn}${suffix_aggregated}"  ${file}
                        fi
                    done
                done
            done
        done
    done
done

wait