#!/bin/bash
#SBATCH --job-name=combine-surveys
#SBATCH --output=/project/cil/home_dirs/mdefranciosi/repos/labor-code-release-2020/1_assemble_dataset/time_use/merge/combine_surveys_%j.out
#SBATCH --error=/project/cil/home_dirs/mdefranciosi/repos/labor-code-release-2020/1_assemble_dataset/time_use/merge/combine_surveys_%j.err
#SBATCH --account=cil
#SBATCH --partition=cil
#SBATCH --cpus-per-task=2
#SBATCH --mem=32G
#SBATCH --time=01:00:00

set -euo pipefail

SCRIPT_DIR=/project/cil/home_dirs/mdefranciosi/repos/labor-code-release-2020/1_assemble_dataset/time_use/merge
PYTHON=/software/python-miniforge-25.3.0-el8-x86_64/bin/python

cd "${SCRIPT_DIR}"

"${PYTHON}" combine_surveys.py
