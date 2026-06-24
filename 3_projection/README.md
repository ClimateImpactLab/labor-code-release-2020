Note: You will find many response function files throughout this directory and its subdirectories. The most up-to-date (as of April 2025) specifications can be found in the `csvv` directory. _add details here about which response function corresponds to which plots_

# Running a Labor Projection

## 0. Generating the response function file (.csvv)

### Background Information
The first step to running a projection is building the response function file. The response functions come from seperate regressions estimating the impact of temperature on labor supply (usually denoted "timeuse" in the code base) and the relationship between long-run temperature, long run income per-capita and the share of high risk workers (usually denoted "empshare"). The former allows us to project the labor supply impacts of climate change in minutes/worker/day. The latter enables us to measure how temperature and socioeconomics shape the composition of the labor force, a proxy in this paper for adaptation.

Response functions in STATA .ster format will be stored in `/project/cil/home_dirs/<your-userid>/repos/labor-code-release-2020/output/ster`. Please refer to the `labor-code-release-2020/2_analysis` for information on how these response functions are generated. 

.csvv files are called metacsv files. They contain the regression coefficients on our predictive variables and the variance covariance matrix of those coefficients for each of the regressions we run. They also include a preamble describing the regression specs. A trick to easily view these is to remove the last "v" to create a .csv file – open that with excel. 

### Generate .csvv files

We run two sets of projections for the labor sector, one for each set of regression coefficients. We do this in 3 steps. First, generate the time use .csvv `3_projection/0_prepare_projections/csvv_writer_timeuse.do`. Next, generate the employment share .csvv `3_projection/0_prepare_projections/csvv_writer_empshare.do`. Finally, combine the individual .csvvs into the projection ready .csvv file (Paper spec response function codes are `uninteracted_main_model_agnonag_27_28_41` and `clim_interacted_model_agnonag_27_28_41`.

## 1. Running a projection

### What kind of run are you executing?

We run three kinds of projections: **singles**, **medians** and **montecarlos**.

- Single:
    
  Uses .csvv "gammma" coefficients (no draws from vcv matrix) to perform a point estimate per year/IR for each output value. 

  Default option is:
     GCM: CCSM4
     RCP: rcp85
     IAM: low
     SSP: SSP3

  You can edit these options in the impact-calculations repo. see `repos/impact-calculations/generate/loadmodels.py`. 
        
- Median:

  Uses .csvv "gamma" coefficients to perform points estimates for both rcps, every gcm, both iams, one SSP of your choosing (usually SSP3).

  You can edit these parameters in the run configs (more info below)

- Montecarlo:

  Takes random draws from the variance-covariance matrix across 15 batches. Batches must be run one at a time the comply with the RCC walltimes. Scripts are located in the projections repo.

### How to run

_Step 1:_ Decide which kind of run you're executing. Are you running a single, median or montecarlo? Are you running the uninteracted model or the interacted model? What spec are you using? Uninteracted projections should outputted to `<projections repo>/impacts-woodwork` and interacted regressions should be outputted to `<projections repo>/impacts-corpsepose`

_Step 2:_ Verify configs before running. SLURM jobs can be found in the projection repo (called `impact-projections-hpc-infra` in gitlab. I've renamed to `projections` in my home_dir).

If you are running a single, set the models in `loadmodels.py` as desired, then verify the .sbatch file in `/projections/SLURM/labor/single/`. You will want to make sure that the SLURM job points to the correct model config, and that the model config in question is pointing to the correct .csvv. You can also run a single on a compute node interactively if you want to monitor outputs in real time. More details below.

If you are running a median or montecarlo, verify the settings of the .sbatch file in the projections repo as before. A key difference here is that now, we operationalize run configs, allowing us to parallelize jobs by model settings. A run config (see example [here](ADD LINK)), will specify the model config used, but will include arguments like `only-ssp: SSP3` or `only-rcp: rcp85`.

_Step 3:_ Run the projection

View resource use and run times for previous runs in the RA manual [here](https://gitlab.com/ClimateImpactLab/Impacts/ra-manual/-/wikis/Compute-Usage).

There are two options for running a projection on the RCC:

- sinteractive: This is only really feasible if you are running a single or a similarly limited run (i.e. montecarlo hole filling – more on that later). However, I would recommend doing this if it's your first time running a projection, or if you have doubts about what is actually going on and you want to observe system outputs as the process is active.

  (1) Open a tmux window: `tmux new -s <session-name>`. This ensures that if for whatever reason your instance crashes, the process will continue. This step is optional but ***strongly*** recommended.
  (2) Start your interactive session (these are some suggested parameters, feel free to change based on your needs): `sinteractive --account=cil --partition=<caslake or cil> --time=06:00:00 --mem=50G --ntasks-per-node=1`. Using partition caslake will use a small portion of our service unit allocation, our usage is not tracked on the CIL partition. Both are fine to use.

  (3) Activate your environment: `source activate impact-env`

  (4) Navigate to the `impact-calculations` repo and run: `./generate.sh </full/path/to/your/config.yml>`

- SLURM jobs: This is the way we currently run projections on the RCC, all SLURM job scripts can be found in the projections repo. These are built to be easily configurable and to efficiently spread the tasks over the nodes available to us. Make sure you've configured the run as described in step 2. Navigate to the projections repository and run `sbatch <your-run-name>.sbatch`. You can check the status of these runs by running `squeue --user=<userid>`.


# Post-Projection

## 2. Create noadapt histclim

***IMPORTANT:*** This must be completed BEFORE aggregation. 

This is a new step we added to projections during revisions in winter 2026. We create a new histclim product using the share of high risk workers (variable `clip`) from the noadapt projections (instead of incadapt like the default histclim output), and the low and high risk impacts from the default histclim, then recombine them to create a new `rebased` variable. We use this to subtract from noadapt. Run `3_projection/1_run_projections/make_noadapt_histclim.py` from command line after making sure that the parameters at the top of your script correspond to the scenario you are trying to process. Activate a python environment (we have no python environment specific to the labor repo, but I have found `source activate /project/cil/home_dirs/rcc/scc` works fine. Then run the script from command line.

## 3. Aggregation

There are four types of aggregation. Each type aggregates to ADM levels higher than IRs and to global values allowing us to make time series and transform minutes/worker/day to either minutes/day or some version of valued ($) results.

- Population: This will give you two outputs per adapation scenario. `pop-levels` and `pop-aggregated`. Levels will give you impacts in minutes/day. Aggregated gives you damages in minutes/worker/day but spatially aggregated.
- Wage: Converts minutes to 2005 USD$PPP. These are used as inputs into dscim (so they get used in integration/inequality/local scc). The paper and the config display the conversion formula (also used for gdp and gdppc). Two output files per adaptation scenario: `wage-levels` and `wage-aggregated`.
- GDP: Monetized damages in % GDP impacts. Two output files per adaptation scenario: `gdp-levels` and `gdp-aggregated`. 
- GDPPC: Monetized damages in % GDP PC. Two output files per adaptation scenario: `gdppc-levels` and `gdppc-aggregated`. This aggregation type isn't used in the paper.

Use the SLURM jobs to run these. They take a while so for montecarlos we parallelize across 990 CPUS at a time.

## 4. Extraction

Make sure that you have installed James' [Prospectus tools repo](https://github.com/jrising/prospectus-tools/tree/master) and that you have the `risingverse-py27` ([link here](https://github.com/ClimateImpactLab/risingverse-py27)) environment ready. If you are on the RCC, you can load in the python module and `source activate /project/cil/home_dirs/rcc/risingverse-py27`. 

For singles, use `gcp/extract/single.py`. For medians and montecarlos, use bash scripts that call `gcp/extract/quantiles.py`.






