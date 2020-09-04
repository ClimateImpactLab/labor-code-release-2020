#!/bin/bash
# Job name:
#SBATCH --job-name=labor
# Partition:
#SBATCH --partition=savio3
# Account:
#SBATCH --account=co_laika
# QoS:
#SBATCH --qos=laika_savio3_normal
# Wall clock limit:
#SBATCH --time=98:00:00

## Command(s) to run:

export SINGULARITY_BINDPATH=/global/scratch2/groups/co_laika/

/global/scratch2/groups/co_laika/gcp-generate.img /global/scratch/liruixue/repos/labor-code-release-2020/3_projection/1_run_projections/mc/uninteracted_main_model_brc_mc_config.yml 10 
