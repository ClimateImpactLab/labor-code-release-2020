#==============================================================================#
#'
#' Author: Elliot Grenier
#' Created: 3 June 2025
#'
#' This script intersects CIL impact regions with the following agglomerated 
#' agriculture-intensive regions:
#'  - California Central Valley
#'  - Eurasian Steppe
#'  - Indo-Gangetic plain
#'  - US Midwest
#'  - Fertile Crescent
#' 
#' Outputs a crosswalk file which we use to calculate the pop-weighted
#' hedonic value of a temperature controlled work place across those regions
#'
#==============================================================================#

#======================================================#
# 0. Path + packages ----

packages = c('tidyverse', 'data.table', 'glue', 'sf', 'rnaturalearth')
invisible(lapply(packages, function(pkg) {
  suppressPackageStartupMessages(library(pkg, character.only = TRUE))
}))
rm(packages)

USER = Sys.getenv("USER")
source(glue('/project/cil/home_dirs/{USER}/repos/labor-code-release-2020/0_subroutines/paths.R'))
source(glue('{DIR_REPO_LABOR}/4_post_projection/0_utils/mapping.R'))

data_out = glue("{ROOT_INT_DATA}/misc")
fig_out = glue("{DIR_FIG}/misc")

format = "pdf"

DEFAULT_CRS = glue("+proj=robin +lon_0=0 +x_0=0 +y_0=0 +ellps=WGS84",
                   " +datum=WGS84 +units=m +no_defs")

#======================================================#
# 1. Load in data, define regions to aggregate ----

regions = fread("/project/cil/gcp/regions/hierarchy-flat.csv")[,"region-key"]
colnames(regions)[1] = "region"

# CIL regions
ir_shp = st_read('/project/cil/sacagawea_shares/gcp/regions/world_combo_201710_mockup/agglomerated-world-new-simp100.shp') %>%
  st_transform(DEFAULT_CRS)

# ====== Cerrado region in Brazil ====== #
# using biome shapefile
# https://data.mendeley.com/datasets/ybjt9gkzr2/1
cerrado = st_read("/project/cil/home_dirs/egrenier/misc/labor/region_shapefiles/cerrado/ECORREGIOES_CERRADO_V7.shp") %>%
  st_transform(DEFAULT_CRS)

# ====== california central valley ====== #  

# using alluvial boundary shapefile
# https://data.cnra.ca.gov/dataset/alluvial-boundary-of-californias-central-valley
ca_central_valley = st_read("/project/cil/home_dirs/egrenier/misc/labor/region_shapefiles/ca_central_valley/Alluvial_Bnd.shp") %>%
  st_transform(DEFAULT_CRS)

# ====== Eurasian Steppe ====== #

# Cross referencing this map (western steppe):
# https://www.britannica.com/place/the-Steppe

# with this shapefile:https://www.arcgis.com/apps/mapviewer/index.html?layers=232c3a6cbf38497a99e4dc7734860366
url = "https://services1.arcgis.com/lDFzr3JyGEn5Eymu/arcgis/rest/services/Steppe_Grasslands_20170907/FeatureServer/0/query?where=1=1&outFields=*&f=geojson"
tmp = tempfile(fileext = ".geojson")
download.file(url, tmp, mode = "wb") 

eurasian_steppe = st_read(tmp) %>% st_make_valid() %>% st_transform(DEFAULT_CRS)
eurasian_steppe = eurasian_steppe %>% filter(ECO_NAME %in% c("Pontic steppe", "East European forest steppe", 
                                                             "Kazakh steppe", "Kazakh forest steppe"))
rm(url, tmp)

# ====== Indo-Gangetic plain ====== #

# couldn't find a shapefile. use map below as reference instead to handpick IRs:
# https://www.researchgate.net/figure/Map-of-the-Indo-Gangetic-Plains-region-source-wwwpinterestcomau_fig1_332428387

west_bengal = regions %>% filter(grepl("IND.35", region)) %>% pull(region)
bihar = regions %>% filter(grepl("IND.5", region)) %>% pull(region)
uttar_pradesh = regions %>% filter(grepl("IND.33", region)) %>% pull(region)
haryana = regions %>% filter(grepl("IND.13", region)) %>% pull(region)
punjab = regions %>% filter(grepl("IND.28", region)) %>% pull(region)
nepal = c("NPL.2.5.27", "NPL.2.4.22", "NPL.2.4.24", "NPL.2.6.32", "NPL.2.6.33",
          "NPL.1.2.9", "NPL.1.2.11", "NPL.1.2.13", "NPL.1.3.19", "NPL.1.3.15",
          "NPL.1.3.18", "NPL.1.3.35", "NPL.5.14.73", "NPL.5.14.75", "NPL.5.14.50",
          "NPL.4.11.56", "NPL.4.9.45", "NPL.4.9.46", "NPL.3.8.44")
bangladesh = regions %>% filter(grepl("BGD", region)) %>% pull(region)
punjab_pak = regions %>% filter(grepl("PAK.7", region)) %>% pull(region)
sindh = regions %>% filter(grepl("PAK.8", region)) %>% pull(region)

indo_gagnetic_plain_irs = data.frame(
  "hierid" = c(west_bengal, bihar, uttar_pradesh, haryana, punjab, nepal, punjab_pak, sindh)
  )

rm(west_bengal, bihar, uttar_pradesh, haryana, punjab, nepal, punjab_pak, sindh)

# ====== Fertile Crescent ====== #

# pull shapefile from ArcGIS
# https://www.arcgis.com/apps/mapviewer/index.html?layers=3a013fba2e774371bdd4e99dc7cad17c

url = "https://services7.arcgis.com/iEMmryaM5E3wkdnU/arcgis/rest/services/Fertile_Crescent/FeatureServer/0/query?where=1=1&outFields=*&f=geojson"
tmp = tempfile(fileext = ".geojson")
download.file(url, tmp, mode = "wb") 

fertile_crescent = st_read(tmp) %>% st_make_valid() %>% st_transform(DEFAULT_CRS)

rm(url, tmp)

# ====== US Midwest ====== #

mw_states = c("USA.14", "USA.15", "USA.16", "USA.17", "USA.23",
              "USA.24", "USA.50", "USA.35", "USA.42", "USA.36",
              "USA.26", "USA.28")
pattern = paste0("^(", paste(mw_states, collapse = "|"), ")\\.", collapse = "")
midwest = regions %>% filter(grepl(pattern, region)) %>% pull(region)
midwest_irs = data.frame("hierid" = midwest)

#======================================================#
# 2. Data Cleaning ----

# Intersect agglom region shapes with IR
# get regions intersecting
cerrado_irs = st_intersection(ir_shp, cerrado) %>% 
  st_drop_geometry() %>% 
  select(hierid) %>% 
  distinct(hierid) %>% 
  mutate(agglom = "Cerrado")

ca_central_valley_irs = st_intersection(ir_shp, ca_central_valley) %>% 
  st_drop_geometry() %>% 
  distinct(hierid) %>% 
  select(hierid) %>% 
  mutate(agglom = "California Central Valley")

eurasian_steppe_irs = st_intersection(ir_shp, eurasian_steppe) %>% 
  st_drop_geometry() %>% 
  select(hierid) %>%
  distinct(hierid) %>%
  mutate(agglom = "Eurasian Steppe")

indo_gagnetic_plain_irs = indo_gagnetic_plain_irs %>% 
  mutate(agglom = "Indo-Gagnetic Plain")

midwest_irs = midwest_irs %>% 
  mutate(agglom = "US Midwest")

fertile_crescent_irs = st_intersection(ir_shp, fertile_crescent) %>% 
  st_drop_geometry() %>% 
  select(hierid) %>% 
  distinct(hierid) %>% 
  mutate(agglom = "Fertile Crescent")

# all agglomerated region IRs
aggloms = rbind(cerrado_irs, ca_central_valley_irs, eurasian_steppe_irs, indo_gagnetic_plain_irs, fertile_crescent_irs, midwest_irs)

# get df to save out for hedonic value result
ir = ir_shp %>% st_drop_geometry() %>% select(hierid) %>% left_join(aggloms)

# for mapping
ir_shp = ir_shp %>% left_join(aggloms)
ir_shp = ir_shp %>% rename(Region = agglom)

#======================================================#
# 3. Plotting ----

# country boundaries
country.shp = ne_countries(scale="large", returnclass="sf") %>%
  filter(sov_a3 != 'ATA') %>% 
  st_transform(DEFAULT_CRS) 

no_pop_irs = c('ARG.8.244', 'ATA', 'ATF.R3ad2a7b0834665e6', 'AUS.1.1', 'AUS.10.1145',
               'AUS.11.1345', 'AUS.3.112', 'AUS.5.387', 'AUS.5.400', 'AUS.6.687',
               'AUS.7.989', 'AUS.7.995', 'BRA.8.836.1993', 'BRA.8.837.1994', 'BVT',
               'CAN.11.269.4448', 'CAN.2.42.1074', 'CAN.3.58.1374',
               'CAN.9.148.Rd02357429ca755ba', 'CHN.21.226.1500',
               'CHN.30.318.2210.R55b41404d256c30a',
               'CHN.30.318.2210.Rdb1a80fb7e65ef11', 'CL-', 'COL.26.852', 'DOM.19.91',
               'ESP.6.27.191.4867', 'ESP.6.27.192.4868', 'GRL.1.2', 'GRL.2.9',
               'GRL.3.18', 'HMD', 'IDN.14.203', 'IND.12.129.431', 'IND.12.129.432',
               'IND.12.132.460', 'IND.12.134.487', 'IND.2.17.134', 'IND.2.17.135',
               'IND.2.17.136', 'IND.2.17.138', 'IND.2.17.142', 'IND.2.17.143', 'IOT',
               'JPN.37.1512', 'MRT.12.38', 'NZL.10.42.253', 'PER.21.169.1647', 'SGS',
               'SJM.1', 'SP-', 'TWN.2.2', 'ZAF.9.313')

lakes = c("CA-", "USA.23.1273", "USA.14.642",
          "USA.50.3082", "USA.50.3083", "USA.23.1275",
          "USA.15.740", "USA.24.1355", "USA.33.1855",
          "USA.36.2089", "USA.23.1272", "UGA.32.80.484",
          "UGA.31.79.483.2760", "UGA.32.80.484.2761",
          "TZA.13.59.1169", "TZA.5.26.564", "TZA.17.86.1759",
          "PER.8.71.705", "PER.7.67.677",
          "ARM.7", "USA.23.1274", "TZA.8.37.779")

lakes_shp = ir_shp %>% filter(hierid %in% lakes)
ir_shp = ir_shp %>% filter(!(hierid %in% no_pop_irs))

p = ggplot(data = ir_shp) +
  geom_sf(aes(fill=Region), lwd = 0.05, color = NA) + #color = NA removes the borders
  scale_fill_discrete(na.value = "gray91", na.translate = FALSE) +
  geom_sf(data=country.shp, fill=NA, color='grey15', linewidth=0.1) +
  geom_sf(data=lakes_shp, fill="white", color="grey15", linewidth=0.1) +
  theme_void() +
  theme(plot.title = element_blank(),
        legend.title = element_text(hjust=0, size = 11),
        legend.position = "right",
        legend.text = element_text(size = 9),
        legend.key.size = unit(0.45, "cm"),
        legend.key.spacing.y = unit(0.1, "cm"))
print(p)

ggsave(glue("{fig_out}/agglomerated_regions.{format}"), p,  width = 10, height = 8)

#======================================================#
# 4. Save data ----

ir = ir %>% mutate(agglom = ifelse(hierid %in% lakes, NA, agglom))

write.csv(ir, glue("{data_out}/ag_intensive_agglomerated_regions.csv"), row.names=F)




