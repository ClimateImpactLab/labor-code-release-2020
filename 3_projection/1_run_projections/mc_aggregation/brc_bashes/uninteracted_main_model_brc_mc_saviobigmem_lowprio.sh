#!/bin/bash
# Job name:
#SBATCH --job-name=mc_lowprio
# Partition:
#SBATCH --partition=savio_bigmem
# Account:
#SBATCH --account=co_laika
# QoS:
#SBATCH --qos=savio_lowprio
# Wall clock limit:
#SBATCH --time=70:00:00
#SBATCH --requeue

## Command(s) to run:

export SINGULARITY_BINDPATH=/global/scratch2/groups/co_laika/

/global/scratch2/groups/co_laika/gcp-aggregate-py37.sif /global/scratch/users/liruixue/repos/labor-code-release-2020/3_projection/1_run_projections/mc_aggregation/aggregation_config_gdp_brc.yml 10
# /global/scratch2/groups/co_laika/gcp-aggregate-py37.sif /global/scratch/users/liruixue/repos/labor-code-release-2020/3_projection/1_run_projections/mc_aggregation/aggregation_config_wage_brc.yml 10
