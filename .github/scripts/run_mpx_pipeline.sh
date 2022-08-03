#!/bin/bash
set -eo pipefail

# Create a Cache Dir
mkdir -p conda_cache_dir

# Get partial human ref genome
wget https://raw.githubusercontent.com/DarianHole/test-datasets/master/partial_human_ref/partial_hg38_ref.fa.gz
gunzip partial_hg38_ref.fa.gz

# Workaround for mamba-org/mamba#488
rm -f /usr/share/miniconda/pkgs/cache/*.json

# Run Illumina Pipeline
nextflow run ./main.nf \
    -profile conda,test \
    --cache ./conda_cache_dir \
    --directory $PWD/.github/ci-data/ \
    --human_ref $PWD/partial_hg38_ref.fa

# Reset and Track
mv .nextflow.log artifacts/nextflow.log
ls results
rm -rf results work/ .nextflow* partial_hg38_ref.fa

echo "Done"
