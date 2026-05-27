# FUNCMAP

FUNCMAP is a Nextflow DSL2 pipeline for functional profiling of shotgun metagenomic data.

It integrates HUMAnN-based microbial functional profiling with AMR/RGI-CARD resistome analysis, producing both per-sample outputs and merged downstream-ready abundance tables.

## Overview

FUNCMAP can run two complementary analysis branches:

- **HUMAnN workflow** for microbial functional profiling at gene family, pathway, module, CAZy, Pfam, eggNOG and KO level.
- **AMR/RGI-CARD workflow** for antimicrobial resistance gene profiling from paired-end reads using RGI bwt.

The two branches can be run together or independently using pipeline parameters.

## Main features

- Nextflow DSL2 workflow structure.
- Containerized execution through Apptainer/Singularity.
- Support for SLURM-based HPC execution.
- HUMAnN functional profiling from paired-end reads and MetaPhlAn taxonomic profiles.
- HUMAnN regrouping, renaming, renormalization and global table merging.
- AMR profiling using RGI bwt against CARD.
- Parsing of RGI output into downstream-ready AMR abundance tables.
- Generation of raw counts, RPKM and relative abundance AMR tables.
- Per-sample and merged output organization.
- Helper script for automatic samplesheet generation.

## Repository structure

```text
FUNCMAP/
├── main.nf
├── nextflow.config
├── modules/
│   └── local/
│       ├── humann_run.nf
│       ├── humann_regroup.nf
│       ├── humann_rename.nf
│       ├── humann_renorm.nf
│       ├── humann_join.nf
│       ├── amr_rgi_bwt.nf
│       ├── amr_parse_rgi.nf
│       └── amr_join.nf
├── bin/
│   ├── make_funcmap_samplesheet.py
│   ├── parse_rgi_bwt.py
│   └── merge_amr_tables.py
├── assets/
│   ├── samplesheet.example.csv
│   ├── databases_funcmap.example.csv
│   ├── params.example.yaml
│   └── funcmap_launch.example.sbatch
├── docs/
│   ├── input.md
│   ├── databases.md
│   ├── output.md
│   └── usage.md
├── tests/
├── README.md
├── CHANGELOG.md
└── LICENSE
```

## Requirements

FUNCMAP requires:

- Nextflow `>=25.04.0`
- Apptainer/Singularity or another supported container engine
- A FUNCMAP container including:
  - HUMAnN
  - RGI/CARD tools
  - Python
  - required Python libraries
- HUMAnN databases
- CARD/RGI database
- Paired-end shotgun metagenomic reads
- MetaPhlAn taxonomic profiles for the HUMAnN branch

## Quick start

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

For local execution:

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

## Input samplesheet

The input samplesheet must be a CSV file with the following columns:

```csv
sample_id,r1,r2,mpa_profile
SAMPLE01,/path/to/SAMPLE01_R1.fastq.gz,/path/to/SAMPLE01_R2.fastq.gz,/path/to/SAMPLE01_metaphlan_profile.txt
SAMPLE02,/path/to/SAMPLE02_R1.fastq.gz,/path/to/SAMPLE02_R2.fastq.gz,/path/to/SAMPLE02_metaphlan_profile.txt
```

Column description:

| Column | Description |
|---|---|
| `sample_id` | Unique sample identifier. |
| `r1` | Absolute or relative path to R1 FASTQ file. |
| `r2` | Absolute or relative path to R2 FASTQ file. |
| `mpa_profile` | Path to the corresponding MetaPhlAn taxonomic profile. Required for the HUMAnN branch. |

## Automatic samplesheet generation

FUNCMAP provides a helper script to generate the samplesheet automatically from paired-end reads and MetaPhlAn profiles:

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

By default, the script removes `_run*` suffixes from the inferred sample ID. For example:

```text
GM04F1_run1.unmapped_1.fastq.gz → GM04F1
```

To keep the full raw ID as sample ID, use:

```bash
--use-raw-id-as-sample-id
```

For AMR-only runs where MetaPhlAn profiles are not available, the script can allow missing profiles:

```bash
--allow-missing-mpa
```

## Database sheet

The database sheet defines the external database paths used by the pipeline.

Example:

```csv
tool,db_name,db_params,db_path
humann,chocophlan,,/path/to/humann/chocophlan
humann,uniref90,,/path/to/humann/uniref90
humann,full_mapping_v201901b,,/path/to/humann/full_mapping_v201901b
rgi,card,local,/path/to/CARD_RGI
```

The exact database requirements are described in:

```text
docs/databases.md
```

## Main parameters

| Parameter | Description | Default |
|---|---|---|
| `--input` | Input samplesheet CSV. | `null` |
| `--samplesheet` | Alternative input samplesheet parameter retained for compatibility. | `null` |
| `--dbsheet` | Database sheet CSV. | `null` |
| `--outdir` | Output directory. | `results` |
| `--funcmap_container` | FUNCMAP Apptainer/Singularity container. | `null` |
| `--run_humann` | Run HUMAnN branch. | `true` |
| `--run_amr` | Run AMR/RGI-CARD branch. | `true` |
| `--amr_aligner` | Aligner used by `rgi bwt`. | `kma` |
| `--amr_include_wildcard` | Include WildCARD/prevalence-derived variants in RGI bwt. | `false` |
| `--amr_include_other_models` | Include additional CARD model types. | `false` |
| `--amr_mapq` | Optional MAPQ filter passed to RGI bwt. | `null` |
| `--amr_coverage` | Optional coverage filter passed to RGI bwt. | `null` |
| `--amr_save_bam` | Keep RGI BAM/BAI files. | `false` |
| `--humann_renorm_units` | HUMAnN renormalization mode. | `full` |
| `--amr_apply_filters` | Apply filters to RGI rows before AMR table generation. | `false` |
| `--amr_min_reads` | Minimum mapped reads for AMR filtering. | `10` |
| `--amr_min_coverage` | Minimum average percent coverage for AMR filtering. | `55` |
| `--amr_min_mapq` | Minimum average MAPQ for AMR filtering. | `10` |
| `--amr_relab_from` | Metric used to calculate AMR relative abundance. | `rpkm` |

## HUMAnN renormalization modes

Allowed values for `--humann_renorm_units` are:

| Value | Output |
|---|---|
| `raw` | Non-normalized HUMAnN tables only. |
| `relab` | Relative abundance tables only. |
| `cpm` | CPM-normalized tables only. |
| `relab_cpm` | Relative abundance and CPM tables. |
| `full` | Raw, relative abundance and CPM tables. |

In FUNCMAP, `full` means:

```text
raw + relab + cpm
```

It does not call a `copies` mode, because the HUMAnN `humann_renorm_table` version used by the FUNCMAP container supports only `relab` and `cpm`.

## Output structure

A typical output directory contains:

```text
results/
├── HUMANN_OUTS/
│   └── SAMPLE_ID/
├── HUMANN_MERGED_TABLES/
├── AMR_OUTS/
│   └── SAMPLE_ID/
├── AMR_MERGED_TABLES/
└── pipeline_info/
```

### HUMAnN outputs

Per-sample HUMAnN outputs are written to:

```text
HUMANN_OUTS/
```

Merged HUMAnN tables are written to:

```text
HUMANN_MERGED_TABLES/
```

### AMR/RGI-CARD outputs

Per-sample RGI raw outputs and parsed AMR tables are written to:

```text
AMR_OUTS/
```

Merged AMR tables are written to:

```text
AMR_MERGED_TABLES/
```

### Pipeline reports

Execution metadata are written to:

```text
pipeline_info/
├── trace.txt
├── report.html
├── timeline.html
└── dag.html
```

## SLURM example launcher

An example SLURM launcher is provided in:

```text
assets/funcmap_launch.example.sbatch
```

This file should be copied and edited for each HPC environment.

Example:

```bash
cp assets/funcmap_launch.example.sbatch funcmap_launch.sbatch
nano funcmap_launch.sbatch
sbatch funcmap_launch.sbatch
```

## Documentation

Additional documentation is available in:

```text
docs/input.md
docs/databases.md
docs/output.md
docs/usage.md
```

## Development status

FUNCMAP is currently under active development.

The current version is:

```text
0.0.2
```

## Citation

A citation will be added once the pipeline is formally released.

## License

See `LICENSE`.
