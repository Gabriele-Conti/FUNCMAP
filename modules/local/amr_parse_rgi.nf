process AMR_PARSE_RGI {

    tag { sample_id }
    container params.funcmap_container

    publishDir "${params.outdir}/AMR_OUTS",
        mode: 'copy',
        overwrite: true

    input:
    tuple val(sample_id),
          path(gene_mapping),
          path(allele_mapping),
          path(overall_stats),
          path(reference_stats),
          path(artifacts_stats),
          path(stdout_log),
          path(stderr_log)

    output:
    tuple val(sample_id),
          path("${sample_id}/*.amr_*.tsv")

    script:
    def filter_flag = params.amr_apply_filters ? '--apply-filters' : ''

    """
    set -euo pipefail

    echo "===== AMR_PARSE_RGI: ${sample_id} ====="

    OUTDIR="${sample_id}"
    mkdir -p "\$OUTDIR"

    OUT_PREFIX="\$OUTDIR/${sample_id}"

    echo "[INFO] gene_mapping=$gene_mapping"
    echo "[INFO] overall_stats=$overall_stats"
    echo "[INFO] OUTDIR=\$OUTDIR"
    echo "[INFO] min_reads=${params.amr_min_reads}"
    echo "[INFO] min_coverage=${params.amr_min_coverage}"
    echo "[INFO] min_mapq=${params.amr_min_mapq}"
    echo "[INFO] apply_filters=${params.amr_apply_filters}"
    echo "[INFO] relab_from=${params.amr_relab_from}"

    if [ ! -s "$gene_mapping" ]; then
        echo "[ERROR] Missing or empty gene mapping file: $gene_mapping"
        exit 1
    fi

    if [ ! -s "$overall_stats" ]; then
        echo "[ERROR] Missing or empty overall mapping stats file: $overall_stats"
        exit 1
    fi

    python ${projectDir}/bin/parse_rgi_bwt.py \\
        --sample-id "${sample_id}" \\
        --gene-mapping "$gene_mapping" \\
        --overall-stats "$overall_stats" \\
        --out-prefix "\$OUT_PREFIX" \\
        --min-reads ${params.amr_min_reads} \\
        --min-coverage ${params.amr_min_coverage} \\
        --min-mapq ${params.amr_min_mapq} \\
        --relab-from ${params.amr_relab_from} \\
        ${filter_flag}

    for f in \\
        "\$OUTDIR/${sample_id}.amr_aro_raw_counts.tsv" \\
        "\$OUTDIR/${sample_id}.amr_aro_rpkm.tsv" \\
        "\$OUTDIR/${sample_id}.amr_aro_relab.tsv" \\
        "\$OUTDIR/${sample_id}.amr_gene_family_raw_counts.tsv" \\
        "\$OUTDIR/${sample_id}.amr_gene_family_rpkm.tsv" \\
        "\$OUTDIR/${sample_id}.amr_gene_family_relab.tsv" \\
        "\$OUTDIR/${sample_id}.amr_drug_class_raw_counts.tsv" \\
        "\$OUTDIR/${sample_id}.amr_drug_class_rpkm.tsv" \\
        "\$OUTDIR/${sample_id}.amr_drug_class_relab.tsv" \\
        "\$OUTDIR/${sample_id}.amr_mechanism_raw_counts.tsv" \\
        "\$OUTDIR/${sample_id}.amr_mechanism_rpkm.tsv" \\
        "\$OUTDIR/${sample_id}.amr_mechanism_relab.tsv" \\
        "\$OUTDIR/${sample_id}.amr_qc_mapping_stats.tsv"
    do
        if [ ! -s "\$f" ]; then
            echo "[ERROR] Missing expected parsed AMR output: \$f"
            exit 1
        fi
    done

    echo "[INFO] Generated parsed AMR files:"
    find "\$OUTDIR" -type f -name "*.amr_*.tsv" -print | sort

    echo "[INFO] AMR_PARSE_RGI finished for ${sample_id}"
    """
}