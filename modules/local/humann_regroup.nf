process HUMANN_REGROUP {

    tag { sample_id }
    container params.funcmap_container

    // Pubblica tutte le tabelle per campione in:
    //   ${params.outdir}/HUMANN_OUTS/sample_id/
    publishDir "${params.outdir}/HUMANN_OUTS", mode: 'copy'

    input:
    // Questi arrivano da HUMANN_RUN (genefamilies e pathabundance)
    tuple val(sample_id), path(gene_fam_in), path(path_abund_in)
    path dbsheet

    output:
    // Ora tutto è sotto HUMANN_OUTS/sample_id/
    tuple val(sample_id),
          path("${sample_id}/${sample_id}_genefamilies.tsv"),
          path("${sample_id}/${sample_id}_pathabundance.tsv"),
          path("${sample_id}/${sample_id}_ko.tsv"),
          path("${sample_id}/${sample_id}_module.tsv"),
          path("${sample_id}/${sample_id}_pathway.tsv"),
          path("${sample_id}/${sample_id}_cazy.tsv"),
          path("${sample_id}/${sample_id}_pfam.tsv"),
          path("${sample_id}/${sample_id}_eggnog.tsv")

    script:
    """
    set -euo pipefail

    echo "===== HUMANN_REGROUP: ${sample_id} ====="

    DB_CSV="$dbsheet"
    MAP_DIR=\$(awk -F, 'NR>1 && \$1=="humann" && \$2=="full_mapping_v201901b" {print \$4}' "\$DB_CSV" | head -n1)

    if [ -z "\$MAP_DIR" ]; then
        echo "[ERROR] Missing full_mapping_v201901b in \$DB_CSV"
        exit 1
    fi

    MAP_KO_UNIREF="\$MAP_DIR/map_ko_uniref90.txt.gz"
    MAP_MOD_KO="\$MAP_DIR/map_module_ko.tsv"
    MAP_PWY_KO="\$MAP_DIR/map_pathway_ko.tsv"
    MAP_CAZY_UNIREF="\$MAP_DIR/map_cazy_uniref90.txt.gz"
    MAP_PFAM_UNIREF="\$MAP_DIR/map_pfam_uniref90.txt.gz"
    MAP_EGGNOG_UNIREF="\$MAP_DIR/map_eggnog_uniref90.txt.gz"

    # Cartella canonica per questo sample nella workdir del processo
    HUMANN_DIR="${sample_id}"
    mkdir -p "\$HUMANN_DIR"

    # Copio (o rinomino) le tabelle di input nel layout desiderato
    GENE_FAM="\$HUMANN_DIR/${sample_id}_genefamilies.tsv"
    PATH_ABUND="\$HUMANN_DIR/${sample_id}_pathabundance.tsv"

    cp "$gene_fam_in"   "\$GENE_FAM"
    cp "$path_abund_in" "\$PATH_ABUND"

    KO_TSV="\$HUMANN_DIR/${sample_id}_ko.tsv"
    MODULE_TSV="\$HUMANN_DIR/${sample_id}_module.tsv"
    PATHWAY_TSV="\$HUMANN_DIR/${sample_id}_pathway.tsv"
    CAZY_TSV="\$HUMANN_DIR/${sample_id}_cazy.tsv"
    PFAM_TSV="\$HUMANN_DIR/${sample_id}_pfam.tsv"
    EGGNOG_TSV="\$HUMANN_DIR/${sample_id}_eggnog.tsv"

    echo "[PP] UniRef90 → KO"
    humann_regroup_table \\
        --input "\$GENE_FAM" \\
        -c "\$MAP_KO_UNIREF" \\
        --output "\$KO_TSV"

    echo "[PP] KO → KEGG MODULE"
    humann_regroup_table \\
        --input "\$KO_TSV" \\
        -c "\$MAP_MOD_KO" \\
        --output "\$MODULE_TSV"

    echo "[PP] KO → KEGG PATHWAY"
    humann_regroup_table \\
        --input "\$KO_TSV" \\
        -c "\$MAP_PWY_KO" \\
        --output "\$PATHWAY_TSV"

    echo "[PP] UniRef90 → CAZy"
    humann_regroup_table \\
        --input "\$GENE_FAM" \\
        -c "\$MAP_CAZY_UNIREF" \\
        --output "\$CAZY_TSV"

    echo "[PP] UniRef90 → PFAM"
    humann_regroup_table \\
        --input "\$GENE_FAM" \\
        -c "\$MAP_PFAM_UNIREF" \\
        --output "\$PFAM_TSV"

    echo "[PP] UniRef90 → eggNOG"
    humann_regroup_table \\
        --input "\$GENE_FAM" \\
        -c "\$MAP_EGGNOG_UNIREF" \\
        --output "\$EGGNOG_TSV"

    echo '[INFO] HUMANN_REGROUP finished for ${sample_id}'
    """
}
