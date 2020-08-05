# Compare replicated PME data to original PME data
# Author: Simon Greenhill, sgreenhill@uchicago.edu
# Date: Jan. 23, 2020

rm(list=ls())
library(tidyverse)
library(magrittr)
library(glue)
library(data.table)
library(haven)
library(testthat)
cilpath.r:::cilpath()

# check the old post-SAS processing raw data against the new version. 
# Was my SAS hackery successful?

# need to od this on sac--data is too big for my local
# parsing isn't working well. ened ot understand why.
# what if I save a dta rather than a csv?
old_raw = glue('{DB}/Baker_LaborForceSurveyBrazil/Data/Intermediate/pmeall_1.dta') %>%
	read_dta()

new_raw = glue('{DB}/Baker_LaborForceSurveyBrazil/Data/Raw/Data/BrazilTXT/pme_all.csv') %>%
	read_csv()

old_in = glue('{SAC_SHARES}/estimation/Labor/labor_merge_2019/intermediate_files/')
new_in = glue('{DB}/Global ACP/labor/replication/1_preparation/time_use/India/')

