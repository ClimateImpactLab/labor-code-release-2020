#!/bin/bash
#SBATCH --job-name=single-labor-013125
#SBATCH --output=single-SSP3-low-RCP85-CCSM4.out
#SBATCH --error=single-SSP3-low-RCP85-CCSM4.err
#SBATCH --account=cil
#SBATCH --partition=caslake
#SBATCH --time=08:00:00
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --mem=50G
#SBATCH --mail-type=ALL 
#SBATCH --mail-user=egrenier@rcc.uchicago.edu

#Load in required modules
module load python

#Activate environment
cd /project/cil/home_dirs/egrenier/repos/impact-calculations/
source activate /project/cil/home_dirs/egrenier/envs/impact-env

#Run projection
echo "Running projection..."
./generate.sh  /project/cil/home_dirs/egrenier/repos/labor-code-release-2020/3_projection/1_run_projections/single_test_correct_rebasing/config.yml

conda deactivate

