#!/bin/bash
#SBATCH --job-name=fair_conc_rcp45
#SBATCH --output=/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/output/logs/slurm/fair_conc_rcp45_%j.out
#SBATCH --error=/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/output/logs/slurm/fair_conc_rcp45_%j.err
#SBATCH --account=cil
#SBATCH --partition=amd
#SBATCH --time=02:00:00
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=20
#SBATCH --mem=64G

# FAIR CO2 concentration pulse experiment for Figure 9 Panel B, RCP4.5 counterpart
# to /project/cil/home_dirs/scadavidsanchez/projects/dscim-labor-2025-update2026/paper-updates/run_fair_concentrations.py

BASE=/project/cil/home_dirs/maiqi/repos/labor-code-release-2020

source /project/cil/home_dirs/maiqi/envs/fair162/bin/activate

export FAIR_N_WORKERS=20

cd "$BASE/4_post_projection/2_damage_function/fair_concentrations"
python run_fair_concentrations_rcp45.py
