# do dos2unix path/to/this/file first!!
source ~/miniconda3/etc/profile.d/conda.sh
conda activate risingverse-py27
cd ~/repos/prospectus-tools/gcp/extract

folder=/mnt/battuta_shares/gcp/outputs/labor/impacts-woodwork/double_edge_restriction_single/median/rcp85/CCSM4/high/SSP3
csv_folder=${folder}/csv
mkdir -p ${csv_folder}

# extract fulladapt and incadapt - need to subtract histclim
for basename in clip_lrt_edge_restriction clip_lrt_edge_restriction-incadapt 
do 
	for var in rebased lowriskimpacts highriskimpacts
	do 
		# pure outputs (mins per worker per day) (for mapping)
		nohup python -W ignore single.py  --column=${var} ${folder}/${basename}.nc4 -${folder}/clip_lrt_edge_restriction-histclim.nc4 | cat > ${csv_folder}/${basename}-${var}.csv

		for agg in pop gdp wage 
		do 
			# levels output (for mapping)
			nohup python -W ignore single.py  --column=${var} ${folder}/${basename}-${agg}-levels.nc4 -${folder}/clip_lrt_edge_restriction-histclim-${agg}-levels.nc4 | cat > ${csv_folder}/${basename}-${var}-${agg}-levels.csv
			# aggregate output (for timeseries)
			nohup python -W ignore single.py  --column=${var} ${folder}/${basename}-${agg}-aggregated.nc4 -${folder}/clip_lrt_edge_restriction-histclim-${agg}-aggregated.nc4 | cat > ${csv_folder}/${basename}-${var}-${agg}-aggregated.csv
		done
	done
done

# extract noadapt - don't subtract histclim
for basename in clip_lrt_edge_restriction-noadapt 
do 
	for var in rebased lowriskimpacts highriskimpacts 
	do 
		# pure outputs (mins per worker per day) (for mapping)
		nohup python -W ignore single.py  --column=${var} ${folder}/${basename}.nc4 | cat > ${csv_folder}/${basename}-${var}.csv

		for agg in pop gdp wage 
		do 
			# levels output (for mapping)
			nohup python -W ignore single.py  --column=${var} ${folder}/${basename}-${agg}-levels.nc4  | cat > ${csv_folder}/${basename}-${var}-${agg}-levels.csv
			# aggregate output (for timeseries)
			nohup python -W ignore single.py  --column=${var} ${folder}/${basename}-${agg}-aggregated.nc4  | cat > ${csv_folder}/${basename}-${var}-${agg}-aggregated.csv
		done
	done
done



# extract riskshare - need to subtract histclim
for basename in clip_lrt_edge_restriction clip_lrt_edge_restriction-incadapt clip_lrt_edge_restriction-noadapt clip_lrt_edge_restriction-histclim 
do 
	for var in clip
	do 
		nohup python -W ignore single.py  --column=${var} ${folder}/${basename}.nc4 | cat > ${csv_folder}/${basename}-${var}.csv
	done
done


