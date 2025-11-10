#!/bin/bash
#SBATCH --job-name=aggr-labor-wage-global
#SBATCH --output=/project/cil/home_dirs/egrenier/repos/labor-code-release-2020/3_projection/1_run_projections/3_aggregation/SLURM/out/output_%A_%a.out
#SBATCH --error=/project/cil/home_dirs/egrenier/repos/labor-code-release-2020/3_projection/1_run_projections/3_aggregation/SLURM/err/error_%A_%a.err
#SBATCH --account=cil
#SBATCH --partition=cil
#SBATCH --cpus-per-task=1
#SBATCH --mem=2G
#SBATCH --time=36:00:00
#SBATCH --array=0-63

# ==== DEFINE CONFIGS ==== #
PARENT_DIR="/project/cil/home_dirs/egrenier/repos/labor-code-release-2020/3_projection/1_run_projections/3_aggregation/configs/median"

CONFIG_FILE="uninteracted_wage.yml"

# pick which config file for this task
CONFIG="${PARENT_DIR}/${CONFIG_FILE}"

# ==== STAGGERING VIA SLEEP ==== #
INTERVAL=15
sleep_time=$(( SLURM_ARRAY_TASK_ID * INTERVAL ))

echo "Task ${SLURM_ARRAY_TASK_ID} sleeping for ${sleep_time}s"  >&2 # <- sends to .err instead of .out :)
sleep "$sleep_time"

# ==== LOAD ENV + GO TO WORK DIR ==== #

module load python
source activate /project/cil/home_dirs/egrenier/envs/impact-env/
cd /project/cil/home_dirs/egrenier/repos/impact-calculations

# ==== RUN ====
echo "Running aggregate.sh with config: $CONFIG"
srun ./aggregate.sh "$CONFIG"
