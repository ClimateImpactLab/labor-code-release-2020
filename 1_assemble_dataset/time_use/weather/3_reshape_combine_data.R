

setup <- function(){

  #clean the global environment
  rm(list=ls(pos=".GlobalEnv"), pos=".GlobalEnv")

  list.of.packages <- c("tictoc","parallel","reshape2", "data.table", "readstata13", "plyr", "dplyr", "gridExtra", "grid", "foreign", "tidyr", "glue") #Put the name of your packages in strings here
  new.packages <- list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]
  if(length(new.packages)) install.packages(new.packages, repos = "http://cran.us.r-project.org")

  invisible(lapply(list.of.packages, library, character.only = TRUE))

  cilpath.r:::cilpath()

  message(glue("date the code was ran : {Sys.Date()}"))
  message(glue("time the code was ran : {Sys.time()}"))

  tic("running time")

  }
setup()

source("/home/liruixue/repos/labor-code-release-2020/0_subroutines/paths.R")

paths <- function(ctry, admin){

  climate_data_dir = glue("{ROOT_INT_DATA}/climate")

  repodir = glue("{DIR_REPO_LABOR}/1_assemble_dataset/time_use/weather")

  csdir <- glue("{ROOT_INT_DATA}/crosswalks/shapefile_to_timeuse_crosswalk_{ctry}.csv")

  inputdir <- glue("{climate_data_dir}/raw/{ctry}/{admin}") #location of raw weather data

  outputdir <-  glue("{climate_data_dir}/final/{ctry}/{admin}") #location of reshaped-combined weather data, ready for merging

  if (dir.exists(outputdir)==FALSE){
    dir.create(outputdir)
  }

  
  return(list(csdir=csdir, inputdir=inputdir, outputdir=outputdir, repodir=repodir))

  }


get_transf <- function(t_version){

  # bins <- c() 
  polynomials <- c()
  prcp <- c()
  splines_nochn <- c()
  splines_wchn <- c()
  
  # long_run <- c()

  # create variable names

  # for (i in seq(-40, 59)){
    
  #   if (i<0){
  #     i <- abs(i)
      
  #     if (i==40){
  #       negative_limit <- glue("{t_version}_bins_nInf_n{i}C")
  #       bins <- c(bins, negative_limit)
  #       j <- i-1
  #       negative_limit <- glue("{t_version}_bins_n{i}C_n{j}C")
  #       bins <- c(bins, negative_limit)
  #     }
      
  #     else if (i==1){
  #       j <- i - 1
  #       negative_limit <- glue("{t_version}_bins_n{i}C_{j}C")
  #       bins <- c(bins, negative_limit)
  #     }
      
  #     else {
  #       j <- i - 1
  #       negative_name <- glue("{t_version}_bins_n{i}C_n{j}C")
  #       bins <- c(bins, negative_name)
  #     }
  #   }
    
  #   else{
  #     j <- i + 1 
  #     positive_name <- glue("{t_version}_bins_{i}C_{j}C")
  #     bins <- c(bins, positive_name)
      
  #     if (i==59){
  #       positive_limit <- glue("{t_version}_bins_{j}C_Inf")
  #       bins <- c(bins, positive_limit)
  #     }
  #   }
  # }

  for (k in c(1,2,3,4)){
    polyname <- glue("{t_version}_poly_{k}")
    polynomials <- c(polynomials, polyname)
  }


  for (k in c(1,2)){
    polyname <- glue("prcp_poly_{k}")
    prcp <- c(prcp, polyname)
  }


  for (i in c(0,1)){
    splines_nochn <- c(splines_nochn, glue("{t_version}_rcspline_3kn_27_37_39_term{i}"))
    splines_wchn <- c(splines_wchn, glue("{t_version}_rcspline_3kn_21_37_41_term{i}"))

  }




  # yearly <- c(glue("tmax_poly_1"), glue("tmax_hdd_10C"), glue("tmax_hdd_15C"), glue("tmax_hdd_20C"), glue("tmax_cdd_30C"))
  # yearly <- c(glue("tmax_poly_1"))


  # transformations <- list(bins=bins, polynomials=polynomials, polynomials_above_below=polynomials_above_below, prcp=prcp, splines=splines, splines_nochn = splines_nochn, splines_nochn_best = splines_nochn_best, yearly=yearly)
  transformations <- list(polynomials=polynomials, prcp=prcp, splines_nochn = splines_nochn, splines_wchn = splines_wchn)

  return(transformations)

  }


get_admin_names <- function(ctry, admin){


  p  = paths(ctry=ctry, admin=admin)
  param = fread(glue("{p$repodir}/aggregation_config_lines.csv"))
  
  admin_names = unlist(stringr:::str_extract_all(param[country==ctry & admin_level==admin, region_columns], "\\w+"))

  return(unique(admin_names))

  }


reshape <- function(ctry, transf, climate_source, admin, yearly){


  if (yearly==FALSE){

    print(glue("reshaping the daily data for country {ctry} and {transf} and admin level {admin}"))

    transf = as.character(transf)
    admin_names = get_admin_names(ctry=ctry, admin=admin)
    p = paths(ctry=ctry, admin=admin)
    file_name = list.files(glue("{p$inputdir}/weather_data/csv_daily/"), pattern=glob2rx(glue("{climate_source}_{transf}_v2*"))) #list file in path folder that fit pattern of "string"; wildcard expression to allow for changing dates (e.g. 2002_2012)
    print(glue("{p$inputdir}/weather_data/csv_daily/{file_name}"))
    dt = data.table(fread(glue("{p$inputdir}/weather_data/csv_daily/{file_name}"), stringsAsFactors=FALSE)) #open file

    #melt 
    dt = melt.data.table(dt, id.vars=admin_names, measure.vars=names(dt)[!(names(dt) %in% admin_names)], variable.name="day_of_sample", value.name=transf)

    print(glue("replacing ids through crosswalk"))

    cs = fread(p$csdir)

    admins_standard = c()
    for (i in seq(1,length(admin_names))){
      admins_standard = c(admins_standard, glue("adm{i}_id"))
    }
      admins_standard = ifelse(admin_names=="GID_3", "adm3_id",admins_standard)
      admins_standard = ifelse(admin_names=="DIST91_ID", "adm2_id",admins_standard)


    #Exceptions first...
    if (ctry=="GBR") { #GBR has to be aggregated

      setkeyv(dt, admin_names)

      cs = subset(cs, select=c(admin_names, admins_standard, "weight"))
      setkeyv(cs, admin_names)
      dt = dt[cs]
      dt = subset(dt, select=names(dt)[names(dt)!=admin_names])

      dt[,value:=dt[,transf, with=FALSE]]

      agg = dt[,.(mean_value=weighted.mean(value, w=weight)), by=c("day_of_sample", admins_standard)]

      ids = unique(subset(cs, select=admins_standard))

      setkeyv(ids, admins_standard)
      setkeyv(agg, admins_standard)

      dt <- ids[agg]

      setnames(dt, old="mean_value",new=transf)

    } else if (ctry=="MEX") { #Mexico has naming problems... exception again 

      setnames(dt, old="NOM_ENT", new="NOM_ENT_adm2")
      setkeyv(dt, names(dt)[1:2])
      cs <- subset(cs, select=c("NOM_ENT_adm2","NOM_MUN", "adm1_id", "adm2_id"))
      setkeyv(cs, c("NOM_ENT_adm2","NOM_MUN"))
      dt <- dt[cs]
      dt[,1:2] <- NULL

    } else if (ctry=="BRA") { #Brazil has same  problem... exception again

      setnames(dt, old="NAME_1", new="NAME_1_adm2")
      # browser()
      setkeyv(dt, names(dt)[1:2])
      cs <- subset(cs, select=c("NAME_1_adm2","NAME_2", "adm1_id", "adm2_id"))
      setkeyv(cs, c("NAME_1_adm2","NAME_2"))
      dt <- dt[cs]
      dt[,1:2] <- NULL

    } else { #rationalizable 
    

      setkeyv(dt, admin_names)
      cs = subset(cs, select=c(admin_names, admins_standard))
      cs = unique(cs)
      setkeyv(cs, admin_names)
      dt = dt[cs]
      dt = subset(dt, select=names(dt)[names(dt)!=admin_names])

      }


    dt[,year:=as.numeric(substr(day_of_sample,start=2,stop=5))][,month:=as.numeric(substr(day_of_sample,start=8,stop=9))][,day:=as.numeric(substr(day_of_sample,start=12,stop=13))][,day_of_sample:=NULL]
    print(glue("writing {p$outputdir}/{climate_source}_{ctry}_{transf}_{admin}.csv"))
    fwrite(dt, glue("{p$outputdir}/{climate_source}_{ctry}_{transf}_{admin}.csv"))

  }


  # if (yearly==TRUE) {

  #   print(glue("reshaping the yearly data for country {ctry} and {transf} and admin level {admin}"))

  #   transf = as.character(transf)

  #   admin_names = get_admin_names(ctry=ctry, admin=admin)
  #   p = paths(ctry=ctry, admin=admin)
  #   file_name = list.files(glue("{p$inputdir}/weather_data/csv_yearly/"), pattern=glob2rx(glue("{climate_source}_{transf}_v2*"))) #list file in path folder that fit pattern of "string"; wildcard expression to allow for changing dates (e.g. 2002_2012)
  #   dt = data.table(fread(glue("{p$inputdir}/weather_data/csv_yearly/{file_name}"), stringsAsFactors=FALSE)) #open file

  #   #melt 
  #   dt = melt.data.table(dt, id.vars=admin_names, measure.vars=names(dt)[!(names(dt) %in% admin_names)], variable.name="year_of_sample", value.name=transf)
  #   print(glue("taking the average across years"))
  #   dt[,value:=dt[,transf, with=FALSE]]
  #   dt <- dt[,.(agg=mean(value, na.rm=TRUE)), by=eval(names(dt)[1])] 
    
  #   print(glue("replacing ids through crosswalk yearly"))

  #   cs <- fread(p$csdir)

  #   admins_standard = c()
  #   for (i in seq(1,length(admin_names))){
  #     admins_standard = c(admins_standard, glue("adm{i}_id"))
  #   }

  #   if (ctry=="GBR") {
  #     setkeyv(dt, admin_names)

  #     cs = subset(cs, select=c(admin_names, admins_standard, "weight"))
  #     setkeyv(cs, admin_names)
  #     dt = dt[cs]
  #     dt = subset(dt, select=names(dt)[names(dt)!=admin_names])

  #     agg = dt[,.(agg=weighted.mean(agg,w=weight)), by=c(admins_standard)]

  #     ids = unique(subset(cs, select=admins_standard))
  #     setkey(ids, "adm1_id")
  #     setkey(agg, "adm1_id")

  #     dt <- ids[agg]
   
     
  #   } else if (ctry=="MEX") { #name problem 

  #     setnames(dt, old="NOM_ENT", new="NOM_ENT_adm1")
  #     setkeyv(dt, names(dt)[1])
  #     cs <- subset(cs, select=c("NOM_ENT_adm1", "adm1_id"))
  #     cs <- unique(cs)
  #     setkeyv(cs, "NOM_ENT_adm1")
  #     dt <- dt[cs]
  #     dt[,1] <- NULL  
   

  #   } else if (ctry=="BRA") { #name problem

  #     setnames(dt, old="NAME_1", new="NAME_1_adm1")
  #     setkeyv(dt, names(dt)[1])
  #     cs <- subset(cs, select=c("NAME_1_adm1", "adm1_id"))
  #     cs <- unique(cs)
  #     setkeyv(cs, "NAME_1_adm1")
  #     dt <- dt[cs]
  #     dt[,1] <- NULL    

  #   } else { #rationalized
  #     setkeyv(dt, admin_names)
  #     cs = subset(cs, select=c(admin_names, admins_standard))
  #     cs = unique(cs)
  #     setkeyv(cs, admin_names)
  #     dt = dt[cs]
  #     dt = subset(dt, select=names(dt)[names(dt)!=admin_names])

  #   }

      
  #   agg_value <- dt[,agg]
  #   dt <- subset(dt, select=admins_standard)
  #   dt[,(transf):=agg_value]

  #   fwrite(dt,glue("{p$outputdir}/{climate_source}_{ctry}_long_run_{transf}_{admin}.csv"))

  }
  
  return(message("done"))


  }


combine <- function(ctry, climate_source, admin, var, t_version){
  print("beginning")
  print(var)

  message(glue("combine for {var} combination and country {ctry} and admin {admin}"))

  admin_names = get_admin_names(ctry=ctry, admin=admin)
  admins_standard = c()

  for (i in seq(1,length(admin_names))){
    admins_standard = c(admins_standard, glue("adm{i}_id"))
  }
  admins_standard = ifelse(admin_names=="GID_3", "adm3_id",admins_standard)
  admins_standard = ifelse(admin_names=="DIST91_ID", "adm2_id",admins_standard)


  p = paths(ctry=ctry, admin=admin)

  transf = unlist(transf_list[names(transf_list)==var])
  print("transf")
  print(transf)

  for (t in transf){
    print("t")
    print(t)
    file = ifelse(var=="yearly", glue("{climate_source}_{ctry}_long_run_{t}_{admin}.csv"), glue("{climate_source}_{ctry}_{t}_{admin}.csv"))
  
    print(file)
    dt = data.table(fread(glue("{p$outputdir}/{file}")))

    if (t==transf[1]){
      ms = dt
    } 

    if (t!=transf[1]){
      
      if (var=="yearly"){
        setkeyv(ms, cols=admins_standard)
        setkeyv(dt, cols=admins_standard)
      } else{
        setkeyv(ms, cols=c(admins_standard, "year", "month", "day"))
        setkeyv(dt, cols=c(admins_standard, "year", "month", "day"))
      }

      dt_var = subset(dt, select=t)
      ms = cbind(ms, dt_var)
    } 
    print("end of loop")

  }


  print("var")
  print(var)
  var = ifelse(var %in% c("polynomials", "splines_nochn","splines_wchn"), glue("{t_version}_{var}"), glue("{var}"))
  print(var)
  print("here")
  # print(var)
  # message(var)
  print(glue("{p$outputdir}/{climate_source}_{ctry}_{var}_{admin}.csv"))
  fwrite(ms, glue("{p$outputdir}/{climate_source}_{ctry}_{var}_{admin}.csv"))

  print("done")



  if (var==glue("{t_version}_bins")){
    
    below_zero_bins <- transf[1:41]

    for (b in below_zero_bins){

      string = glue("{climate_source}_{ctry}_{b}_{admin}.csv")

      file <- list.files(p$outputdir, pattern=glob2rx(string)) #list file in path folder that fit pattern of "string"; wildcard expression to allow for changing dates (e.g. 2002_2012)

      dt <- data.table(fread(glue("{p$outputdir}/{file}")))

      if (b==below_zero_bins[1]){
        ms = dt
      } 

      if (b!=below_zero_bins[1]){
        setkeyv(ms, cols=c(admins_standard, "year", "month", "day"))
        setkeyv(dt, cols=c(admins_standard, "year", "month", "day"))
        dt_var = subset(dt, select=b)
        ms = cbind(ms, dt_var)
      } 

    }

    setkeyv(ms, cols=c(admins_standard, "year", "month", "day"))

    keys = subset(ms, select=c(admins_standard, "year", "month", "day"))

    ms[,c(admins_standard, "year", "month", "day"):=NULL]
    ms = cbind(keys, ms)

    bins <- subset(ms, select=below_zero_bins)

    below_zero_bin <- data.table(below0=rowSums(bins))

    ms_ids <- subset(ms, select=c(admins_standard, "year", "month", "day"))

    done <- cbind(ms_ids, below_zero_bin)

    fwrite(done, glue("{p$outputdir}/{climate_source}_{ctry}_{t_version}_below_zero_bin_{admin}.csv"))

    print("done")

  }


  }



rename <- function(ctry, climate_source, admin, t_version='tmax', rename_splines_nochn,rename_splines_wchn, rename_precip, rename_polynomials){

  print(glue("renaming {ctry}"))
  paths = paths(ctry=ctry,admin=admin)

  polynomials_new <- c()
  prcp_new <- c()
  splines_nochn_new <- c()
  splines_wchn_new <- c()
  
  # long_run_new <- c()


  for (k in c(1,2,3,4)){
    polyname <- glue("{t_version}_p{k}")
    polynomials_new <- c(polynomials_new, polyname)
  }


  for (k in c(1,2)){
    polyname <- glue("precip_p{k}")
    prcp_new <- c(prcp_new, polyname)
  }


  for (i in c(0,1)){
    splines_nochn_new <- c(splines_nochn_new, glue("{t_version}_rcspl_27_37_39_3kn_t{i}"))
    splines_wchn_new <- c(splines_wchn_new, glue("{t_version}_rcspl_21_37_41_3kn_t{i}"))
     
  }

  # if (rename_long_run==TRUE) {
  #   #long_run_new <- c("lr_tmax_p1", "lr_tmax_hdd_10C", "lr_tmax_hdd_15C", "lr_tmax_hdd_20C", "lr_tmax_cdd_30C")
  #   long_run_new <- c("lr_tmax_p1")
    
  #   long_run_dt <- fread(glue("{paths$outputdir}/{climate_source}_{ctry}_yearly_{admin}.csv"))
  #   setnames(long_run_dt, old=transf_list$yearly, new=long_run_new)
  #   haven::write_dta(long_run_dt, glue("{paths$outputdir}/{climate_source}_{ctry}_long_run_{admin}.dta"))
  # }


  if (rename_splines_nochn==TRUE) {
    splines_nochn_dt <- fread(glue("{paths$outputdir}/{climate_source}_{ctry}_{t_version}_splines_nochn_{admin}.csv"))
    setnames(splines_nochn_dt, old=transf_list$splines_nochn, new=splines_nochn_new)
    haven::write_dta(splines_nochn_dt, glue("{paths$outputdir}/{climate_source}_{ctry}_{t_version}_splines_nochn_{admin}.dta"))

  }

  if (rename_splines_wchn==TRUE) {
    splines_wchn_dt <- fread(glue("{paths$outputdir}/{climate_source}_{ctry}_{t_version}_splines_wchn_{admin}.csv"))
    setnames(splines_wchn_dt, old=transf_list$splines_wchn, new=splines_wchn_new)
    haven::write_dta(splines_wchn_dt, glue("{paths$outputdir}/{climate_source}_{ctry}_{t_version}_splines_wchn_{admin}.dta"))

  }

  if (rename_precip==TRUE) {
    prcp_dt <- fread(glue("{paths$outputdir}/{climate_source}_{ctry}_prcp_{admin}.csv"))
    setnames(prcp_dt, old=transf_list$prcp, new=prcp_new)
    haven::write_dta(prcp_dt, glue("{paths$outputdir}/{climate_source}_{ctry}_prcp_{admin}.dta"))

  }

  if (rename_polynomials==TRUE) {
    polynomials_dt <- fread(glue("{paths$outputdir}/{climate_source}_{ctry}_{t_version}_polynomials_{admin}.csv"))
    setnames(polynomials_dt, old=transf_list$polynomials, new=polynomials_new)
    haven::write_dta(polynomials_dt, glue("{paths$outputdir}/{climate_source}_{ctry}_{t_version}_polynomials_{admin}.dta"))
  }


  # if (rename_bins==TRUE) {
  #   bins <- fread(glue("{paths$outputdir}/{climate_source}_{ctry}_{t_version}_bins_{admin}.csv"))
  #   haven::write_dta(bins, glue("{paths$outputdir}/{climate_source}_{ctry}_{t_version}_bins_{admin}.dta"))

  # }

  return("renamed stuff")
  }



check_duplicates <- function(ctry, climate_source, variable, admin){

  paths <- paths(ctry=ctry)


  dt <- data.table(haven::read_dta(glue("{paths$outputdir}/{climate_source}_{ctry}_below_zero_bin.dta")))
  dt_sub_dates <- dt[,list(adm2_id, year, month, day)]
  dt_sub_dates_N <- nrow(dt_sub_dates)
  dt_sub_dates_unique_N <- nrow(unique(dt_sub_dates))


  message(glue("there are {dt_sub_dates_unique_N} unique dates and {dt_sub_dates_N} dates in the splines adm2 file for country {ctry}"))
 
  return("done")


  }

remove_csvs <- function (ctry, climate_source, variable, admin){

}


# reshape and aggregate for daily vars
t_version_list = c('tmax')
###### change the number!!!
countries <- vector(mode = "list", length = 8)
###### use the correct set of countries! for no chn splines use second line
names(countries) <- c('GBR','FRA','ESP','IND','CHN','USA','MEX','BRA')
# names(countries) <- c('BRA','GBR','FRA','ESP','IND','USA','MEX')

countries$BRA <- "adm2"
countries$GBR <- "adm1"
countries$FRA <- "adm1"
countries$ESP <- "adm1"
countries$IND <- "adm2"
# for no chn splines comment out the following line!
countries$CHN <- "adm3"
countries$USA <- "adm2"
countries$MEX <- "adm2"

# splines_nochn should be run separately! 
transf_columns <- c("splines_nochn","splines_wchn","polynomials", "prcp")
# transf_columns <- c("splines","polynomials","polynomials_above_below")
# transf_columns <- c("bins")
# transf_columns <- c("splines_wchn")

for (country in names(countries)) {
  for (t in t_version_list) {
       
    transf_list = get_transf(t_version=t)
    climate_source = "GMFD"
    admin = countries[names(countries) == country][[1]]

    # reshaping
    args = expand.grid(climate_source=climate_source,ctry=country, transf=unlist(transf_list[names(transf_list) %in% transf_columns]), admin=admin, yearly=FALSE)
    # browser()
    mcmapply(FUN=reshape, ctry=args$ctry, transf=args$transf, climate_source=args$climate_source, admin=args$admin, yearly=args$yearly, mc.cores=1)
  }
}

for (country in names(countries)) {
  for (t in t_version_list) {
       
    transf_list = get_transf(t_version=t)
    climate_source = "GMFD"
    admin = countries[names(countries) == country][[1]]

    # combining
    args = expand.grid(climate_source=climate_source,ctry=country, var=transf_columns, admin=admin, t_version=t)
    mcmapply(combine, ctry=args$ctry, climate_source=args$climate_source, var=args$var, admin=args$admin, t_version=args$t_version, mc.cores=1)

    # renaming
    rename(climate_source=climate_source,ctry=country, rename_splines_nochn=FALSE,rename_splines_wchn=TRUE, rename_precip=FALSE, rename_polynomials=FALSE,admin=admin, t_version=t)
  }
}




# reshape and aggregate for yearly vars

# t_version_list = c('tmax')
# countries <- vector(mode = "list", length = 8)
# ###### use the correct set of countries! for no chn splines use second line
# names(countries) <- c('GBR','FRA','ESP','IND','CHN','USA','MEX','BRA')
# # names(countries) <- c('GBR','FRA','ESP','IND','USA','MEX','BRA')

# countries$GBR <- "adm1"
# countries$FRA <- "adm1"
# countries$ESP <- "adm1"
# countries$IND <- "adm1"
# # for no chn splines comment out the following line!
# countries$CHN <- "adm1"
# countries$USA <- "adm1"
# countries$MEX <- "adm1"
# countries$BRA <- "adm1"

# transf_columns <- c("yearly")

# for (country in names(countries)) {
#   for (t in t_version_list) {
       
#     transf_list = get_transf(t_version=t)
#     climate_source = "GMFD"
#     admin = countries[names(countries) == country][[1]]

#     # reshaping
#     args = expand.grid(climate_source=climate_source,ctry=country, transf=unlist(transf_list[names(transf_list) %in% transf_columns]), admin=admin, yearly=TRUE)
#     args <- args %>% filter(args$transf == "tmax_poly_1")
#     mcmapply(FUN=reshape, ctry=args$ctry, transf=args$transf, climate_source=args$climate_source, admin=args$admin, yearly=args$yearly, mc.cores=2)

#     # combining
#     args = expand.grid(climate_source=climate_source,ctry=country, var=transf_columns, admin=admin, t_version=t)

#     #There is a problem with precip....
#     mcmapply(combine, ctry=args$ctry, climate_source=args$climate_source, var=args$var, admin=args$admin, t_version=args$t_version, mc.cores=2)

#     # renaming
#     rename(climate_source=climate_source,ctry=country, rename_splines=FALSE, rename_splines_nochn=FALSE, rename_precip=FALSE, rename_polynomials=FALSE, rename_long_run=TRUE, rename_bins=FALSE, rename_below0=FALSE,admin=admin, t_version=t)
#   }
# }
