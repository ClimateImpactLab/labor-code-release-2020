# Impacts by income deciles bar chart
# 
rm(list = ls())
# Load in the required packages, installing them if necessary 
if(!require("pacman")){install.packages(("pacman"))}
pacman::p_load(ggplot2, 
               dplyr,
               readr,
               glue,
               parallel)


source("~/repos/labor-code-release-2020/0_subroutines/paths.R")
source("~/repos/post-projection-tools/mapping/imgcat.R") #this redefines the way ggplot plots. 

# Load in the required packages, installing them if necessary 
if(!require("pacman")){install.packages(("pacman"))}
pacman::p_load(ggplot2, 
               dplyr,
               readr)


DB_data = paste0("/mnt/CIL_energy/code_release_data_pixel_interaction")


# Take deciles of 2012 income/ clim data distribution of IRs, by getting equal populations in each population

get_deciles = function(df){
  
  deciles = df %>% 
    filter(year == 2012)
  
  # Get cut-off population levels for each quantile
  total_pop = sum(deciles$pop)
  pop_per_quantile = total_pop / 10
  
  deciles <- deciles[order(deciles$gdppc),] 
  deciles$cum_pop = cumsum(deciles$pop)
  deciles$decile = 10
  
  # Loop over deciles, assigning them to the ordered IRs up to the point where population is equal in each decile
  for (quant in 1:10){
    deciles$decile[deciles$cum_pop < quant* pop_per_quantile & deciles$cum_pop >= (quant-1)* pop_per_quantile] <- quant
  }
  
  deciles = deciles %>%
    dplyr::select(region, decile)
  
  return(deciles)
}

# Load in pop and income data
df_covariates = read_csv(paste0(DB_data, '/projection_system_outputs/covariates', 
                        '/SSP3-high-IR_level-gdppc-pop-2012.csv'))

# Find each Impact region's 2012 decile of income per capita. 
deciles = get_deciles(df_covariates)


##############################################
# plot pop weighted per capita damage
# Load in impacts data
df_impacts = read_csv(glue('{ROOT_INT_DATA}/projection_outputs/extracted_data/SSP3-rcp85_high_allrisk_fulladapt-wage-levels_2099_map.csv'))%>%
  mutate(damage = mean) %>%  
  left_join(deciles, by = "region")

# Join with 2099 population data
df_pop99= read_csv(paste0(DB_data, '/projection_system_outputs/covariates', 
                                   '/SSP3-high-IR_level-gdppc_pop-2099.csv')) %>% 
  dplyr::select(region, pop99)

df_impacts = df_impacts %>% 
    left_join(df_pop99, by = "region")

# Collapse to decile level
df_plot = df_impacts %>% 
  group_by(decile) %>% 
  summarize(total_damage_2099 = sum(damage), 
            total_pop_2099 = sum(pop99))%>%
  mutate(damagepc = total_damage_2099 / total_pop_2099 )


# Plot and save 
p = ggplot(data = df_plot) +
  geom_bar(aes( x=decile, y = damagepc ), 
           position="dodge", stat="identity", width=.8) + 
  theme_minimal() +
  ylab("Impact of Climate Change, 2019 USD") +
  xlab("2012 Income Decile") +
  scale_x_discrete(limits = seq(1,10))

ggsave(p, file = paste0(DIR_FIG, 
    "/SSP3-high_rcp85-total-damages_by_inc_decile.pdf"), 
    width = 8, height = 6)




#################################################
# plot damage in percentage GDP by income decile

# Load in impacts data
df_pct_gdp_impacts = read_csv(glue('{ROOT_INT_DATA}/projection_outputs/extracted_data/SSP3-rcp85_high_allrisk_fulladapt-gdp-levels_2099_map.csv'))%>%
  mutate(pct_gdp = mean) %>%  
  left_join(deciles, by = "region")

# Join with 2099 population data
df_gdp99= read_csv(paste0(DB_data, '/projection_system_outputs/covariates', 
                                   '/SSP3-high-IR_level-gdppc_pop-2099.csv')) %>% 
  dplyr::select(region, gdp99)

df_pct_gdp_impacts = df_pct_gdp_impacts %>% 
    left_join(df_gdp99, by = "region") %>% 
    mutate(pct_x_gdp = pct_gdp * gdp99)

# Collapse to decile level
df_plot = df_pct_gdp_impacts %>% 
  group_by(decile) %>% 
  summarize(total_pct_x_gdp_2099 = sum(pct_x_gdp, na.rm = TRUE), 
            total_gdp_2099 = sum(gdp99, na.rm = TRUE))%>%
  mutate(mean_pct_gdp = total_pct_x_gdp_2099 / total_gdp_2099 )


# Plot and save 
p = ggplot(data = df_plot) +
  geom_bar(aes( x=decile, y = mean_pct_gdp ), 
           position="dodge", stat="identity", width=.8) + 
  theme_minimal() +
  ylab("Impact of Climate Change, Percentage GDP") +
  xlab("2012 Income Decile") +
  scale_x_discrete(limits = seq(1,10))

ggsave(p, file = paste0(DIR_FIG, 
    "/SSP3-high_rcp85-pct-gdp_by_inc_decile.pdf"), 
    width = 8, height = 6)


