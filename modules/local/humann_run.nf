process HUMANN_RUN {

    tag { sample_id }
    container params.funcmap_container

    // Copia gli output HUMANN
    publishDir "${params.outdir}/HUMANN_OUTS/${sample_id}",
        mode: 'copy',
        pattern: "HUMANN_OUTS/${sample_id}/*",
        saveAs: { filename -> file(filename).name },
        overwrite: true

    input:
    tuple val(sample_id), path(r1), path(r2), path(mpa_profile)
    path dbsheet

    output:
    tuple val(sample_id),
          path("HUMANN_OUTS/${sample_id}/${sample_id}_genefamilies.tsv"),
          path("HUMANN_OUTS/${sample_id}/${sample_id}_pathabundance.tsv")

    script:
    """
    set -euo pipefail

    echo "===== HUMANN_RUN: ${sample_id} ====="

    DB_CSV="$dbsheet"

    CHOCOPHLAN_DB=\$(awk -F, 'NR>1 && \$1=="humann" && \$2=="chocophlan" {print \$4}' "\$DB_CSV" | head -n1)
    UNIREFF_DB=\$(awk -F, 'NR>1 && \$1=="humann" && \$2=="uniref90" {print \$4}' "\$DB_CSV" | head -n1)

    echo "[INFO] Using CHOCOPHLAN_DB=\$CHOCOPHLAN_DB"
    echo "[INFO] Using UNIREFF_DB=\$UNIREFF_DB"

    if [ -z "\$CHOCOPHLAN_DB" ] || [ -z "\$UNIREFF_DB" ]; then
        echo "[ERROR] Missing HUMAnN DB paths in \$DB_CSV"
        exit 1
    fi

    # Struttura interna alla workdir del processo
    MERGED_DIR="MERGED_READS/${sample_id}"
    HUMANN_DIR="HUMANN_OUTS/${sample_id}"

    mkdir -p "\$MERGED_DIR" "\$HUMANN_DIR"

    MERGED="\$MERGED_DIR/${sample_id}.fastq.gz"
    echo "[INFO] Merging reads for ${sample_id}"
    cat $r1 $r2 > "\$MERGED"

    humann \\
      --input "\$MERGED" \\
      --output "\$HUMANN_DIR" \\
      --threads ${task.cpus} \\
      --taxonomic-profile $mpa_profile \\
      --nucleotide-database "\$CHOCOPHLAN_DB" \\
      --protein-database "\$UNIREFF_DB" \\
      --metaphlan /opt/conda/envs/humann4/bin/metaphlan \\
      --memory-use maximum \\
      --verbose \\
      --log-level DEBUG \\
      --o-log "\$HUMANN_DIR/humann_debug.log"

    GENE_FAM="\$HUMANN_DIR/${sample_id}_genefamilies.tsv"
    PATH_ABUND="\$HUMANN_DIR/${sample_id}_pathabundance.tsv"

    for f in "\$GENE_FAM" "\$PATH_ABUND"; do
        if [ ! -s "\$f" ]; then
            echo "[ERROR] Missing expected HUMAnN output: \$f"
            exit 1
        fi
    done

    echo '[INFO] HUMANN_RUN finished for ${sample_id}'
    """
}
