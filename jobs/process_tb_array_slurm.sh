#!/bin/bash
set -euo pipefail
#SBATCH --job-name=tb_pipeline
#SBATCH --cpus-per-task=8
#SBATCH --mem=20G
#SBATCH --time=4:00:00
#SBATCH --array=1-10000%100
#SBATCH -o logs/%x.%A_%a.out
#SBATCH -e logs/%x.%A_%a.err

# Clean module environment and load compatible toolchain
module --force purge
module load StdEnv/2023
module load sra-toolkit
module load fastp
module load bwa
module load samtools
module load bcftools

# Print module list for debugging in SLURM logs
module list

PROJECT_DIR="$(cd "$SLURM_SUBMIT_DIR" && pwd)"
cd "$PROJECT_DIR"

# Ensure log directory exists for SLURM output
mkdir -p "$PROJECT_DIR/logs"

# Match pipeline threads to SLURM allocation
export THREADS=$SLURM_CPUS_PER_TASK

# Ensure pipeline output directories exist
mkdir -p "$PROJECT_DIR/fastq"
mkdir -p "$PROJECT_DIR/qc_fastq"
mkdir -p "$PROJECT_DIR/aligned_bam"
mkdir -p "$PROJECT_DIR/vcf"

RUN_LIST="$PROJECT_DIR/resistance_dataset/run_accessions.txt"
RUN_ID=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$RUN_LIST")

if [ -z "$RUN_ID" ]; then
    echo "No RUN_ID found for task ${SLURM_ARRAY_TASK_ID}. Exiting."
    exit 1
fi

chmod +x "$PROJECT_DIR/scripts/process_tb_sample.sh"

"$PROJECT_DIR/scripts/process_tb_sample.sh" \
    "$RUN_ID" \
    "$PROJECT_DIR/fastq" \
    "$PROJECT_DIR/qc_fastq" \
    "$PROJECT_DIR/aligned_bam" \
    "$PROJECT_DIR/vcf" \
    "$PROJECT_DIR/reference/H37Rv.fasta"