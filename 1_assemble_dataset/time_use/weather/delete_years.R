#this script automates raw files deletion depending on the year they cover.
#it's either having this, either generating the data for very specific years and then combine years. It's a pain. So I generate single year chunks. 
# I.e imaigne you generate 2000-2009 and you noticed you missed 2010. You cannot generate 2010 and combine with the current reshaping code. You can just generate 2000-2010 and delete 2000-2009 files with this code.
# it's silly but.. time constraint!

setup <- function(){

  #clean environment
  rm(list = ls())


  list.of.packages <- c("tictoc","parallel","reshape2", "data.table", "readstata13", "plyr", "dplyr", "gridExtra", "grid", "foreign", "tidyr", "glue") #Put the name of your packages in strings here
  new.packages <- list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]
  if(length(new.packages)) install.packages(new.packages, repos = "http://cran.us.r-project.org")

  invisible(lapply(list.of.packages, library, character.only = TRUE))

  cilpath.r:::cilpath()

  }


setup()


paths <- function(ctry){

  location_climate_data_labor <- glue("{SAC_SHARES}/estimation/labor/climate_data")

  datadir <- glue("{location_climate_data_labor}/raw/{ctry}/weather_data/csv_daily") #location of raw weather data


  return(datadir)

  }




# file.remove(glue("{paths('FRA')}/{list.files(path=paths('FRA'), pattern='1998_1999')}"))
# file.remove(glue("{paths('BRA')}/{list.files(path=paths('BRA'), pattern='2002_2010')}"))
# file.remove(glue("{paths('ESP')}/{list.files(path=paths('ESP'), pattern='2002_2003')}"))
# file.remove(glue("{paths('IND')}/{list.files(path=paths('IND'), pattern='1998_1999')}"))
# file.remove(glue("{paths('MEX')}/{list.files(path=paths('MEX'), pattern='2005_2010')}"))
# file.remove(glue("{paths('USA')}/{list.files(path=paths('USA'), pattern='2003_2010')}"))
# file.remove(glue("{paths('CHN')}/{list.files(path=paths('CHN'), pattern='1989_2010')}"))

file.remove(glue("{paths('GBR')}/{list.files(path=paths('GBR'), pattern='1973_2001')}"))
