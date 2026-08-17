#!/bin/bash -l
#SBATCH --job-name=EuropeUS_knots
#SBATCH --account=cil
#SBATCH --partition=caslake
#SBATCH --time=02:00:00
#SBATCH --mem=20G
#SBATCH --cpus-per-task=8
# 120 candidate triples; run all in one task
#SBATCH --array=1-1%1
#SBATCH --output=/project/cil/home_dirs/mdefranciosi/repos/labor-code-release-2020/2_analysis/spline_search/region/logs/%x.%A.%a.out
#SBATCH --error=/project/cil/home_dirs/mdefranciosi/repos/labor-code-release-2020/2_analysis/spline_search/region/logs/%x.%A.%a.err

export ISO=EuropeUS
export BATCH_SIZE=9999   # all candidate triples in one task

module purge 2>/dev/null || true
STATA=/software/stata-16-el8-x86_64/stata-mp

DOFILE="/project/cil/home_dirs/$USER/repos/labor-code-release-2020/2_analysis/spline_search/region/03_run_region_knots_candidate.do"
"$STATA" -b do "$DOFILE"

