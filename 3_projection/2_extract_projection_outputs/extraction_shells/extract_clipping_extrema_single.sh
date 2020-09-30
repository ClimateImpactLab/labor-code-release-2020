conda activate risingverse-py27
cd repos/prospectus-tools/gcp/extract
basename=combined_mixed_model_splines_empshare_noFE
folder=/shares/gcp/outputs/labor/impacts-woodwork/clipping_extrema/combined_mixed_splines_27_37_39_by_risk_empshare_noFE_YearlyAverageDay/rcp85/CCSM4/high/SSP3
csv_folder=${folder}/csv

# diagnostics for high risk
python single.py  --column=highriskimpacts ${folder}/${basename}.nc4 | tee ${csv_folder}/${basename}-highriskimpacts-fulladapt.csv
python single.py  --column=highriskimpacts ${folder}/${basename}-histclim.nc4 | tee ${csv_folder}/${basename}-highriskimpacts-histclim.csv

# pure outputs (mins per worker per day)
python single.py  --column=rebased ${folder}/${basename}.nc4 -${folder}/${basename}-histclim.nc4 | tee ${csv_folder}/${basename}-rebased-combined.csv
python single.py  --column=lowriskimpacts ${folder}/${basename}.nc4 -${folder}/${basename}-histclim.nc4 | tee ${csv_folder}/${basename}-lowriskimpacts-combined.csv
python single.py  --column=highriskimpacts ${folder}/${basename}.nc4 -${folder}/${basename}-histclim.nc4 | tee ${csv_folder}/${basename}-highriskimpacts-combined.csv
