#!/usr/bin/env python3

import argparse
import re
import sys
from pathlib import Path
from typing import Dict, Optional, Tuple

import pandas as pd


REQUIRED_GENE_COLUMNS = [
    "ARO Term",
    "ARO Accession",
    "All Mapped Reads",
    "Average Percent Coverage",
    "Average MAPQ (Completely Mapped Reads)",
    "Reference Length",
    "AMR Gene Family",
    "Drug Class",
    "Resistance Mechanism",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Parse CARD RGI bwt gene_mapping_data.txt and overall_mapping_stats.txt "
            "to generate per-sample AMR abundance tables and QC statistics."
        )
    )

    parser.add_argument(
        "--sample-id",
        required=True,
        help="Sample identifier used as the abundance column name.",
    )

    parser.add_argument(
        "--gene-mapping",
        required=True,
        help="RGI bwt gene_mapping_data.txt file.",
    )

    parser.add_argument(
        "--overall-stats",
        required=True,
        help="RGI bwt overall_mapping_stats.txt file.",
    )

    parser.add_argument(
        "--out-prefix",
        required=True,
        help="Output prefix. Usually the sample_id.",
    )

    parser.add_argument(
        "--min-reads",
        type=float,
        default=10,
        help="Minimum All Mapped Reads required when --apply-filters is used. Default: 10.",
    )

    parser.add_argument(
        "--min-coverage",
        type=float,
        default=40,
        help="Minimum Average Percent Coverage required when --apply-filters is used. Default: 40.",
    )

    parser.add_argument(
        "--min-mapq",
        type=float,
        default=5,
        help=(
            "Minimum Average MAPQ (Completely Mapped Reads) required when "
            "--apply-filters is used. Default: 5."
        ),
    )

    parser.add_argument(
        "--apply-filters",
        action="store_true",
        help=(
            "Apply min-read, min-coverage and min-MAPQ filters before generating "
            "abundance tables. If not set, all RGI rows are used and filter-pass "
            "statistics are reported only in the QC table."
        ),
    )

    parser.add_argument(
        "--relab-from",
        choices=["rpkm", "raw"],
        default="rpkm",
        help=(
            "Metric used to calculate relative abundance. "
            "Default: rpkm. Use raw to calculate relative abundance from raw counts."
        ),
    )

    return parser.parse_args()


def fail(message: str) -> None:
    print(f"[ERROR] {message}", file=sys.stderr)
    sys.exit(1)


def warn(message: str) -> None:
    print(f"[WARN] {message}", file=sys.stderr)


def clean_feature(value) -> str:
    if pd.isna(value):
        return "Unclassified"

    value = str(value).strip()

    if value == "" or value.lower() in {"nan", "none", "n/a", "na", "null"}:
        return "Unclassified"

    return value


def to_numeric(series: pd.Series, column_name: str) -> pd.Series:
    converted = pd.to_numeric(series, errors="coerce")

    n_bad = int(converted.isna().sum())
    if n_bad > 0:
        warn(
            f"Column '{column_name}' contains {n_bad} non-numeric values; "
            "they were converted to 0."
        )

    return converted.fillna(0)


def parse_count_percent(line: str) -> Tuple[Optional[int], Optional[float]]:
    """
    Parse lines like:
        Mapped reads:      112553    (0.18007%)

    Returns:
        count, percent
    """

    count = None
    percent = None

    count_match = re.search(r":\s*([0-9]+)", line)
    if count_match:
        count = int(count_match.group(1))

    percent_match = re.search(r"\(([0-9.+\-eE]+)%\)", line)
    if percent_match:
        percent = float(percent_match.group(1))

    return count, percent


def parse_overall_stats(path: Path) -> Dict[str, float]:
    """
    Parse RGI bwt overall_mapping_stats.txt.

    Example input:

        Total reads:       62505238
        Mapped reads:      112553    (0.18007%)
        Forward strand:    62448297  (99.9089%)
        Reverse strand:    56941     (0.091098%)
        Failed QC:         0         (0%)
        Duplicates:        0         (0%)
        Paired-end reads:  62505238  (100%)
        'Proper-pairs':    92094     (0.147338%)
        Both pairs mapped: 96516     (0.154413%)
        Read 1:            31252619
        Read 2:            31252619
        Singletons:        16037     (0.025657%)
    """

    if not path.exists():
        fail(f"Overall stats file not found: {path}")

    if path.stat().st_size == 0:
        fail(f"Overall stats file is empty: {path}")

    stats = {
        "total_reads": 0,
        "mapped_reads": 0,
        "mapped_reads_percent": 0.0,
        "forward_strand": 0,
        "forward_strand_percent": 0.0,
        "reverse_strand": 0,
        "reverse_strand_percent": 0.0,
        "failed_qc": 0,
        "failed_qc_percent": 0.0,
        "duplicates": 0,
        "duplicates_percent": 0.0,
        "paired_end_reads": 0,
        "paired_end_reads_percent": 0.0,
        "proper_pairs": 0,
        "proper_pairs_percent": 0.0,
        "both_pairs_mapped": 0,
        "both_pairs_mapped_percent": 0.0,
        "read_1": 0,
        "read_2": 0,
        "singletons": 0,
        "singletons_percent": 0.0,
    }

    key_map = {
        "Total reads": ("total_reads", None),
        "Mapped reads": ("mapped_reads", "mapped_reads_percent"),
        "Forward strand": ("forward_strand", "forward_strand_percent"),
        "Reverse strand": ("reverse_strand", "reverse_strand_percent"),
        "Failed QC": ("failed_qc", "failed_qc_percent"),
        "Duplicates": ("duplicates", "duplicates_percent"),
        "Paired-end reads": ("paired_end_reads", "paired_end_reads_percent"),
        "'Proper-pairs'": ("proper_pairs", "proper_pairs_percent"),
        "Both pairs mapped": ("both_pairs_mapped", "both_pairs_mapped_percent"),
        "Read 1": ("read_1", None),
        "Read 2": ("read_2", None),
        "Singletons": ("singletons", "singletons_percent"),
    }

    with path.open("r", encoding="utf-8", errors="replace") as handle:
        for raw_line in handle:
            line = raw_line.strip()

            if not line or ":" not in line:
                continue

            label = line.split(":", 1)[0].strip()

            if label not in key_map:
                continue

            count_key, percent_key = key_map[label]
            count, percent = parse_count_percent(line)

            if count is not None:
                stats[count_key] = count

            if percent_key is not None and percent is not None:
                stats[percent_key] = percent

    return stats


def read_gene_mapping(path: Path) -> pd.DataFrame:
    if not path.exists():
        fail(f"Gene mapping file not found: {path}")

    if path.stat().st_size == 0:
        fail(f"Gene mapping file is empty: {path}")

    try:
        df = pd.read_csv(path, sep="\t", dtype=str)
    except Exception as exc:
        fail(f"Could not read gene mapping file '{path}': {exc}")

    missing = [col for col in REQUIRED_GENE_COLUMNS if col not in df.columns]
    if missing:
        fail(
            "Gene mapping file is missing required columns: "
            + ", ".join(missing)
        )

    return df


def prepare_gene_mapping(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()

    text_columns = [
        "ARO Term",
        "ARO Accession",
        "AMR Gene Family",
        "Drug Class",
        "Resistance Mechanism",
    ]

    for col in text_columns:
        df[col] = df[col].map(clean_feature)

    df["All Mapped Reads"] = to_numeric(
        df["All Mapped Reads"],
        "All Mapped Reads",
    )

    df["Average Percent Coverage"] = to_numeric(
        df["Average Percent Coverage"],
        "Average Percent Coverage",
    )

    df["Average MAPQ (Completely Mapped Reads)"] = to_numeric(
        df["Average MAPQ (Completely Mapped Reads)"],
        "Average MAPQ (Completely Mapped Reads)",
    )

    df["Reference Length"] = to_numeric(
        df["Reference Length"],
        "Reference Length",
    )

    # Avoid division by zero in RPKM.
    df.loc[df["Reference Length"] <= 0, "Reference Length"] = pd.NA

    return df


def compute_rpkm(df: pd.DataFrame, total_reads: int) -> pd.DataFrame:
    df = df.copy()

    if total_reads <= 0:
        warn("total_reads is 0 or missing; all RPKM values will be set to 0.")
        df["RPKM"] = 0.0
        return df

    # RPKM = mapped_reads * 1e9 / (reference_length_bp * total_reads)
    df["RPKM"] = (
        df["All Mapped Reads"] * 1_000_000_000
        / (df["Reference Length"] * total_reads)
    )

    df["RPKM"] = df["RPKM"].fillna(0.0)

    return df


def filter_gene_mapping(
    df: pd.DataFrame,
    min_reads: float,
    min_coverage: float,
    min_mapq: float,
) -> pd.DataFrame:
    return df[
        (df["All Mapped Reads"] >= min_reads)
        & (df["Average Percent Coverage"] >= min_coverage)
        & (df["Average MAPQ (Completely Mapped Reads)"] >= min_mapq)
    ].copy()


def add_relab(table: pd.DataFrame, value_col: str, sample_id: str) -> pd.DataFrame:
    """
    Input table format:
        feature columns + value_col

    Output:
        same feature columns + sample_id containing relative abundance.
    """

    out = table.copy()
    total = out[value_col].sum()

    if total > 0:
        out[sample_id] = out[value_col] / total
    else:
        out[sample_id] = 0.0

    return out.drop(columns=[value_col])


def write_empty_aro_tables(sample_id: str, out_prefix: str) -> None:
    raw = pd.DataFrame(columns=["feature_id", "feature_name", sample_id])
    rpkm = pd.DataFrame(columns=["feature_id", "feature_name", sample_id])
    relab = pd.DataFrame(columns=["feature_id", "feature_name", sample_id])

    raw.to_csv(f"{out_prefix}.amr_aro_raw_counts.tsv", sep="\t", index=False)
    rpkm.to_csv(f"{out_prefix}.amr_aro_rpkm.tsv", sep="\t", index=False)
    relab.to_csv(f"{out_prefix}.amr_aro_relab.tsv", sep="\t", index=False)


def write_aro_tables(
    df: pd.DataFrame,
    sample_id: str,
    out_prefix: str,
    relab_from: str,
) -> None:
    if df.empty:
        write_empty_aro_tables(sample_id, out_prefix)
        return

    aro = (
        df.groupby(["ARO Accession", "ARO Term"], dropna=False)
        .agg(
            raw_count=("All Mapped Reads", "sum"),
            rpkm=("RPKM", "sum"),
        )
        .reset_index()
        .rename(
            columns={
                "ARO Accession": "feature_id",
                "ARO Term": "feature_name",
            }
        )
    )

    aro["feature_id"] = aro["feature_id"].map(clean_feature)
    aro["feature_name"] = aro["feature_name"].map(clean_feature)

    aro = aro.sort_values(["feature_id", "feature_name"])

    raw = aro[["feature_id", "feature_name", "raw_count"]].rename(
        columns={"raw_count": sample_id}
    )

    rpkm = aro[["feature_id", "feature_name", "rpkm"]].rename(
        columns={"rpkm": sample_id}
    )

    relab_value_col = "rpkm" if relab_from == "rpkm" else "raw_count"
    relab_base = aro[["feature_id", "feature_name", relab_value_col]]
    relab = add_relab(relab_base, relab_value_col, sample_id)

    raw.to_csv(f"{out_prefix}.amr_aro_raw_counts.tsv", sep="\t", index=False)
    rpkm.to_csv(f"{out_prefix}.amr_aro_rpkm.tsv", sep="\t", index=False)
    relab.to_csv(f"{out_prefix}.amr_aro_relab.tsv", sep="\t", index=False)


def write_empty_feature_table(output_path: str, sample_id: str) -> None:
    pd.DataFrame(columns=["feature", sample_id]).to_csv(
        output_path,
        sep="\t",
        index=False,
    )


def aggregate_feature_table(
    df: pd.DataFrame,
    feature_col: str,
    value_col: str,
) -> pd.DataFrame:
    if df.empty:
        return pd.DataFrame(columns=["feature", value_col])

    out = (
        df.groupby(feature_col, dropna=False)[value_col]
        .sum()
        .reset_index()
        .rename(columns={feature_col: "feature"})
    )

    out["feature"] = out["feature"].map(clean_feature)
    out = out.sort_values("feature")

    return out


def write_feature_tables(
    df: pd.DataFrame,
    feature_col: str,
    output_stem: str,
    sample_id: str,
    out_prefix: str,
    relab_from: str,
) -> None:
    raw_table = aggregate_feature_table(
        df=df,
        feature_col=feature_col,
        value_col="All Mapped Reads",
    )

    rpkm_table = aggregate_feature_table(
        df=df,
        feature_col=feature_col,
        value_col="RPKM",
    )

    raw_out = raw_table.rename(columns={"All Mapped Reads": sample_id})
    rpkm_out = rpkm_table.rename(columns={"RPKM": sample_id})

    relab_value_col = "RPKM" if relab_from == "rpkm" else "All Mapped Reads"
    relab_base = rpkm_table if relab_from == "rpkm" else raw_table
    relab_out = add_relab(relab_base, relab_value_col, sample_id)

    raw_path = f"{out_prefix}.{output_stem}_raw_counts.tsv"
    rpkm_path = f"{out_prefix}.{output_stem}_rpkm.tsv"
    relab_path = f"{out_prefix}.{output_stem}_relab.tsv"

    if raw_out.empty:
        write_empty_feature_table(raw_path, sample_id)
    else:
        raw_out.to_csv(raw_path, sep="\t", index=False)

    if rpkm_out.empty:
        write_empty_feature_table(rpkm_path, sample_id)
    else:
        rpkm_out.to_csv(rpkm_path, sep="\t", index=False)

    if relab_out.empty:
        write_empty_feature_table(relab_path, sample_id)
    else:
        relab_out.to_csv(relab_path, sep="\t", index=False)


def split_semicolon_features(df: pd.DataFrame, feature_col: str) -> pd.DataFrame:
    """
    Explode semicolon-separated annotations.

    Example:
        Drug Class = "macrolide antibiotic; fluoroquinolone antibiotic"

    The same count/RPKM is assigned to both categories.

    This means class-level totals may exceed ARO-level totals.
    """

    if df.empty:
        return df.copy()

    records = []

    for _, row in df.iterrows():
        raw_value = clean_feature(row[feature_col])

        parts = [clean_feature(x) for x in raw_value.split(";")]
        parts = [x for x in parts if x and x != "Unclassified"]

        if not parts:
            parts = ["Unclassified"]

        for part in parts:
            new_row = row.copy()
            new_row[feature_col] = part
            records.append(new_row)

    if not records:
        return pd.DataFrame(columns=df.columns)

    return pd.DataFrame(records)


def write_category_tables(
    df: pd.DataFrame,
    sample_id: str,
    out_prefix: str,
    relab_from: str,
) -> None:
    # AMR Gene Family: usually single annotation, no semicolon splitting.
    write_feature_tables(
        df=df,
        feature_col="AMR Gene Family",
        output_stem="amr_gene_family",
        sample_id=sample_id,
        out_prefix=out_prefix,
        relab_from=relab_from,
    )

    # Drug Class: frequently semicolon-separated.
    drug_df = split_semicolon_features(df, "Drug Class")

    write_feature_tables(
        df=drug_df,
        feature_col="Drug Class",
        output_stem="amr_drug_class",
        sample_id=sample_id,
        out_prefix=out_prefix,
        relab_from=relab_from,
    )

    # Resistance Mechanism: usually single, but split for safety.
    mech_df = split_semicolon_features(df, "Resistance Mechanism")

    write_feature_tables(
        df=mech_df,
        feature_col="Resistance Mechanism",
        output_stem="amr_mechanism",
        sample_id=sample_id,
        out_prefix=out_prefix,
        relab_from=relab_from,
    )


def write_qc_table(
    sample_id: str,
    out_prefix: str,
    stats: Dict[str, float],
    n_gene_rows_raw: int,
    n_gene_rows_passing_filters: int,
    n_gene_rows_used: int,
    n_aro_raw: int,
    n_aro_passing_filters: int,
    n_aro_used: int,
    total_raw_amr_reads_raw: float,
    total_raw_amr_reads_passing_filters: float,
    total_raw_amr_reads_used: float,
    total_rpkm_raw: float,
    total_rpkm_passing_filters: float,
    total_rpkm_used: float,
    min_reads: float,
    min_coverage: float,
    min_mapq: float,
    apply_filters: bool,
    relab_from: str,
) -> None:
    row = {
        "sample_id": sample_id,
        **stats,
        "n_rgi_gene_rows_raw": n_gene_rows_raw,
        "n_rgi_gene_rows_passing_filters": n_gene_rows_passing_filters,
        "n_rgi_gene_rows_used": n_gene_rows_used,
        "n_aro_raw": n_aro_raw,
        "n_aro_passing_filters": n_aro_passing_filters,
        "n_aro_used": n_aro_used,
        "total_amr_raw_reads_raw": total_raw_amr_reads_raw,
        "total_amr_raw_reads_passing_filters": total_raw_amr_reads_passing_filters,
        "total_amr_raw_reads_used": total_raw_amr_reads_used,
        "total_amr_rpkm_raw": total_rpkm_raw,
        "total_amr_rpkm_passing_filters": total_rpkm_passing_filters,
        "total_amr_rpkm_used": total_rpkm_used,
        "filtering_applied": str(bool(apply_filters)).lower(),
        "min_reads": min_reads,
        "min_coverage": min_coverage,
        "min_mapq": min_mapq,
        "relab_from": relab_from,
    }

    pd.DataFrame([row]).to_csv(
        f"{out_prefix}.amr_qc_mapping_stats.tsv",
        sep="\t",
        index=False,
    )


def main() -> None:
    args = parse_args()

    gene_mapping_path = Path(args.gene_mapping)
    overall_stats_path = Path(args.overall_stats)

    stats = parse_overall_stats(overall_stats_path)
    total_reads = int(stats.get("total_reads", 0))

    df_raw = read_gene_mapping(gene_mapping_path)
    df_raw = prepare_gene_mapping(df_raw)
    df_raw = compute_rpkm(df_raw, total_reads=total_reads)

    df_passing = filter_gene_mapping(
        df_raw,
        min_reads=args.min_reads,
        min_coverage=args.min_coverage,
        min_mapq=args.min_mapq,
    )

    if args.apply_filters:
        df_used = df_passing.copy()
    else:
        df_used = df_raw.copy()

    n_gene_rows_raw = len(df_raw)
    n_gene_rows_passing_filters = len(df_passing)
    n_gene_rows_used = len(df_used)

    n_aro_raw = int(df_raw["ARO Accession"].nunique()) if not df_raw.empty else 0
    n_aro_passing_filters = (
        int(df_passing["ARO Accession"].nunique()) if not df_passing.empty else 0
    )
    n_aro_used = int(df_used["ARO Accession"].nunique()) if not df_used.empty else 0

    total_raw_amr_reads_raw = float(df_raw["All Mapped Reads"].sum())
    total_raw_amr_reads_passing_filters = float(df_passing["All Mapped Reads"].sum())
    total_raw_amr_reads_used = float(df_used["All Mapped Reads"].sum())

    total_rpkm_raw = float(df_raw["RPKM"].sum())
    total_rpkm_passing_filters = float(df_passing["RPKM"].sum())
    total_rpkm_used = float(df_used["RPKM"].sum())

    write_aro_tables(
        df=df_used,
        sample_id=args.sample_id,
        out_prefix=args.out_prefix,
        relab_from=args.relab_from,
    )

    write_category_tables(
        df=df_used,
        sample_id=args.sample_id,
        out_prefix=args.out_prefix,
        relab_from=args.relab_from,
    )

    write_qc_table(
        sample_id=args.sample_id,
        out_prefix=args.out_prefix,
        stats=stats,
        n_gene_rows_raw=n_gene_rows_raw,
        n_gene_rows_passing_filters=n_gene_rows_passing_filters,
        n_gene_rows_used=n_gene_rows_used,
        n_aro_raw=n_aro_raw,
        n_aro_passing_filters=n_aro_passing_filters,
        n_aro_used=n_aro_used,
        total_raw_amr_reads_raw=total_raw_amr_reads_raw,
        total_raw_amr_reads_passing_filters=total_raw_amr_reads_passing_filters,
        total_raw_amr_reads_used=total_raw_amr_reads_used,
        total_rpkm_raw=total_rpkm_raw,
        total_rpkm_passing_filters=total_rpkm_passing_filters,
        total_rpkm_used=total_rpkm_used,
        min_reads=args.min_reads,
        min_coverage=args.min_coverage,
        min_mapq=args.min_mapq,
        apply_filters=args.apply_filters,
        relab_from=args.relab_from,
    )


if __name__ == "__main__":
    main()