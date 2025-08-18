#!/bin/bash
# Job name:
#SBATCH --job-name=mc_lowprio
# Partition:
#SBATCH --partition=savio3_bigmem
# Account:
#SBATCH --account=co_laika
# QoS:
#SBATCH --qos=savio_lowprio
# Wall clock limit:
#SBATCH --time=70:00:00
#SBATCH --requeue

## Command(s) to run:

export SINGULARITY_BINDPATH=/global/scratch2/groups/co_laika/

/global/scratch2/groups/co_laika/gcp-generate-py37_TEST-2020-10-01.sif /global/scratch/users/liruixue/repos/labor-code-release-2020/3_projection/1_run_projections/mc/uninteracted_main_model_brc_mc_config.yml 7
