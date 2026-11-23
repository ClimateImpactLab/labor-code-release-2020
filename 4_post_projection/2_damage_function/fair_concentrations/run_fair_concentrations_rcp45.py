#!/usr/bin/env python3
"""
FAIR CO2 Concentration Pulse Experiment for Figure 9 Panel B (RCP4.5)

Runs FAIR with AR6 parameters to compute CO2 concentration response to a 1 GtC pulse.
Saves both temperature AND concentrations.

Adapted from run_fair_concentrations.py (S. Cadavid-Sanchez,
/project/cil/home_dirs/scadavidsanchez/projects/dscim-labor-2025-update2026/paper-updates/)
to add an RCP4.5 counterpart alongside the existing RCP8.5 file. The AR6 climate
sensitivity parameters (PARAMS_FILE) are scenario-independent, so only the
emissions scenario needs to change; ssp245 is the standard SSP proxy for RCP4.5
forcing, matching how the original script used ssp585 as the RCP8.5 proxy.

Based on ar6_climate_ensemble_annual_pulse.py from pFAIR.

Configuration:
- RCP: ssp245 (RCP4.5 proxy)
- Pulse years: 2020 and 2025
- Simulations: All 2237 AR6 parameter sets (for IQR uncertainty)
- Parallelization: 20 workers using multiprocessing
- Output: control and pulse concentrations + temperatures

Usage:
    python run_fair_concentrations_rcp45.py

Output:
    output/fair_concentrations/fair_co2_concentrations_rcp45_pulse2020_2025.nc
"""

import xarray as xr
import pandas as pd
import numpy as np
import copy
import os
import sys
import time
from datetime import datetime
from multiprocessing import Pool

# Import FaIR
import fair
from fair.constants import molwt

print(f"FaIR version: {fair.__version__}")
print(f"FaIR location: {fair.__file__}")
fair_version = fair.__version__

# =============================================================================
# CONFIGURATION
# =============================================================================

REFERENCE_YEAR = 1750

# Output directory (repo output/ convention, not tracked in git - see .gitignore)
REPO_DIR = "/project/cil/home_dirs/maiqi/repos/labor-code-release-2020"
OUTPUT_DIR = os.path.join(REPO_DIR, "output", "fair_concentrations")
os.makedirs(OUTPUT_DIR, exist_ok=True)
OUTPUT_FILE = os.path.join(OUTPUT_DIR, "fair_co2_concentrations_rcp45_pulse2020_2025.nc")

# Parameters directory (shared AR6 climate params, RCP-independent)
PARAMS_FILE = "/project/cil/home_dirs/scadavidsanchez/repos/pFAIR/climate/parameters/ar6/fair_ar6_climate_params_v4.0.nc"

# Pulse configuration
CO2_PULSE_SIZE = 1.0  # GtC
PULSE_YEARS = [2020, 2025]
SCENARIO = "ssp245"  # RCP4.5 proxy
# Change to "ssp245" for RCP4.5 proxy

# Parallelization
N_WORKERS = int(os.environ.get('FAIR_N_WORKERS', 20))

# =============================================================================
# GLOBAL VARIABLES (set in main, used by workers)
# =============================================================================

# These will be set in main() before spawning workers
_ar6paramds = None
_emissions = None

# =============================================================================
# LOAD PARAMETERS (copied from original)
# =============================================================================

def load_parameters():
    """Load AR6 calibrated climate parameters"""
    print(f"Loading AR6 parameters from: {PARAMS_FILE}")

    ar6paramds = xr.open_dataset(PARAMS_FILE)
    n_simulations = len(ar6paramds.simulation)
    print(f"  Loaded {n_simulations} AR6 parameter sets")

    # Compute median parameters
    ar6paramdsdropped = ar6paramds.drop_vars(["ghg_forcing", "tropO3_forcing"])
    ar6median = ar6paramdsdropped.median(dim="simulation")
    ar6median["ghg_forcing"] = ar6paramds["ghg_forcing"]
    ar6median["tropO3_forcing"] = ar6paramds["tropO3_forcing"]

    print(f"  Median ECS: {float(ar6median['lambda_global'].values):.3f}")

    return ar6paramds, ar6median

# =============================================================================
# LOAD EMISSIONS (copied from original)
# =============================================================================

def prep_rcmip_emissions_conc(scenario):
    """Load and prepare RCMIP emissions and concentration data for AR6"""
    emis_all = pd.read_csv("/project/cil/gcp/climate/fair_rff/rcmip_raw_rcmip-emissions-annual-means-v5-1-0.csv")
    emis_subset = emis_all[(emis_all['Scenario'] == scenario) & (emis_all['Region'] == 'World')]

    species = [
        'CO2|MAGICC Fossil and Industrial', 'CO2|MAGICC AFOLU', 'CH4', 'N2O',
        'Sulfur', 'CO', 'VOC', 'NOx', 'BC', '|OC', 'NH3',
        'CF4', 'C2F6', 'C6F14', 'HFC23', 'HFC32', 'HFC4310mee', 'HFC125',
        'HFC134a', 'HFC143a', 'HFC227ea', 'HFC245fa', 'SF6', 'CFC11', 'CFC12',
        'CFC113', 'CFC114', 'CFC115', 'CCl4', 'CH3CCl3', 'HCFC22',
        'HCFC141b', 'HCFC142b', 'Halon1211', 'Halon1202', 'Halon1301',
        'Halon2402', 'CH3Br', '|CH3Cl'
    ]

    # AR6 uses 751 years (1750-2500)
    emis = np.zeros((751, 40))
    emis[:, 0] = np.arange(1750, 2501)

    for ie, specie in enumerate(species):
        try:
            tmp = emis_subset[emis_subset.Variable.str.endswith(specie)].loc[:, '1750':'2500'].values.squeeze()
            emis[:, ie+1] = pd.Series(tmp).interpolate().values
        except:
            emis[:, ie+1] = 0

    # Unit conversions
    unit_convert = np.ones(40)
    unit_convert[1] = 0.001 * molwt.C / molwt.CO2
    unit_convert[2] = 0.001 * molwt.C / molwt.CO2
    unit_convert[4] = 0.001 * molwt.N2 / molwt.N2O
    unit_convert[5] = molwt.S / molwt.SO2
    unit_convert[8] = molwt.N / molwt.NO2

    emis = emis * unit_convert

    return emis

# =============================================================================
# FAIR RUNNER
# =============================================================================

def run_fair_ar6_control_pulse(job, argsds, emissions, pulse_amount=1.0):
    """
    Run FaIR with AR6 parameters for control and pulse simulations.

    Modified from original to also return CO2 concentrations.

    Args:
        job: tuple of (pulse_year, simulation_id)
        argsds: AR6 parameter dataset
        emissions: emissions array for the scenario
        pulse_amount: pulse size in GtC

    Returns:
        dict with control and pulse temperatures AND concentrations
    """
    pulse_year, simid = job
    args = argsds.sel(simulation=simid)

    gasidx = 1  # CO2_Fossil

    nt = 751  # 1750 to 2500

    # Prepare natural forcings
    F_solar = np.zeros(nt)
    F_volcanic = np.zeros(nt)
    natural = np.zeros((nt, 2))
    F_solar[:361] = args["F_solar"]
    F_volcanic[:361] = args["F_volcanic"]
    natural[:361, :] = args["natural"]
    natural[361:, :] = args["natural"][-1, :]  # hold constant after 2110

    # Control run
    Cc, Fc, Tc, ariacic, lambda_effc, ohcc, heatfluxc = fair.forward.fair_scm(
        emissions=emissions,
        emissions_driven=True,
        C_pi=args["C_pi"].values,
        natural=natural,
        F_volcanic=F_volcanic,
        F_solar=F_solar,
        F2x=args["F2x"].values,
        r0=args["r0"].values,
        rt=args["rt"].values,
        rc=args["rc"].values,
        ariaci_out=True,
        ghg_forcing="Meinshausen",
        scale=np.asarray(args["scale"].values),
        aerosol_forcing="aerocom+ghan2",
        b_aero=np.asarray(args["b_aero"].values),
        ghan_params=np.asarray(args["ghan_params"].values),
        tropO3_forcing="thorhnill+skeie",
        ozone_feedback=args["ozone_feedback"].values,
        b_tro3=np.array(args["b_tro3"].values),
        E_pi=emissions[0, :],
        scaleAerosolAR5=False,
        scaleHistoricalAR5=False,
        fixPre1850RCP=False,
        aviNOx_frac=0,
        aCO2land=args["aCO2land"].values,
        stwv_from_ch4=args["stwv_from_ch4"].values,
        F_ref_BC=args["F_ref_BC"].values,
        E_ref_BC=args["E_ref_BC"].values,
        efficacy=np.ones(45),
        diagnostics="AR6",
        temperature_function="Geoffroy",
        lambda_global=args["lambda_global"].values,
        deep_ocean_efficacy=args["deep_ocean_efficacy"].values,
        ocean_heat_capacity=np.asarray(args["ocean_heat_capacity"].values),
        ocean_heat_exchange=args["ocean_heat_exchange"].values,
    )

    # Pulse run
    pulse_emissions = copy.copy(emissions)
    pulse_emissions[pulse_year - REFERENCE_YEAR, gasidx] += pulse_amount

    Cp, Fp, Tp, ariacip, lambda_effp, ohcp, heatfluxp = fair.forward.fair_scm(
        emissions=pulse_emissions,
        emissions_driven=True,
        C_pi=args["C_pi"].values,
        natural=natural,
        F_volcanic=F_volcanic,
        F_solar=F_solar,
        F2x=args["F2x"].values,
        r0=args["r0"].values,
        rt=args["rt"].values,
        rc=args["rc"].values,
        ariaci_out=True,
        ghg_forcing="Meinshausen",
        scale=np.asarray(args["scale"].values),
        aerosol_forcing="aerocom+ghan2",
        b_aero=np.asarray(args["b_aero"].values),
        ghan_params=np.asarray(args["ghan_params"].values),
        tropO3_forcing="thorhnill+skeie",
        ozone_feedback=args["ozone_feedback"].values,
        b_tro3=np.array(args["b_tro3"].values),
        E_pi=emissions[0, :],
        scaleAerosolAR5=False,
        scaleHistoricalAR5=False,
        fixPre1850RCP=False,
        aviNOx_frac=0,
        aCO2land=args["aCO2land"].values,
        stwv_from_ch4=args["stwv_from_ch4"].values,
        F_ref_BC=args["F_ref_BC"].values,
        E_ref_BC=args["E_ref_BC"].values,
        efficacy=np.ones(45),
        diagnostics="AR6",
        temperature_function="Geoffroy",
        lambda_global=args["lambda_global"].values,
        deep_ocean_efficacy=args["deep_ocean_efficacy"].values,
        ocean_heat_capacity=np.asarray(args["ocean_heat_capacity"].values),
        ocean_heat_exchange=args["ocean_heat_exchange"].values,
    )

    return {
        'pulse_year': pulse_year,
        'simid': simid,
        'control_temperature': Tc.astype(np.float32),
        'pulse_temperature': Tp.astype(np.float32),
        'control_concentration': Cc[:, 0].astype(np.float32),  # CO2 only
        'pulse_concentration': Cp[:, 0].astype(np.float32),    # CO2 only
    }


def run_fair_ar6_median(ar6median, emissions, pulse_year, pulse_amount=1.0):
    """Run FaIR with median AR6 parameters."""
    args = ar6median
    gasidx = 1

    nt = 751
    F_solar = np.zeros(nt)
    F_volcanic = np.zeros(nt)
    natural = np.zeros((nt, 2))
    F_solar[:361] = args["F_solar"]
    F_volcanic[:361] = args["F_volcanic"]
    natural[:361, :] = args["natural"]
    natural[361:, :] = args["natural"][-1, :]

    # Control run
    Cc, Fc, Tc, ariacic, lambda_effc, ohcc, heatfluxc = fair.forward.fair_scm(
        emissions=emissions,
        emissions_driven=True,
        C_pi=args["C_pi"].values,
        natural=natural,
        F_volcanic=F_volcanic,
        F_solar=F_solar,
        F2x=args["F2x"].values,
        r0=args["r0"].values,
        rt=args["rt"].values,
        rc=args["rc"].values,
        ariaci_out=True,
        ghg_forcing="Meinshausen",
        scale=np.asarray(args["scale"].values),
        aerosol_forcing="aerocom+ghan2",
        b_aero=np.asarray(args["b_aero"].values),
        ghan_params=np.asarray(args["ghan_params"].values),
        tropO3_forcing="thorhnill+skeie",
        ozone_feedback=args["ozone_feedback"].values,
        b_tro3=np.array(args["b_tro3"].values),
        E_pi=emissions[0, :],
        scaleAerosolAR5=False,
        scaleHistoricalAR5=False,
        fixPre1850RCP=False,
        aviNOx_frac=0,
        aCO2land=args["aCO2land"].values,
        stwv_from_ch4=args["stwv_from_ch4"].values,
        F_ref_BC=args["F_ref_BC"].values,
        E_ref_BC=args["E_ref_BC"].values,
        efficacy=np.ones(45),
        diagnostics="AR6",
        temperature_function="Geoffroy",
        lambda_global=args["lambda_global"].values,
        deep_ocean_efficacy=args["deep_ocean_efficacy"].values,
        ocean_heat_capacity=np.asarray(args["ocean_heat_capacity"].values),
        ocean_heat_exchange=args["ocean_heat_exchange"].values,
    )

    # Pulse run
    pulse_emissions = copy.copy(emissions)
    pulse_emissions[pulse_year - REFERENCE_YEAR, gasidx] += pulse_amount

    Cp, Fp, Tp, ariacip, lambda_effp, ohcp, heatfluxp = fair.forward.fair_scm(
        emissions=pulse_emissions,
        emissions_driven=True,
        C_pi=args["C_pi"].values,
        natural=natural,
        F_volcanic=F_volcanic,
        F_solar=F_solar,
        F2x=args["F2x"].values,
        r0=args["r0"].values,
        rt=args["rt"].values,
        rc=args["rc"].values,
        ariaci_out=True,
        ghg_forcing="Meinshausen",
        scale=np.asarray(args["scale"].values),
        aerosol_forcing="aerocom+ghan2",
        b_aero=np.asarray(args["b_aero"].values),
        ghan_params=np.asarray(args["ghan_params"].values),
        tropO3_forcing="thorhnill+skeie",
        ozone_feedback=args["ozone_feedback"].values,
        b_tro3=np.array(args["b_tro3"].values),
        E_pi=emissions[0, :],
        scaleAerosolAR5=False,
        scaleHistoricalAR5=False,
        fixPre1850RCP=False,
        aviNOx_frac=0,
        aCO2land=args["aCO2land"].values,
        stwv_from_ch4=args["stwv_from_ch4"].values,
        F_ref_BC=args["F_ref_BC"].values,
        E_ref_BC=args["E_ref_BC"].values,
        efficacy=np.ones(45),
        diagnostics="AR6",
        temperature_function="Geoffroy",
        lambda_global=args["lambda_global"].values,
        deep_ocean_efficacy=args["deep_ocean_efficacy"].values,
        ocean_heat_capacity=np.asarray(args["ocean_heat_capacity"].values),
        ocean_heat_exchange=args["ocean_heat_exchange"].values,
    )

    return {
        'control_temperature': Tc.astype(np.float32),
        'pulse_temperature': Tp.astype(np.float32),
        'control_concentration': Cc[:, 0].astype(np.float32),
        'pulse_concentration': Cp[:, 0].astype(np.float32),
    }


# =============================================================================
# WORKER WRAPPER (for multiprocessing)
# =============================================================================

def worker_wrapper(job):
    """Wrapper function for multiprocessing that uses global data."""
    global _ar6paramds, _emissions
    return run_fair_ar6_control_pulse(job, _ar6paramds, _emissions, pulse_amount=CO2_PULSE_SIZE)


def init_worker(ar6paramds, emissions):
    """Initialize global variables in each worker process."""
    global _ar6paramds, _emissions
    _ar6paramds = ar6paramds
    _emissions = emissions


# =============================================================================
# MAIN
# =============================================================================

def main():
    """Main execution function with parallel processing."""
    global _ar6paramds, _emissions

    start_time = time.time()

    print("=" * 70)
    print("FAIR CO2 CONCENTRATION PULSE EXPERIMENT (RCP4.5)")
    print("=" * 70)
    print(f"FaIR version: {fair_version}")
    print(f"Scenario: {SCENARIO}")
    print(f"Pulse years: {PULSE_YEARS}")
    print(f"Pulse size: {CO2_PULSE_SIZE} GtC")
    print(f"Workers: {N_WORKERS}")
    print(f"Output: {OUTPUT_FILE}")
    print()

    # parameters
    ar6paramds, ar6median = load_parameters()
    n_simulations = len(ar6paramds.simulation)
    simulation_ids = ar6paramds.simulation.values

    # emissions
    print(f"Loading {SCENARIO} emissions...")
    emissions = prep_rcmip_emissions_conc(SCENARIO)
    print(f"  Emissions shape: {emissions.shape}")

    # test: run ONE simulation sequentially BEFORE any multiprocessing
    print("\n" + "=" * 50)
    print("Testing single simulation (no multiprocessing)...")
    print("=" * 50)
    test_job = (2025, simulation_ids[0])
    print(f"Test job: pulse_year={test_job[0]}, simid={test_job[1]}")
    try:
        test_result = run_fair_ar6_control_pulse(
            test_job, ar6paramds, emissions,
            pulse_amount=CO2_PULSE_SIZE
        )
        print(f"Test PASSED!")
        print(f"  Control temp shape: {test_result['control_temperature'].shape}")
        print(f"  Control CO2 conc at year 2025: {test_result['control_concentration'][2025-1750]:.1f} ppm")
    except Exception as e:
        print(f"Test FAILED with error: {e}")
        import traceback
        traceback.print_exc()
        print("\nThis is a FAIR issue, not a multiprocessing issue.")
        print("Check that FAIR v1.6.2 is properly installed in this environment.")
        sys.exit(1)
    print("=" * 50 + "\n")

    # global variables for this process (needed for pool initializer)
    _ar6paramds = ar6paramds
    _emissions = emissions

    # jobs: (pulse_year, simulation_id) for all combinations
    jobs = [(pulse_year, simid) for pulse_year in PULSE_YEARS for simid in simulation_ids]
    total_jobs = len(jobs)
    print(f"\nTotal jobs: {total_jobs:,} ({n_simulations} sims x {len(PULSE_YEARS)} pulse years)")
    print()

    # init result arrays
    n_years = 751
    n_pulse_years = len(PULSE_YEARS)

    control_temp = np.zeros((n_simulations, n_years), dtype=np.float32)
    pulse_temp = np.zeros((n_pulse_years, n_simulations, n_years), dtype=np.float32)
    control_conc = np.zeros((n_simulations, n_years), dtype=np.float32)
    pulse_conc = np.zeros((n_pulse_years, n_simulations, n_years), dtype=np.float32)

    # simulation ID to index mapping
    simid_to_idx = {simid: idx for idx, simid in enumerate(simulation_ids)}

    # run parallel
    print(f"Starting parallel execution with {N_WORKERS} workers...")
    parallel_start = time.time()

    completed = 0
    control_stored = set()

    with Pool(processes=N_WORKERS, initializer=init_worker, initargs=(ar6paramds, emissions)) as pool:
        for result in pool.imap_unordered(worker_wrapper, jobs, chunksize=10):
            pulse_year = result['pulse_year']
            simid = result['simid']
            sim_idx = simid_to_idx[simid]
            pulse_idx = PULSE_YEARS.index(pulse_year)

            # store control only once per simulation [avoid multiple runs]
            if sim_idx not in control_stored:
                control_temp[sim_idx, :] = result['control_temperature']
                control_conc[sim_idx, :] = result['control_concentration']
                control_stored.add(sim_idx)

            # Store pulse
            pulse_temp[pulse_idx, sim_idx, :] = result['pulse_temperature']
            pulse_conc[pulse_idx, sim_idx, :] = result['pulse_concentration']

            completed += 1
            if completed % 200 == 0 or completed == total_jobs:
                elapsed = time.time() - parallel_start
                rate = completed / elapsed
                remaining = (total_jobs - completed) / rate if rate > 0 else 0
                print(f"  Progress: {completed:,}/{total_jobs:,} jobs "
                      f"({100*completed/total_jobs:.1f}%) - "
                      f"{elapsed:.0f}s elapsed, ~{remaining:.0f}s remaining")

    parallel_time = time.time() - parallel_start
    print(f"\nParallel execution completed in {parallel_time:.1f}s")

    # Run median params (just 2 runs, do sequentially)
    print("\nRunning median parameter simulations...")
    median_control_temp = np.zeros((n_years,), dtype=np.float32)
    median_pulse_temp = np.zeros((n_pulse_years, n_years), dtype=np.float32)
    median_control_conc = np.zeros((n_years,), dtype=np.float32)
    median_pulse_conc = np.zeros((n_pulse_years, n_years), dtype=np.float32)

    for pulse_idx, pulse_year in enumerate(PULSE_YEARS):
        result = run_fair_ar6_median(ar6median, emissions, pulse_year, CO2_PULSE_SIZE)

        if pulse_idx == 0:
            median_control_temp[:] = result['control_temperature']
            median_control_conc[:] = result['control_concentration']

        median_pulse_temp[pulse_idx, :] = result['pulse_temperature']
        median_pulse_conc[pulse_idx, :] = result['pulse_concentration']

    print("  Done")

    # create xarray ds
    print("\nCreating xarray Dataset...")
    years = np.arange(REFERENCE_YEAR, REFERENCE_YEAR + n_years)

    ds = xr.Dataset(
        {
            # all simulations
            'control_temperature': (['simulation', 'year'], control_temp),
            'pulse_temperature': (['pulse_year', 'simulation', 'year'], pulse_temp),
            'control_co2_concentration': (['simulation', 'year'], control_conc),
            'pulse_co2_concentration': (['pulse_year', 'simulation', 'year'], pulse_conc),
            # median params
            'medianparams_control_temperature': (['year'], median_control_temp),
            'medianparams_pulse_temperature': (['pulse_year', 'year'], median_pulse_temp),
            'medianparams_control_co2_concentration': (['year'], median_control_conc),
            'medianparams_pulse_co2_concentration': (['pulse_year', 'year'], median_pulse_conc),
        },
        coords={
            'simulation': simulation_ids,
            'pulse_year': PULSE_YEARS,
            'year': years,
        }
    )

    # add attributes
    ds.attrs = {
        'description': (
            f'FAIR CO2 concentration pulse experiment for Figure 9 Panel B (RCP4.5). '
            f'FaIR version {fair_version} with AR6 calibrated parameters. '
            f'Includes both temperature AND CO2 concentrations for control and pulse runs.'
        ),
        'created': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
        'author': 'Sebastian Cadavid-Sanchez',
        'FaIR_version': fair_version,
        'scenario': SCENARIO,
        'pulse_years': str(PULSE_YEARS),
        'pulse_size_GtC': CO2_PULSE_SIZE,
        'n_simulations': n_simulations,
        'n_workers': N_WORKERS,
        'reference_year': REFERENCE_YEAR,
        'AR6_parameters': 'fair_ar6_climate_params_v4.0.nc',
    }

    # Add variable attributes
    ds['control_co2_concentration'].attrs = {
        'long_name': 'Control run atmospheric CO2 concentration',
        'units': 'ppm',
    }
    ds['pulse_co2_concentration'].attrs = {
        'long_name': 'Pulse run atmospheric CO2 concentration',
        'units': 'ppm',
    }
    ds['control_temperature'].attrs = {
        'long_name': 'Control run global mean surface temperature anomaly',
        'units': 'K',
    }
    ds['pulse_temperature'].attrs = {
        'long_name': 'Pulse run global mean surface temperature anomaly',
        'units': 'K',
    }

    # Save
    print(f"Saving to: {OUTPUT_FILE}")
    ds.to_netcdf(OUTPUT_FILE)

    # Summary
    total_time = time.time() - start_time
    print()
    print("=" * 70)
    print("COMPLETE!")
    print("=" * 70)
    print(f"Total runtime: {total_time:.1f}s ({total_time/60:.1f} minutes)")
    print(f"Parallel time: {parallel_time:.1f}s")
    print(f"Output file: {OUTPUT_FILE}")
    print()

    # Quick validation
    print("Quick validation:")
    delta_C_2025 = ds['pulse_co2_concentration'].sel(pulse_year=2025) - ds['control_co2_concentration']
    delta_C_median = delta_C_2025.median(dim='simulation')
    idx_2030 = np.where(years == 2030)[0][0]
    idx_2100 = np.where(years == 2100)[0][0]
    idx_2200 = np.where(years == 2200)[0][0]
    print(f"  Delta CO2 (2025 pulse, median) at 2030: {float(delta_C_median[idx_2030]):.4f} ppm")
    print(f"  Delta CO2 (2025 pulse, median) at 2100: {float(delta_C_median[idx_2100]):.4f} ppm")
    print(f"  Delta CO2 (2025 pulse, median) at 2200: {float(delta_C_median[idx_2200]):.4f} ppm")
    print(f"  Peak delta CO2: {float(delta_C_median.max()):.4f} ppm")

    # Check for secondary rise
    if float(delta_C_median[idx_2200]) > float(delta_C_median[idx_2100]):
        print(f"  Secondary CO2 rise detected (2200 > 2100)!")


if __name__ == "__main__":
    main()
