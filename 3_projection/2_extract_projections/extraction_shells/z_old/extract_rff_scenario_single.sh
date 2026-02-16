# do dos2unix path/to/this/file first!!
source ~/miniconda3/etc/profile.d/conda.sh
conda activate risingverse-py27
cd ~/repos/prospectus-tools/gcp/extract

for rcp in rcp45 rcp85
do
	folder=/shares/gcp/outputs/labor/impacts-woodwork/test_rff_scenario_single/median/${rcp}/CCSM4/rff/6546
	csv_folder=${folder}/csv
	mkdir -p ${csv_folder}

	# extract fulladapt and incadapt - need to subtract histclim
	for basename in uninteracted_main_model uninteracted_main_model-incadapt 
	do 
		for var in rebased lowriskimpacts highriskimpacts
		do 
			# pure outputs (mins per worker per day) (for mapping)
			nohup python -W ignore single.py  --column=${var} ${folder}/${basename}.nc4 -${folder}/uninteracted_main_model-histclim.nc4 | cat > ${csv_folder}/${basename}-${var}.csv

			# for agg in pop gdp wage 
			do 
				# levels output (for mapping)
				nohup python -W ignore single.py  --column=${var} ${folder}/${basename}-${agg}-levels.nc4 -${folder}/uninteracted_main_model-histclim-${agg}-levels.nc4 | cat > ${csv_folder}/${basename}-${var}-${agg}-levels.csv
				# aggregate output (for timeseries)
				nohup python -W ignore single.py  --column=${var} ${folder}/${basename}-${agg}-aggregated.nc4 -${folder}/uninteracted_main_model-histclim-${agg}-aggregated.nc4 | cat > ${csv_folder}/${basename}-${var}-${agg}-aggregated.csv
			done
		done
	done

	# extract noadapt - don't subtract histclim
	for basename in uninteracted_main_model-noadapt 
	do 
		for var in rebased lowriskimpacts highriskimpacts 
		do 
			# pure outputs (mins per worker per day) (for mapping)
			nohup python -W ignore single.py  --column=${var} ${folder}/${basename}.nc4 | cat > ${csv_folder}/${basename}-${var}.csv

			# for agg in pop wage 
			do 
				# levels output (for mapping)
				nohup python -W ignore single.py  --column=${var} ${folder}/${basename}-${agg}-levels.nc4  | cat > ${csv_folder}/${basename}-${var}-${agg}-levels.csv
				# aggregate output (for timeseries)
				nohup python -W ignore single.py  --column=${var} ${folder}/${basename}-${agg}-aggregated.nc4  | cat > ${csv_folder}/${basename}-${var}-${agg}-aggregated.csv
			done
		done
	done



	# extract riskshare
	for basename in uninteracted_main_model uninteracted_main_model-incadapt uninteracted_main_model-noadapt uninteracted_main_model-histclim 
	do 
		for var in clip
		do 
			nohup python -W ignore single.py  --column=${var} ${folder}/${basename}.nc4 | cat > ${csv_folder}/${basename}-${var}.csv
		done
	done
done

