####################################################################################################
# This script extracts projection results (interacted model), mainly for timeseries plots (one regions in all years).
#. !! This script is the same as the uninteracted timeseries one, with only a few changes in naming and folders
# How to use:
#   1. Log in to a computing node.
#   2. conda activate risingverse-py27
#   3. Change directories and edit the section marked "CHANGE HERE", especially extract_main_model_mc_ts.yml.
#   4. Run:
#        bash <path_to_this_script>
#
# Runtime:
#   - A few minutes, depending on how much you extract.
####################################################################################################


#########CHANGE HERE###################################################################################################################################################

#Set directories
REPO="/project/cil/home_dirs/maiqi/repos" #confirm path points to your repos folder, if you follow CLI convention this should not change 
projection_root="/project/cil/gcp/outputs/labor/impacts-corpsepose/montecarlo/interacted_model" #path to general energy projection outputs (path to energy projection outputs to be used will later be generated)
DB="/project/cil/gcp/outputs/labor/impacts-corpsepose/montecarlo/interacted_model"  #path to where data should be placed
output="/project/cil/gcp/outputs/labor/impacts-woodwork/montecarlo/timeseries_interacted"

NOW=$(date +%Y%m%dT%H%M%S%z)
CUR_SCRIPT=$(basename "$0")
LOG_DIR="/project/cil/home_dirs/maiqi/tmp/extract_logs"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/${CUR_SCRIPT}_labor_${NOW}.txt"

echo "Projection system outputs pulled from ${projection_root}" >> "$LOG_FILE"
echo "Extraction output directory is ${output}" >> "$LOG_FILE"

show_output="TRUE" # if FALSE parallelizes using run_bg below
aggregated="TRUE"  
levels="FALSE"     
varlist=( rebased ) # rebased highriskimpacts lowriskimpacts clip highrisk allrisk 
ssplist=( SSP3 ) # SSP2 SSP3 SSP4
rcplist=( rcp45 ) # rcp45 rcp85
iamlist=( low ) # low high
scnlist=( fulladapt ) # noadapt incadapt fulladapt histclim
processes=12 #set number of processes so that extraction will not use more than this 
spatiallist=( aggregated )  

echo "DEBUG: Using default years from config/data" >> "$LOG_FILE"

CONFIG=${REPO}/labor-code-release-2020/3_projection/2_extract_projections/mc/extraction_configs/extract_main_model_mc_ts.yml
echo "Config file used ${CONFIG}" >> "${LOG_FILE}"

############################################################################################################################################################

cd ${REPO}/prospectus-tools/gcp/extract
echo "Repo is now ${REPO}" >> "${LOG_FILE}"

script=/project/cil/home_dirs/maiqi/repos/prospectus-tools/gcp/extract/quantiles.py

# define basename (no quotations)
basename=interacted_model

#declaring some more arrays to fill information
declare -A ADAPTS #adaptation scenario suffix in the netcdf.  

ADAPTS[fulladapt]=''
ADAPTS[noadapt]=-noadapt
ADAPTS[incadapt]=-incadapt
ADAPTS[histclim]=-histclim

if [ "$levels" == "TRUE" ]; then
    suffix_list=( "-pop-levels" "-gdp-levels" "-wage-levels" )
elif [ "$aggregated" == "TRUE" ]; then
    suffix_list=( "-pop-aggregated" "-gdp-aggregated" "-wage-aggregated" )
else
    suffix_list=( "" )
fi

# Run in background function
run_bg() {
  "$@" &
  while [ "$(jobs -rp | wc -l)" -ge "$processes" ]; do 
    sleep 1
  done
}

for rcp in "${rcplist[@]}"; do
  for iam in "${iamlist[@]}"; do
    for ssp in "${ssplist[@]}"; do
      for v in "${varlist[@]}"; do
        for scn in "${scnlist[@]}"; do
          for suffix_aggregated in "${suffix_list[@]}"; do

            
            file_args=( "${basename}${ADAPTS[$scn]}${suffix_aggregated}" )
            if [[ "$scn" != "noadapt" && "$scn" != "histclim" && "$v" != "clip" ]]; then
              file_args+=( -"${basename}-histclim${suffix_aggregated}" )
            fi

            clean_args=()
            for f in "${file_args[@]}"; do
              [[ -n "$f" ]] && clean_args+=("$f")
            done
            
            if [[ ${#clean_args[@]} -eq 0 ]]; then
              echo "ERROR: empty basename list (scn=$scn, suffix=$suffix_aggregated)" >&2
              continue  
            fi

            echo "[DEBUG] Processing: ${ssp}_${rcp}_${iam}_${v}_${scn}${suffix_aggregated}_global_timeseries_interacted" >> "$LOG_FILE"
            echo "[DEBUG] basenames count: ${#clean_args[@]}" >> "$LOG_FILE"
            for i in "${!clean_args[@]}"; do
              printf '[DEBUG] basename[%d]=<%s>\n' "$i" "${clean_args[$i]}" >> "$LOG_FILE"
            done

            log="${LOG_DIR}/${ssp}_${rcp}_${iam}_${v}_${scn}${suffix_aggregated}_global_timeseries_interacted.log"

            python_args=(
              "$script"
              "$CONFIG"
              "--results-root=${projection_root}"
              "--db=${DB}"
              "--output-dir=${output}"
              "--column=${v}"
              "--only-rcp=${rcp}"
              "--only-iam=${iam}"
              "--only-ssp=${ssp}"
              "--yearsets=no"
              "--region=global" 
              "--aggregate-regions"      
              "--suffix=_${iam}_${v}_${scn}${suffix_aggregated}_global_timeseries_interacted"
              "--verbose"
            )

            for arg in "${clean_args[@]}"; do
              python_args+=("$arg")
            done

            weight_file="/project/cil/gcp/climate/BCSD/SMME/SMME-weights/${rcp}_2090_SMME_edited_for_April_2016.tsv"
            if [[ ! -f "$weight_file" ]]; then
              echo "WARNING: Weight file not found: $weight_file" >> "$LOG_FILE"
              echo "Available weight files:" >> "$LOG_FILE"
              ls -la /project/cil/gcp/climate/BCSD/SMME/SMME-weights/ >> "$LOG_FILE" 2>/dev/null || echo "Weight directory not accessible" >> "$LOG_FILE"
              
              echo "Skipping ${rcp} due to missing weight files" >> "$LOG_FILE"
              continue
            fi

            expected_path="${projection_root}/batch0/${rcp}"
            if [[ ! -d "$expected_path" ]]; then
              echo "WARNING: Expected data path does not exist: $expected_path" >> "$LOG_FILE"
              echo "Available paths in ${projection_root}/batch0/:" >> "$LOG_FILE"
              ls -la "${projection_root}/batch0/" >> "$LOG_FILE" 2>/dev/null || echo "batch0 directory not found" >> "$LOG_FILE"
              continue
            fi

            echo "Running: python ${python_args[*]}" >> "$LOG_FILE"

            if [[ "$show_output" == "TRUE" ]]; then
              python "${python_args[@]}" 2>&1 | tee -a "$LOG_FILE"
            else
              run_bg python "${python_args[@]}" >"$log" 2>&1
            fi

          done
        done
      done
    done
  done
done

wait
echo "All tasks finished. Logs under $LOG_DIR"