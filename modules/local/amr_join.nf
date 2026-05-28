process AMR_JOIN {

    tag "amr_join"
    container params.funcmap_container

    // Publish globally merged AMR tables to AMR_MERGED_TABLES.
    publishDir "${params.outdir}/AMR_MERGED_TABLES",
        mode: 'copy',
        pattern: "amr_*",
        overwrite: true

    input:
    // Receive all parsed per-sample AMR tables from the channel.
    // Files are staged by Nextflow under AMR_INPUT_TABLES/.
    tuple val(sample_ids), path(amr_tables, name: 'AMR_INPUT_TABLES/*')

    output:
    // Emit all merged AMR abundance and QC tables.
    path "amr_*"

    script:
    """
    set -euo pipefail

    echo "===== AMR_JOIN: global AMR table merge ====="

    INPUT_DIR="AMR_INPUT_TABLES"
    SAMPLE_IDS="sample_ids.txt"

    cat > "\$SAMPLE_IDS" <<'EOF_SAMPLE_IDS'
${sample_ids.join('\n')}
EOF_SAMPLE_IDS

    if [ ! -d "\$INPUT_DIR" ]; then
        echo "[ERROR] Input directory not staged by Nextflow: \$INPUT_DIR"
        exit 1
    fi

    echo "[INFO] Using parsed AMR tables staged by Nextflow in: \$INPUT_DIR"
    echo "[INFO] Number of sample IDs received: \$(wc -l < "\$SAMPLE_IDS")"
    echo "[INFO] Number of staged AMR TSV files: \$(find -L "\$INPUT_DIR" -name '*.tsv' | wc -l)"
    echo "[INFO] Writing merged AMR tables to current work directory: \$PWD"

    if ! find -L "\$INPUT_DIR" -name '*.tsv' | grep -q .; then
        echo "[ERROR] No parsed AMR TSV files were staged for merging"
        echo "[DEBUG] Content of \$INPUT_DIR:"
        ls -lah "\$INPUT_DIR" || true
        find "\$INPUT_DIR" -maxdepth 3 -ls || true
        exit 1
    fi

    echo "[INFO] Staged AMR tables:"
    find -L "\$INPUT_DIR" -name '*.tsv' -printf '  %P\\n' | sort

    python ${projectDir}/bin/merge_amr_tables.py \\
        --input-dir "\$INPUT_DIR" \\
        --outdir "."

    echo "[INFO] Checking expected merged AMR outputs..."

    for f in \\
        "amr_aro_raw_counts.tsv" \\
        "amr_aro_rpkm.tsv" \\
        "amr_aro_relab.tsv" \\
        "amr_gene_family_raw_counts.tsv" \\
        "amr_gene_family_rpkm.tsv" \\
        "amr_gene_family_relab.tsv" \\
        "amr_drug_class_raw_counts.tsv" \\
        "amr_drug_class_rpkm.tsv" \\
        "amr_drug_class_relab.tsv" \\
        "amr_mechanism_raw_counts.tsv" \\
        "amr_mechanism_rpkm.tsv" \\
        "amr_mechanism_relab.tsv" \\
        "amr_qc_mapping_stats.tsv"
    do
        if [ ! -s "\$f" ]; then
            echo "[ERROR] Missing expected merged AMR output: \$f"
            exit 1
        fi
    done

    echo "[INFO] AMR_JOIN finished successfully"
    echo "[INFO] Merged AMR tables:"
    ls -lh amr_*
    """
}