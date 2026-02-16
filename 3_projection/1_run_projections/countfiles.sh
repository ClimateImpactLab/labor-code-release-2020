#!/bin/bash

# Usage: ./countfiles.sh /path/to/parent_directory

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 parent_directory"
  exit 1
fi

parent_dir="$1"

if [ ! -d "$parent_dir" ]; then
  echo "Error: '$parent_dir' is not a valid directory."
  exit 1
fi

# Initialize aggregate counters
total_std=0
total_pop=0
total_gdp=0
total_wage=0

# Use process substitution so the while-loop runs in the current shell (not a subshell)
while IFS= read -r dir; do
  # Only consider terminal directories (no subdirectories)
  if [ -z "$(find "$dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)" ]; then
    # Count "standard" by exact filenames
    std_count=0
    for fname in \
      "uninteracted_main_model_agnonag_27_28_41.nc4" \
      "uninteracted_main_model_agnonag_27_28_41-noadapt.nc4" \
      "uninteracted_main_model_agnonag_27_28_41-incadapt.nc4" \
      "uninteracted_main_model_agnonag_27_28_41-histclim.nc4"
    do
      [ -f "$dir/$fname" ] && std_count=$((std_count + 1))
    done

    # Count matches for "pop", "gdp", "wage"
    pop_count=$(find "$dir" -maxdepth 1 -type f -iname "*pop*.nc4" 2>/dev/null | wc -l)
    gdp_count=$(find "$dir" -maxdepth 1 -type f -iname "*gdp*.nc4" 2>/dev/null | wc -l)
    wage_count=$(find "$dir" -maxdepth 1 -type f -iname "*wage*.nc4" 2>/dev/null | wc -l)

    total_std=$((total_std + std_count))
    total_pop=$((total_pop + pop_count))
    total_gdp=$((total_gdp + gdp_count))
    total_wage=$((total_wage + wage_count))
  fi
done < <(find "$parent_dir" -type d)

echo "standard: $total_std"
echo "pop:      $total_pop"
echo "gdp:      $total_gdp"
echo "wage:     $total_wage"