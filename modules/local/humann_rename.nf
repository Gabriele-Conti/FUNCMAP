process HUMANN_RENAME {

    tag { sample_id }
    container params.funcmap_container

    // Publish all per-sample HUMAnN tables to the final HUMANN_OUTS directory.
    publishDir "${params.outdir}/HUMANN_OUTS", mode: 'copy'

    input:
    // Inputs produced by HUMANN_REGROUP.
    tuple val(sample_id),
          path(gene_fam),
          path(path_abund),
          path(ko_tsv),
          path(module_tsv),
          path(pathway_tsv),
          path(cazy_tsv),
          path(pfam_tsv),
          path(eggnog_tsv)
    path dbsheet

    output:
    // Emit original regrouped tables plus named annotation tables.
    tuple val(sample_id),
          path("${sample_id}/${sample_id}_genefamilies.tsv"),
          path("${sample_id}/${sample_id}_pathabundance.tsv"),
          path("${sample_id}/${sample_id}_ko.tsv"),
          path("${sample_id}/${sample_id}_module.tsv"),
          path("${sample_id}/${sample_id}_pathway.tsv"),
          path("${sample_id}/${sample_id}_cazy.tsv"),
          path("${sample_id}/${sample_id}_pfam.tsv"),
          path("${sample_id}/${sample_id}_eggnog.tsv"),
          path("${sample_id}/${sample_id}_ko_named.tsv"),
          path("${sample_id}/${sample_id}_module_named.tsv"),
          path("${sample_id}/${sample_id}_pathway_named.tsv"),
          path("${sample_id}/${sample_id}_pfam_named.tsv"),
          path("${sample_id}/${sample_id}_eggnog_named.tsv")

    script:
    """
    set -euo pipefail
    echo "===== HUMANN_RENAME: ${sample_id} ====="

    DB_CSV="$dbsheet"
    MAP_DIR=\$(awk -F, 'NR>1 && \$1=="humann" && \$2=="full_mapping_v201901b" {print \$3}' "\$DB_CSV" | head -n1)

    if [ -z "\$MAP_DIR" ]; then
        echo "[ERROR] Missing full_mapping_v201901b in \$DB_CSV"
        exit 1
    fi

    MAP_KO_NAME="\$MAP_DIR/map_ko_name.txt.gz"
    MAP_MOD_NAME="\$MAP_DIR/map_module_name.tsv"
    MAP_PWY_NAME="\$MAP_DIR/map_pathway_name.tsv"
    MAP_PFAM_NAME="\$MAP_DIR/map_pfam_name.txt.gz"
    MAP_EGGNOG_NAME="\$MAP_DIR/map_eggnog_name.txt.gz"

    # Canonical per-sample directory within the process work directory.
    HUMANN_DIR="${sample_id}"
    mkdir -p "\$HUMANN_DIR"

    # Copy original tables into the expected per-sample output layout.
    cp "$gene_fam"    "\$HUMANN_DIR/${sample_id}_genefamilies.tsv"
    cp "$path_abund"  "\$HUMANN_DIR/${sample_id}_pathabundance.tsv"
    cp "$ko_tsv"      "\$HUMANN_DIR/${sample_id}_ko.tsv"
    cp "$module_tsv"  "\$HUMANN_DIR/${sample_id}_module.tsv"
    cp "$pathway_tsv" "\$HUMANN_DIR/${sample_id}_pathway.tsv"
    cp "$cazy_tsv"    "\$HUMANN_DIR/${sample_id}_cazy.tsv"
    cp "$pfam_tsv"    "\$HUMANN_DIR/${sample_id}_pfam.tsv"
    cp "$eggnog_tsv"  "\$HUMANN_DIR/${sample_id}_eggnog.tsv"

    echo "[PP] Add names to KO"
    humann_rename_table \\
        --input "\$HUMANN_DIR/${sample_id}_ko.tsv" \\
        -c "\$MAP_KO_NAME" \\
        --output "\$HUMANN_DIR/${sample_id}_ko_named.tsv"

    echo "[PP] Add names to KEGG MODULE"
    humann_rename_table \\
        --input "\$HUMANN_DIR/${sample_id}_module.tsv" \\
        -c "\$MAP_MOD_NAME" \\
        --output "\$HUMANN_DIR/${sample_id}_module_named.tsv"

    echo "[PP] Add names to KEGG PATHWAY"
    humann_rename_table \\
        --input "\$HUMANN_DIR/${sample_id}_pathway.tsv" \\
        -c "\$MAP_PWY_NAME" \\
        --output "\$HUMANN_DIR/${sample_id}_pathway_named.tsv"

    echo "[PP] Add names to PFAM"
    humann_rename_table \\
        --input "\$HUMANN_DIR/${sample_id}_pfam.tsv" \\
        -c "\$MAP_PFAM_NAME" \\
        --output "\$HUMANN_DIR/${sample_id}_pfam_named.tsv"

    echo "[PP] Add names to eggNOG"
    humann_rename_table \\
        --input "\$HUMANN_DIR/${sample_id}_eggnog.tsv" \\
        -c "\$MAP_EGGNOG_NAME" \\
        --output "\$HUMANN_DIR/${sample_id}_eggnog_named.tsv"

    echo '[INFO] HUMANN_RENAME finished for ${sample_id}'
    """
}