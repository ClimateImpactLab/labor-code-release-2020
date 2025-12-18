#!/bin/bash
#SBATCH --job-name=fulldb-energy-ssp245
#SBATCH --output=fulldb-energy-ssp245.out
#SBATCH --error=fulldb-energy-ssp245.err
#SBATCH --partition=caslake
#SBATCH --account=cil
#SBATCH --time=04:00:00
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --mem=32G
#SBATCH --mail-type=ALL
#SBATCH --mail-user=egrenier@rcc.uchicago.edu

# Load modules
module load netcdf
module load curl/7.79.1
module load udunits
module load geos/3.9.1
module load sqlite/3.36.0
module load proj/7.2
module load gdal/3.3.3
module load gcc/12.2.0 
module load python/anaconda-2022.05
module load R/4.2.1

# Run script
Rscript energy_db_script.R


