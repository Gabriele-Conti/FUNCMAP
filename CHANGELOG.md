# Changelog

All notable changes to FUNCMAP will be documented in this file.

## [0.0.2] - 2026-05-27

### Added

- Public-oriented repository structure.
- Standard `nextflow.config`.
- `assets/` directory with example input files and SLURM launcher.
- `docs/` directory with input, database, output and usage documentation.
- `bin/make_funcmap_samplesheet.py` helper script for automatic samplesheet generation.
- Support for running the pipeline using `nextflow run /path/to/FUNCMAP` without explicitly passing a custom config file.

### Changed

- Moved AMR helper scripts to the standard Nextflow `bin/` directory.
- Updated AMR modules to call scripts from `${projectDir}/bin`.
- Standardized output structure for HUMAnN and AMR results.
- Standardized HUMAnN renormalization mode handling.

### Fixed

- Removed dependence on local working-directory scripts.
- Improved portability for public/HPC usage.
