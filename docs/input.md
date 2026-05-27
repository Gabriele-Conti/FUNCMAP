# FUNCMAP input files

FUNCMAP requires two main input files:

1. a samplesheet describing the samples and input files;
2. a database sheet describing the external database paths.

Additional parameters can be provided through a YAML params file or directly from the command line.

## Samplesheet

The main input samplesheet is a comma-separated file with the following columns:

```csv
sample_id,r1,r2,mpa_profile
SAMPLE01,/path/to/SAMPLE01_R1.fastq.gz,/path/to/SAMPLE01_R2.fastq.gz,/path/to/SAMPLE01_metaphlan_profile.txt
SAMPLE02,/path/to/SAMPLE02_R1.fastq.gz,/path/to/SAMPLE02_R2.fastq.gz,/path/to/SAMPLE02_metaphlan_profile.txt
```

## Required columns

| Column | Description |
|---|---|
| `sample_id` | Unique sample identifier. This value is used to name output folders and abundance columns. |
| `r1` | Path to the forward paired-end FASTQ file. |
| `r2` | Path to the reverse paired-end FASTQ file. |
| `mpa_profile` | Path to the MetaPhlAn taxonomic profile. Required when running the HUMAnN branch. |

## Path recommendations

Absolute paths are recommended, especially on HPC systems.

Example:

```csv
sample_id,r1,r2,mpa_profile
GM04F1,/data/project/reads/GM04F1_R1.fastq.gz,/data/project/reads/GM04F1_R2.fastq.gz,/data/project/metaphlan/GM04F1_metaphlan_profile.txt
```

Relative paths can be used, but they must be valid from the directory where Nextflow is launched.

## Sample ID rules

`sample_id` values should:

- be unique;
- not contain spaces;
- avoid special characters;
- preferably use only letters, numbers, dots, hyphens or underscores.

Recommended:

```text
SAMPLE01
GM04F1
patient_001
```

Avoid:

```text
sample 01
sample/01
sample:01
```

## HUMAnN branch requirements

When `--run_humann true`, the `mpa_profile` column must contain a valid MetaPhlAn profile for each sample.

These profiles are passed to HUMAnN using the taxonomic profile input option.

## AMR-only runs

When running only the AMR/RGI-CARD branch:

```bash
--run_humann false --run_amr true
```

the `mpa_profile` column may be left empty if the samplesheet is generated with:

```bash
bin/make_funcmap_samplesheet.py \
  --reads-dir /path/to/reads \
  --mpa-dir /path/to/metaphlan_profiles_or_empty_dir \
  --out samplesheet.csv \
  --allow-missing-mpa \
  --force
```

The column should still be present for consistency.

## Automatic samplesheet generation

FUNCMAP provides a helper script:

```bash
bin/make_funcmap_samplesheet.py
```

Example usage:

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

## FASTQ naming example

For files named:

```text
GM04F1_run1.unmapped_1.fastq.gz
GM04F1_run1.unmapped_2.fastq.gz
```

the default inferred sample ID is:

```text
GM04F1
```

because `_run*` is stripped by default.

To keep the full raw ID:

```bash
--use-raw-id-as-sample-id
```

This would produce:

```text
GM04F1_run1
```

as the sample ID.

## Duplicate sample IDs

If multiple sequencing runs exist for the same sample and `_run*` stripping produces duplicated sample IDs, the samplesheet generation script will stop with an error.

In that case, either:

1. merge runs upstream; or
2. use `--use-raw-id-as-sample-id`.

## Example files

Example input files are available in:

```text
assets/samplesheet.example.csv
assets/databases_funcmap.example.csv
assets/params.example.yaml
```
