#!/bin/bash
#SBATCH --job-name=aggr-labor-gdp-SSP3
#SBATCH --output=/dev/null
#SBATCH --error=/dev/null
#SBATCH --account=cil
#SBATCH --partition=caslake
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=36:00:00
#SBATCH --array=0-989

# ==== DEFINE CONFIGS ==== #
PARENT_DIR="/project/cil/home_dirs/egrenier/repos/labor-code-release-2020/3_projection/1_run_projections/3_aggregation/configs/montecarlo"

CONFIG_FILES=(
  "pop-batch0.yml"
  "pop-batch1.yml"
  "pop-batch2.yml"
  "pop-batch3.yml"
  "pop-batch4.yml"
  "pop-batch5.yml"
  "pop-batch6.yml"
  "pop-batch7.yml"
  "pop-batch8.yml"
  "pop-batch9.yml"
  "pop-batch10.yml"
  "pop-batch11.yml"
  "pop-batch12.yml"
  "pop-batch13.yml"
  "pop-batch14.yml"
)

SET_SIZE=${#CONFIG_FILES[@]}

# pick which config file for this task
CONFIG="${PARENT_DIR}/${CONFIG_FILES[$(( SLURM_ARRAY_TASK_ID % SET_SIZE ))]}"

# ==== STAGGERING VIA SLEEP ==== #
INTERVAL=20                                    # seconds between each batch of 15
group_index=$(( SLURM_ARRAY_TASK_ID / SET_SIZE ))
sleep_time=$(( group_index * INTERVAL ))

echo "Task ${SLURM_ARRAY_TASK_ID} sleeping for ${sleep_time}s"  >&2
sleep $sleep_time

# ==== LOAD ENV + GO TO WORK DIR ==== #

module load python
source activate /project/cil/home_dirs/egrenier/envs/impact-env/
cd /project/cil/home_dirs/egrenier/repos/impact-calculations

# ==== RUN ====
./aggregate.sh "$CONFIG"
