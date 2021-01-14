# do dos2unix path/to/this/file first!!
source ~/miniconda3/etc/profile.d/conda.sh
conda activate risingverse-py27
cd ~/repos/prospectus-tools/gcp/extract

folder=/shares/gcp/outputs/labor/impacts-woodwork/clipping_lrclim_copy/uninteracted_splines_27_37_39_by_risk_empshare_noFE_YearlyAverageDay/rcp85/CCSM4/high/SSP3
csv_folder=${folder}/csv
mkdir -p ${csv_folder}

# extract fulladapt and incadapt - need to subtract histclim
for basename in clip clip-incadapt 
do 
	for var in rebased_new lowriskimpacts highriskimpacts 
	do 
		# pure outputs (mins per worker per day) (for mapping)
		nohup python single.py  --column=${var} ${folder}/${basename}.nc4 -${folder}/${basename}-histclim.nc4  | cat > ${csv_folder}/${basename}-${var}.csv

		for agg in pop gdp wage 
		do 
			# levels output (for mapping)
			nohup python single.py  --column=${var} ${folder}/${basename}-${agg}-levels.nc4 -${folder}/${basename}-histclim-${agg}-levels.nc4 | cat > ${csv_folder}/${basename}-${var}-${agg}-levels.csv
			# aggregate output (for timeseries)
			nohup python single.py  --column=${var} ${folder}/${basename}-${agg}-aggregated.nc4 -${folder}/${basename}-histclim-${agg}-aggregated.nc4 | cat > ${csv_folder}/${basename}-${var}-${agg}-aggregated.csv
		done
	done
done

# extract noadapt - don't subtract histclim
for basename in clip-noadapt 
do 
	for var in rebased_new lowriskimpacts highriskimpacts 
	do 
		# pure outputs (mins per worker per day) (for mapping)
		nohup python single.py  --column=${var} ${folder}/${basename}.nc4 | cat > ${csv_folder}/${basename}-${var}.csv

		for agg in pop gdp wage 
		do 
			# levels output (for mapping)
			nohup python single.py  --column=${var} ${folder}/${basename}-${agg}-levels.nc4  | cat > ${csv_folder}/${basename}-${var}-${agg}-levels.csv
			# aggregate output (for timeseries)
			nohup python single.py  --column=${var} ${folder}/${basename}-${agg}-aggregated.nc4  | cat > ${csv_folder}/${basename}-${var}-${agg}-aggregated.csv
		done
	done
done



