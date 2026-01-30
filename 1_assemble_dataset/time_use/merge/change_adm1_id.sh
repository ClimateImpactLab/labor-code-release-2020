#!/bin/bash

INPUT_DIR="/project/cil/battuta_shares/gcp/estimation/labor/code_release_int_data/climate/spatial_data/GBR/adm1_updated"
OUTPUT_DIR="/project/cil/battuta_shares/gcp/estimation/labor/code_release_int_data/climate/final/GBR/adm1"

mkdir -p "$OUTPUT_DIR"

# mapping region_code → adm1_id
declare -A MAP
MAP[1]=50030000
MAP[2]=50090000
MAP[3]=50010000
MAP[4]=50060000
MAP[5]=50070000
MAP[6]=50080000
MAP[7]=50050000
MAP[8]=50040000

echo "Starting conversion..."

for file in "$INPUT_DIR"/*.csv; do
    fname=$(basename "$file")
    echo "Processing $fname"

    awk -F, -v OFS=',' \
        -v a1="${MAP[1]}" -v a2="${MAP[2]}" -v a3="${MAP[3]}" \
        -v a4="${MAP[4]}" -v a5="${MAP[5]}" -v a6="${MAP[6]}" \
        -v a7="${MAP[7]}" -v a8="${MAP[8]}" '

        NR==1 {
            # 找到 adm1_id 列
            for(i=1; i<=NF; i++){
                if($i == "adm1_id") col=i
            }
            print
            next
        }

        NR>1 {
            # 从 "GBR_X" 中提取 X 作为 region_code
            gsub("GBR_", "", $col)
            code = $col + 0

            if (code == 1) $col = a1
            else if (code == 2) $col = a2
            else if (code == 3) $col = a3
            else if (code == 4) $col = a4
            else if (code == 5) $col = a5
            else if (code == 6) $col = a6
            else if (code == 7) $col = a7
            else if (code == 8) $col = a8
            else $col = "NA"   # debug: unexpected values

            print
        }
    ' "$file" > "$OUTPUT_DIR/$fname"

done

echo "Done. Output stored in $OUTPUT_DIR"
