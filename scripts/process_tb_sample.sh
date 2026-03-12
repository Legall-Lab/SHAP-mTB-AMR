#!/bin/bash

# Usage:
# process_tb_sample.sh RUN_ID FASTQ_DIR QC_DIR BAM_DIR VCF_DIR REF


set -euo pipefail

# ---------- Resume protection ----------
# If final VCF already exists, skip this sample
RUN_ID=$1
FASTQ_DIR=$2
QC_DIR=$3
BAM_DIR=$4
VCF_DIR=$5
REF=$6

if [ -f "$VCF_DIR/${RUN_ID}.vcf.gz" ]; then
    echo "${RUN_ID} already processed. Skipping."
    exit 0
fi

THREADS=${THREADS:-8}

# Ensure output directories exist 
mkdir -p "$FASTQ_DIR"
mkdir -p "$QC_DIR"
mkdir -p "$BAM_DIR"
mkdir -p "$VCF_DIR"

# Print paths for debugging in SLURM logs
echo "FASTQ_DIR: $FASTQ_DIR"
echo "QC_DIR: $QC_DIR"
echo "BAM_DIR: $BAM_DIR"
echo "VCF_DIR: $VCF_DIR"
echo "RUN_ID: $RUN_ID"

# ---------- 1. Download FASTQ ----------
# Print node information for debugging heterogeneous HPC nodes

echo "Running on node: $(hostname)"
lscpu | head

# Use prefetch + fasterq-dump (more stable on HPC clusters)
if [ ! -f "$FASTQ_DIR/${RUN_ID}_1.fastq" ]; then
    prefetch "$RUN_ID"

    fasterq-dump "$RUN_ID" \
        --split-files \
        --threads 1 \
        -O "$FASTQ_DIR"
fi

# ---------- 2. QC ----------
fastp \
  -i "$FASTQ_DIR/${RUN_ID}_1.fastq" \
  -I "$FASTQ_DIR/${RUN_ID}_2.fastq" \
  -o "$QC_DIR/${RUN_ID}_1.clean.fastq" \
  -O "$QC_DIR/${RUN_ID}_2.clean.fastq" \
  --thread "$THREADS" \
  --detect_adapter_for_pe \
  --qualified_quality_phred 20 \
  --length_required 30

# ---------- 3. Alignment ----------
bwa mem -t "$THREADS" "$REF" \
  "$QC_DIR/${RUN_ID}_1.clean.fastq" \
  "$QC_DIR/${RUN_ID}_2.clean.fastq" | \
  samtools sort -@ "$THREADS" -o "$BAM_DIR/${RUN_ID}.bam"

samtools index "$BAM_DIR/${RUN_ID}.bam"

# ---------- 4. Variant calling ----------
bcftools mpileup -Ou -f "$REF" "$BAM_DIR/${RUN_ID}.bam" | \
  bcftools call -mv -Oz -o "$VCF_DIR/${RUN_ID}.vcf.gz"

bcftools index "$VCF_DIR/${RUN_ID}.vcf.gz"

# ---------- 5. Cleanup large intermediates ----------
rm -f "$FASTQ_DIR/${RUN_ID}_1.fastq" "$FASTQ_DIR/${RUN_ID}_2.fastq"
rm -f "$QC_DIR/${RUN_ID}_1.clean.fastq" "$QC_DIR/${RUN_ID}_2.clean.fastq"
rm -f "$BAM_DIR/${RUN_ID}.bam" "$BAM_DIR/${RUN_ID}.bam.bai"

# Remove SRA download directory created by prefetch
if [ -d "$RUN_ID" ]; then
    rm -rf "$RUN_ID"
fi

echo "[$RUN_ID] pipeline finished successfully"
