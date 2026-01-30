#!/bin/bash
#SBATCH --job-name=stata_job                
#SBATCH --output=/project/cil/home_dirs/maiqi/logs/stata_job_%j.out 
#SBATCH --error=/project/cil/home_dirs/maiqi/logs/stata_job_%j.err 
#SBATCH --time=08:00:00
#SBATCH --partition=cil
#SBATCH --account=cil
#SBATCH --mem=64G         
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=10
#SBATCH --mail-type=BEGIN,END,FAIL         
#SBATCH --mail-user=maiqi@uchicago.edu 

module load stata
cd /project/cil/home_dirs/maiqi/repos/labor-code-release-2020/2_analysis/1_regression


stata-mp -b do uninteracted_reg_comlohi_3sector.do
