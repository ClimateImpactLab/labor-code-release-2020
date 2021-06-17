#!/bin/bash
# Job name:
#SBATCH --job-name=s3_low
# Partition:
#SBATCH --partition=savio3
# Account:
#SBATCH --account=co_laika
# QoS:
#SBATCH --qos=savio_lowprio
# Wall clock limit:
#SBATCH --time=70:00:00
#SBATCH --requeue
#SBATCH --array=1-500%50

## Command(s) to run:

export SINGULARITY_BINDPATH=/global/scratch2/groups/co_laika/

/global/scratch2/groups/co_laika/gcp-generate-py37.sif /global/scratch/liruixue/repos/labor-code-release-2020/3_projection/1_run_projections/mc_correct_rebasing/config_brc.yml 1
