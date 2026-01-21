####################################################################################################
# This script extracts projection results, mainly for maps (all regions in a given year).
#
# How to use:
#   1. Log in to a computing node.
#   2. conda activate risingverse-py27
#   3. Change directories and damage_function_valuescsv.yml.
#   4. rcp and iam are set in yml; other paras are set "CHANGE HERE".
#   4. Run:
#        bash <path_to_this_script>
#
# Runtime:
#   - A few minutes, depending on how much you extract.
####################################################################################################


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

#########CHANGE HERE###################################################################################################################################################
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
aggregation="-gdp"
file_type="-levels"
###################################################################################################################################################

# Process each region in parallel
for region in "${regions[@]}"; do
    echo "Queuing region: $region" >> "$LOG_FILE"
    run_bg get_valuescsv "$ssp" "$region" "$aggregation" "$file_type"
done

# Wait for all background jobs to complete
wait
echo "All parallel jobs completed" >> "$LOG_FILE"
echo "Values CSV extraction completed at $(date)" >> "$LOG_FILE"
echo "All extraction tasks completed. Check log: $LOG_FILE"