# get popop (population-weighted population density, or perceived population density)
# This is a python script meant to be run from the QGIS interpreter in an admittedly outdated way. 
# To get popop, run this script from QGIS, then manually save the attributes table as a csv. 
# Then, run calculate_popop.py to actually get the ratio you need for popop. 
# In the future, it could be worthwhile to transistion this into a single, python only script 
# that uses Theo's zonal stats code as a starting point. We are using this for the time being. 
# I've started working on this, but QGIS threw tons of warnings and seemed generally unhappy, 
# so I'm leaving it for now in favor of more urgent tasks. 
# Author: Simon Greenhill, sgreenhill@uchicago.edu (adapted from code by Trinetta Chong)
# Date: 31 May 2019

# -*- coding: utf-8 -*-
import os
import getpass
import qgis 
from qgis.core import *
from qgis.analysis import QgsZonalStatistics
import osgeo
import csv
import string
import gc
import itertools
import processing
from shutil import copyfile
import time
import numpy as np
import pandas as pd

# toggle for admin level 
adm_lev = "geolev1"

# set up directories 
if getpass.getuser() == 'simongreenhill':
    labDB = '/Users/simongreenhill/Dropbox/Global ACP/labor/1_preparation/IPUMS/data/'
    migDB = '/Users/simongreenhill/Dropbox/Wilkes_InternalMigrationGlobal/'
    # QgsApplication.setPrefixPath("~/Applications/QGIS3", True) # qgis install location

# qgs = QgsApplication([], False) # reference to the QgsApplication
# qgs.initQgis()

shp_dir = "{}/shp/world_{}_2019/".format(labDB, adm_lev) 
pop_dir = "{}/internal/Data/Raw/landscan".format(migDB)
out_dir = "{}/popop".format(migDB)
in_dir = "{}/popop".format(migDB)

# shapefile for full sample
shapefile = "{}/world_{}_2019.shp".format(shp_dir, adm_lev)

# load shapefile 
vlayer = QgsVectorLayer(shapefile, "adm1", "ogr")

QgsProject.instance().addMapLayer(vlayer)

# get landscan rasters with population and population^2
pop = QgsRasterLayer("{}/pop_robinson.tif".format(pop_dir))
pop2 = QgsRasterLayer("{}/pop2_robinson.tif".format(pop_dir))

#ZS calcul
zoneStat = QgsZonalStatistics(vlayer, pop, 'pop_', 1)
zoneStat.calculateStatistics(None)
zoneStat = QgsZonalStatistics(vlayer, pop2, 'pop2_', 1)
zoneStat.calculateStatistics(None)

# save as csv (do this manually for now)
QgsVectorFileWriter.writeAsVectorFormat(vlayer, "{}/popop_{}.csv".format(out_dir, adm_lev), "utf-8", vlayer.crs(), "CSV")

# exit qgis 
# qgs.exitQgis()

# do some final processing
# df = pd.read_csv("{}/popop_{}.csv".format(in_dir, adm_lev))

# # make popop
# df["popop"] = df["pop2_mean"] / df["pop_mean"]

# # write csv
# df.to_csv("{}/popop_{}.csv".format(in_dir, adm_lev))
