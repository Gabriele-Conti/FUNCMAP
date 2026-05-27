# FUNCMAP usage

This document provides practical examples for running FUNCMAP.

## Basic SLURM + Apptainer run

```bash
nextflow run /path/to/FUNCMAP \
  -profile slurm,apptainer \
  --input /path/to/samplesheet.csv \
  --dbsheet /path/to/databases_funcmap.csv \
  --outdir /path/to/results \
  --funcmap_container /path/to/funcmap_container.sif \
  -work-dir /path/to/work \
  -resume
```

## Local + Apptainer run

```bash
nextflow run /path/to/FUNCMAP \
  -profile local,apptainer \
  --input /path/to/samplesheet.csv \
  --dbsheet /path/to/databases_funcmap.csv \
  --outdir /path/to/results \
  --funcmap_container /path/to/funcmap_container.sif \
  -work-dir /path/to/work \
  -resume
```

## Run both branches

By default, both branches are enabled:

```bash
--run_humann true --run_amr true
```

Equivalent command:

```bash
nextflow run /path/to/FUNCMAP \
  -profile slurm,apptainer \
  --input samplesheet.csv \
  --dbsheet databases_funcmap.csv \
  --outdir results \
  --funcmap_container funcmap.sif \
  -work-dir work \
  -resume
```

## HUMAnN-only run

```bash
nextflow run /path/to/FUNCMAP \
  -profile slurm,apptainer \
  --input samplesheet.csv \
  --dbsheet databases_funcmap.csv \
  --outdir results_humann \
  --funcmap_container funcmap.sif \
  --run_humann true \
  --run_amr false \
  -work-dir work \
  -resume
```

## AMR/RGI-CARD-only run

```bash
nextflow run /path/to/FUNCMAP \
  -profile slurm,apptainer \
  --input samplesheet.csv \
  --dbsheet databases_funcmap.csv \
  --outdir results_amr \
  --funcmap_container funcmap.sif \
  --run_humann false \
  --run_amr true \
  -work-dir work \
  -resume
```

## Generate a samplesheet

```bash
bin/make_funcmap_samplesheet.py \
  --reads-dir /path/to/reads \
  --mpa-dir /path/to/metaphlan_profiles \
  --out samplesheet.csv \
  --r1-suffix ".unmapped_1.fastq.gz" \
  --r2-suffix ".unmapped_2.fastq.gz" \
  --mpa-pattern "*metaphlan*profile*.txt" \
  --force
```

## Generate a samplesheet for AMR-only analysis

```bash
bin/make_funcmap_samplesheet.py \
  --reads-dir /path/to/reads \
  --mpa-dir /path/to/metaphlan_profiles_or_empty_dir \
  --out samplesheet.csv \
  --allow-missing-mpa \
  --force
```

## Use a params file

Parameters can be provided in YAML format:

```yaml
input: /path/to/samplesheet.csv
dbsheet: /path/to/databases_funcmap.csv
outdir: /path/to/results
funcmap_container: /path/to/funcmap_container.sif

run_humann: true
run_amr: true

humann_renorm_units: full

amr_apply_filters: false
amr_min_reads: 10
amr_min_coverage: 40
amr_min_mapq: 5
amr_relab_from: rpkm
```

Run with:

```bash
nextflow run /path/to/FUNCMAP \
  -profile slurm,apptainer \
  -params-file params_funcmap.yaml \
  -work-dir /path/to/work \
  -resume
```

## SLURM launcher

An example SLURM launcher is available in:

```text
assets/funcmap_launch.example.sbatch
```

Copy and edit it for your environment:

```bash
cp assets/funcmap_launch.example.sbatch funcmap_launch.sbatch
nano funcmap_launch.sbatch
sbatch funcmap_launch.sbatch
```

## Resume runs

FUNCMAP supports standard Nextflow resume mode:

```bash
-resume
```

Use the same command and work directory to resume a previous run.

## Output reports

Execution reports are written to:

```text
results/pipeline_info/
```

including:

```text
trace.txt
report.html
timeline.html
dag.html
```
