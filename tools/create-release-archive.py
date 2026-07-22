#!/usr/bin/env python3
"""Create a deterministic ZIP from a staged release directory."""
from __future__ import annotations

import argparse
import os
import zipfile
from pathlib import Path

# ZIP cannot represent dates before 1980. A fixed timestamp makes identical
# staged trees produce identical archives and therefore identical SHA-256 sums.
FIXED_TIMESTAMP = (2026, 7, 22, 0, 0, 0)


def add_directory(zf: zipfile.ZipFile, relative: str) -> None:
    info = zipfile.ZipInfo(relative.rstrip('/') + '/', FIXED_TIMESTAMP)
    info.create_system = 3
    info.external_attr = (0o40755 << 16) | 0x10
    info.compress_type = zipfile.ZIP_STORED
    zf.writestr(info, b'')


def add_file(zf: zipfile.ZipFile, source: Path, relative: str) -> None:
    info = zipfile.ZipInfo(relative, FIXED_TIMESTAMP)
    info.create_system = 3
    info.external_attr = 0o100644 << 16
    info.compress_type = zipfile.ZIP_DEFLATED
    with source.open('rb') as handle:
        zf.writestr(info, handle.read(), compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('source', help='staged release directory')
    parser.add_argument('output', help='output ZIP path')
    args = parser.parse_args()

    source = Path(args.source).resolve()
    output = Path(args.output).resolve()
    if not source.is_dir():
        parser.error(f'not a directory: {source}')
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists():
        output.unlink()

    entries = sorted(source.rglob('*'), key=lambda p: p.relative_to(source).as_posix().casefold())
    with zipfile.ZipFile(output, 'w', allowZip64=True) as zf:
        for entry in entries:
            rel = entry.relative_to(source).as_posix()
            if entry.is_dir():
                add_directory(zf, rel)
            elif entry.is_file():
                add_file(zf, entry, rel)
            else:
                raise RuntimeError(f'unsupported filesystem entry: {entry}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
