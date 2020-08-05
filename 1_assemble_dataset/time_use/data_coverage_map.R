# Labor data coverage map 
# Adapted from figure 1 of mortality paper 

#  by: Simon Greenhill, sgreenhill@uchicago.edu
# last edited: 3/11/2020

rm(list=ls())
library(glue)
library(ggplot2)
library(rgdal)
library(dplyr)
library(magrittr)
library(rgeos)
library(viridis)
library(RColorBrewer)
library(maptools)
library(ggmap)
library(scales)
library(reshape2)
library(directlabels)
library(tidyr)
library(purrr)
library(sf)
library(directlabels)

cilpath.r:::cilpath()

inputwd <- paste0(DB, "/Global ACP/MORTALITY/Replication_2018/3_Output/5_figures/Figure_1/") #location of output
outputwd = glue("{DB}/Global ACP/labor/1_preparation/time_use/data_coverage_map")
shploc <- paste0(inputwd, "shapefile_compressed/")
shploc_world <- paste0(DB,"/Migration/internal/Data/Raw/Oct2018Download/shp/world/simplified")
shpname_world <- "world_countries_2017_simplified"

#source for mapping function
source(glue("{REPO}/post-projection-tools/mapping/mapping.R"))

df <- read.csv(glue("{DB}/Global ACP/labor/replication/1_preparation/time_use/data_summary.csv")) %>%
    rename(start=min_year, end=max_year) %>%
    arrange(desc(start))

df$iso_factor = factor(df$iso, ordered = TRUE, levels = c("IND", "USA", "ESP", "MEX", "BRA", "FRA", "GBR", "CHN"))

# load insample shapefile
shp_cov <- readOGR (dsn = shploc, layer = "mortality_insample_world", stringsAsFactors = FALSE) %>%
  spTransform(CRS("+proj=robin +lon_0=0 +x_0=0 +y_0=0 +ellps=WGS84 +datum=WGS84 +units=m +no_defs")) %>% #set crs
  gBuffer(byid=TRUE, width=0) %>%
  subset(id > 14904 | id < 14884) 
iso <- data.frame(id = shp_cov$id, adm2_id = seq.int(nrow(shp_cov)), iso = shp_cov$iso) #save ISO code
shp_cov <- fortify(shp_cov, region="id") %>% #set spatial data as df
  left_join(iso, by = c("id")) #join iso 

shp_cov$iso[shp_cov$id==14908] <- "BRA" # Not part of BRA, it's part of EU - French Guyana

#load IR world shapefile
shp_world <- load.map(shpname = "new_shapefile", shploc = paste0(dir,"/Global ACP/ClimateLaborGlobalPaper/Paper/Datasets/covariates/Impact_regions/shapefiles/IR_compressed"))

shp_world = readOGR(dsn=shploc_world, 
                    layer=shpname_world) %>%
  spTransform(CRS("+proj=robin +lon_0=0 +x_0=0 +y_0=0 +ellps=WGS84 +datum=WGS84 +units=m +no_defs")) %>%
  gBuffer(byid=TRUE, width=0) %>%
  fortify(region="CNTRY_CODE")

color.values <- brewer.pal(11, "Spectral") 
color.values <- color.values[!color.values %in% c("#FFFFBF", "#E6F598")] #remove light yellows
color.values <- rev(color.values) #reverse the order of the colors

shp_world$group1 <- substr(shp_world$group, 1, 3)
libs <- c("rgdal", "maptools", "gridExtra")


shp_covered_daily <- shp_world %>% filter(group1 %in% c("IND", "USA", "ESP", "FRA", "GBR"))
shp_covered_weekly <- shp_world %>% filter(group1 %in% c("MEX", "BRA", "CHN"))

# create patterns
# the code for creating the patterns comes from https://raw.githubusercontent.com/imaddowzimet/drawcrosshatch/master/draw_crosshatch.R,
# from this person's blog: https://imaddowzimet.github.io/crosshatch/
# to avoid any issues associated with this being taken down, I've downloaded the code to the labor repo.
source(glue('{REPO}/gcp-labor/1_preparation/time_use/draw_crosshatch.R'))

# create lines for municipality-level data
# try this on a simpler df
shp_world_simple = readOGR(glue("{DB}/Wilkes_InternalMigrationGlobal/internal/Data/Raw/Oct2018Download/shp/world/simplified"), "world_countries_2017_simplified") %>%
  spTransform(CRS("+proj=robin +lon_0=0 +x_0=0 +y_0=0 +ellps=WGS84 +datum=WGS84 +units=m +no_defs")) %>%
  gBuffer(byid=TRUE, width=0) %>%
  fortify(region="CNTRY_NAME")

shp_covered_adm3 = shp_world_simple %>% 
  dplyr::filter(id %in% c("Brazil", "Mexico")) %>% 
  group_by(group) %>%
  nest()

shp_covered_adm2 = shp_world_simple %>%
  dplyr::filter(id %in% c("United States", "India", "China")) %>%
  group_by(group) %>%
  nest()

shp_covered_adm1 = shp_world_simple %>%
  dplyr::filter(id %in% c("United Kingdom", "France", "Spain")) %>%
  group_by(group) %>%
  nest()

# draw lines in different patterns for each of the adm levels
lines_adm3 = map_df(shp_covered_adm3$data, draw.crosshatch, width=300000, pattern="crosshatch")
lines_adm2 = map_df(shp_covered_adm2$data, draw.crosshatch, width=300000, pattern="vertical")
# note that the lines from Manchuria do not extend down through the rest of china--will extend these manually
china_addl_lines = data.frame(
  x = c(10319428, 10619428), 
  y = c(4100000, 4000000), 
  xend = c(10319428, 10619428), 
  yend = c(2302090, 2484818)
  )
# a possible third manual line to add: 
# 10919428, 3380000, 10919428, 2494818, 
lines_adm2 = rbind(lines_adm2, china_addl_lines)
lines_adm1 = map_df(shp_covered_adm1$data, draw.crosshatch, width=300000, pattern="horizontal")

# map of coverage
p  = ggplot() +
  geom_polygon(data=shp_world, aes(x=long, y=lat, group=group), color="grey85", fill="grey85", size=0) + #world background
  geom_polygon(data=shp_covered_daily, aes(x=long, y=lat, group=group), fill="#80cdc1") + 
  geom_polygon(data=shp_covered_weekly, aes(x=long, y=lat, group=group), fill="#dfc27d") +
  geom_segment(data=lines_adm3, color="#8b8b8b", size=0.3, aes(x=x, y=y, xend=xend, yend=yend)) +
  geom_segment(data=lines_adm2, aes(x=x, y=y, xend=xend, yend=yend), size=0.3, color="#8b8b8b") +
  geom_segment(data=lines_adm1, aes(x=x, y=y, xend=xend, yend=yend), size=0.3, colour="#8b8b8b") + 
  coord_equal() + 
  theme_bw() + 
  theme(plot.title = element_text(hjust=0.5, size = 10),
        plot.caption = element_text(hjust=0.5, size = 7), 
        legend.position = "right",
        axis.title= element_blank(), 
        axis.text = element_blank(),
        axis.ticks = element_blank(),
        panel.grid = element_blank(),
        panel.border = element_blank()) + 
  labs(legend.title = "Temporal resolution")
  
ggsave(p, filename = paste0(outputwd, "country_spacecoverage_map.pdf"), dpi = 500, width = 16, height=12)

# line chart of time series coverage
df %<>%
  tidyr::gather(key=ts, value=year, c(start, end)) %>%
  mutate(
    name = recode(iso, 
      BRA = 'Brazil',
      CHN = 'China',
      ESP = 'Spain',
      FRA = 'France',
      GBR = 'United Kingdom',
      IND = 'India',
      MEX = 'Mexico',
      USA = 'United States'
      )
    ) %>%
  arrange(desc(name), year) %>%
  mutate(name = factor(name, ordered=TRUE)) 

b2 <- ggplot(data = df) + 
  geom_line(aes(x=year, y=iso_factor), size = 0.8) +
  geom_point(shape = "circle", aes(x=year, y=iso_factor)) +
  expand_limits(x = c(1970, 2020)) + 
  scale_x_continuous(breaks = seq(1950, 2020, by=10)) +
  geom_dl(aes(x=year, y=iso_factor, label=name),
          method = list(dl.trans(x = x + 0.2), "last.points", cex = 0.8)) + 
  theme_bw() + 
  theme(panel.border = element_blank(),
        panel.grid.major = element_blank(),
        panel.grid.minor = element_blank(),
        axis.title.y = element_blank(),
        axis.ticks.y = element_blank(),
        axis.text.y = element_blank(),
        axis.title.x = element_blank(),
        axis.line.x = element_line(color = "black"),
        legend.position = "none") +
  scale_fill_manual(values = color.values) +
  scale_color_manual(values = color.values)
ggsave(b2, filename = paste0(outputwd, "country_timecoverage_lineplot.pdf"), dpi = 500, width = 10, height = 2)

# note: combining these and creating a legend is done in illustrator. see country_coverage_map_combined.ai



