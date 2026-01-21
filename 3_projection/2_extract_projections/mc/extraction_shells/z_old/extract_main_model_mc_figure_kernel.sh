#!/bin/bash
# Bash script to extract values CSV data - converted from R code
# Usage: 
#   1. conda activate risingverse-py27
#   2. cd "/project/cil/home_dirs/maiqi/repos/prospectus-tools/gcp/extract"
#   3. bash this_script.sh

# Set up logging
NOW=$(date +%Y%m%dT%H%M%S%z)
CUR_SCRIPT=$(basename "$0")
LOG_DIR="/project/cil/home_dirs/maiqi/tmp/extract_logs"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/${CUR_SCRIPT}_valuescsv_${NOW}.txt"

echo "Starting values CSV extraction at $(date)" >> "$LOG_FILE"

# Set working directory
cd "/project/cil/home_dirs/maiqi/repos/prospectus-tools/gcp/extract"
echo "Working directory: $(pwd)" >> "$LOG_FILE"

# Function equivalent to get_valuescsv
get_valuescsv() {
    local ssp="$1"
    local region="$2"
    local aggregation="$3"
    local file_type="$4"
    
    local quantiles_command="python -u quantiles.py /project/cil/home_dirs/maiqi/repos/labor-code-release-2020/3_projection/2_extract_projections/mc/extraction_configs/damage_function_valuescsv.yml --only-ssp=${ssp} --region=${region} --suffix=valuescsv_${aggregation}_${region} uninteracted_main_model${aggregation}${file_type} -uninteracted_main_model-histclim${aggregation}${file_type}"
    
    echo "Running command: $quantiles_command" >> "$LOG_FILE"
    echo "Running command: $quantiles_command"
    
    # Execute the command and capture output
    if $quantiles_command >> "$LOG_FILE" 2>&1; then
        echo "Success: ${ssp} ${region} ${aggregation} ${file_type}" >> "$LOG_FILE"
    else
        echo "Error: ${ssp} ${region} ${aggregation} ${file_type}" >> "$LOG_FILE"
        return 1
    fi
}

# Run background function for parallel processing
run_bg() {
    "$@" &
    while [ "$(jobs -rp | wc -l)" -ge 6 ]; do  # mc.cores = 6 equivalent
        sleep 1
    done
}

# SSP loop (equivalent to for (do_ssp in 4:4))
# for do_ssp in 4; do
#     ssp_arg="SSP${do_ssp}"
#     echo "Processing SSP: $ssp_arg" >> "$LOG_FILE"
    
#     # Single call equivalent to get_valuescsv(ssp_arg, "global","-wage", "-aggregated")
#     get_valuescsv "$ssp_arg" "global" "-gdp" "-aggregated"
# done

# Define regions array
regions=(
    "NGA.25.510"                    # lagos
    "IND.10.121.371"               # delhi
    "CHN.2.18.78"                  # beijing
    "BRA.25.5212.R3fd4ed07b36dfd9c" # sao paulo
    "USA.14.608"                   # chicago
    "NOR.12.288"                   # oslo
)

# Parallel processing equivalent to mcmapply
echo "Starting parallel processing for regions..." >> "$LOG_FILE"

ssp="SSP3"
aggregation=""
file_type=""

# Process each region in parallel
for region in "${regions[@]}"; do
    echo "Queuing region: $region" >> "$LOG_FILE"
    run_bg get_valuescsv "$ssp" "$region" "-gdp" "-levels"
done

# Wait for all background jobs to complete
wait
echo "All parallel jobs completed" >> "$LOG_FILE"

# Optional: Test reading results (commented out as in original R code)
# echo "Testing results..." >> "$LOG_FILE"
# test_file="/shares/gcp/estimation/labor/code_release_int_data/projection_outputs/extracted_data_mc/SSP3-valuescsv_wage_global.csv"
# if [[ -f "$test_file" ]]; then
#     echo "Test file exists: $test_file" >> "$LOG_FILE"
#     head -n 5 "$test_file" >> "$LOG_FILE"
# else
#     echo "Test file not found: $test_file" >> "$LOG_FILE"
# fi

echo "Values CSV extraction completed at $(date)" >> "$LOG_FILE"
echo "All extraction tasks completed. Check log: $LOG_FILE"