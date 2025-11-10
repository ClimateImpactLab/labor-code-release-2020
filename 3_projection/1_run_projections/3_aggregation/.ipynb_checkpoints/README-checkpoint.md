# Aggregation

There are 4 aggregation configs used in the labor sector:
1. Population
2. Wages
3. GDP
4. GDP per capita

Aggregation for the labor sector takes a significant amount of time per config and projection spec. Expect that aggregating one spec (i.e. one combination of batch/rcp/gcm/iam/ssp) and one config (i.e. pop or wage or gdp) can take a little over an hour. To aggregate a montecarlo run on the RCC, the most efficient way to run aggregation is through a SLURM job. You can find a config to do this in the `SLURM` folder. 

You can also run aggregation using an interactive sesssion. To do so:

1. Start an interactive session on a CIL node: `sinteractive --account=cil --partition=cil --time=24:00:00`
2. Load the required python module: `module load python` (this will default to python/anaconda-2022.05)
3. Activate the projection system environment: `source activate /project/cil/home_dirs/egrenier/envs/impact-env` (anyone with access to the CIL directories can activate this environment)
4. Navigate to the impact-calculations directory: `cd /project/cil/home_dirs/{user}/impact-calculations`
5. Run aggregation: `./aggregate.sh {path/to/your/config.yml}`

Note: please read the config files before you run aggregation to make sure you are using the correct directories, aggregation formulas and units

Note2: If aggregating singles, you may need to add a directory in between the parent directory that you would like to aggregate and the rcp folder. For example, if you are aggregating projections in `/project/cil/gcp/output/impacts-woodwork/single/uninteracted_main_model`, you may need to add a directory (call it `batch` or `single`, the name doesn't really matter). Then the aggregation system will know to travel down the directory path to the location of the projection outputs.

### Population

Running this aggregation config will give you 2 types of aggregated netcdfs:

1. Levels aggregation in minutes/day by IR (suffix `-pop-levels.nc4`. This just multiplies the projection output in minutes per worker per day by IR level population in each year.
2. Standard aggregation (suffix `pop-aggregated.nc4`). This is the result aggregated to higher levels of spatial aggregation. We go from 24,378 IRs

## Wages

Running this aggregation config will give you 2 types of aggregated netcdfs:

1. Levels aggregation in wages per year by IR (suffix `-wage-levels.nc4`).
2. Standard aggregation (suffix `wage-aggregated.nc4`).

## GDP 

## GDP per Capita