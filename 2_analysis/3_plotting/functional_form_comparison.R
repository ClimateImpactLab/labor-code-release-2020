#############
# INITIALIZE
#############

rm(list = ls())
library(dplyr)
library(ggplot2)
library(readr)
library(patchwork)
library(parallel)
library(testit)  
library(dplyr)
library(readr)
library(testit)
library(glue)
library(data.table)

source('~/repos/labor-code-release-2020/0_subroutines/paths.R')
source('~/repos/labor-code-release-2020/2_analysis/0_subroutines/functions.R')

# set macro
reg = "wchn"
# note splines needs to be manually set
# because I named it like an idiota

#############
# GET DATA
#############

bins = read_csv(
		glue("{DIR_RF}/uninteracted_bins/",
		"uninteracted_bins_{reg}_full_response.csv"))

poly_2 = read_csv(
		glue("{DIR_RF}/uninteracted_polynomials/",
		"uninteracted_polynomials_{reg}_2_full_response.csv"))

poly_3 = read_csv(
		glue("{DIR_RF}/uninteracted_polynomials/",
		"uninteracted_polynomials_{reg}_3_full_response.csv"))

poly_4 = read_csv(
		glue("{DIR_RF}/uninteracted_polynomials/",
		"uninteracted_polynomials_{reg}_4_full_response.csv"))

spline = read_csv(
		glue("{DIR_RF}/uninteracted_reg_w_chn/",
		"uninteracted_reg_w_chn_full_response.csv"))

forms = list(bins, poly_2, poly_3, poly_4, spline)

#######################
# RESHAPE DATA & MERGE
#######################

# reshape each dataframe

# merge dataframes for plotting
df = Reduce(function(x,y) merge(x = x, y = y, by = "temp"), 
       forms)

View(df)


View(reshape_args)

prep_df = function(df, vars=c("yhat"), risk="low") {
  
  df = reshape(
    risk, df=df, vars=vars)

  }

rename_df(spline)







