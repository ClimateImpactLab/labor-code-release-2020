cd repos/prospectus-tools/gcp/extract
basename=combined_mixed_model_splines_empshare_noFE
folder=/shares/gcp/outputs/labor/impacts-woodwork/combined_mixed_splines_27_37_39_by_risk_empshare_noFE_YearlyAverageDay/rcp85/CCSM4/high/SSP3
csv_folder=${folder}/csv

python single.py  --column=rebased ${folder}/${basename}.nc4 -${folder}/${basename}-histclim.nc4 | tee ${csv_folder}/${basename}-rebased-combined.csv
python single.py  --column=lowriskimpacts ${folder}/${basename}.nc4 -${folder}/${basename}-histclim.nc4 | tee ${csv_folder}/${basename}-lowriskimpacts-combined.csv
python single.py  --column=highriskimpacts ${folder}/${basename}.nc4 -${folder}/${basename}-histclim.nc4 | tee ${csv_folder}/${basename}-highriskimpacts-combined.csv

python single.py  --column=rebased ${folder}/${basename}-pop-levels.nc4 -${folder}/${basename}-histclim-pop-levels.nc4 | tee ${csv_folder}/${basename}-rebased-pop-levels-combined.csv
python single.py  --column=rebased ${folder}/${basename}-gdp-levels.nc4 -${folder}/${basename}-histclim-gdp-levels.nc4 | tee ${csv_folder}/${basename}-rebased-gdp-levels-combined.csv
python single.py  --column=rebased ${folder}/${basename}-wage-levels.nc4 -${folder}/${basename}-histclim-wage-levels.nc4 | tee ${csv_folder}/${basename}-rebased-wage-levels-combined.csv

python single.py  --column=lowriskimpacts ${folder}/${basename}-pop-levels.nc4 -${folder}/${basename}-histclim-pop-levels.nc4 | tee ${csv_folder}/${basename}-lowriskimpacts-pop-levels-combined.csv
python single.py  --column=lowriskimpacts ${folder}/${basename}-gdp-levels.nc4 -${folder}/${basename}-histclim-gdp-levels.nc4 | tee ${csv_folder}/${basename}-lowriskimpacts-gdp-levels-combined.csv
python single.py  --column=lowriskimpacts ${folder}/${basename}-wage-levels.nc4 -${folder}/${basename}-histclim-wage-levels.nc4 | tee ${csv_folder}/${basename}-lowriskimpacts-wage-levels-combined.csv
    
python single.py  --column=highriskimpacts ${folder}/${basename}-pop-levels.nc4 -${folder}/${basename}-histclim-pop-levels.nc4 | tee ${csv_folder}/${basename}-highriskimpacts-pop-levels-combined.csv
python single.py  --column=highriskimpacts ${folder}/${basename}-gdp-levels.nc4 -${folder}/${basename}-histclim-gdp-levels.nc4 | tee ${csv_folder}/${basename}-highriskimpacts-gdp-levels-combined.csv
python single.py  --column=highriskimpacts ${folder}/${basename}-wage-levels.nc4 -${folder}/${basename}-histclim-wage-levels.nc4 | tee ${csv_folder}/${basename}-highriskimpacts-wage-levels-combined.csv
   