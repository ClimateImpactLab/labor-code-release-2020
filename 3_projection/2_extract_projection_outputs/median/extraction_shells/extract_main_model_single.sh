# do dos2unix path/to/this/file first!!
source ~/miniconda3/etc/profile.d/conda.sh
conda activate risingverse-py27
cd repos/prospectus-tools/gcp/extract

basename=uninteracted_main_model
folder=/shares/gcp/outputs/labor/impacts-woodwork/test_rcc_copy1/uninteracted_splines_27_37_39_by_risk_empshare_noFE_YearlyAverageDay/rcp45/CCSM4/high/SSP3
csv_folder=${folder}/csv
mkdir -p ${csv_folder}

# diagnostics for high risk
# python single.py  --column=highriskimpacts ${folder}/${basename}.nc4 | tee ${csv_folder}/${basename}-highriskimpacts-fulladapt.csv
# python single.py  --column=highriskimpacts ${folder}/${basename}-histclim.nc4 | tee ${csv_folder}/${basename}-highriskimpacts-histclim.csv

# pure outputs (mins per worker per day) (for mapping)
python single.py  --column=rebased_new ${folder}/${basename}.nc4 -${folder}/${basename}-histclim.nc4 | tee ${csv_folder}/${basename}-rebased_new-combined.csv
python single.py  --column=lowriskimpacts ${folder}/${basename}.nc4 -${folder}/${basename}-histclim.nc4 | tee ${csv_folder}/${basename}-lowriskimpacts-combined.csv
python single.py  --column=highriskimpacts ${folder}/${basename}.nc4 -${folder}/${basename}-histclim.nc4 | tee ${csv_folder}/${basename}-highriskimpacts-combined.csv

# levels output (for mapping)

python single.py  --column=rebased_new ${folder}/${basename}-pop-levels.nc4 -${folder}/${basename}-histclim-pop-levels.nc4 | tee ${csv_folder}/${basename}-rebased_new-pop-levels-combined.csv
python single.py  --column=rebased_new ${folder}/${basename}-gdp-levels.nc4 -${folder}/${basename}-histclim-gdp-levels.nc4 | tee ${csv_folder}/${basename}-rebased_new-gdp-levels-combined.csv
python single.py  --column=rebased_new ${folder}/${basename}-wage-levels.nc4 -${folder}/${basename}-histclim-wage-levels.nc4 | tee ${csv_folder}/${basename}-rebased_new-wage-levels-combined.csv

python single.py  --column=lowriskimpacts ${folder}/${basename}-pop-levels.nc4 -${folder}/${basename}-histclim-pop-levels.nc4 | tee ${csv_folder}/${basename}-lowriskimpacts-pop-levels-combined.csv
python single.py  --column=lowriskimpacts ${folder}/${basename}-gdp-levels.nc4 -${folder}/${basename}-histclim-gdp-levels.nc4 | tee ${csv_folder}/${basename}-lowriskimpacts-gdp-levels-combined.csv
python single.py  --column=lowriskimpacts ${folder}/${basename}-wage-levels.nc4 -${folder}/${basename}-histclim-wage-levels.nc4 | tee ${csv_folder}/${basename}-lowriskimpacts-wage-levels-combined.csv
    
python single.py  --column=highriskimpacts ${folder}/${basename}-pop-levels.nc4 -${folder}/${basename}-histclim-pop-levels.nc4 | tee ${csv_folder}/${basename}-highriskimpacts-pop-levels-combined.csv
python single.py  --column=highriskimpacts ${folder}/${basename}-gdp-levels.nc4 -${folder}/${basename}-histclim-gdp-levels.nc4 | tee ${csv_folder}/${basename}-highriskimpacts-gdp-levels-combined.csv
python single.py  --column=highriskimpacts ${folder}/${basename}-wage-levels.nc4 -${folder}/${basename}-histclim-wage-levels.nc4 | tee ${csv_folder}/${basename}-highriskimpacts-wage-levels-combined.csv

 # aggregate output (for timeseries)

python single.py  --column=rebased_new ${folder}/${basename}-pop-aggregated.nc4 -${folder}/${basename}-histclim-pop-aggregated.nc4 | tee ${csv_folder}/${basename}-rebased_new-pop-aggregated-combined.csv
python single.py  --column=rebased_new ${folder}/${basename}-gdp-aggregated.nc4 -${folder}/${basename}-histclim-gdp-aggregated.nc4 | tee ${csv_folder}/${basename}-rebased_new-gdp-aggregated-combined.csv
python single.py  --column=rebased_new ${folder}/${basename}-wage-aggregated.nc4 -${folder}/${basename}-histclim-wage-aggregated.nc4 | tee ${csv_folder}/${basename}-rebased_new-wage-aggregated-combined.csv

python single.py  --column=lowriskimpacts ${folder}/${basename}-pop-aggregated.nc4 -${folder}/${basename}-histclim-pop-aggregated.nc4 | tee ${csv_folder}/${basename}-lowriskimpacts-pop-aggregated-combined.csv
python single.py  --column=lowriskimpacts ${folder}/${basename}-gdp-aggregated.nc4 -${folder}/${basename}-histclim-gdp-aggregated.nc4 | tee ${csv_folder}/${basename}-lowriskimpacts-gdp-aggregated-combined.csv
python single.py  --column=lowriskimpacts ${folder}/${basename}-wage-aggregated.nc4 -${folder}/${basename}-histclim-wage-aggregated.nc4 | tee ${csv_folder}/${basename}-lowriskimpacts-wage-aggregated-combined.csv
    
python single.py  --column=highriskimpacts ${folder}/${basename}-pop-aggregated.nc4 -${folder}/${basename}-histclim-pop-aggregated.nc4 | tee ${csv_folder}/${basename}-highriskimpacts-pop-aggregated-combined.csv
python single.py  --column=highriskimpacts ${folder}/${basename}-gdp-aggregated.nc4 -${folder}/${basename}-histclim-gdp-aggregated.nc4 | tee ${csv_folder}/${basename}-highriskimpacts-gdp-aggregated-combined.csv
python single.py  --column=highriskimpacts ${folder}/${basename}-wage-aggregated.nc4 -${folder}/${basename}-histclim-wage-aggregated.nc4 | tee ${csv_folder}/${basename}-highriskimpacts-wage-aggregated-combined.csv
   