#!/usr/bin/env python3

import argparse
import csv
import sys
from pathlib import Path
from typing import List, Optional


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Generate a FUNCMAP samplesheet from paired-end FASTQ files "
            "and matching MetaPhlAn taxonomic profiles."
        )
    )

    parser.add_argument(
        "--reads-dir",
        required=True,
        help="Directory containing paired-end reads.",
    )

    parser.add_argument(
        "--mpa-dir",
        required=True,
        help="Directory containing MetaPhlAn profiles.",
    )

    parser.add_argument(
        "--out",
        required=True,
        help="Output samplesheet CSV path.",
    )

    parser.add_argument(
        "--r1-suffix",
        default=".unmapped_1.fastq.gz",
        help="Suffix identifying R1 files. Default: .unmapped_1.fastq.gz",
    )

    parser.add_argument(
        "--r2-suffix",
        default=".unmapped_2.fastq.gz",
        help="Suffix identifying R2 files. Default: .unmapped_2.fastq.gz",
    )

    parser.add_argument(
        "--r1-pattern",
        default=None,
        help=(
            "Optional glob pattern for R1 files. "
            "If not provided, '*' + r1_suffix is used."
        ),
    )

    parser.add_argument(
        "--mpa-pattern",
        default="*metaphlan*profile*.txt",
        help=(
            "Glob pattern for MetaPhlAn profiles. "
            "Default: *metaphlan*profile*.txt"
        ),
    )

    parser.add_argument(
        "--use-raw-id-as-sample-id",
        action="store_true",
        help=(
            "Use the full inferred raw_id as sample_id. "
            "By default, '_run*' suffixes are stripped from sample_id."
        ),
    )

    parser.add_argument(
        "--allow-missing-mpa",
        action="store_true",
        help=(
            "Allow missing MetaPhlAn profiles and write an empty mpa_profile field. "
            "Useful only when running AMR-only analyses."
        ),
    )

    parser.add_argument(
        "--force",
        action="store_true",
        help="Overwrite output samplesheet if it already exists.",
    )

    return parser.parse_args()


def fail(message: str) -> None:
    print(f"[ERROR] {message}", file=sys.stderr)
    sys.exit(1)


def warn(message: str) -> None:
    print(f"[WARN] {message}", file=sys.stderr)


def info(message: str) -> None:
    print(f"[INFO] {message}", file=sys.stderr)


def resolve_existing_dir(path: str, label: str) -> Path:
    p = Path(path).expanduser().resolve()

    if not p.exists():
        fail(f"{label} does not exist: {p}")

    if not p.is_dir():
        fail(f"{label} is not a directory: {p}")

    return p


def infer_raw_id(r1_name: str, r1_suffix: str) -> str:
    if not r1_name.endswith(r1_suffix):
        fail(f"R1 file does not end with expected suffix '{r1_suffix}': {r1_name}")

    return r1_name[: -len(r1_suffix)]


def infer_sample_id(raw_id: str, use_raw_id: bool) -> str:
    if use_raw_id:
        return raw_id

    if "_run" in raw_id:
        return raw_id.split("_run", 1)[0]

    return raw_id


def find_mpa_profile(
    mpa_dir: Path,
    raw_id: str,
    sample_id: str,
    mpa_pattern: str,
) -> Optional[Path]:
    """
    Search priority:
      1. profile starting with raw_id
      2. profile containing raw_id
      3. profile starting with sample_id
      4. profile containing sample_id
    """

    search_patterns = [
        f"{raw_id}{mpa_pattern}",
        f"*{raw_id}*{mpa_pattern}",
        f"{sample_id}{mpa_pattern}",
        f"*{sample_id}*{mpa_pattern}",
    ]

    candidates: List[Path] = []

    for pattern in search_patterns:
        candidates = sorted(mpa_dir.glob(pattern))
        if candidates:
            break

    if not candidates:
        return None

    if len(candidates) > 1:
        fail(
            "Multiple MetaPhlAn profiles found for sample "
            f"'{sample_id}' / raw_id '{raw_id}':\n"
            + "\n".join(f"  - {x}" for x in candidates)
            + "\nPlease refine --mpa-pattern or file naming."
        )

    return candidates[0].resolve()


def main() -> None:
    args = parse_args()

    reads_dir = resolve_existing_dir(args.reads_dir, "reads-dir")
    mpa_dir = resolve_existing_dir(args.mpa_dir, "mpa-dir")

    out_path = Path(args.out).expanduser().resolve()

    if out_path.exists() and not args.force:
        fail(
            f"Output samplesheet already exists: {out_path}\n"
            "Use --force to overwrite."
        )

    out_path.parent.mkdir(parents=True, exist_ok=True)

    r1_pattern = args.r1_pattern or f"*{args.r1_suffix}"

    info("Generating FUNCMAP samplesheet")
    info(f"reads_dir                 : {reads_dir}")
    info(f"mpa_dir                   : {mpa_dir}")
    info(f"out                       : {out_path}")
    info(f"r1_pattern                : {r1_pattern}")
    info(f"r1_suffix                 : {args.r1_suffix}")
    info(f"r2_suffix                 : {args.r2_suffix}")
    info(f"mpa_pattern               : {args.mpa_pattern}")
    info(f"use_raw_id_as_sample_id   : {args.use_raw_id_as_sample_id}")
    info(f"allow_missing_mpa         : {args.allow_missing_mpa}")

    r1_files = sorted(reads_dir.glob(r1_pattern))

    if not r1_files:
        fail(f"No R1 files found in {reads_dir} with pattern: {r1_pattern}")

    rows = []
    seen_sample_ids = set()

    for r1 in r1_files:
        r1 = r1.resolve()
        raw_id = infer_raw_id(r1.name, args.r1_suffix)
        sample_id = infer_sample_id(raw_id, args.use_raw_id_as_sample_id)

        if not raw_id:
            fail(f"Could not infer raw_id from R1 file: {r1}")

        if not sample_id:
            fail(f"Could not infer sample_id from raw_id: {raw_id}")

        if sample_id in seen_sample_ids:
            fail(
                f"Duplicated sample_id detected: {sample_id}\n"
                "This can happen when multiple runs exist for the same sample "
                "and --use-raw-id-as-sample-id is not used."
            )

        r2 = reads_dir / f"{raw_id}{args.r2_suffix}"

        if not r2.exists():
            fail(
                f"Missing R2 for sample '{sample_id}' / raw_id '{raw_id}'.\n"
                f"Expected: {r2}"
            )

        r2 = r2.resolve()

        mpa_profile = find_mpa_profile(
            mpa_dir=mpa_dir,
            raw_id=raw_id,
            sample_id=sample_id,
            mpa_pattern=args.mpa_pattern,
        )

        if mpa_profile is None:
            if args.allow_missing_mpa:
                warn(
                    f"Missing MetaPhlAn profile for sample '{sample_id}'. "
                    "Writing empty mpa_profile field."
                )
                mpa_value = ""
            else:
                fail(
                    f"Missing MetaPhlAn profile for sample '{sample_id}' / raw_id '{raw_id}'.\n"
                    f"Searched in: {mpa_dir}\n"
                    f"Pattern: {args.mpa_pattern}\n"
                    "Use --allow-missing-mpa only for AMR-only runs."
                )
        else:
            mpa_value = str(mpa_profile)

        rows.append(
            {
                "sample_id": sample_id,
                "r1": str(r1),
                "r2": str(r2),
                "mpa_profile": mpa_value,
            }
        )

        seen_sample_ids.add(sample_id)

        info(f"Added sample: {sample_id}")
        info(f"  raw_id      : {raw_id}")
        info(f"  R1          : {r1}")
        info(f"  R2          : {r2}")
        info(f"  mpa_profile : {mpa_value if mpa_value else 'NA'}")

    with out_path.open("w", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=["sample_id", "r1", "r2", "mpa_profile"],
        )
        writer.writeheader()
        writer.writerows(rows)

    info(f"Samplesheet generated with {len(rows)} samples: {out_path}")


if __name__ == "__main__":
    main()
