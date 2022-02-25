rm(list=ls())
library(glue)
library(parallel)
library(vroom)

REPO <- "/home/liruixue/repos"

source(glue("{REPO}/mortality/utils/wrap_mapply.R"))

source(glue("{REPO}/labor-code-release-2020/4_post_projection/UN_press_release_stuff/labor_outreach_data.R"))


# # testing function
# out = ProcessImpacts(
#   time_step="all",
#   impact_type="impacts_pct_gdp",
#   resolution="global", 
#   rcp="rcp85",
#   stats="q17",
#   risk_type = "allrisk",
#   export = TRUE)


##########################################################
# aggregated
out = wrap_mapply(  
  time_step=c("all", "averaged"),
  impact_type=c("impacts_pct_gdp"),
  resolution=c("states","global","iso"), 
  rcp=c("rcp45", "rcp85"),
  stats=c("mean", "q5", "q17", "q50", "q83", "q95"),
  risk_type = c("allrisk"),
  export = TRUE,
  FUN=ProcessImpacts,
  mc.cores=30,
  mc.silent=FALSE
)

out = wrap_mapply(  
  time_step=c("all", "averaged"),
  impact_type=c("impacts_mins_worked"),
  resolution=c("states","global","iso"), 
  rcp=c("rcp45", "rcp85"),
  stats=c("mean", "q5", "q17", "q50", "q83", "q95"),
  risk_type = c("highrisk", "lowrisk"),
  export = TRUE,
  FUN=ProcessImpacts,
  mc.cores=30,
  mc.silent=FALSE
)

# IR level
out = wrap_mapply(  
  time_step=c("all", "averaged"),
  impact_type=c("impacts_pct_gdp"),
  resolution=c( "all_IRs"), 
  rcp=c("rcp45", "rcp85"),
  stats=c("mean", "q5", "q17", "q50", "q83", "q95"),
  risk_type = c("allrisk"),
  export = TRUE,
  FUN=ProcessImpacts,
  mc.cores=40,
  mc.silent=FALSE
)

out = wrap_mapply(  
  time_step=c("all", "averaged"),
  impact_type=c("impacts_mins_worked"),
  resolution=c("all_IRs"), 
  rcp=c("rcp45", "rcp85"),
  stats=c("mean", "q5", "q17", "q50", "q83", "q95"),
  risk_type = c("highrisk", "lowrisk"),
  export = TRUE,
  FUN=ProcessImpacts,
  mc.cores=40,
  mc.silent=FALSE
)





# filter 500k cities from all IR level files

path = "/mnt/CIL_labor/outreach/UN/"
setwd(path)

all_IRs_files = list.files(path = path, 
                           pattern = "geography_impact_regions",
                           recursive = TRUE,
                           include.dirs = TRUE)

cities_500k = read_csv("~/repos/energy-code-release-2020/data/500k_cities.csv")	%>% 
  select(city, country, Region_ID)

cities_500k_regions = unlist(cities_500k$Region_ID)

filter_500k_cities <- function(path, overwrite, cities_500k_arg = cities_500k, cities_500k_regions_arg = cities_500k_regions) {
  save_path = gsub("impact_regions", "500kcities", path)
  print(save_path)  
  # browser()
  if ((!file.exists(save_path)) || overwrite ) {
    dir.create(dirname(save_path), recursive = TRUE, showWarnings = FALSE)
    print("generating")
    dt = vroom(path)
    dt = dt %>% filter(Region_ID %in% cities_500k_regions_arg) 
    dt=setkey(as.data.table(dt),Region_ID)
    cities_500k_lookup = setkey(as.data.table(cities_500k_arg), Region_ID)
    merged = merge(cities_500k_arg, dt)
    write_csv(dt, save_path)
    return(dt)
  }
  else return(glue("{save_path} exists"))
}

# testing function
dt = filter_500k_cities(all_IRs_files[3], cities_500k, cities_500k_regions)

# run over all files
out = wrap_mapply(  
  path = all_IRs_files,
  overwrite = TRUE,
  FUN=filter_500k_cities,
  mc.cores=40,
  mc.silent=FALSE
)




# convert to hours/year 
# change in hours worked/worker/year = (change in minutes worked/worker/day)*365/60

path = "/mnt/CIL_labor/outreach/UN/"
setwd(path)

all_mins_files = list.files(path = path, 
                           pattern = "*impacts_mins*",
                           recursive = TRUE,
                           include.dirs = TRUE)


convert_to_hours_per_year <- function(path, overwrite = TRUE) {
  save_path = gsub("impacts_mins", "impacts_hours", path)
  print(save_path)  
  # browser()
  if ((!file.exists(save_path)) || overwrite ) {
    dir.create(dirname(save_path), recursive = TRUE, showWarnings = FALSE)
    print("generating")
    dt = vroom(path)
    dt = dt %>% mutate_if(is.numeric, ~ .*365/60)
    write_csv(dt, save_path)
    return(dt)
  }
  else return(glue("{save_path} exists"))
}

# testing function
dt = convert_to_hours_per_year(all_mins_files[3])

# run over all files
out = wrap_mapply(  
  path = all_mins_files,
  overwrite = TRUE,
  FUN=convert_to_hours_per_year,
  mc.cores=40,
  mc.silent=FALSE
)



