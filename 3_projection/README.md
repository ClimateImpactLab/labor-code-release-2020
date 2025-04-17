Note: You will find many response function files throughout this directory and its subdirectories. The most up-to-date (as of April 2025) specifications can be found in the `csvv` directory. _add details here about which response function corresponds to which plots_

# Running a Labor Projection

0. Generating the response function file (.cssvv)

### Background Information
The first step to running a projection is building the response function file. The response functions come from seperate regressions estimating the impact of temperature on labor supply (usually denoted "timeuse" in the code base) and the relationship between long-run temperature, long run income per-capita and the share of high risk workers (usually denoted "empshare"). The former allows us to project the labor supply impacts of climate change in minutes/worker/day. The latter enables us to measure how temperature and socioeconomics shape the composition of the labor force, a proxy in this paper for adaptation.

Response functions in STATA .ster format will be stored in `/project/cil/home_dirs/<your-userid>/repos/labor-code-release-2020/output/ster`. Please refer to the `labor-code-release-2020/2_analysis` for information on how these response functions are generated. 

.csvv files are called metacsv files. They contain the regression coefficients on our predictive variables and the variance covariance matrix of those coefficients for each of the regressions we run. They also include a preamble describing the regression specs. A trick to easily view these is to remove the last "v" to create a .csv file – open that with excel. 

### Generate .csvv files

We run two sets of projections for the labor sector, one for each set of regression coefficients. We do this in 3 steps. First, generate the time use .csvv `3_projection/0_prepare_projections/csvv_writer_timeuse.do` (NOTE HERE TO EDIT PATHS TO HOWEVER I STRUCTURE DIRECTORY ONCE INTERACTED IS RUN). Next, generate the employment share .csvv `3_projection/0_prepare_projections/csvv_writer_empshare.do` (PATHS HERE TOO). Finally, combine the individual .csvvs into the projection ready .csvv file (Paper spec response function codes are `uninteracted_main_model` and `<interacted model goes here>`.

1. Running a projection

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

        You can edit these parameters in the run_configs (more info below)

    - Montecarlo:

        Takes random draws from the variance-covariance matrix across 15 batches. Batches must be run once at a time the comply with the RCC walltimes. Scripts are located in the projections repo (UNDER CONSTRUCTION). 

### How to run

_Step 1:_ Decide which kind of run you're executing. Are you running a single, median or montecarlo? Are you running the uninteracted model or the interacted model? What spec are you using?

_Step :_ 
2. 