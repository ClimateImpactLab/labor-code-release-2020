#!/bin/bash -l
#SBATCH --job-name=knots320
#SBATCH --account=cil
#SBATCH --partition=caslake
#SBATCH --time=02:45:00
#SBATCH --mem=30G
#SBATCH --cpus-per-task=6
#SBATCH --array=1-320%20
#SBATCH --output=/project/cil/home_dirs/mdefranciosi/repos/labor-code-release-2020/2_analysis/spline_search/global/logs/%x.%A.%a.out
#SBATCH --error=/project/cil/home_dirs/mdefranciosi/repos/labor-code-release-2020/2_analysis/spline_search/global/logs/%x.%A.%a.err

# Stata executable on RCC
STATA=/software/stata-16-el8-x86_64/stata-mp

LOGDIR="/project/cil/home_dirs/$USER/repos/labor-code-release-2020/2_analysis/spline_search/global/logs"
mkdir -p "$LOGDIR"

KNOT_GRID_ROW=${SLURM_ARRAY_TASK_ID}
STATA_DO_FILE="/project/cil/home_dirs/$USER/repos/labor-code-release-2020/2_analysis/spline_search/global/02_run_global_knots_candidate.do"

# Print job context before running Stata
pwd
hostname
ls -l "$STATA_DO_FILE"

# Run one knot-grid row
"$STATA" -b do "$STATA_DO_FILE" "row(${KNOT_GRID_ROW})"
