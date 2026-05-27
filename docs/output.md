# FUNCMAP output structure

FUNCMAP writes per-sample and merged outputs to the directory specified by:

```bash
--outdir /path/to/results
```

A typical output directory contains:

```text
results/
├── HUMANN_OUTS/
├── HUMANN_MERGED_TABLES/
├── AMR_OUTS/
├── AMR_MERGED_TABLES/
└── pipeline_info/
```

## HUMAnN outputs

Per-sample HUMAnN outputs are written to:

```text
HUMANN_OUTS/
```

Example:

```text
HUMANN_OUTS/
├── SAMPLE01/
│   ├── SAMPLE01_genefamilies_raw.tsv
│   ├── SAMPLE01_genefamilies_relab.tsv
│   ├── SAMPLE01_genefamilies_cpm.tsv
│   ├── SAMPLE01_pathabundance_raw.tsv
│   ├── SAMPLE01_pathabundance_relab.tsv
│   └── ...
└── SAMPLE02/
    └── ...
```

The exact output files depend on the HUMAnN regrouping, renaming and renormalization settings.

## HUMAnN merged tables

Merged HUMAnN tables are written to:

```text
HUMANN_MERGED_TABLES/
```

These files contain downstream-ready matrices where rows are functional features and columns are samples.

Example:

```text
HUMANN_MERGED_TABLES/
├── humann_merged_genefamilies_raw.tsv
├── humann_merged_genefamilies_relab.tsv
├── humann_merged_genefamilies_cpm.tsv
├── humann_merged_pathabundance_raw.tsv
├── humann_merged_pathabundance_relab.tsv
└── ...
```

## HUMAnN renormalization modes

The `--humann_renorm_units` parameter controls which HUMAnN abundance units are generated.

| Value | Output |
|---|---|
| `raw` | Non-normalized HUMAnN tables only. |
| `relab` | Relative abundance tables only. |
| `cpm` | CPM-normalized tables only. |
| `relab_cpm` | Relative abundance and CPM tables. |
| `full` | Raw, relative abundance and CPM tables. |

In FUNCMAP:

```text
full = raw + relab + cpm
```

## AMR/RGI-CARD outputs

Per-sample RGI raw outputs and parsed AMR tables are written to:

```text
AMR_OUTS/
```

Example:

```text
AMR_OUTS/
├── SAMPLE01/
│   ├── SAMPLE01.rgi.gene_mapping_data.txt
│   ├── SAMPLE01.rgi.allele_mapping_data.txt
│   ├── SAMPLE01.rgi.overall_mapping_stats.txt
│   ├── SAMPLE01.rgi.reference_mapping_stats.txt
│   ├── SAMPLE01.rgi.artifacts_mapping_stats.txt
│   ├── SAMPLE01.rgi.stdout.log
│   ├── SAMPLE01.rgi.stderr.log
│   ├── SAMPLE01.amr_aro_raw_counts.tsv
│   ├── SAMPLE01.amr_aro_rpkm.tsv
│   ├── SAMPLE01.amr_aro_relab.tsv
│   ├── SAMPLE01.amr_gene_family_raw_counts.tsv
│   ├── SAMPLE01.amr_gene_family_rpkm.tsv
│   ├── SAMPLE01.amr_gene_family_relab.tsv
│   └── SAMPLE01.amr_qc_mapping_stats.tsv
└── SAMPLE02/
    └── ...
```

## AMR merged tables

Merged AMR tables are written to:

```text
AMR_MERGED_TABLES/
```

Expected files include:

```text
AMR_MERGED_TABLES/
├── amr_aro_raw_counts.tsv
├── amr_aro_rpkm.tsv
├── amr_aro_relab.tsv
├── amr_gene_family_raw_counts.tsv
├── amr_gene_family_rpkm.tsv
├── amr_gene_family_relab.tsv
├── amr_drug_class_raw_counts.tsv
├── amr_drug_class_rpkm.tsv
├── amr_drug_class_relab.tsv
├── amr_mechanism_raw_counts.tsv
├── amr_mechanism_rpkm.tsv
├── amr_mechanism_relab.tsv
└── amr_qc_mapping_stats.tsv
```

## Pipeline information

Nextflow execution reports are written to:

```text
pipeline_info/
├── trace.txt
├── report.html
├── timeline.html
└── dag.html
```

These files are useful for troubleshooting, benchmarking and reproducibility.

## Work directory

The Nextflow work directory is controlled by:

```bash
-work-dir /path/to/work
```

The work directory can become large and should usually be located on high-performance scratch storage.
