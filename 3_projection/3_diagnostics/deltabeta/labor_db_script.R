#------------------------------------------------------------------------------------------
# Labor Delta Beta Run Script 

# Author: Elliot Grenier (egrenier@uchicago.edu)
# Date Created: Jan 31 2025
# Last Modified: Jan 31 2025

# Description:
#
#'  This script runs delta-betas for all IRS for both worker risk sectors. Combine sectors using combine_labor_db.R
#'  Currently set up to only run one ssp-iam-rcp-gcp scenario combination at a time. 
#'  
#'  How to run:
#'     - Read documentation in labor_db_wrapper.R
#'     - Set globals, file paths, and function arguments
#'     - Go to terminal, on a compute node run {Rscript labor_db_script.R}
#------------------------------------------------------------------------------------------

# Load packages ------------------------------
if(!require("pacman")){install.packages(("pacman"))}
pacman::p_load(ggplot2, 
               dplyr,
               readr,
               cowplot,
               glue,
               grid,
               gridExtra)

# 0. Source and time -----------------------

# Time the whole process (this is mostly useful to estimate larger job times)
start_time = Sys.time()

# Source repo paths and yellow purple functions
source('/project/cil/home_dirs/egrenier/repos/labor-code-release-2020/0_subroutines/paths.R')
REPO=ROOT_REPO # this is to make yp package paths consistent with labor repo. 

source(glue("{DIR_REPO_LABOR}/3_projection/3_diagnostics/deltabeta/labor_db_wrapper.R"))
source(glue("{DIR_REPO_LABOR}/3_projection/3_diagnostics/deltabeta/get_curve_labor.R"))

#===================================#
# 1. Set globals ----
#===================================#

# Set scenario -- this only matters for temp distribution
ssp = "SSP3"
iam = "low"
rcp = "rcp85"
gcm = "CCSM4"

# Need covars for interacted sector. Not used in the labor paper's main spec (see csvv)
csvv.dir = glue("{DIR_REPO_LABOR}/3_projection/1_run_projections/0_csvv/") # trailing slash
csvv.name = "uninteracted_main_model.csvv"
output.dir = glue("{DIR_REPO_LABOR}/3_projection/3_diagnostics/deltabeta/output")
sector_list = c("low", "high")

# Test with subsets or specific region(s)
#region_list = read_csv('/project/cil/gcp/regions/hierarchy-flat.csv') %>% rename(region = `region-key`) %>% select(region)
#region_list = region_list[[1]][1:2] # any range in [1,24378]
#"CAN.3.54" "ETH.3.15.68" "TUR.40.441" "CHN.5.36.222" "ETH.8.40.336" "ARG.1.89" "YEM.6.84" "PER.13.123.1195" "SAU.1" "YEM.12.156" "IND.2.21.181" "CHN.5.34.213"

# "TCD.1.2" "COL.5.169" "CAN.8.118.2365" 
region_list = list('AUS.11.1392')

# Set args
args = list(year=2099, 
            base_year=2015,
            year1=2004, # We need two years to "rebase" these results. more detailed comments in labor_db_wrapper.R
            year2=2006,
            csvv.dir = csvv.dir,
            csvv.name = csvv.name,
            func=get_curve_rcspline_labor,
            tas_value = "tasmax",
            ncname = "1.1",
            TT_upper_bound = 60,
            TT_lower_bound = -45,
            TT_step = 1,
            full_db=T,
            delta.beta=T,
            save.plot=F)
            

#===================================#
# 2. Run function ----
#===================================#

low = lapply(region_list, get_all_db_tables, "low", args) %>% as.data.frame()
high = lapply(region_list, get_all_db_tables, "high", args) %>% as.data.frame()

years_sub = sort(c(args$base_year,args$year))
clim = mapply_extract_climate_data(years=years_sub, tas_value=args$tas_value, ncname=args$ncname, gcm=gcm, rcp=rcp)
binclim2 = mapply_bin_clim(regions=region_list[1], years=years_sub, clim=clim, TT_lower_bound=-45, TT_upper_bound=60, TT_step=args$TT_step)

bounds = mapply_bound_to_hist(regions=region_list[1], years=years_sub, binclim=binclim2)
names(bounds) <- region_list[1]
yrs = names(bounds[[1]])
bound2 = list()
bound2[[names(bounds)[1]]] = list(setNames(list(bounds[[1]][[2]]), yrs[2]))
bound2[[names(bounds)[1]]] = unlist(bound2[[names(bounds)[1]]], recursive = FALSE)

plots = list()
for (sector in sector_list){
  
  csvv = read.csvv(filepath = paste0(csvv.dir,csvv.name))
  curve_ds = mapply_curve(regions=region_list[1], years=args$year, base_year=args$base_year, csvv=csvv, func=args$func, sector=sector, 
                          TT_lower_bound=-45, TT_upper_bound=60, TT_step=args$TT_step)
  curve_plots = mapply_plot_curve(regions=region_list[1], curve_ds=curve_ds, bounds=bound2, y.lim=c(-100,50),
                                  years=years_sub, base_year=args$base_year, y.lab="Change in minutes worked (worker/day)")
  hist_plots = mapply_plot_hist(regions=region_list[1], binclim=binclim2)
  yp = mapply_yellow_purple(regions=region_list[1], curve_plots=curve_plots, hist_plots=hist_plots)
  
  # add to list
  plots[[sector]] = yp
}

low = low %>% 
  select(hierid, bin, T_y, T_by, T_diff, beta_fa, effect_fa, effect_na) %>% 
  dplyr::rename(effect_fa_low = effect_fa,
                effect_na_low = effect_na, 
                beta_low = beta_fa)

high = high %>% 
  select(hierid, bin, beta_fa, effect_fa, effect_na) %>% 
  dplyr::rename(effect_fa_high = effect_fa, 
                effect_na_high = effect_na, 
                beta_high = beta_fa)

df = low %>% left_join(high) %>% select(-hierid)

risk_share_fa = read_csv('/project/cil/home_dirs/egrenier/misc/labor/extracted_single/uninteracted_main_model-highriskshare-dec2025.csv')
risk_share_fa = risk_share_fa %>% 
  filter(region == region_list[1],
         year == args$year) %>%
  select(value) %>% pull(1)

risk_share_ia = read_csv('/project/cil/home_dirs/egrenier/misc/labor/extracted_single/uninteracted_main_model-incadapt-highriskshare-dec2025.csv')
risk_share_ia = risk_share_ia %>% 
  filter(region == region_list[1],
         year == args$year) %>%
  select(value) %>% pull(1)

risk_share_na = read_csv('/project/cil/home_dirs/egrenier/misc/labor/extracted_single/uninteracted_main_model-noadapt-highriskshare-dec2025.csv')
risk_share_na = risk_share_na %>% 
  filter(region == region_list[1],
         year == args$year) %>%
  select(value) %>% pull(1)

# Plot over-under 20 Table
plot_df = df %>% 
  mutate(effect_fa_low = round(as.numeric(effect_fa_low),2),
         effect_fa_high = round(as.numeric(effect_fa_high),2),
         effect_na_low = round(as.numeric(effect_na_low),2),
         effect_na_high = round(as.numeric(effect_na_high),2),
         riskshare_fa = round(as.numeric(risk_share_fa),4),
         riskshare_ia = round(as.numeric(risk_share_ia),4),
         riskshare_na = round(as.numeric(risk_share_na),4)) %>%
  mutate(fa = round((effect_fa_low*(1-riskshare_fa) + effect_fa_high*riskshare_fa)/365,2),
         ia = round((effect_fa_low*(1-riskshare_ia) + effect_fa_high*riskshare_ia)/365,2),
         na = round((effect_na_low*(1-riskshare_na) + effect_na_high*riskshare_na)/365,2))

plot_df = plot_df %>% 
  tail(3)
table = tableGrob(plot_df, rows = NULL)

proj = fread("/project/cil/home_dirs/egrenier/misc/labor/extracted_single/combined_impacts.csv") %>% 
  filter(region == region_list[1],
         year == args$year) %>% 
  mutate(`Results from` = "Projection system single")

proj_table = tableGrob(proj, rows = NULL)

# Get projection system results
p = plot_grid(plotlist = c(plots$low, plots$high), ncol = 2)
p = plot_grid(p, table, proj_table, nrow = 3, rel_heights = c(1, 0.3, 0.3))
print(p)

ggsave(glue("{output.dir}/{region_list[1]}_deltabeta_plot.pdf"), plot = p, width = 15, height = 10)
write.csv(df, glue("{output.dir}/{region_list[1]}_deltabeta_data.csv"), row.names=F)

# # If running multiple regions just for the data (no figure)
# joined = data.frame()
# 
# # This will take about 8 minutes if run in terminal
# for (sector in sector_list){
#   
#   # Run function
#   df = lapply(region_list, get_all_db_tables, sector, args) 
#   
#   # Convert to df
#   df = do.call(rbind, df) %>% as.data.frame() #%>% select(hierid, bin, sector, effect_fa, effect_y_rb, effect_by_rb)
#   joined = rbind(joined, df)
#   
#   # save output
#   #save_sector_output(df=df, sector=sector, ssp=ssp, iam=iam, rcp=rcp, gcm=gcm, year=args$year, out=output.dir)
#   
# }
# 

# Get time
time = Sys.time() - start_time
message(time)


