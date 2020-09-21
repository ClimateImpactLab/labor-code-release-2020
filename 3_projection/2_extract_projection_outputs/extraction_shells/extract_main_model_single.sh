# do dos2unix path/to/this/file first!!

conda activate risingverse-py27
cd repos/prospectus-tools/gcp/extract

basename=combined_uninteracted_spline_empshare_noFE
folder=/shares/gcp/outputs/labor/impacts-woodwork/combined_uninteracted_splines_27_37_39_by_risk_empshare_noFE_YearlyAverageDay/median/rcp85/CCSM4/high/SSP3
csv_folder=${folder}/csv

# pure outputs (mins per worker per day)
# python single.py  --column=rebased ${folder}/${basename}.nc4 -${folder}/${basename}-histclim.nc4 | tee ${csv_folder}/${basename}-rebased-combined.csv
# python single.py  --column=response22 ${folder}/${basename}.nc4 -${folder}/${basename}-histclim.nc4 | tee ${csv_folder}/${basename}-lowriskimpacts-combined.csv
# python single.py  --column=response ${folder}/${basename}.nc4 -${folder}/${basename}-histclim.nc4 | tee ${csv_folder}/${basename}-highriskimpacts-combined.csv

# aggregate output (for timeseries)
python single.py  --column=rebased ${folder}/${basename}-pop-allvars-aggregated.nc4 -${folder}/${basename}-histclim-pop-allvars-aggregated.nc4 | tee ${csv_folder}/${basename}-rebased-pop-aggregated-combined.csv
python single.py  --column=rebased ${folder}/${basename}-gdp-aggregated.nc4 -${folder}/${basename}-histclim-gdp-aggregated.nc4 | tee ${csv_folder}/${basename}-rebased-gdp-aggregated-combined.csv
# python single.py  --column=rebased ${folder}/${basename}-wage-aggregated.nc4 -${folder}/${basename}-histclim-wage-aggregated.nc4 | tee ${csv_folder}/${basename}-rebased-wage-aggregated-combined.csv
python single.py  --column=response22 ${folder}/${basename}-pop-allvars-aggregated.nc4 -${folder}/${basename}-histclim-pop-allvars-aggregated.nc4 | tee ${csv_folder}/${basename}-lowriskimpacts-pop-aggregated-combined.csv
python single.py  --column=response22 ${folder}/${basename}-gdp-aggregated.nc4 -${folder}/${basename}-histclim-gdp-aggregated.nc4 | tee ${csv_folder}/${basename}-lowriskimpacts-gdp-aggregated-combined.csv
python single.py  --column=response22 ${folder}/${basename}-wage-aggregated.nc4 -${folder}/${basename}-histclim-wage-aggregated.nc4 | tee ${csv_folder}/${basename}-lowriskimpacts-wage-aggregated-combined.csv
python single.py  --column=response ${folder}/${basename}-pop-allvars-aggregated.nc4 -${folder}/${basename}-histclim-pop-allvars-aggregated.nc4 | tee ${csv_folder}/${basename}-highriskimpacts-pop-aggregated-combined.csv
python single.py  --column=response ${folder}/${basename}-gdp-aggregated.nc4 -${folder}/${basename}-histclim-gdp-aggregated.nc4 | tee ${csv_folder}/${basename}-highriskimpacts-gdp-aggregated-combined.csv
python single.py  --column=response ${folder}/${basename}-wage-aggregated.nc4 -${folder}/${basename}-histclim-wage-aggregated.nc4 | tee ${csv_folder}/${basename}-highriskimpacts-wage-aggregated-combined.csv