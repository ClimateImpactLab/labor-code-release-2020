# reweight dataset with china

#######################################################
# Re-weight Labor dataset

# This script creates weights for the labor dataset and transforms variables for lags/leads
# Types of weights: individual weights, country population weights, sample weights

# Sector: Labor
# By Trinetta Chong 
# Date: 24 Jul 2019
# modified by Rae on 7 Jan 2020 to reweight all data including china
########################################################

#clean environment
rm(list = ls())
source("~/repos/labor-code-release-2020/0_subroutines/paths.R")

#load packages
library(readstata13)
library(dplyr)
library(plyr)
library(foreign)
library(glue)

#set decimal places
options(digits=15)

#####################################

input_file <- glue(
  '{ROOT_INT_DATA}/temp/',
  'all_time_use_pop_merged.dta')

#####################################

df <- read.dta13(input_file)
#create list of countries
ctrylist <- as.list(unique(df$iso))

#####################################
#1. Assign person weights
#####################################

df$weight <- 1

#for (ctry in ctrylist) { #modify weights by country if there are repeated individuals
  # This gets a dataframe with 
#  duplicates <- ddply(subset(df, iso==ctry),.(ind_id),nrow) #subset to country & count the number of duplicates for this country
#  if(length(unique(duplicates$V1))>1){ 
#    print(paste(ctry, "has repeated persons"))
#    duplicates$iso <- ctry #add country
 #   df <- left_join(df, duplicates, by = c("iso", "ind_id")) #merge duplicates back into df
#    df$weight[df$iso==ctry] <- df$weight[df$iso==ctry]/df$V1[df$iso==ctry] #divide person weights by number of repeated instances (i.e. V1)
#    df <- subset(df, select = -c(V1)) #drop V1
#  }
#}
# Tom's version... 
df = df %>%
  group_by(iso, ind_id) %>%
  add_tally() %>% 
  mutate(weight = weight/n)

table(df$weight,df$iso) #see countries person-adjusted weights

#####################################
#2. Assign sample weight 
#####################################

df$sample_wgt <- ifelse(is.na(df$sample_wgt), 1, df$sample_wgt) #for countries without sample weights (previously "GTM", "NIC", "MEX"), assign 1
stopifnot(sum(is.na(df$sample_wgt))==0) #check if there are any more NAs in the sample_wgt column

#Sample weights sum to 1 for each country
df$adj_sample_wgt <- df$weight*df$sample_wgt
country_sum_sample <- aggregate(list(adj_ctry_sum_sample = df$adj_sample_wgt), list(iso = df$iso), FUN = sum, na.rm=T) #find sum of all adj sample weights for each country
df <- left_join(df, country_sum_sample, by = c("iso")) #merge with dataframe
df$adj_sample_wgt <- df$adj_sample_wgt/df$adj_ctry_sum_sample #normalize adjusted sample weight so they sum to 1 for each country



for (ctry in ctrylist) { #check that they sum to 1 for each country
  print(paste0("checking ", ctry))
  stopifnot(sum(df$adj_sample_wgt[df$iso==ctry]) - 1 < 0.000001)
}


#Sample weights sum to 1 for each ADM1 region
df$adm1_adj_sample_wgt <- df$weight*df$sample_wgt
adm1_sum_sample <- aggregate(list(adj_adm1_sum_sample = df$adm1_adj_sample_wgt), list(adm1_id = df$adm1_id), FUN = sum, na.rm=T) #find sum of all adj sample weights for each adm1
df <- left_join(df, adm1_sum_sample, by = c("adm1_id")) #merge with dataframe
df$adm1_adj_sample_wgt <- df$adm1_adj_sample_wgt/df$adj_adm1_sum_sample #normalize adjusted sample weight so they sum to 1 for each adm1

for (adm in as.list(unique(df$adm1_id))) { #check that they sum to 1 for each country
  print(paste0("checking ", adm))
  stopifnot(round(sum(df$adm1_adj_sample_wgt[df$adm1_id==adm]), 1) == 1)
}


#Sample weights sum to 1 for each ADM2 region
df$adm2_adj_sample_wgt <- df$weight*df$sample_wgt
adm2_sum_sample <- aggregate(list(adj_adm2_sum_sample = df$adm2_adj_sample_wgt), list(adm2_id = df$adm2_id), FUN = sum, na.rm=T) #find sum of all adj sample weights for each adm2
df <- left_join(df, adm2_sum_sample, by = c("adm2_id")) #merge with dataframe
df$adm2_adj_sample_wgt <- df$adm2_adj_sample_wgt/df$adj_adm2_sum_sample #normalize adjusted sample weight so they sum to 1 for each adm2

for (adm in as.list(unique(df$adm2_id))) { #check that they sum to 1 for each country
  print(paste0("checking ", adm))
  stopifnot(round(sum(df$adm2_adj_sample_wgt[df$adm2_id==adm]), 1) == 1)
}


#####################################
#3. Assign country population weight
#####################################

df$pop_adj_sample_wgt <- df$adm0_pop*df$adj_sample_wgt
sum_all <- sum(df$pop_adj_sample_wgt) #calculate sum of all weights
df$pop_adj_sample_wgt <- df$pop_adj_sample_wgt/sum_all #normalize pop_adj_sample_wgt
#stopifnot(sum(df$pop_adj_sample_wgt) == 1) #check that all weights sum to 1


#save dataset
output_file <- glue(
  '{ROOT_INT_DATA}/temp/',
  'all_time_use_pop_merged_reweighted.dta')
write.dta(df, output_file)

