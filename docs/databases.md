# FUNCMAP database configuration

FUNCMAP uses a database sheet to define external database paths.

The database sheet is passed to the pipeline using:

```bash
--dbsheet /path/to/databases_funcmap.csv
```

## Database sheet format

The database sheet is a CSV file with the following columns:

```csv
tool,db_name,db_params,db_path
humann,chocophlan,,/path/to/humann/chocophlan
humann,uniref90,,/path/to/humann/uniref90
humann,full_mapping_v201901b,,/path/to/humann/full_mapping_v201901b
rgi,card,local,/path/to/CARD_RGI
```

## Columns

| Column | Description |
|---|---|
| `tool` | Tool or workflow branch using the database. |
| `db_name` | Database identifier expected by the pipeline modules. |
| `db_params` | Optional additional database parameter field. |
| `db_path` | Path to the database directory or file. |

## HUMAnN databases

The HUMAnN branch requires paths to the relevant HUMAnN databases.

Typical entries include:

```csv
tool,db_name,db_params,db_path
humann,chocophlan,,/path/to/chocophlan
humann,uniref90,,/path/to/uniref90
humann,full_mapping_v201901b,,/path/to/full_mapping_v201901b
```

The exact names must match those expected by the FUNCMAP HUMAnN modules.

## RGI/CARD database

The AMR/RGI-CARD branch requires a local CARD/RGI database.

Example:

```csv
tool,db_name,db_params,db_path
rgi,card,,/path/to/CARD_RGI
```

The CARD/RGI database directory should be accessible inside the container through Apptainer/Singularity bind mounts.

## Path recommendations

Use absolute paths whenever possible.

Recommended:

```csv
rgi,card,,/scratch/databases/CARD_RGI
```

Avoid relying on relative paths for production runs, especially on HPC systems.

## Container bind visibility

All database paths must be visible inside the container.

When using Apptainer, make sure parent directories are bind-mounted. With:

```groovy
apptainer.autoMounts = true
```

Nextflow usually handles input file and work directory mounts automatically. However, database locations outside standard project/work directories may still require cluster-specific bind configuration.

If a database cannot be found at runtime, check:

1. the path exists on the host system;
2. the path is readable by the user running Nextflow;
3. the path is visible inside the Apptainer container;
4. the path in `databases_funcmap.csv` matches the expected mounted path.

## Example database sheet

An example file is provided in:

```text
assets/databases_funcmap.example.csv
```
