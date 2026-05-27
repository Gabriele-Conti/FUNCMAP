process HUMANN_RENORM {

  tag { sample_id }
  container params.funcmap_container

  publishDir "${params.outdir}/HUMANN_OUTS", mode: 'copy'

  input:
  tuple val(sample_id),
        path(gene_fam),
        path(path_abund),
        path(ko_tsv),
        path(module_tsv),
        path(pathway_tsv),
        path(cazy_tsv),
        path(pfam_tsv),
        path(eggnog_tsv),
        path(ko_named_tsv),
        path(module_named_tsv),
        path(pathway_named_tsv),
        path(pfam_named_tsv),
        path(eggnog_named_tsv)

  output:
  tuple val(sample_id),
        path("${sample_id}/*.tsv")

  script:
  """
  set -euo pipefail

  echo "===== HUMANN_RENORM: ${sample_id} ====="

  outdir="${sample_id}"
  tmpdir="${sample_id}_tmp"

  mkdir -p "\$outdir" "\$tmpdir"

  RENORM_MODE="${params.humann_renorm_units ?: 'full'}"

  case "\$RENORM_MODE" in
    raw)
      KEEP_RAW="true"
      UNITS=""
      ;;
    relab)
      KEEP_RAW="false"
      UNITS="relab"
      ;;
    cpm)
      KEEP_RAW="false"
      UNITS="cpm"
      ;;
    relab_cpm)
      KEEP_RAW="false"
      UNITS="relab cpm"
      ;;
    full)
      KEEP_RAW="true"
      UNITS="relab cpm"
      ;;
    copies)
      echo "[ERROR] humann_renorm_units='copies' is not supported by humann_renorm_table in this FUNCMAP container."
      echo "[ERROR] Use 'raw' for non-normalized tables, or 'full' for raw + relab + cpm."
      exit 1
      ;;
    *)
      echo "[ERROR] Invalid humann_renorm_units: \$RENORM_MODE"
      echo "[ERROR] Allowed values: raw, relab, cpm, relab_cpm, full"
      exit 1
      ;;
  esac

  echo "[INFO] HUMAnN renormalization mode: \$RENORM_MODE"
  echo "[INFO] Keep raw/non-normalized tables: \$KEEP_RAW"
  echo "[INFO] Units to generate: \${UNITS:-none}"

  check_input() {
    local in="\$1"
    local label="\$2"

    if [ ! -s "\$in" ]; then
      echo "[ERROR] Missing or empty input table for \$label: \$in"
      exit 1
    fi
  }

  fix_header() {
    local in="\$1"
    local out="\$2"

    if [ ! -s "\$in" ]; then
      echo "[ERROR] Missing or empty temporary file before header fix: \$in"
      exit 1
    fi

    rm -f "\$out"

    awk 'BEGIN{FS=OFS="\\t"}
         NR==1{
           gsub(/_Abundance-RPKs/,"")
           gsub(/_Abundance-RELAB/,"")
           gsub(/_Abundance-CPM/,"")
           gsub(/_Abundance-Copies/,"")
           gsub(/_Abundance-COPIES/,"")
           print
           next
         }
         {print}' "\$in" >| "\$out"

    if [ ! -s "\$out" ]; then
      echo "[ERROR] Empty or missing output after header fix: \$out"
      exit 1
    fi
  }

  copy_raw() {
    local in="\$1"
    local prefix="\$2"

    local out="\$outdir/${sample_id}_\${prefix}_raw.tsv"

    echo "[INFO] Keeping raw/non-normalized table for \${prefix}"
    echo "[INFO] input: \$in"
    echo "[INFO] out  : \$out"

    check_input "\$in" "\$prefix"

    rm -f "\$out"

    cp "\$in" "\$out"

    if [ ! -s "\$out" ]; then
      echo "[ERROR] Failed to create raw output: \$out"
      exit 1
    fi
  }

  renorm_and_fix() {
    local in="\$1"
    local unit="\$2"
    local prefix="\$3"

    local tmp="\$tmpdir/tmp_\${prefix}_\${unit}.tsv"
    local out="\$outdir/${sample_id}_\${prefix}_\${unit}.tsv"

    echo "[INFO] Renormalizing \${prefix} to \${unit}"
    echo "[INFO] input: \$in"
    echo "[INFO] tmp  : \$tmp"
    echo "[INFO] out  : \$out"

    check_input "\$in" "\$prefix"

    rm -f "\$tmp" "\$out"

    humann_renorm_table \\
      --input "\$in" \\
      -u "\$unit" \\
      --output "\$tmp"

    if [ ! -s "\$tmp" ]; then
      echo "[ERROR] humann_renorm_table did not create expected tmp file: \$tmp"
      exit 1
    fi

    fix_header "\$tmp" "\$out"

    rm -f "\$tmp"
  }

  renorm_all_units() {
    local in="\$1"
    local prefix="\$2"

    if [ -n "\$UNITS" ]; then
      for unit in \$UNITS; do
        renorm_and_fix "\$in" "\$unit" "\$prefix"
      done
    fi
  }

  process_table() {
    local in="\$1"
    local prefix="\$2"

    if [ "\$KEEP_RAW" = "true" ]; then
      copy_raw "\$in" "\$prefix"
    fi

    renorm_all_units "\$in" "\$prefix"
  }

  process_table "$gene_fam"          "genefamilies"
  process_table "$path_abund"        "pathabundance"
  process_table "$ko_tsv"            "ko"
  process_table "$module_tsv"        "module"
  process_table "$pathway_tsv"       "pathway"
  process_table "$cazy_tsv"          "cazy"
  process_table "$pfam_tsv"          "pfam"
  process_table "$eggnog_tsv"        "eggnog"
  process_table "$ko_named_tsv"      "ko_named"
  process_table "$module_named_tsv"  "module_named"
  process_table "$pathway_named_tsv" "pathway_named"
  process_table "$pfam_named_tsv"    "pfam_named"
  process_table "$eggnog_named_tsv"  "eggnog_named"

  rm -rf "\$tmpdir"

  echo "[INFO] Generated HUMAnN output files:"
  find "\$outdir" -type f -name "*.tsv" -print | sort

  echo "[INFO] HUMANN_RENORM finished for ${sample_id}"
  """
}