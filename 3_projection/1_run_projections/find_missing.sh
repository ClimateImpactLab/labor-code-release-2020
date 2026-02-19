#!/bin/bash
# Usage: ./missingfiles.sh /path/to/median

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 parent_directory"
  exit 1
fi

parent_dir="$1"
if [ ! -d "$parent_dir" ]; then
  echo "Error: '$parent_dir' is not a valid directory."
  exit 1
fi

base="uninteracted_main_model_agnonag_27_28_41"

# Expected standard files
std_files=(
  "${base}.nc4"
  "${base}-noadapt.nc4"
  "${base}-incadapt.nc4"
  "${base}-histclim.nc4"
)

# Expected models per rcp
models_rcp85=(
  ACCESS1-0 bcc-csm1-1 BNU-ESM CanESM2 CCSM4 CESM1-BGC CNRM-CM5
  CSIRO-Mk3-6-0 GFDL-CM3 GFDL-ESM2G GFDL-ESM2M inmcm4 IPSL-CM5A-LR
  IPSL-CM5A-MR MIROC5 MIROC-ESM MIROC-ESM-CHEM MPI-ESM-LR MPI-ESM-MR
  MRI-CGCM3 NorESM1-M surrogate_CanESM2_89 surrogate_CanESM2_94
  surrogate_CanESM2_99 surrogate_GFDL-CM3_89 surrogate_GFDL-CM3_94
  surrogate_GFDL-CM3_99 surrogate_GFDL-ESM2G_01 surrogate_GFDL-ESM2G_06
  surrogate_GFDL-ESM2G_11 surrogate_MRI-CGCM3_01 surrogate_MRI-CGCM3_06
  surrogate_MRI-CGCM3_11
)

models_rcp45=(
  ACCESS1-0 bcc-csm1-1 BNU-ESM CanESM2 CCSM4 CESM1-BGC CNRM-CM5
  CSIRO-Mk3-6-0 GFDL-CM3 GFDL-ESM2G GFDL-ESM2M inmcm4 IPSL-CM5A-LR
  IPSL-CM5A-MR MIROC5 MIROC-ESM MIROC-ESM-CHEM MPI-ESM-LR MPI-ESM-MR
  MRI-CGCM3 NorESM1-M surrogate_CanESM2_89 surrogate_CanESM2_94
  surrogate_CanESM2_99 surrogate_GFDL-CM3_89 surrogate_GFDL-CM3_94
  surrogate_GFDL-CM3_99 surrogate_GFDL-ESM2G_01
  surrogate_GFDL-ESM2G_11 surrogate_MRI-CGCM3_01 surrogate_MRI-CGCM3_06
  surrogate_MRI-CGCM3_11
)

iams=("high" "low")
ssps=("SSP2" "SSP3" "SSP4")

missing_count=0

for rcp in rcp45 rcp85; do
  if [ "$rcp" == "rcp85" ]; then
    models=("${models_rcp85[@]}")
  else
    models=("${models_rcp45[@]}")
  fi

  for model in "${models[@]}"; do
    model_dir="$parent_dir/$rcp/$model"

    # Check model dir exists
    if [ ! -d "$model_dir" ]; then
      echo "MISSING DIR: $model_dir"
      missing_count=$((missing_count + 1))
      continue
    fi

    for iam in "${iams[@]}"; do
      for ssp in "${ssps[@]}"; do
        leaf_dir="$model_dir/$iam/$ssp"

        # Check iam/ssp dir exists
        if [ ! -d "$leaf_dir" ]; then
          echo "MISSING DIR: $leaf_dir"
          missing_count=$((missing_count + 1))
          continue
        fi

        # Check standard files
        for fname in "${std_files[@]}"; do
          if [ ! -f "$leaf_dir/$fname" ]; then
            echo "MISSING FILE: $leaf_dir/$fname"
            missing_count=$((missing_count + 1))
          fi
        done

      done
    done
  done
done

echo ""
echo "Total missing: $missing_count"