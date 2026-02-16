# do dos2unix path/to/this/file first!!
source ~/miniconda3/etc/profile.d/conda.sh
conda activate risingverse-py27
cd repos/prospectus-tools/gcp/extract

model=surrogate_GFDL-CM3_99
# model=CCSM4
basename=uninteracted_main_model
folder=/shares/gcp/outputs/labor/impacts-woodwork/point_estimate_google_rebased/median/rcp85/${model}/high/SSP3
csv_folder=${folder}/csv
mkdir -p ${csv_folder}

# diagnostics for high risk
# python single.py  --column=highriskimpacts ${folder}/${basename}.nc4 | tee ${csv_folder}/${basename}-highriskimpacts-fulladapt.csv
# python single.py  --column=highriskimpacts ${folder}/${basename}-histclim.nc4 | tee ${csv_folder}/${basename}-highriskimpacts-histclim.csv

# pure outputs (mins per worker per day) (for mapping)
python single.py  --column=rebased ${folder}/${basename}.nc4 -${folder}/${basename}-incadapt.nc4 | tee ${csv_folder}/${basename}-rebased-combined.csv
python single.py  --column=rebased_new ${folder}/${basename}.nc4 -${folder}/${basename}-incadapt.nc4 | tee ${csv_folder}/${basename}-rebased_new-combined.csv
# python single.py  --column=lowriskimpacts ${folder}/${basename}.nc4 -${folder}/${basename}-incadapt.nc4 | tee ${csv_folder}/${basename}-lowriskimpacts-combined.csv
# python single.py  --column=highriskimpacts ${folder}/${basename}.nc4 -${folder}/${basename}-incadapt.nc4 | tee ${csv_folder}/${basename}-highriskimpacts-combined.csv

