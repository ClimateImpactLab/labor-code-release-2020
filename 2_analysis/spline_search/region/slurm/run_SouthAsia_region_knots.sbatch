#!/bin/bash -l
#SBATCH --job-name=SouthAsia_knots
#SBATCH --account=cil
#SBATCH --partition=caslake
#SBATCH --time=01:00:00
#SBATCH --mem=20G
#SBATCH --cpus-per-task=8
# 72 candidate triples; 4 triples per task; run up to 8 tasks at once
#SBATCH --array=1-18%8
#SBATCH --output=/project/cil/home_dirs/mdefranciosi/repos/labor-code-release-2020/2_analysis/spline_search/region/logs/%x.%A.%a.out
#SBATCH --error=/project/cil/home_dirs/mdefranciosi/repos/labor-code-release-2020/2_analysis/spline_search/region/logs/%x.%A.%a.err

export ISO=SouthAsia
export BATCH_SIZE=4

module purge 2>/dev/null || true
STATA=/software/stata-16-el8-x86_64/stata-mp

DOFILE="/project/cil/home_dirs/$USER/repos/labor-code-release-2020/2_analysis/spline_search/region/03_run_region_knots_candidate.do"
"$STATA" -b do "$DOFILE"
