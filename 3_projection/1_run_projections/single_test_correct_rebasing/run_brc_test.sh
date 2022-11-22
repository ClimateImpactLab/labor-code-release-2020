#!/bin/bash
# Job name:
#SBATCH --job-name=labor_test
# Partition:
#SBATCH --partition=savio3
# Account:
#SBATCH --account=co_laika
# QoS:
#SBATCH --qos=laika_savio3_normal
# Wall clock limit:
#SBATCH --time=98:00:00
#SBATCH --requeue

## Command(s) to run:

export SINGULARITY_BINDPATH=/global/scratch2/groups/co_laika/

/global/scratch2/groups/co_laika/gcp-generate-py37.sif /global/scratch/users/liruixue/repos/labor-code-release-2020/3_projection/1_run_projections/single_test_correct_rebasing/config_test_brc_run.yml 1
