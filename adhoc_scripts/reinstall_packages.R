
# [1] "/home/liruixue/R/x86_64-pc-linux-gnu-library/4.1"
# [2] "/usr/local/lib/R/site-library"
# [3] "/usr/lib/R/site-library"
# [4] "/usr/lib/R/library"


# grab old packages names
old_packages <- installed.packages(lib.loc = "/usr/lib/R/library")
old_packages <- as.data.frame(old_packages)
list.of.packages <- unlist(old_packages$Package)
list.of.packages
# remove old packages 
remove.packages(installed.packages( priority = "NA" )[,1] )

# reinstall all packages 
new.packages <- list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)
lapply(list.of.packages,function(x){library(x,character.only=TRUE)})