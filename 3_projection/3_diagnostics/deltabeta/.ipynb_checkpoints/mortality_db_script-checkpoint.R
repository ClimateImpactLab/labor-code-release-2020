#------------------------------------------------------------------------------------------
# Mortality Delta Beta Run Script

# Author: Elliot Grenier (egrenier@uchicago.edu)
# Date Created: Feb 10 2025
# Last Modified: Feb 10 2025

# Description:
#
#   This script runs mortality delta beta to generate data for blob, scatter plots,
#   and tables. 
#   
# How To Run:
#   - Change variable names in section 0 and output path in section 3
#   - Pick toggles (pay close attention to global and full_db)
#   - Save changes
#   - Run on a compute node through command line (Rscript db_wrapper.R) 
#     (or SLURM job to do this can be found in regional_scc repo)
#------------------------------------------------------------------------------------------

# 0. Source, set packages and paths -----------

# Time the whole process
start_time = Sys.time()

library(glue)
source("/project/cil/home_dirs/egrenier/repos/regional-scc/utils/paths.R")
source(glue("{REPO}/regional_scc/deltabeta/mortality_db_wrapper.R"))

#===================================#
# 1. Set globals ----
#===================================#

agelist = c(3,2,1)
het.list = list(age = c(rep.int(1, 12),rep.int(2, 12),rep.int(3, 12))) # to define agegroups for csvv coeffs

gcm = "CCSM4"
rcp = "rcp85"
ssp = "SSP3"
iam = "low"

# This loads in global covars. NOTE: a random region will be chosen for the "delta" portion.
# running this for global only returns the global beta. The "delta" here should be ignored and is
# just passed through the script to ensure that it functions as intended (see mortality_db_wrapper.R for specifics)
global = F
g_slug = ifelse(global, "-global", "")
  
# Set paths below
csvv.dir = glue("{DB}/deltabeta/input/csvv/mortality/") # Should have trailing slash
csvv.name = "Agespec_interaction_response.csvv"
cov.dir = glue("{DB}/deltabeta/input/covariates/econ_clim-{gcm}-{rcp}-{ssp}-{iam}{g_slug}.csv")
output.dir = glue("{DB}/deltabeta/output/mortality/") 

# Get list of regions to loop over 
region_list = list(unique((fread(cov.dir))$region))

# Testing with subsets or specific regions
# region_list = region_list[[1]][1:1] # any range in [1,24378]
# region_list = list('GHA.5.70')

#----------Define args here-------
args = list(
  years=2099,
  base_year=1993,
  rebase_year=2005,
  csvv.dir=csvv.dir,
  csvv.name=csvv.name,
  het.list=het.list,
  cov.dir=cov.dir,
  covarkey='region',
  list.names=c('climtas','loggdppc'),
  covar.names=c('climtas','loggdppc'),
  func=get.clipped.curve.mortality,
  get.covars=T,
  tas_value="tas",
  ncname="1.6",
  TT_upper_bound=100,
  TT_lower_bound=-100,
  TT_step=1,
  do.clipping=T,
  goodmoney.clipping=T, 
  do.diffclip=T,
  full_db=T,
  do_global=global
)


#===================================#
# 2. Run Function ----
#===================================#
stored=data.frame()
for (age in agelist){
  df = lapply(region_list, get_all_db_tables, age, args)
  df = do.call(rbind, df) %>% as.data.frame()
  
  agegroup = ifelse(age==3, "oldest", ifelse(age==2, "older", "young"))
  
  df = df %>% mutate(age = agegroup)
  stored = rbind(stored, df)
  save_sector_output(df=df, agegroup=agegroup, ssp=ssp, iam=iam, rcp=rcp, gcm=gcm,
                     year=args$years, out=output.dir, full_db=args$full_db, global=args$do_global,
                     slug='NEW_TO_COMPARE')
}

# Get time
time = Sys.time() - start_time
message(time)

# PLOT CURVES QUICK AND DIRTY (only with full_db=T)
# Convert columns to numeric and subset rows
# Comment out and run one by one
# df <- stored[1:200,] # OLDEST
# agegroup = "oldest"
# 
# df <- stored[204:403,] # OLDER
# agegroup = "older"
# 
# df <- stored[407:606,] # YOUNG
# agegroup = "young"
# 
# df$index <- as.numeric(gsub(".*,(.*)]", "\\1", df$bin))
# df$beta_fa <- as.numeric(df$beta_fa)
# df$beta_ia <- as.numeric(df$beta_ia)
# df$beta_na <- as.numeric(df$beta_na)
# 
# # Reshape the data from wide to long format
# df_long <- df %>%
#   pivot_longer(
#     cols = c(beta_fa, beta_ia, beta_na),
#     names_to = "beta_type",
#     values_to = "value"
#   )
# 
# # Plot with y-axis limits set from -1 to 50
# p = ggplot(df_long, aes(x = index, y = value, color = beta_type)) +
#   geom_point() +
#   geom_line() +
#   scale_y_continuous(limits = c(-1, 50)) +
#   scale_x_continuous(limits = c(-20, 40)) +
#   labs(x = "Average Temperature (Celsius)",
#     y = "Deaths per 100,000",
#     title = glue("{agegroup} {gcm} {rcp} {ssp} {iam}"),
#     color = "Beta Type") +
#   theme_bw()
# 
# out = glue("/project/cil/gcp/regional_scc/figures/diagnostics/global_curve/global-betas-{gcm}-{rcp}-{ssp}-{iam}-{agegroup}.png")
# 
# ggsave(p, filename=out)

