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

#load packages
library(readstata13)
library(dplyr)
library(plyr)
library(foreign)

#set decimal places
options(digits=15)

#####################################

input_file <- "/shares/gcp/estimation/Labor/labor_merge_2019/intermediate_files/labor_time_use_all_countries.dta"


#####################################

df <- read.dta13(input_file)
#create list of countries
ctrylist <- as.list(unique(df$iso))

#####################################
#1. Assign person weights
#####################################

df$weight <- 1

for (ctry in ctrylist) { #modify weights by country if there are repeated individuals
  
  duplicates <- ddply(subset(df, iso==ctry),.(id),nrow) #subset to country & count the number of duplicates for this country
  
  if(length(unique(duplicates$V1))>1){ 
    print(paste(ctry, "has repeated persons"))
    duplicates$iso <- ctry #add country
    df <- left_join(df, duplicates, by = c("iso", "id")) #merge duplicates back into df
    df$weight[df$iso==ctry] <- df$weight[df$iso==ctry]/df$V1[df$iso==ctry] #divide person weights by number of repeated instances (i.e. V1)
    df <- subset(df, select = -c(V1)) #drop V1
  }
}

table(df$weight,df$iso) #see countries person-adjusted weights

#####################################
#2. Assign sample weight 
#####################################

df$sample_weight <- ifelse(is.na(df$sample_weight), 1, df$sample_weight) #for countries without sample weights (previously "GTM", "NIC", "MEX"), assign 1
stopifnot(sum(is.na(df$sample_weight))==0) #check if there are any more NAs in the sample_weight column

#Sample weights sum to 1 for each country
df$adj_sample_weight <- df$weight*df$sample_weight
country_sum_sample <- aggregate(list(adj_ctry_sum_sample = df$adj_sample_weight), list(iso = df$iso), FUN = sum, na.rm=T) #find sum of all adj sample weights for each country
df <- left_join(df, country_sum_sample, by = c("iso")) #merge with dataframe
df$adj_sample_weight <- df$adj_sample_weight/df$adj_ctry_sum_sample #normalize adjusted sample weight so they sum to 1 for each country

output_file <- "/shares/gcp/estimation/Labor/labor_merge_2019/intermediate_files/labor_time_use_all_countries_weighted.dta"
#output_csv <- "/shares/gcp/estimation/Labor/labor_merge_2019/merged_all_countries_after_assigning_weights.csv"

#write.csv(df, output_csv)
write.dta(df, output_file)


for (ctry in ctrylist) { #check that they sum to 1 for each country
  print(paste0("checking ", ctry))
  stopifnot(sum(df$adj_sample_weight[df$iso==ctry]) - 1 < 0.000001)
}


#Sample weights sum to 1 for each ADM1 region
df$adj_sample_weight_adm1 <- df$weight*df$sample_weight
adm1_sum_sample <- aggregate(list(adj_adm1_sum_sample = df$adj_sample_weight_adm1), list(location_id1 = df$location_id1), FUN = sum, na.rm=T) #find sum of all adj sample weights for each adm1
df <- left_join(df, adm1_sum_sample, by = c("location_id1")) #merge with dataframe
df$adj_sample_weight_adm1 <- df$adj_sample_weight_adm1/df$adj_adm1_sum_sample #normalize adjusted sample weight so they sum to 1 for each adm1

for (adm in as.list(unique(df$location_id1))) { #check that they sum to 1 for each country
  print(paste0("checking ", adm))
  stopifnot(round(sum(df$adj_sample_weight_adm1[df$location_id1==adm]), 1) == 1)
}


#Sample weights sum to 1 for each ADM2 region
df$adj_sample_weight_adm2 <- df$weight*df$sample_weight
adm2_sum_sample <- aggregate(list(adj_adm2_sum_sample = df$adj_sample_weight_adm2), list(location_id2 = df$location_id2), FUN = sum, na.rm=T) #find sum of all adj sample weights for each adm2
df <- left_join(df, adm2_sum_sample, by = c("location_id2")) #merge with dataframe
df$adj_sample_weight_adm2 <- df$adj_sample_weight_adm2/df$adj_adm2_sum_sample #normalize adjusted sample weight so they sum to 1 for each adm2

for (adm in as.list(unique(df$location_id2))) { #check that they sum to 1 for each country
  print(paste0("checking ", adm))
  stopifnot(round(sum(df$adj_sample_weight_adm2[df$location_id2==adm]), 1) == 1)
}


#####################################
#3. Assign country population weight
#####################################

df$pop_adj_sample_weight <- df$pop*df$adj_sample_weight
sum_all <- sum(df$pop_adj_sample_weight) #calculate sum of all weights
df$pop_adj_sample_weight <- df$pop_adj_sample_weight/sum_all #normalize pop_adj_sample_weight
#stopifnot(sum(df$pop_adj_sample_weight) == 1) #check that all weights sum to 1

#save dataset

output_file <- "/shares/gcp/estimation/Labor/labor_merge_2019/intermediate_files/labor_time_use_all_countries_weighted.dta"
#output_csv <- "/shares/gcp/estimation/Labor/labor_merge_2019/merged_all_countries_after_assigning_weights.csv"

#write.csv(df, output_csv)
write.dta(df, output_file)

