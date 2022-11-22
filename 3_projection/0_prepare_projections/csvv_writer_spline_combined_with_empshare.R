# Combines csvv from employment share and time use regressions, for use in a combined projection!
# Works by reading the existing CSVVs - so make sure they are up to date before using this code
# Two csvv types can be produced using this code - spline combined with empshare with continent FEs, or without FEs. 
# change the string FE to determine which one

rm(list = ls())
library(stringr)
library(dplyr)

# set up paths
REPO = '/home/nsharma/repos'
lab_repo = paste0(REPO, "/labor-code-release-2020")
csvv_dir = paste0(lab_repo, "/3_projection/1_run_projections/single_test_correct_rebasing/")
pp_tools_repo = "~/repos/post-projection-tools/"

# Source dylan's YP package, to get the read.csvv function
source(paste0(pp_tools_repo, "response_function/yellow_purple_package.R"))

# Option for type of FE in employment shares - options are "noFE" or "continentFE"
FE = "noFE"

# Option for choosing interacted/uninteracted regression - options are "interacted" or "uninteracted"
interaction = "uninteracted"
weight = "risk_adj_sample_wgt"

csvv_name_spline = glue("uninteracted_reg_comlohi_risk_adj_sample_wgt.csvv")
csvv_name_empshare = paste0("labor_empshare_", FE, ".csvv")


##############################################
# 1 . Read in CSVV files 
##############################################


# Function for formatting the csvv information, returning a list of the stuff we need for the csvv
get_csvv =function(dir, name) {
  
  file = paste0(dir,name)

  csvv = read.csvv(filepath = file, vars=c('gamma','prednames','covarnames'))
  csvv_vcv = read.csvv(filepath =file, vars=c('gammavcv')) %>% as.data.frame()
  nobs = read.csvv(filepath =file, vars=c('observations')) %>% as.data.frame()
  residvcv = read.csvv(filepath =file, vars=c('residvcv')) %>% as.data.frame()

  return(c(csvv, csvv_vcv, nobs, residvcv))
}

# Don't worry about the warning message from readLines here
spline = get_csvv(dir = csvv_dir, name = csvv_name_spline)
num_coef_spline = length(spline$V1)

empshare = get_csvv(dir = csvv_dir, name = csvv_name_empshare)
num_coef_empshare = length(empshare$V1)


##############################################
# 2 . Get a nice list of prednames, covar names, and gammas
##############################################

observations = 
    as.numeric(levels(spline$observations))[spline$observations] + 
    as.numeric(levels(empshare$observations))[empshare$observations]

list_preds = paste0(
                paste(unlist(spline$prednames), collapse=', '), 
                ', ',
                paste(unlist(empshare$prednames), collapse=', '))

list_covars = paste0( 
                paste(unlist(spline$covarnames), collapse=', '), 
                  ', ',
                paste(unlist(empshare$covarnames), collapse=', '))

# replace variable name in the empshare csvv with the one we need for joint projection:
list_covars = str_replace_all(list_covars, "climmeantas", "climtas")

list_gammas = paste0(
                paste(unlist(spline$gamma), collapse=', '), 
                ', ',
                paste(unlist(empshare$gamma), collapse=', '))

residvcv =
  as.numeric(spline$residvcv) * as.numeric(empshare$residvcv)



##############################################
# 3 . Get the vcv matrix, which is block diagonal
##############################################
vcv = c()
for(i in 1:num_coef_spline){
  vcv_row = paste0(
    paste(unlist(spline[paste0("V", i)]), collapse=', '), 
    ', ',
    paste(rep(0, num_coef_empshare), collapse=', '))
  

    vcv = c(vcv, vcv_row)
}

for(j in 1:(num_coef_empshare)){
  print(j)
  
  vcv_row = paste0(
    paste(rep(0, num_coef_spline), collapse=', '),
    ', ',
    paste(unlist(empshare[paste0("V", j)]), collapse=', '))
  print(vcv_row)

  vcv = c(vcv, vcv_row)
}

if(FE == "continentFE"){
  FE_desc = c(
  "  continent-america: dummy variable for north and south America [NA]",
  "  continent-asia: dummy variable for Asia and Oceania [NA]",
  "  continent-europe: dummy variable for Europe [NA]", 
  "...")
}else{
  FE_desc = "..."
}


##############################################
# 4 . Use the info to write the csvv!
##############################################

# Initiate the file
fileConn<-file(paste0(csvv_dir,"uninteracted_main_model_new.csvv"))

# Write the csvv!
writeLines(
  c(
    "---",
    paste0("oneline: Labor ", interaction, " regression restricted cubic spline term (3 knots), located at 21_37_41. Empshare with ", FE), 
     
    paste0("version: LABOR-", str_to_upper(interaction), "-RCSPLINE-3KNOTS-COMBINED-EMPSHARE-Knots-21_37_41.-",FE),
      
    paste0( "description: Generated from labor ", interaction, " regression with restricted cubic spline, 3 knots.",
             "The first 2 gammas are for the low-risk sector. The next 2 for the high-risk sector.",
             "The remaining gammas are from the employment shares projection, with ", FE),
      
    paste0("dependencies: ", csvv_name_spline, " and ",csvv_name_empshare ), 
     
    "csvv-version: girdin-2017-01-10", 
    
    "variables:",
    "  tasmax: daily maximum temperature [C]",
    "  tasmax_rcspline1: restricted cubic spline term of daily max temperature [C^3]",
    "  climtasmax: long run average daily maximum temperature [C]",
    "  outcome: labor productivity [minutes worked by individual]",
    "  loggdppc: 15-year moving average of log GDP per capita [log USD2000]",
    "  climtas: poly 1 daily mean temperature, population weighted to aggregate to IR level, then averaged for 15 years [C]",
    "  climtas-poly-2: poly 2 daily mean temperature, population weighted to aggregate to IR level, then averaged for 15 years [C^2]",
    "  climtas-poly-3: poly 3 daily mean temperature, population weighted to aggregate to IR level, then averaged for 15 years [C^3]",
    "  climtas-poly-4: poly 4 daily mean temperature, population weighted to aggregate to IR level, then averaged for 15 years [C^4]",
    "  outcome: share of high-risk labor [unitless]",
    
    FE_desc,
    
    "observations", 
    observations, 
  
    "prednames",
    list_preds, 
    
    "covarnames",
    list_covars,

    "gamma",
    list_gammas, 
  
    "gammavcv", 
    vcv,
    
    "residvcv", 
    residvcv),
    
    fileConn)

close(fileConn)
print(paste0(csvv_dir,"uninteracted_main_model_new.csvv"))

