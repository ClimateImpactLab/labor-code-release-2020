





setup <- function(){


	#Quickly installing packages

	list.of.packages <- c("dplyr","data.table", "glue", "ggplot2", "sf") #Put the name of your packages in strings here
	new.packages <- list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]
	if(length(new.packages)) install.packages(new.packages, repos = "http://cran.us.r-project.org")

	invisible(lapply(list.of.packages, library, character.only = TRUE))


}


setup()


load_data <- function(){ 

	shapefile_dir <- "/shares/gcp/estimation/labor/spatial_data/CHN/CHN_adm2_corrected.shp"

	data_dir <- "/shares/gcp/estimation/labor/time_use_data/intermediate/CHN_CHNS_time_use_with_missing_with_location.csv"

	shapefile <- st_read(shapefile_dir)

	data <- fread(data_dir)[,list(idind, occupation_primary, NAME_1, NAME_2)]

	data[,missing_occupation:=data[,occupation_primary] %in% c(NA,-9)]


	# obs_per_ind <- setkeyv(data[,list(sum_obs_per_id=.N),by=.(idind)], "idind")

	# setkeyv(data, "idind")

	# data = data[obs_per_ind]

	# mis_per_id <- setkeyv(data[,list(sum_missing_occ_per_id=sum(missing_occupation)),by=.(idind)], "idind")

	# data = data[mis_per_id]
	
	# missing_guys <- data[sum_missing_occ_per_id!=0]
	

	# sum(missing_guys[,sum_obs_per_id]!=missing_guys[,sum_missing_occ_per_id])



	# sum(data[,missing_occupation])

	# nrow(data)


	data_agg <- data[,.(missing_proportion=mean(missing_occupation)), by=list(NAME_1, NAME_2)]


	return(list(shapefile=shapefile, data=data.frame(data_agg)))

}



make_map <- function(){


	outputdir <- "/local/shsiang/Dropbox/Global ACP/labor/1_preparation/time_use/china/map_missing_occupation.png"

	list_datas <- load_data()

	shapefile <- list_datas$shapefile

	data <- list_datas$data 

	shapefile <- shapefile %>% arrange.sf(., NAME_1, NAME_2)

	data <- data %>% arrange(., NAME_1, NAME_2)

	shapefile_info <- left_join(x=shapefile, y=data) 

	#shapefile_info <- shapefile_info %>% filter(!is.na(missing_proportion))

	plot <- ggplot(data=shapefile_info) +
		geom_sf(aes(fill=missing_proportion)) +
		scale_fill_continuous(na.value="white") +
		ggtitle("proportion of missing-occupation observations per adm2 region")



	ggsave(plot, filename=outputdir)


}
