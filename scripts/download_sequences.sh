#!/bin/bash

INPUT_FILE="/C/Users/Noah Legall/LegallLab/SHAP-mTB-AMR/accesion_ids/1000_dataset/rifampicin_susceptible_mtb_accessions.csv"
MAX_JOBS=4
TIME_LIMIT=900  

# Read accessions into an array
mapfile -t accessions < "$INPUT_FILE"

# Job counter
job_count=0

for accession in "${accessions[@]}"; do
    (
        echo "Starting: $accession"
        timeout "$TIME_LIMIT"  fastq-dump $accession --split-files -skip-technical -v --gzip
            > "${accession}.out.log" 2> "${accession}.err.log"

        status=$?
        if [[ $status -eq 124 ]]; then
            echo "Timed out: $accession" >> timeouts.log
        elif [[ $status -ne 0 ]]; then
            echo "Error (code $status): $accession" >> errors.log
        else
            echo "Finished: $accession"
        fi

        rm "${accession}.out.log" "${accession}.err.log"
    ) &  # Run in background

    ((job_count++))

    # Wait if number of background jobs hits the limit
    while (( $(jobs -r | wc -l) >= MAX_JOBS )); do
        sleep 1
    done
done

wait  # Wait for all jobs to complete
