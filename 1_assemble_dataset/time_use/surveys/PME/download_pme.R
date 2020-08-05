# Download PME data using the lodown package. 
# This is an alternative way of getting the data.
# The other option is to run process_pme.sas (using SAS).
# Author: Simon Greenhill, sgreenhill@uchicago.edu
# Date: Jan. 27, 2020

library(lodown)
library(tidyverse)
library(data.table)
library(glue)
library(parallel)
cilpath.r:::cilpath()

output_dir = glue(
	'{SAC_SHARES}',
	'estimation/Labor/replication_data/time_use/brazil'
	)

# list all pme files
pme_all = get_catalog(
	"pme", 
	output_dir = output_dir)
	) %>%
	filter(year <= 2015)

# download all files
lodown(data_name='pme', output_dir=output_dir, catalog=pme_all)

# these write R datasets (.rds) for each raw file.
# I want a csv, so let's rbind and export.

# we remove the first element because it's the documentation directoru
files = list.files(
	glue('{output_dir}/pme_lodown/'), 
	full.names = TRUE)[-1]

to_save = mclapply(files, read_rds, mc.cores=12) %>%
	rbindlist()

fwrite(to_save, file = glue('{output_dir}/pme_all_lodown.csv'))


# EOD 1/27: This is not working.
# The problem is in this script: https://github.com/ajdamico/lodown/blob/master/R/cachaca.R
# By default, the function `cachaca` uses httr::GET to try to access the files,
# and this does not seem to work for the first file I need to download in PME:
# "ftp://ftp.ibge.gov.br/Trabalho_e_Rendimento/Pesquisa_Mensal_de_Emprego/Microdados/documentacao/Documentacao.zip"
# If I run cachaca(..., filesize_fun = 'unzip_verify'), the issues seems to be fixed.

# Options: 
# 1. Keep digging on what's going on with httr (huge rabbit hold)
# 2. Open a git issue on lodown and let them fix it (could be a time sink)
# 3. Fork the repo, implement a hack solution using `unzip_verify`, and then
# Create a git issue for the repo maintainer to follow up on.

# My favorite is option 3. 