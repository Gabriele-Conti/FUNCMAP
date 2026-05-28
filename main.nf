nextflow.enable.dsl = 2

//
// Helper functions
//

def toBoolParam(value, String name) {
    if (value == null) {
        return false
    }

    if (value instanceof Boolean) {
        return value
    }

    def text = value.toString().trim().toLowerCase()

    if (text in ['true', 't', 'yes', 'y', '1']) {
        return true
    }

    if (text in ['false', 'f', 'no', 'n', '0']) {
        return false
    }

    exit 1, "ERROR: invalid boolean value for --${name}: '${value}'. Allowed values: true/false, yes/no, 1/0"
}


def requireParam(value, String name) {
    if (!value) {
        exit 1, "ERROR: missing required parameter --${name}"
    }

    return value
}


def requireExistingFile(value, String label) {
    def f = file(value)

    if (!f.exists()) {
        exit 1, "ERROR: ${label} not found: ${value}"
    }

    return f
}


//
// Parameter normalization
//

def input_csv = params.input ?: params.samplesheet
def dbsheet_csv = params.dbsheet
def outdir = params.outdir
def funcmap_container = params.funcmap_container

def run_humann = toBoolParam(params.run_humann, 'run_humann')
def run_amr = toBoolParam(params.run_amr, 'run_amr')

requireParam(input_csv, 'input / --samplesheet')
requireParam(dbsheet_csv, 'dbsheet')
requireParam(outdir, 'outdir')

requireExistingFile(input_csv, 'Input samplesheet')
requireExistingFile(dbsheet_csv, 'Database sheet')
def dbsheet_header = file(dbsheet_csv).readLines().find { it?.trim() }

if (dbsheet_header != 'tool,db_name,db_path') {
    exit 1, """
    ERROR: invalid database sheet header.

    Expected:
    tool,db_name,db_path

    Found:
    ${dbsheet_header}

    Example:
    humann,chocophlan,/path/to/humann/chocophlan
    humann,uniref90,/path/to/humann/uniref90
    humann,full_mapping_v201901b,/path/to/humann/full_mapping_v201901b
    rgi,CARD,/path/to/preloaded/CARD_RGI
    """.stripIndent()
}

if (!run_humann && !run_amr) {
    exit 1, "ERROR: Nothing to do. At least one between --run_humann and --run_amr must be true"
}


//
// Including local modules
//

include { HUMANN_RUN     } from './modules/local/humann_run'
include { HUMANN_REGROUP } from './modules/local/humann_regroup'
include { HUMANN_RENAME  } from './modules/local/humann_rename'
include { HUMANN_RENORM  } from './modules/local/humann_renorm'
include { HUMANN_JOIN    } from './modules/local/humann_join'

include { AMR_RGI_BWT   } from './modules/local/amr_rgi_bwt'
include { AMR_PARSE_RGI } from './modules/local/amr_parse_rgi'
include { AMR_JOIN      } from './modules/local/amr_join'


workflow {

    println """
    ============================================================
    FUNCMAP run configuration
    ============================================================
    Input samplesheet : ${input_csv}
    Database sheet    : ${dbsheet_csv}
    Output directory  : ${outdir}
    Run HUMAnN        : ${run_humann}
    Run AMR/RGI       : ${run_amr}
    FUNCMAP container  : ${params.funcmap_container ?: 'not set'}
    ============================================================
    """.stripIndent()

    // --------- SAMPLES ---------

    // Channel for HUMAnN: requires mpa_profile
    if (run_humann) {
        Channel
            .fromPath(input_csv, checkIfExists: true)
            .splitCsv(header: true, sep: ',')
            .map { row ->

                if (!row.sample_id) {
                    throw new IllegalArgumentException("Missing sample_id in samplesheet row: ${row}")
                }

                if (!row.r1) {
                    throw new IllegalArgumentException("Missing r1 for sample ${row.sample_id}")
                }

                if (!row.r2) {
                    throw new IllegalArgumentException("Missing r2 for sample ${row.sample_id}")
                }

                if (!row.mpa_profile) {
                    throw new IllegalArgumentException("Missing mpa_profile for sample ${row.sample_id}. Required when run_humann=true")
                }

                def r1_file = file(row.r1)
                def r2_file = file(row.r2)
                def mpa_file = file(row.mpa_profile)

                if (!r1_file.exists()) {
                    throw new IllegalArgumentException("R1 file not found for sample ${row.sample_id}: ${row.r1}")
                }

                if (!r2_file.exists()) {
                    throw new IllegalArgumentException("R2 file not found for sample ${row.sample_id}: ${row.r2}")
                }

                if (!mpa_file.exists()) {
                    throw new IllegalArgumentException("MetaPhlAn profile not found for sample ${row.sample_id}: ${row.mpa_profile}")
                }

                tuple(
                    row.sample_id,
                    r1_file,
                    r2_file,
                    mpa_file
                )
            }
            .set { samples_humann_ch }
    }

    // Channel for AMR: does not require mpa_profile
    if (run_amr) {
        Channel
            .fromPath(input_csv, checkIfExists: true)
            .splitCsv(header: true, sep: ',')
            .map { row ->

                if (!row.sample_id) {
                    throw new IllegalArgumentException("Missing sample_id in samplesheet row: ${row}")
                }

                if (!row.r1) {
                    throw new IllegalArgumentException("Missing r1 for sample ${row.sample_id}")
                }

                if (!row.r2) {
                    throw new IllegalArgumentException("Missing r2 for sample ${row.sample_id}")
                }

                def r1_file = file(row.r1)
                def r2_file = file(row.r2)

                if (!r1_file.exists()) {
                    throw new IllegalArgumentException("R1 file not found for sample ${row.sample_id}: ${row.r1}")
                }

                if (!r2_file.exists()) {
                    throw new IllegalArgumentException("R2 file not found for sample ${row.sample_id}: ${row.r2}")
                }

                tuple(
                    row.sample_id,
                    r1_file,
                    r2_file
                )
            }
            .set { samples_amr_ch }
    }


    // --------- DB SHEET ---------

    def dbsheet_file = file(dbsheet_csv)
    def dbsheet_ch = Channel.value(dbsheet_file)


    // --------- HUMAnN branch ---------

    if (run_humann) {

        humann_raw_ch = HUMANN_RUN(samples_humann_ch, dbsheet_ch)

        regroup_ch = HUMANN_REGROUP(humann_raw_ch, dbsheet_ch)

        renamed_ch = HUMANN_RENAME(regroup_ch, dbsheet_ch)

        renorm_ch = HUMANN_RENORM(renamed_ch)

        // Prepare HUMAnN renormalized tables for global merge.
        // HUMANN_JOIN consumes files through the Nextflow channel,
        // not by scanning params.outdir/HUMANN_OUTS after publishDir.
        humann_join_ch = renorm_ch
            .collect(flat: false)
            .map { rows ->

                if (!rows || rows.size() == 0) {
                    throw new IllegalArgumentException("No HUMAnN renormalized tables received by HUMANN_JOIN")
                }

                def sample_ids = rows.collect { row ->
                    row[0].toString()
                }

                def tables = rows.collectMany { row ->
                    def files = row[1]

                    if (files instanceof Collection) {
                        return files.collect { it }
                    }

                    return [ files ]
                }

                if (!tables || tables.size() == 0) {
                    throw new IllegalArgumentException("No HUMAnN TSV files collected for HUMANN_JOIN")
                }

                def non_path_values = tables.findAll { item ->
                    item instanceof CharSequence
                }

                if (non_path_values && non_path_values.size() > 0) {
                    throw new IllegalArgumentException(
                        "HUMANN_JOIN received non-path values among HUMAnN tables: ${non_path_values}"
                    )
                }

                tuple(sample_ids, tables)
            }

        HUMANN_JOIN(humann_join_ch)

    }
    // --------- AMR branch ---------

    if (run_amr) {

        amr_bwt_ch = AMR_RGI_BWT(samples_amr_ch, dbsheet_ch)

        amr_parsed_ch = AMR_PARSE_RGI(amr_bwt_ch)

        // Prepare parsed AMR tables for global merge.
        // AMR_JOIN consumes files through the Nextflow channel,
        // not by scanning params.outdir/AMR_OUTS after publishDir.
        amr_join_ch = amr_parsed_ch
            .collect(flat: false)
            .map { rows ->

                if (!rows || rows.size() == 0) {
                    throw new IllegalArgumentException("No parsed AMR tables received by AMR_JOIN")
                }

                def sample_ids = rows.collect { row ->
                    row[0].toString()
                }

                def tables = rows.collectMany { row ->
                    def files = row[1]

                    if (files instanceof Collection) {
                        return files.collect { it }
                    }

                    return [ files ]
                }

                if (!tables || tables.size() == 0) {
                    throw new IllegalArgumentException("No AMR TSV files collected for AMR_JOIN")
                }

                /*
                * Safety check:
                * AMR_JOIN expects only file-like objects in the second tuple element.
                * If a sample ID string such as GM65F1 reaches this list,
                * Nextflow path staging fails with errors like:
                * "Not a valid path value: 'M'".
                */
                def non_path_values = tables.findAll { item ->
                    item instanceof CharSequence
                }

                if (non_path_values && non_path_values.size() > 0) {
                    throw new IllegalArgumentException(
                        "AMR_JOIN received non-path values among AMR tables: ${non_path_values}"
                    )
                }

                tuple(sample_ids, tables)
            }

        AMR_JOIN(amr_join_ch)
    }
}