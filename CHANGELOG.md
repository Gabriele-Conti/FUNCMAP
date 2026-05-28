# Changelog

All notable changes to FUNCMAP will be documented in this file.

## [0.0.2] - 2026-05-28

### Added

- Public-oriented repository structure.
- Standard `nextflow.config`.
- `assets/` directory with example input files and SLURM launcher.
- `docs/` directory with input, database, output and usage documentation.
- `bin/make_funcmap_samplesheet.py` helper script for automatic samplesheet generation.
- Support for running the pipeline using `nextflow run /path/to/FUNCMAP` without explicitly passing a custom config file.
- Default public FUNCMAP container through GitHub Container Registry:
  `oras://ghcr.io/gabriele-conti/funcmap:0.0.2`.
- Support for overriding the default online container with a local SIF file using `--funcmap_container`.
- Optional `--apptainer_run_options` parameter to pass runtime bind options for Apptainer/Singularity execution.
- README description of FUNCMAP as a downstream read-mapping-based functional profiling workflow after MetaPhlAn-based taxonomic profiling.
- Documentation of compatibility with upstream taxonomic profiling workflows such as nf-core/taxprofiler.

### Changed

- Moved AMR helper scripts to the standard Nextflow `bin/` directory.
- Updated AMR modules to call scripts from `${projectDir}/bin`.
- Standardized output structure for HUMAnN and AMR results.
- Standardized HUMAnN renormalization mode handling.
- Simplified database sheet format from `tool,db_name,db_params,db_path` to `tool,db_name,db_path`.
- Updated HUMAnN database configuration to use `full_mapping_v201901b`.
- Updated example database sheet, parameter file and documentation to match the simplified database-sheet format.
- Updated module comments and documentation for public/international repository use.
- Updated default AMR filtering parameters in documentation and example configuration.

### Fixed

- Removed dependence on local working-directory scripts.
- Improved portability for public/HPC usage.
- Fixed database path parsing in HUMAnN and AMR modules after removal of the unused `db_params` column.
- Improved consistency between `nextflow.config`, example parameter files and documentation.