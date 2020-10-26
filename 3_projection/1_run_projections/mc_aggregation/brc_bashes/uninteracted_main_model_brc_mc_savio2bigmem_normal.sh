#!/bin/bash
# Job name:
#SBATCH --job-name=labor_mc
# Partition:
#SBATCH --partition=savio2_bigmem
# Account:
#SBATCH --account=co_laika
# QoS:
#SBATCH --qos=laika_bigmem2_normal
# Wall clock limit:
#SBATCH --time=98:00:00
#SBATCH --requeue

## Command(s) to run:

export SINGULARITY_BINDPATH=/global/scratch2/groups/co_laika/

/global/scratch2/groups/co_laika/gcp-aggregate-py37.sif /global/scratch/liruixue/repos/labor-code-release-2020/3_projection/1_run_projections/mc_aggregation/aggregation_config_gdp_brc.yml 12

# /global/scratch2/groups/co_laika/gcp-aggregate-py37.sif /global/scratch/liruixue/repos/labor-code-release-2020/3_projection/1_run_projections/mc_aggregation/aggregation_config_wage_brc.yml 12
