#' nested comparison of a value from table, depending on dimensions within which we want to compare values
#' @param data data table, should contain a 'value' column, and at least the dimensions contained in the `within` parameter. 
#' @param within dimensions within which to make comparison
#' @param count logical
#' @param dotabulate logical
#' @param unique logical
#' @return integer vector of counts. It represents the tabulation of unique values for each comparison. Its length depends on `within`. 
NestedComparison <- function(data, impacts.folder='/shares/gcp/outputs/labor/impacts-woodwork/labor_mc_re-rebased',within=c('batch', 'rcp','gcm','iam','ssp'), unique=TRUE,dotabulate=TRUE, count=TRUE, precision=Inf){
	setkeyv(data, within)
	if(!is.infinite(precision)) data[,value:=round(value, precision)][]
	if(count){
		if(unique) {
			collapse <-data[,.(count=uniqueN(value)), by=within] #counts number of unique values by group. check out : 
			#data.table(value=c(1,1,1,1,2,4), group=c(1,1,1,2,2,2))[,.(count=uniqueN(value)), by=group]
		} else {
			collapse <-data[,.(count=.N), by=within]
		}
		if(!dotabulate) return(collapse)
		count <- tabulate(collapse[,count])
		names(count) <- as.character(1:length(count))
		return(count)
	} else {
		log <- copy(data)
		log[,within_duplicated:=duplicated(value), by=within][]
		if(!unique){
			return(log[within_duplicated==TRUE])
		} else {
			return(log)
		}
	}
}
DT <- fread(MORTALITYFILE)
NestedComparison(data=DT[region=='ABW' & year==2050 & adapt=='incadapt'], impacts.folder='/shares/gcp/outputs/mortality/impacts-darwin/montecarlo', within=c('rcp','gcm','iam','ssp'))
NestedComparison(data=DT[region=='ABW' & year==2050 & adapt=='noadapt'], impacts.folder='/shares/gcp/outputs/mortality/impacts-darwin/montecarlo', within=c('rcp','gcm','iam','ssp'))
NestedComparison(data=DT[region=='ABW' & year==2050 & adapt=='fulladapt'], impacts.folder='/shares/gcp/outputs/mortality/impacts-darwin/montecarlo', within=c('rcp','gcm','iam','ssp'))




