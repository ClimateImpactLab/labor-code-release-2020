# diagnostic of labor impacts for particular regions using yellow_purple_package.R
# author: Emile Tenezakis, etenezakis@uchicago.edu
# date: 11/1/2019


#This script runs the yellow_purple_package.R code that produces a plot of impacts as a function of temperature,
 # and a table giving impact of days differential at each temperature bin

#Initial code was made for mortality. I added a function named get_response_labor() into the yellow_purple_package.R to 
# apply the package to labor. It computes response to temperature in labor settings. 
#labor impacts are measured in minutes of work lost (or gained) yearly or daily, per worker 

# REMEMBER TO SET KNOTS!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

#In the future this code will be changed to use the alternative to the for loop. Alternative is incomplete and commented out at the end of code. 
#------------------------------------------------------------------------------------------

# Temperature bounds is buggy - use the 'debug(function)'

REPO = '/home/nsharma/repos'

setup <- function(){

  #Quickly installing packages

  rm(list=ls())

  list.of.packages <- c("purrr", "rlist", "reshape", "data.table", "stringr", "glue") #Put the name of your packages in strings here
  new.packages <- list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]
  if(length(new.packages)) install.packages(new.packages, repos = "http://cran.us.r-project.org")

  invisible(lapply(list.of.packages, library, character.only = TRUE))

  cilpath.r:::cilpath()
  squish_function <- stringr::str_squish


  source(glue("{REPO}/post-projection-tools/response_function/yellow_purple_package.R"))
  source(glue("{REPO}/labor-code-release-2020/3_projection/3_diagnostics/deltabetas/get_curve_labor.R"))

}

setup()


paths <- function(interacted=FALSE){

    csvv.dir = "/shares/gcp/social/parameters/labor/post_replication/"
    csvv.name <- "labor_test_post_replication.csvv"
    # cov.dir = "/mnt/battuta_shares/gcp/outputs/labor/impacts-woodwork/single/rcp85/CCSM4/high/SSP3/combined-poly-allcalcs-labor_test_post_replication-highrisk.csv"
    output.dir <- "/local/shsiang/Dropbox/Global ACP/labor/3_projection/deltabetas/poly4/"

    return(list(csvv.dir=csvv.dir, csvv.name=csvv.name, output.dir=output.dir))
}

paths_spline_function  =  function(interacted=TRUE){

    # uninteracted main model
    # csvv.dir = glue("{REPO}/labor-code-release-2020/3_projection/1_run_projections/mc/")
    # csvv.name <- "uninteracted_main_model.csvv"
    # cov.dir = "/mnt/battuta_shares/gcp/outputs/labor/impacts-woodwork/test_rcc_copy/uninteracted_splines_27_37_39_by_risk_empshare_noFE_YearlyAverageDay/rcp85/CCSM4/high/SSP3/test_rcc_main_model_single_config-allcalcs-uninteracted_main_model.csv"
    # output.dir <- "/mnt/CIL_labor/3_projection/deltabetas/spline_27_37_39/uninteracted_main_model/"
    # knots <- c(27,37,39)

    # mixed model
    # csvv.dir = "/shares/gcp/social/parameters/labor/post_replication/"
    # csvv.name <- "combined_mixed_model_splines_empshare_noFE.csvv"
    # cov.dir = "/mnt/battuta_shares/gcp/outputs/labor/impacts-replicated-march-2020/single/rcp85/CCSM4/high/SSP3/combined-spline-allcalcs-labor_spline_interacted-highrisk.csv"
    # output.dir <- "/home/kschwarz/repos/labor-code-release-2020/output/diagnostics/deltabetas/hi_1factor_lo_unint_mixed_model/"
    # knots = c(27, 37, 39)

    # plankpose
    csvv.dir = "/shares/gcp/social/parameters/labor/post_replication/"
    csvv.name <- "hi_1factor_lo_unint_mixed_model_splines_empshare_noFE.csvv"
    cov.dir = "/mnt/battuta_shares/gcp/outputs/labor/impacts-woodwork/hi_1factor_lo_unint_mixed_model_plankpose/combined_mixed_splines_27_37_39_by_risk_empshare_noFE_YearlyAverageDay/rcp85/CCSM4/high/SSP3/hi_1factor_lo_unint_mixed_model_single_plankpose_config-allcalcs-hi_1factor_lo_unint_mixed_model_splines_empshare_noFE.csv"
    output.dir <- "{REPO}/labor-code-release-2020/output/diagnostics/deltabetas/plankpose/"
    knots = c(27, 37, 39)

    # with China model
    # csvv.dir = "/shares/gcp/social/parameters/labor/post_replication/"
    # csvv.name <- "uninteracted_main_model_w_chn.csvv"
    # cov.dir = "/mnt/battuta_shares/gcp/outputs/labor/impacts-replicated-march-2020/single/rcp85/CCSM4/high/SSP3/combined-spline-allcalcs-labor_spline_interacted-highrisk.csv"
    # output.dir <- "/mnt/CIL_labor/3_projection/deltabetas/spline_27_37_39/uninteracted_main_model_w_chn/"
    # knots <- c(21,37,41)

    return(list(csvv.dir=csvv.dir, csvv.name=csvv.name, output.dir=output.dir, cov.dir =cov.dir, knots=knots))
}

paths_interacted_poly4_function  =  function(interacted=TRUE){
    csvv.dir = "/shares/gcp/social/parameters/labor/post_replication/z_old/"
    csvv.name <- "labor_post_replication_interacted_poly4.csvv"
    cov.dir = "/mnt/battuta_shares/gcp/outputs/labor/impacts-replicated-march-2020/single/rcp85/CCSM4/high/SSP3/combined-spline-allcalcs-labor_spline_interacted-highrisk.csv"
    output.dir <- "/mnt/CIL_labor/3_projection/deltabetas/poly4_interacted/test/"
    return(list(csvv.dir=csvv.dir, csvv.name=csvv.name, output.dir=output.dir,cov.dir =cov.dir))
}



##Location map into readable strings 

location.dict = list()
location.dict[["USA.5.221"]] = 'USA, San Francisco'
# location.dict[["SWE.15"]] = 'SWE, Stockholm'
# location.dict[["IRN.14.148"]] = 'IRAN, Shush'
# location.dict[["USA.14.608"]] = 'USA, Chicago'
# location.dict[["NGA.25.510"]] = 'NGA, Lagos'
# location.dict[["IND.10.121.371"]] = 'IND, Delhi'
# location.dict[["POL.9.200"]] = 'Pol, Ostroleka City'
# location.dict[["GBR.1.108"]] = 'Gods own county aka toms hometown'
# location.dict[["SDN.6.16.75.230"]] = 'SDN, Ez Zeidab'
# location.dict[["MLI.9.49"]] = 'MLI, Niafunke'
# location.dict[["THA.3.R3edeff05b7928bfc"]] = 'THA, Bangkok' # subnode though
# location.dict[["ARE.3"]] = 'UAE, Dubai'
# location.dict[["EGY.16"]] = 'EGY, Aswan'
# location.dict[["SDN.6.15.73.226"]] = 'SDN, Wadi Halfa'
# location.dict[["CAN.2.33.913"]] = 'Vancouver, CAN'
# location.dict[["GBR.1.R7074136591e79d11"]] = 'London, GBR'
location.dict[["QAT.1"]] = 'Doha, QAT'
location.dict[["USA.2.70"]] = 'Anchorage, USA'
location.dict[["ZAF.8.263"]] = 'Bloemfontein, S Africa'

# resume here. find the zero diff IR in china
# location.dict[["CHN"]] = ', CHN'

# regions = c('CAN.2.33.913', 'GBR.1.R7074136591e79d11')
# regions = c('SDN.4.11.49.163', 'THA.3.R3edeff05b7928bfc', 'USA.5.221', 'CAN.3.50.1276')
# regions = c("USA.5.221", "SWE.15", "IRN.14.148", "USA.14.608")
regions = c("QAT.1", "USA.2.70", "ZAF.8.263", "USA.5.221")

# paths <- paths()
# sector <- "low"
# interacted <- F


# #Poly 4
# args = list(
#         sector=sector,
#         db.prefix=glue("deltabeta_{sector}_"),
#         regions=regions,
#         years=2099,
#         base_year=2015,
#         y.lim=c(-200, 50),
#         inc.adapt=F,
#         bound_to_hist=F,
#         csvv.dir = paths$csvv.dir,
#         csvv.name = paths$csvv.name,
#         #het.list = het.list,
#         #cov.dir=cov.dir, 
#         #covarkey = 'hierid', 
#         #filetype='dta',
#         func=get_curve_polynomial_labor, 
#         get.covariates=F, 
#         load.covariates=F,
#         # covar.names=c('tmean','loggdppc'), 
#         #list.names=c('climtas','loggdppc'), 
#         TT_lower_bound=-30,
#         TT_upper_bound=60,
#         TT_step = 1,
#         #x.lim=c(-30, 60),
#         bound_to_hist=F,
#         export.singles=F,
#         export.matrix=F,
#         delta.beta=T,
#         export.path=paths$output.dir,
#         ncname="1.1",
#         tas_value="tasmax",
#         location.dict=location.dict,
#         y.lab = "Change in work time",
#         interacted=FALSE)

# yp = do.call(generate_yellow_purple,args)


#Spline
paths_spline <- paths_spline_function()
sector = "low"


#####################################
####### plank pose delta beta #######
#####################################

for(region in regions) {
    args = list(
            sector=sector,
            db.prefix=glue("deltabeta_{sector}_"),
            regions=region,
            years=2099,
            base_year=2015,
            inc.adapt=T,
            csvv.dir = paths_spline$csvv.dir,
            csvv.name = paths_spline$csvv.name,
            cov.dir=paths_spline$cov.dir, 
            covarkey = "region", 
            filetype="csv",
            func=get_curve_rcspline_labor, 
            get.covariates=T, 
            load.covariates=T,
            covar.names=c("climtas", "loggdppc"),
            TT_lower_bound=-20,
            TT_upper_bound=60,
            x.lim=c(-30, 60),
            bound_to_hist=F,
            export.singles=F,
            export.matrix=F,
            delta.beta=T,
            csv=TRUE,
            export.path=paths_spline$output.dir,
            ncname="1.1",
            tas_value="tasmax",
            location.dict=location.dict,
            y.lab = "Change in work time",
            interacted='mixed_model')

    yp = do.call(generate_yellow_purple,args)
}

#####################################
###### mixed model delta beta ######
#####################################

# for(region in regions) {

# args = list(
#         sector=sector,
#         db.prefix=glue("deltabeta_{sector}_"),
#         regions=region,
#         years=2099,
#         base_year=2015,
#         #age=age,
#         #y.lim=c(-40, 40),
#         inc.adapt=T,
#         csvv.dir = paths_spline$csvv.dir,
#         csvv.name = paths_spline$csvv.name,
#         cov.dir=paths_spline$cov.dir, 
#         covarkey = "region", 
#         filetype="csv",
#         func=get_curve_rcspline_labor, 
#         get.covariates=T, 
#         load.covariates=T,
#         covar.names=c("climtasmax", "loggdppc"),
#         TT_lower_bound=-20,
#         TT_upper_bound=60,
#         x.lim=c(-30, 60),
#         bound_to_hist=F,
#         export.singles=F,
#         export.matrix=F,
#         delta.beta=T,
#         export.path=paths_spline$output.dir,
#         ncname="1.1",
#         tas_value="tasmax",
#         location.dict=NULL,
#         y.lab = "Change in work time",
#         interacted='mixed_model')

# yp = do.call(generate_yellow_purple,args)

# }

#####################################
#####################################

# for(region in regions) {
#     args =list(
#             sector=sector,
#             db.prefix=glue("deltabeta_{sector}"),
#             regions=region,
#             years=2099,
#             base_year=2015,
#             # y.lim=c(-10, 20),
#             inc.adapt=F,
#             bound_to_hist=F,
#             csvv.dir = paths_spline$csvv.dir,
#             csvv.name = paths_spline$csvv.name,
#             # cov.dir=paths_spline$cov.dir, 
#             # covarkey = "region", 
#             # filetype="csv",
#             func=get_curve_rcspline_labor, 
#             get.covariates=F, 
#             load.covariates=F,
#             # covar.names=c('tmean','loggdppc'), 
#             # list.names=c('climtas','loggdppc'), 
#             TT_lower_bound=-30,
#             TT_upper_bound=60,
#             TT_step = 1,
#             x.lim=c(-30, 60),
#             bound_to_hist=F,
#             export.singles=F,
#             export.matrix=F,
#             delta.beta=T,
#             export.path=paths_spline$output.dir,
#             ncname="1.1",
#             tas_value="tasmax",
#             location.dict=NULL,
#             y.lab = "Change in work time",
#             knots=paths_spline$knots,
#             interacted=F)

#     yp = do.call(generate_yellow_purple,args)
# }


#####################################
#####################################

# #interacted arguments - interacted poly 4 model
# # ONLY FEED IN ONE IR AT A TIME, IT BUGS OTHERWISE!!
# sector = "high"
# paths_inter_poly <- paths_interacted_poly4_function()
# # regions = c("ARE.3", "SSD.2.7.25.28")

# args = list(
#         sector=sector,
#         db.prefix=glue("deltabeta_{sector}_"),
#         regions="ARE.3",
#         years=2099,
#         base_year=2015,
#         #age=age,
#         #y.lim=c(-40, 40),
#         inc.adapt=T,
#         #mat.file=paste0('matrix_plot_age',age,'_incadapt'),
#         bound_to_hist=F,
#         csvv.dir = paths_inter_poly$csvv.dir,
#         csvv.name = paths_inter_poly$csvv.name,
#         cov.dir=paths_inter_poly$cov.dir, 
#         covarkey = "region", 
#         filetype="csv",
#         func=get_curve_poly4_interacted_labor, 
#         get.covariates=T, 
#         load.covariates=T,
#         covar.names=c("climtasmax", "loggdppc"),
#         TT_lower_bound=-20,
#         TT_upper_bound=60,
#         x.lim=c(-30, 60),
#         bound_to_hist=F,
#         export.singles=F,
#         export.matrix=F,
#         delta.beta=T,
#         export.path=paths_inter_poly$output.dir,
#         ncname="1.1",
#         tas_value="tasmax",
#         location.dict=NULL,
#         y.lab = "Change in work time",
#         interacted=TRUE)

# yp = do.call(generate_yellow_purple,args)


# test_covars <- load.covariates(
#     regions=c("ARE.3", "SSD.2.7.25.28"), 
#     years=c(2015,2040, 2099), 
#     cov.dir= paths_inter_poly$cov.dir,
#     covar.names=c("climtasmax", "loggdppc"), 
#     covarkey="region"
#     )
# test_covars
# test <- get.covariates(covars=test_covars, region="CAN.1.2.28", years=2015,
#     covar.names=c("climtasmax", "loggdppc"))


# test <- fread("/mnt/battuta_shares/gcp/outputs/labor/impacts-woodwork/single/rcp85/CCSM4/high/SSP3/combined-spline-allcalcs-labor_spline-highrisk.csv")
# test = fread(paths_inter_poly$cov.dir)
# test1 = read_csv(paths_inter_poly$cov.dir)