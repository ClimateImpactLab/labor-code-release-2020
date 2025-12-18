#====================================================================================#
# Labor Three-Bin Delta Beta Run Script 
#
# Author: Elliot Grenier (egrenier@uchicago.edu)
# Date Created: Feb 12 2025
# Last Modified: Feb 14 2025
#
# Description:
#
#'  This script runs energy delta-betas for all impact regions. 
#'  Currently set up to only run one ssp-iam-rcp-gcp scenario combination at a time. 
#'  
#'  How to run:
#'     - Read documentation in energy_db_wrapper.R
#'     - Set globals, file paths, and function arguments
#'     - Configure run-db.sbatch and run the SBATCH job (or sinteractive if instead 
#'       you'd like to see it go)
#'       
#====================================================================================#

# 0. Source and time -----------------------

# Time the whole process
start_time = Sys.time()

# Source repo paths and yellow purple functions
library(glue)
source("/project/cil/home_dirs/egrenier/repos/regional-scc/utils/paths.R")
source(paste0(REPO, "/regional_scc/deltabeta/energy_db_wrapper.R"))

#===================================#
# 1. Set globals ----
#===================================#

# Set scenario
ssp = "SSP3"
iam = "low"
rcp = "rcp85"
gcm = "CCSM4"
product='electricity'

# This loads in global covars. NOTE: an arbitrary region will be chosen for the "delta" portion.
# running this for global only returns the global beta. The "delta" here should be ignored and is
# just passed through the script to ensure that it functions as intended (see energy_db_wrapper.R for specifics)
global = F
g_slug = ifelse(global, "-global", "")

csvv.dir = glue("{DB}/deltabeta/input/csvv/energy/") # trailing slash
csvv.name = glue("FD_FGLS_inter_OTHERIND_{product}_TINV_clim.csvv")
cov.dir = glue("{DB}/deltabeta/input/covariates/econ_clim-{gcm}-{rcp}-{ssp}-{iam}{g_slug}.csv")
config.path = "/project/cil/home_dirs/egrenier/repos/energy-code-release-2020/projection_inputs/configs/GMFD/TINV_clim/break2_Exclude/semi-parametric/Projection_Configs/run/diagnostics/"
output.dir = glue("{DB}/deltabeta/output/energy/")

# Get list of regions to loop over 
region_list = list(unique((fread(cov.dir))$region))

# Test with subsets or specific region(s)
#region_list = region_list[[1]][1:10] # any range in [1,24378]
#region_list = list("NOR.12.288")

# Set args
args = list(years=2099, 
            base_year=1993,
            rebase_year=2005,
            rcp=rcp,
            csvv.dir=csvv.dir,
            csvv.name=csvv.name,
            config.path=config.path,
            func=get.energy.response,
            cov.dir=cov.dir,
            covarkey='region',
            covar.names=c('loggdppc', 'tas-cdd-20', 'tas-hdd-20'),
            get.covars=T,
            tas_value="tas",
            ncname="1.6",
            TT_upper_bound=100,
            TT_lower_bound=-100,
            TT_step=1,
            full_db=T,
            do_global=global)

#===================================#
# 2. Run function ----
#===================================#

message(glue("Computing Scenario: Electricity, {ssp}-{iam}, {gcm}-{rcp}"))

df = lapply(region_list, get_all_db_tables, args)
df = do.call(rbind, df) %>% as.data.frame() 

save_sector_output(df=df, product=product, ssp=ssp, iam=iam, rcp=rcp, gcm=gcm,
                   year=args$years, out=output.dir, full_db=args$full_db, global=args$do_global,
                   slug='NEW_TO_COMPARE')

# Get time
time = Sys.time() - start_time
message(time)



