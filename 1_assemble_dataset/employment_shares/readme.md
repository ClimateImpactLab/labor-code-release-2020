# `1_preparation/employment_shares`: Readme

Scripts in this folder relate to preparing the employment shares data used to fit a model of shares of high-risk employment for weighting time-use impacts projections. Note that many of these scripts are similar to ones originally developed for the internal migration sector, as both our employment shares project and our internal migration project both use IPUMS data. See [here](https://gitlab.com/ClimateImpactLab/Impacts/migration) for details.

## `data_cleaning/`
Scripts in this folder are related to cleaning the data used in the employment shares regressions.

Subfolders:
- The scripts in `income/` downscale Penn World Tables income data to subnational data using data from Gennaioli et al. The procedure for doing this was developed by Simon Greenhill and Tom Bearpark in the migration sector and has been generalized for use in any sector. See [here](https://gitlab.com/ClimateImpactLab/Impacts/post-projection-tools/tree/master/income) for details.
- The scripts in `popop/` prepare perceived population density ("popop") data.
	- `get_popop.py` is a pyQGIS script to save a csv of the values needed to calculate popop at the IPUMS adm1 unit level
	- `calculate_popop.py` calculates popop using the values saved by `get_popop.py`.
- The scripts in `weather/` produce the historical weather data used in regressions. These scripts rely on the [`climate_data_aggregation`](https://bitbucket.org/ClimateImpactLab/climate_data_aggregation/src/master/) repo.
	- The workflow of these scripts is almost identical to the workflow for producing the internal migration data. See [here](https://gitlab.com/ClimateImpactLab/Impacts/migration/-/blob/master/code/1_clean/02_clean_weather/climate_data_generation/internal/readme.md).
	- The main differences is the addition of `calculate_climtas.R`, a script for calculating moving averages of daily weather data, allowing us to generate the long run temperature values we use in the regressions.
- Standalone scripts:
	- `clean_ipums_shapefiles.R` simplifies IPUMS shapefiles for faster plotting
	- `extract_IPUMS.do` is a modified version of code provided by IPUMS for extracting the raw data (which comes in a fixed-width file format) and saving out the files we will use for the migration data in our analysis.
	- `merge_data.R` is a script to merge together the cleaned IPUMS employment data, the income data, and the long run temperature data. This script produces a regression-ready dataset.

## `visualization/`
Scripts in this folder were used for simple diagnostics on the cleaned data.
- `clim_data_vis.R` plots long-run temperature values
- `map_income.R` plots maps of downscaled income
- `summary_stats_and_visualizations.R` produces maps of the spatial distribution of high-risk employment shares, time series of average high risk shares at the country level, and tables of average high risk shares at the country level.

## Next step in this analysis
The next step in this analysis is to run regressions using the cleaned data. See `gcp-labor/2_regression/employment_shares/readme.md`.