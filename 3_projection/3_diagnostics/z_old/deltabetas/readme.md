## Overview 

Codes in this repo draw on Dylan's lovely [Delta Beta code](https://gitlab.com/ClimateImpactLab/Impacts/post-projection-tools/-/tree/master/response_function) 
to break down our projection results. 

See this [issue](https://gitlab.com/ClimateImpactLab/Impacts/gcp-labor/-/issues/9) for a description of what's necessary for 
running a delta beta. 


## Code Instructions



###  `yellow_purple_script_labor.R`
- This code is the script for running delta betas. 
- To run it: 
    - You need to make sure `get_curve_labor.R` is up to date, since this code is sourced by `yellow_purple_script_labor.R`. 
    - Make sure you have a `paths` function in that code that is up to date with the correct location of the csvv you 
    want to run a delta beta for. If your model is interacted, then you also need to make sure that the path to the covariates
    (which come from the output of a single run).
    - Whatever region you want to run - add it to the location.dict so that the title of the plot is readable (ie its 
    an actual name of a place in English rather than an Impact Region code).
    - Check the `args` are all what you want - and are pointing to the paths you need. 
    - Run the delta beta by running: `yp = do.call(generate_yellow_purple,args)`. 
        - Note, you can run multiple IRs at a time if you wish! 

### `get_curve_labor.R`
- This code contains the response functions for the labor sector. The functions in this code are an input to the 
delta beta code that's run in `yellow_purple_script_labor.R`.
- The functional form here needs to be coded into R, so that the delta beta knows what response function to use. 
- You should review this code before running a delta beta, to make sure that the response function being used in the delta 
beta is doing what you want it to do. 
- ***NOTE***: the spline knot locations are currently hard coded into the `get_curve_rcspline_labor` function. If we are running a 
delta beta for a spline with different knots, you should change these. It's probably easiest to just keep those as hard coded in, and
update as needed (although I guess an alternative would be to provide an extra argument to the function used in `yellow_purple_script_labor.R`.