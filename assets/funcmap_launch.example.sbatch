#!/bin/bash

#SBATCH -t 5-00:00:00
#SBATCH -c 2
#SBATCH --mem=8G
#SBATCH --job-name="FUNCMAP"
#SBATCH --export=ALL
#SBATCH --output=slurm_%x_%j.out
#SBATCH --error=slurm_%x_%j.err

# ===================================================================
# FUNCMAP example SLURM launcher
#
# This is a public template. Copy it, edit paths for your HPC/project,
# then submit it with: sbatch funcmap_launch.sbatch
# ===================================================================

set -euo pipefail

# -------------------------------------------------------------------
# 0) RUN NAME / TIMESTAMP
# -------------------------------------------------------------------

TIMESTAMP="$(date +%Y%m%d)"

# -------------------------------------------------------------------
# 1) MAIN PATHS — EDIT THESE
# -------------------------------------------------------------------

# FUNCMAP repository directory
PIPELINE_DIR="/path/to/FUNCMAP"

# Project directories
PROJECT_DIR="/path/to/project"
WORKDIR="/scratch/${USER}/FUNCMAP/work_${TIMESTAMP}"
RESULTS_DIR="${PROJECT_DIR}/funcmap_results/run_${TIMESTAMP}"

# Input directories used to generate the samplesheet
CLEAN_READS_DIR="${PROJECT_DIR}/reads"
MPA_PROFILE_DIR="${PROJECT_DIR}/metaphlan_profiles"

# Generated samplesheet
SAMPLESHEET="${PROJECT_DIR}/samplesheet_funcmap_${TIMESTAMP}.csv"

# FUNCMAP parameter/database files
PARAMS_FILE="${PIPELINE_DIR}/assets/params.example.yaml"
DBSHEET="${PROJECT_DIR}/databases_funcmap.csv"

# FUNCMAP Apptainer/Singularity container
# Optional local container override.
# Leave empty to use the default online container defined in nextflow.config.
FUNCMAP_SIF="/path/to/funcmap_container.sif"

# Read/profile naming options
R1_SUFFIX="_R1.fastq.gz"
R2_SUFFIX="_R2.fastq.gz"
R1_PATTERN="*${R1_SUFFIX}"
MPA_PROFILE_GLOB="*metaphlan*profile*.txt"
USE_RAW_ID_AS_SAMPLE_ID=false
ALLOW_MISSING_MPA=false

# -------------------------------------------------------------------
# 2) PREPARE DIRECTORIES
# -------------------------------------------------------------------

mkdir -p "${RESULTS_DIR}" "${WORKDIR}"

# -------------------------------------------------------------------
# 3) SANITY CHECKS
# -------------------------------------------------------------------

if [ ! -d "${PIPELINE_DIR}" ]; then
    echo "[ERROR] PIPELINE_DIR not found: ${PIPELINE_DIR}" >&2
    exit 1
fi

if [ ! -x "${PIPELINE_DIR}/bin/make_funcmap_samplesheet.py" ]; then
    echo "[ERROR] Samplesheet generator not found or not executable:" >&2
    echo "        ${PIPELINE_DIR}/bin/make_funcmap_samplesheet.py" >&2
    exit 1
fi

if [ ! -r "${FUNCMAP_SIF}" ]; then
    echo "[ERROR] FUNCMAP container not found or not readable:" >&2
    echo "        ${FUNCMAP_SIF}" >&2
    exit 1
fi

if [ ! -d "${CLEAN_READS_DIR}" ]; then
    echo "[ERROR] CLEAN_READS_DIR not found: ${CLEAN_READS_DIR}" >&2
    exit 1
fi

if [ ! -d "${MPA_PROFILE_DIR}" ]; then
    echo "[ERROR] MPA_PROFILE_DIR not found: ${MPA_PROFILE_DIR}" >&2
    exit 1
fi

if [ ! -r "${PARAMS_FILE}" ]; then
    echo "[ERROR] PARAMS_FILE not found or not readable: ${PARAMS_FILE}" >&2
    exit 1
fi

if [ ! -r "${DBSHEET}" ]; then
    echo "[ERROR] DBSHEET not found or not readable: ${DBSHEET}" >&2
    exit 1
fi

# -------------------------------------------------------------------
# 4) GENERATE SAMPLESHEET
# -------------------------------------------------------------------

echo "[$(date)] Generating FUNCMAP samplesheet"
echo "  CLEAN_READS_DIR        : ${CLEAN_READS_DIR}"
echo "  MPA_PROFILE_DIR        : ${MPA_PROFILE_DIR}"
echo "  SAMPLESHEET            : ${SAMPLESHEET}"
echo "  R1_PATTERN             : ${R1_PATTERN}"
echo "  R1_SUFFIX              : ${R1_SUFFIX}"
echo "  R2_SUFFIX              : ${R2_SUFFIX}"
echo "  MPA_PROFILE_GLOB       : ${MPA_PROFILE_GLOB}"
echo "  USE_RAW_ID_AS_SAMPLE_ID: ${USE_RAW_ID_AS_SAMPLE_ID}"
echo "  ALLOW_MISSING_MPA      : ${ALLOW_MISSING_MPA}"

SAMPLESHEET_CMD=(
    "${PIPELINE_DIR}/bin/make_funcmap_samplesheet.py"
    --reads-dir "${CLEAN_READS_DIR}"
    --mpa-dir "${MPA_PROFILE_DIR}"
    --out "${SAMPLESHEET}"
    --r1-pattern "${R1_PATTERN}"
    --r1-suffix "${R1_SUFFIX}"
    --r2-suffix "${R2_SUFFIX}"
    --mpa-pattern "${MPA_PROFILE_GLOB}"
    --force
)

if [ "${USE_RAW_ID_AS_SAMPLE_ID}" = "true" ]; then
    SAMPLESHEET_CMD+=(--use-raw-id-as-sample-id)
fi

if [ "${ALLOW_MISSING_MPA}" = "true" ]; then
    SAMPLESHEET_CMD+=(--allow-missing-mpa)
fi

"${SAMPLESHEET_CMD[@]}"

N_WRITTEN=$(tail -n +2 "${SAMPLESHEET}" | wc -l)

echo "[INFO] Samplesheet generated with ${N_WRITTEN} samples: ${SAMPLESHEET}"
head -n 5 "${SAMPLESHEET}"

# -------------------------------------------------------------------
# 5) APPTAINER / NEXTFLOW CACHE
# -------------------------------------------------------------------

export APPTAINER_CACHEDIR="/scratch/${USER}/cache/apptainer"
export NXF_APPTAINER_CACHEDIR="/scratch/${USER}/cache/containers_tmp"
export NXF_HOME="/scratch/${USER}/.nextflow"

mkdir -p "${APPTAINER_CACHEDIR}" "${NXF_APPTAINER_CACHEDIR}" "${NXF_HOME}"

# -------------------------------------------------------------------
# 6) RUN NEXTFLOW
# -------------------------------------------------------------------

echo "[$(date)] Starting FUNCMAP"
echo "  TIMESTAMP    : ${TIMESTAMP}"
echo "  PIPELINE_DIR : ${PIPELINE_DIR}"
echo "  RESULTS_DIR  : ${RESULTS_DIR}"
echo "  WORKDIR      : ${WORKDIR}"
echo "  SAMPLESHEET  : ${SAMPLESHEET} (${N_WRITTEN} samples)"
echo "  PARAMS_FILE  : ${PARAMS_FILE}"
echo "  DBSHEET      : ${DBSHEET}"
echo "  FUNCMAP_SIF  : ${FUNCMAP_SIF}"

set +e

nextflow run "${PIPELINE_DIR}" \
    -profile slurm,apptainer \
    -params-file "${PARAMS_FILE}" \
    --input "${SAMPLESHEET}" \
    --dbsheet "${DBSHEET}" \
    --outdir "${RESULTS_DIR}" \
    --funcmap_container "${FUNCMAP_SIF}" \
    -work-dir "${WORKDIR}" \
    -resume

NF_EXIT=$?

set -e

if [ "${NF_EXIT}" -eq 0 ]; then
    STATUS="finished"
else
    STATUS="failed"
fi

echo "[$(date)] FUNCMAP ${STATUS} in ${RESULTS_DIR}"
exit "${NF_EXIT}"
