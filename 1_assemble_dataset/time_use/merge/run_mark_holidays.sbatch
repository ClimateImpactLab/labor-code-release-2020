#!/bin/bash
#SBATCH --job-name=mark-holidays
#SBATCH --output=/project/cil/home_dirs/mdefranciosi/repos/labor-code-release-2020/1_assemble_dataset/time_use/merge/mark_holidays_%j.out
#SBATCH --error=/project/cil/home_dirs/mdefranciosi/repos/labor-code-release-2020/1_assemble_dataset/time_use/merge/mark_holidays_%j.err
#SBATCH --account=cil
#SBATCH --partition=amd
#SBATCH --cpus-per-task=12
#SBATCH --mem=64G
#SBATCH --time=02:00:00

set -euo pipefail

SCRIPT_DIR=/project/cil/home_dirs/mdefranciosi/repos/labor-code-release-2020/1_assemble_dataset/time_use/merge
RSCRIPT=/project/cil/home_dirs/mdefranciosi/rcc_onboarding/envs/r_geospatial/bin/Rscript

cd "${SCRIPT_DIR}"

"${RSCRIPT}" --vanilla mark_holidays.R
