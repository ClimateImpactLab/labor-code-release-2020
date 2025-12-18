#########################################################################################################################

  # This code sets the function to compute the response of daily minutes worked to temperature, 
  # using estimates from the restricted cubic spline regression.


  # The function written here is used by yellow_purple_package.R in its home repository, for delta beta analysis.


  # It is an argument in the call of the latter in yellow_purple_script.R.
  # spline is set up for interacted surface

  # Author : Emile 02/19/2020


  ########################################################
library(Hmisc)


get.cov.labor <- function(cov.list, cov, adapt){


  if (adapt== "full") {

    return(cov.list[[cov]][2])

  } else if (adapt== "no") {

    return(cov.list[[cov]][1])

  } else if (adapt=="clim") {


    if (cov == "loggdppc") {
      return(cov.list[[cov]][1])
    } else {
      return(cov.list[[cov]][2])
    }


  } else if (adapt=="income") {

    if (cov == "loggdppc") {
      return(cov.list[[cov]][2])
    } else {
      return(cov.list[[cov]][1])
    }


  }


}


# remove the else statement for the below zero bin
# change to 8 coefficients 
# TT is the temperature range vector - for the whole delta beta situation


get_curve_polynomial_labor <- function(interacted = FALSE, TT_lower_bound=-23, TT_upper_bound=45, 
  year, region, sector, csvv, adapt="full", TT_step = 1, ...){

  # print(TT_step)
  TT=as.numeric(seq(TT_lower_bound, TT_upper_bound, TT_step / 2))

  if (sector=="low") { 
    
  coef <- c(csvv[1:4, "gamma"])
  }
  else {
    coef <- c(csvv[5:8, "gamma"])
  }

  response_27C <- coef[1] * 27 + coef[2] * (27^2) + coef[3] * (27^3) + coef[4] * (27^4)
  
  compute_at_T <- function(T){
    
      response <- coef[1] * T + coef[2] * (T^2) + 
        coef[3] * (T^3) + coef[4] * (T^4) - response_27C
      
  }
  
  
  responses = unlist(lapply(FUN=compute_at_T, X=TT))
  
  # note - check format of responses
    # otherwise will bug at plotting
  return(format.curve(curve=responses, TT=TT, year=year, region=region, base_year=2015, adapt=adapt))
  
}


# This functino needs updating to be able to do multiple regions at the same time
get_curve_poly4_interacted_labor <- function(covars, base_year, 
  TT_lower_bound=-23, TT_upper_bound=45, 
  year, region, sector, csvv, adapt="full", TT_step = 1, ...){

  # browser()
  # print(TT_step)
  TT=as.numeric(seq(TT_lower_bound, TT_upper_bound, TT_step / 2))
  ref <- rep(27, length(TT))

  adapt_year <- year
  covars <- data.table(covars)
  region_name = region
  covars = covars[region==region_name]
  covars_year <- covars[year==adapt_year]
  covars_base_year <- covars[year==base_year]

  # Extract the relevant covariates 
  if (adapt== "full") {
      climtasmax <- covars_year[,climtasmax]
      loggdppc <- covars_year[,loggdppc]
  } else if (adapt== "no") {
      climtasmax <- covars_base_year[,climtasmax]
      loggdppc <- covars_base_year[,loggdppc]
  } else if (adapt=="clim") {
      climtasmax <- covars_year[,climtasmax]
      loggdppc <- covars_base_year[,loggdppc]
  } else if (adapt=="income") {
      climtasmax <- covars_base_year[,climtasmax]
      loggdppc <- covars_year[,loggdppc] 
  }

  climtasmax = as.numeric(gsub("\\[|]","",climtasmax))
  loggdppc = as.numeric(gsub("\\[|]","",loggdppc))

  # 
  if (sector=="low") { 
    coef_tasmax <- csvv[1:4, "gamma"]
    coef_tasmax_climtasmax <- csvv[5:8, "gamma"]
    coef_tasmax_loggdppc <- csvv[9:12, "gamma"]
  } else {
    coef_tasmax <- csvv[13:16, "gamma"]
    coef_tasmax_climtasmax <- csvv[17:20, "gamma"]
    coef_tasmax_loggdppc <- csvv[21:24, "gamma"]
  }
  response_ref = rep(0, length(TT))
  responses= rep(0, length(TT))

  # Loop over the polynomial order, adding in the terms
  for(i in 1:4){

    response_ref = response_ref + coef_tasmax[i] * ref ^ i + 
                      coef_tasmax_climtasmax[i] * ref ^ i * climtasmax + 
                      coef_tasmax_loggdppc[i] * ref ^ i * loggdppc
    
    responses <-  responses + coef_tasmax[i] * TT ^ i + 
                      coef_tasmax_climtasmax[i] * TT ^ i * climtasmax + 
                      coef_tasmax_loggdppc[i] * TT ^ i * loggdppc
  }
  responses = as.numeric(responses - response_ref)
  
  # message("responses are")
  # message(responses)

  return(format.curve(curve=responses, TT=TT, year=year, 
            region=region, base_year=base_year, adapt=adapt))
  
}





get_curve_rcspline_labor <- function(covars, interacted = FALSE, base_year=2010,TT_lower_bound=-23, 
  TT_upper_bound=45, year, region, sector, csvv, adapt="full", knots=c(27, 37, 39), ...){

  # old knots... 
  # kn <- c(11.6, 26.8, 35.2)
  
  # kn <- c(16.6, 30.3, 36.6)
  # kn <- knots
  # kn <- c(21,37,41)
  kn <- knots

  TT=seq(TT_lower_bound, TT_upper_bound, 0.5)

  ref <- rep(27, length(TT))

  TT_spline <- as.numeric(rcspline.eval(x=TT, knots=kn, norm=0))
  ref_spline <- as.numeric(rcspline.eval(x=ref, knots=kn, norm=0))


  if (interacted==F){


    if (sector=="low") { 
      coef_tasmax <- csvv[1, "gamma"]
      coef_tasmax_rcs <- csvv[2, "gamma"]
    }

    else {
      coef_tasmax <- csvv[3, "gamma"]
      coef_tasmax_rcs <- csvv[4, "gamma"]
    }

    response_ref <- coef_tasmax * ref + coef_tasmax_rcs * ref_spline

    responses <- as.numeric(coef_tasmax * TT + coef_tasmax_rcs * (TT_spline) - response_ref)
    

  }

  else if (interacted==T){

    adapt_year <- year
    covars <- data.table(covars)
    covars_year <- covars[year==adapt_year]
    covars_base_year <- covars[year==base_year]


    if (adapt== "full") {

        climtasmax <- covars_year[,climtasmax]
        loggdppc <- covars_year[,loggdppc]


      } else if (adapt== "no") {

        climtasmax <- covars_base_year[,climtasmax]
        loggdppc <- covars_base_year[,loggdppc]


      } else if (adapt=="clim") {

        climtasmax <- covars_year[,climtasmax]
        loggdppc <- covars_base_year[,loggdppc]
 

      } else if (adapt=="income") {

        climtasmax <- covars_base_year[,climtasmax]
        loggdppc <- covars_year[,loggdppc] 

      }

    message(glue("{adapt} adaptation, covariates values are {climtasmax} and {loggdppc}"))


    if (sector=="low") { 

      coef_tasmax <- csvv[1, "gamma"]
      coef_tasmax_rcs <- csvv[2, "gamma"]
      coef_tasmax_climtasmax <- csvv[3, "gamma"]
      coef_tasmax_rcs_climtasmax <- csvv[4, "gamma"]
      coef_tasmax_loggdppc <- csvv[5, "gamma"]
      coef_tasmax_rcs_loggdppc <- csvv[6, "gamma"]

    }

    else {

      coef_tasmax <- csvv[7, "gamma"]
      coef_tasmax_rcs <- csvv[8, "gamma"]
      coef_tasmax_climtasmax <- csvv[9, "gamma"]
      coef_tasmax_rcs_climtasmax <- csvv[10, "gamma"]
      coef_tasmax_loggdppc <- csvv[11, "gamma"]
      coef_tasmax_rcs_loggdppc <- csvv[12, "gamma"]

    }

    response_ref <-  (coef_tasmax * ref) + (coef_tasmax_rcs * ref_spline) + (((coef_tasmax_climtasmax * ref) + (coef_tasmax_rcs_climtasmax * ref_spline))*climtasmax) + (((coef_tasmax_loggdppc * ref) + (coef_tasmax_rcs_loggdppc * ref_spline))*loggdppc)

    responses <-  as.numeric((coef_tasmax * TT) + (coef_tasmax_rcs * TT_spline) + (((coef_tasmax_climtasmax * TT) + (coef_tasmax_rcs_climtasmax * TT_spline))*climtasmax) + (((coef_tasmax_loggdppc * TT) + (coef_tasmax_rcs_loggdppc * TT_spline))*loggdppc) - response_ref)


    message("responses are")

    message(responses)
  }

##########################################
# KIT IS TESTING THIS SHADY 1-FACTOR MIXED MODEL CODE!
# @rae this would be the right part to check --
# making sure low is uninteracted and high is 1-factor
##########################################

  else if (interacted=='mixed_model'){

    adapt_year <- year
    covars <- data.table(covars)
    covars_year <- covars[year==adapt_year]
    covars_base_year <- covars[year==base_year]


    if (adapt== "full") {

        climtas <- covars_year[,climtas]
        loggdppc <- covars_year[,loggdppc]


      } else if (adapt== "no") {

        climtas <- covars_base_year[,climtas]
        loggdppc <- covars_base_year[,loggdppc]


      } else if (adapt=="clim") {

        climtas <- covars_year[,climtas]
        loggdppc <- covars_base_year[,loggdppc]
 

      } else if (adapt=="income") {

        climtas <- covars_base_year[,climtas]
        loggdppc <- covars_year[,loggdppc] 

      }

    message(glue("{adapt} adaptation, covariates values are {climtas} and {loggdppc}"))


    if (sector=="low") { 

      coef_tasmax <- csvv[1, "gamma"]
      coef_tasmax_rcs <- csvv[2, "gamma"]

      response_ref <- coef_tasmax * ref + coef_tasmax_rcs * ref_spline

      responses <- as.numeric(coef_tasmax * TT + coef_tasmax_rcs * (TT_spline) - response_ref)

    }

    else {

      coef_tasmax <- csvv[3, "gamma"]
      coef_tasmax_rcs <- csvv[4, "gamma"]
      coef_tasmax_loggdppc <- csvv[5, "gamma"]
      coef_tasmax_rcs_loggdppc <- csvv[6, "gamma"]

      response_ref <-  (coef_tasmax * ref) + (coef_tasmax_rcs * ref_spline) + (((coef_tasmax_loggdppc * ref) + (coef_tasmax_rcs_loggdppc * ref_spline))*loggdppc)

      responses <-  as.numeric((coef_tasmax * TT) + (coef_tasmax_rcs * TT_spline) + (((coef_tasmax_loggdppc * TT) + (coef_tasmax_rcs_loggdppc * TT_spline))*loggdppc) - response_ref)


    }

    message("resopnses are")

    message(responses)
  }


  return(format.curve(curve=responses, TT=TT, year=year, region=region, base_year=base_year, adapt=adapt))

}
