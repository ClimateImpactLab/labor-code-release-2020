#!/usr/bin/env bash
set -euo pipefail

############################
# 1. Hard-coded paths
############################
# !! CHANGE THESE TO YOUR REAL PATHS !!
INPUT_DIR="/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/1_assemble_dataset/time_use/weather/test_in"
OUTPUT_DIR="/project/cil/home_dirs/maiqi/repos/labor-code-release-2020/1_assemble_dataset/time_use/weather/test_out"

############################
# 2. Hard-coded weights
############################
# North of England:
#   50030000 -> North West
#   50020000 -> North East
#   50100000 -> Yorkshire and the Humber
w_NW=0.3      # North of England - North West
w_NE=0.4      # North of England - North East
w_YH=0.3      # North of England - Yorkshire and the Humber

# English Midlands:
#   50000000 -> West Midlands
#   50010000 -> East Midlands
w_WM=0.5      # English Midlands - West Midlands
w_EM=0.5      # English Midlands - East Midlands

mkdir -p "$OUTPUT_DIR"

############################
# 3. Loop over CSV files
############################
for f in "$INPUT_DIR"/*.csv; do
  [ -e "$f" ] || continue

  base=$(basename "$f")
  out="$OUTPUT_DIR/$base"

  awk -F',' -v OFS=',' \
      -v w_NW="$w_NW" -v w_NE="$w_NE" -v w_YH="$w_YH" \
      -v w_WM="$w_WM" -v w_EM="$w_EM" '
    NR == 1 {
      nfields = NF

      # identify important columns by name
      idx_adm = idx_year = idx_month = idx_day = 0
      for (i = 1; i <= NF; i++) {
        header[i] = $i
        if ($i == "adm1_id") idx_adm = i
        else if ($i == "year")  idx_year  = i
        else if ($i == "month") idx_month = i
        else if ($i == "day")   idx_day   = i
      }

      # panel_mode = file has year, month, day columns
      panel_mode = (idx_year > 0 && idx_month > 0 && idx_day > 0)

      if (panel_mode) {
        # collect positions of all "data" columns (to be weighted)
        # = all columns except adm1_id/year/month/day
        nd = 0
        for (i = 1; i <= NF; i++) {
          if (i != idx_adm && i != idx_year && i != idx_month && i != idx_day) {
            nd++
            data_idx[nd] = i
            data_pos[i]  = nd
          }
        }
      }

      print $0
      next
    }

    ###########################################################
    # NON-PANEL CASE (no year/month/day)
    ###########################################################
    !panel_mode {
      print $0

      # Assume column 1 is adm1_id, column 2 is value to average
      if ($idx_adm == "50030000") v_50030000 = $2
      if ($idx_adm == "50020000") v_50020000 = $2
      if ($idx_adm == "50100000") v_50100000 = $2

      if ($idx_adm == "50000000") v_50000000 = $2
      if ($idx_adm == "50010000") v_50010000 = $2

      next
    }

    ###########################################################
    # PANEL CASE (has year/month/day)
    ###########################################################
    panel_mode {
      print $0

      id = $idx_adm
      y  = $idx_year
      m  = $idx_month
      d  = $idx_day

      key = y "-" m "-" d   # date key

      if (!(key in key_seen)) {
        key_seen[key] = 1
        nkeys++
        keys[nkeys] = key
        Y[key] = y
        M[key] = m
        D[key] = d
      }

      # store values for each adm1 and data column, by day
      for (k = 1; k <= nd; k++) {
        col = data_idx[k]
        val = $(col)

        if (id == "50030000") NW[key, k] = val
        if (id == "50020000") NE[key, k] = val
        if (id == "50100000") YH[key, k] = val

        if (id == "50000000") WM[key, k] = val
        if (id == "50010000") EM[key, k] = val
      }
      next
    }

    ###########################################################
    # END BLOCK
    ###########################################################
    END {
      if (!panel_mode) {
        # ---------- Old behavior: one weighted average on column 2 ----------
        if (v_50030000 != "" && v_50020000 != "" && v_50100000 != "") {
          sumw1 = w_NW + w_NE + w_YH
          if (sumw1 != 0) {
            avg1 = (w_NW * v_50030000 + w_NE * v_50020000 + w_YH * v_50100000) / sumw1
            print "50110000", avg1
          }
        }

        if (v_50000000 != "" && v_50010000 != "") {
          sumw2 = w_WM + w_EM
          if (sumw2 != 0) {
            avg2 = (w_WM * v_50000000 + w_EM * v_50010000) / sumw2
            print "50120000", avg2
          }
        }
        exit
      }

      # ---------- Panel behavior: per-day, for all data columns ----------
      for (ki = 1; ki <= nkeys; ki++) {
        key = keys[ki]
        y = Y[key]; m = M[key]; d = D[key]

        ######## Group 1: North of England -> new adm1_id 50110000 ########
        ok1 = 1
        for (k = 1; k <= nd; k++) {
          if (!((key, k) in NW) || !((key, k) in NE) || !((key, k) in YH)) {
            ok1 = 0
            break
          }
        }
        if (ok1) {
          sumw1 = w_NW + w_NE + w_YH
          if (sumw1 != 0) {
            for (k = 1; k <= nd; k++) {
              avg1[k] = (w_NW * NW[key, k] + w_NE * NE[key, k] + w_YH * YH[key, k]) / sumw1
            }
            # print one new row with adm1_id = 50110000
            for (i = 1; i <= nfields; i++) {
              if (i == idx_adm)      field = "50110000"
              else if (i == idx_year)  field = y
              else if (i == idx_month) field = m
              else if (i == idx_day)   field = d
              else {
                pos = data_pos[i]
                field = (pos in avg1) ? avg1[pos] : ""
              }
              if (i == 1) printf "%s", field
              else        printf OFS "%s", field
            }
            printf "\n"
          }
        }

        ######## Group 2: English Midlands -> new adm1_id 50120000 ########
        ok2 = 1
        for (k = 1; k <= nd; k++) {
          if (!((key, k) in WM) || !((key, k) in EM)) {
            ok2 = 0
            break
          }
        }
        if (ok2) {
          sumw2 = w_WM + w_EM
          if (sumw2 != 0) {
            for (k = 1; k <= nd; k++) {
              avg2[k] = (w_WM * WM[key, k] + w_EM * EM[key, k]) / sumw2
            }
            # print one new row with adm1_id = 50120000
            for (i = 1; i <= nfields; i++) {
              if (i == idx_adm)      field = "50120000"
              else if (i == idx_year)  field = y
              else if (i == idx_month) field = m
              else if (i == idx_day)   field = d
              else {
                pos = data_pos[i]
                field = (pos in avg2) ? avg2[pos] : ""
              }
              if (i == 1) printf "%s", field
              else        printf OFS "%s", field
            }
            printf "\n"
          }
        }
      }
    }
  ' "$f" > "$out"

  echo "Processed: $f -> $out"
done
