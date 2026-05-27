process AMR_RGI_BWT {

    tag { sample_id }
    container params.funcmap_container

    publishDir "${params.outdir}/AMR_OUTS",
        mode: 'copy',
        overwrite: true

    input:
    tuple val(sample_id), path(r1), path(r2)
    path dbsheet

    output:
    tuple val(sample_id),
          path("${sample_id}/${sample_id}.rgi.gene_mapping_data.txt"),
          path("${sample_id}/${sample_id}.rgi.allele_mapping_data.txt"),
          path("${sample_id}/${sample_id}.rgi.overall_mapping_stats.txt"),
          path("${sample_id}/${sample_id}.rgi.reference_mapping_stats.txt"),
          path("${sample_id}/${sample_id}.rgi.artifacts_mapping_stats.txt"),
          path("${sample_id}/${sample_id}.rgi.stdout.log"),
          path("${sample_id}/${sample_id}.rgi.stderr.log")

    script:
    def wildcard_flag = params.amr_include_wildcard ? '--include_wildcard' : ''
    def other_models_flag = params.amr_include_other_models ? '--include_other_models' : ''
    def mapq_flag = params.amr_mapq ? "--mapq ${params.amr_mapq}" : ''
    def coverage_flag = params.amr_coverage ? "--coverage ${params.amr_coverage}" : ''

    """
    set -euo pipefail

    echo "===== AMR_RGI_BWT: ${sample_id} ====="

    TASK_DIR="\$PWD"

    CARD_DB=\$(awk -F',' '
        NR > 1 && \$1 == "rgi" {
            print \$4
            exit
        }
    ' "$dbsheet")

    if [ -z "\$CARD_DB" ]; then
        echo "[ERROR] No RGI/CARD database found in dbsheet: $dbsheet"
        echo "[ERROR] Expected a row like:"
        echo "tool,db_name,db_params,db_path"
        echo "rgi,CARD,local,/path/to/CARD_RGI"
        exit 1
    fi

    if [ ! -d "\$CARD_DB" ]; then
        echo "[ERROR] CARD database directory not found: \$CARD_DB"
        exit 1
    fi

    if [ ! -d "\$CARD_DB/localDB" ]; then
        echo "[ERROR] CARD localDB not found in: \$CARD_DB/localDB"
        echo "[ERROR] Did you run: rgi auto_load --local ?"
        exit 1
    fi

    R1="\$(readlink -f ${r1})"
    R2="\$(readlink -f ${r2})"

    OUTDIR="\$TASK_DIR/${sample_id}"
    mkdir -p "\$OUTDIR"

    OUT_PREFIX="\$OUTDIR/${sample_id}.rgi"

    echo "[INFO] TASK_DIR=\$TASK_DIR"
    echo "[INFO] dbsheet=$dbsheet"
    echo "[INFO] CARD_DB=\$CARD_DB"
    echo "[INFO] R1=\$R1"
    echo "[INFO] R2=\$R2"
    echo "[INFO] OUTDIR=\$OUTDIR"
    echo "[INFO] aligner=${params.amr_aligner}"
    echo "[INFO] threads=${task.cpus}"

    cd "\$CARD_DB"

    rgi bwt \\
        -1 "\$R1" \\
        -2 "\$R2" \\
        -o "\$OUT_PREFIX" \\
        --local \\
        -a ${params.amr_aligner} \\
        -n ${task.cpus} \\
        --clean \\
        ${wildcard_flag} \\
        ${other_models_flag} \\
        ${mapq_flag} \\
        ${coverage_flag} \\
        > "\$OUT_PREFIX.stdout.log" \\
        2> "\$OUT_PREFIX.stderr.log"

    cd "\$TASK_DIR"

    for f in \\
        "\$OUTDIR/${sample_id}.rgi.gene_mapping_data.txt" \\
        "\$OUTDIR/${sample_id}.rgi.allele_mapping_data.txt" \\
        "\$OUTDIR/${sample_id}.rgi.overall_mapping_stats.txt" \\
        "\$OUTDIR/${sample_id}.rgi.reference_mapping_stats.txt" \\
        "\$OUTDIR/${sample_id}.rgi.artifacts_mapping_stats.txt"
    do
        if [ ! -s "\$f" ]; then
            echo "[ERROR] Missing expected RGI output: \$f"
            exit 1
        fi
    done

    if [ "${params.amr_save_bam}" != "true" ]; then
        rm -f "\$OUTDIR"/${sample_id}.rgi*.bam "\$OUTDIR"/${sample_id}.rgi*.bam.bai || true
    fi

    echo "[INFO] AMR_RGI_BWT finished for ${sample_id}"
    """
}