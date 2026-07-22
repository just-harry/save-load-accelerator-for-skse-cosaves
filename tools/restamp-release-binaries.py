#!/usr/bin/env python3
"""Restamp a metadata-only release without changing executable code.

This tool is intended only when a release deliberately carries forward the
exact same compiled implementation and changes version metadata. Old and new
semantic version strings must have equal encoded length.

Example:
  python tools/restamp-release-binaries.py <release-tree> 1.5.0 1.5.1
"""
from __future__ import annotations

import argparse
import struct
import sys
from pathlib import Path

VS_FIXEDFILEINFO_SIGNATURE = 0xFEEF04BD


def parse_version(value: str) -> tuple[int, int, int, int]:
    parts = value.split('.')
    if len(parts) not in (3, 4) or any(not p.isdigit() for p in parts):
        raise ValueError(f"invalid version: {value!r}; expected major.minor.patch[.revision]")
    nums = [int(p) for p in parts]
    if len(nums) == 3:
        nums.append(0)
    if any(n > 0xFFFF for n in nums):
        raise ValueError("each version component must fit in 16 bits")
    return tuple(nums)  # type: ignore[return-value]


def checksum_offset(data: bytes) -> int:
    if len(data) < 0x40 or data[:2] != b'MZ':
        raise ValueError('not a PE image')
    pe = struct.unpack_from('<I', data, 0x3C)[0]
    if data[pe:pe + 4] != b'PE\0\0':
        raise ValueError('missing PE signature')
    return pe + 4 + 20 + 64


def calculate_pe_checksum(data: bytes) -> int:
    off = checksum_offset(data)
    buf = bytearray(data)
    buf[off:off + 4] = b'\0\0\0\0'
    total = 0
    stop = len(buf) - (len(buf) % 2)
    for i in range(0, stop, 2):
        total += buf[i] | (buf[i + 1] << 8)
        total = (total & 0xFFFF) + (total >> 16)
    if len(buf) % 2:
        total += buf[-1]
        total = (total & 0xFFFF) + (total >> 16)
    total = (total & 0xFFFF) + (total >> 16)
    return (total + len(buf)) & 0xFFFFFFFF


def replace_all_equal(buf: bytearray, old: bytes, new: bytes) -> int:
    if len(old) != len(new):
        raise ValueError('old and new encodings must have equal length')
    count = 0
    start = 0
    while True:
        pos = buf.find(old, start)
        if pos < 0:
            return count
        buf[pos:pos + len(old)] = new
        count += 1
        start = pos + len(new)


def sanitize_codeview_path(buf: bytearray) -> int:
    count = 0
    cursor = 0
    while True:
        pos = buf.find(b'RSDS', cursor)
        if pos < 0:
            return count
        start = pos + 24  # signature + GUID + age
        end = buf.find(b'\0', start)
        if end < 0:
            raise ValueError('unterminated CodeView PDB path')
        old_path = bytes(buf[start:end])
        basename = old_path.replace(b'/', b'\\').rsplit(b'\\', 1)[-1]
        if basename and len(basename) <= len(old_path):
            buf[start:end] = basename + b'\0' * (len(old_path) - len(basename))
            count += 1
        cursor = end + 1


def restamp(path: Path, old: str, new: str) -> tuple[int, int, int]:
    old4 = parse_version(old)
    new4 = parse_version(new)
    old_sem = '.'.join(map(str, old4[:3]))
    new_sem = '.'.join(map(str, new4[:3]))
    if len(old_sem) != len(new_sem):
        raise ValueError('semantic versions must have equal string length for metadata-only restamping')

    original = path.read_bytes()
    buf = bytearray(original)
    ascii_count = replace_all_equal(buf, old_sem.encode('ascii'), new_sem.encode('ascii'))
    utf16_count = replace_all_equal(buf, old_sem.encode('utf-16-le'), new_sem.encode('utf-16-le'))

    signature = struct.pack('<I', VS_FIXEDFILEINFO_SIGNATURE)
    fixed_count = 0
    cursor = 0
    new_ms = (new4[0] << 16) | new4[1]
    new_ls = (new4[2] << 16) | new4[3]
    while True:
        pos = buf.find(signature, cursor)
        if pos < 0:
            break
        if pos + 24 <= len(buf):
            # VS_FIXEDFILEINFO: signature, struct version, file MS/LS, product MS/LS.
            struct.pack_into('<IIII', buf, pos + 8, new_ms, new_ls, new_ms, new_ls)
            fixed_count += 1
        cursor = pos + 4

    if ascii_count + utf16_count == 0 or fixed_count == 0:
        raise ValueError(f'{path}: expected version metadata was not found')

    codeview_count = sanitize_codeview_path(buf)

    off = checksum_offset(buf)
    struct.pack_into('<I', buf, off, 0)
    struct.pack_into('<I', buf, off, calculate_pe_checksum(buf))
    path.write_bytes(buf)
    return ascii_count + utf16_count, fixed_count, codeview_count


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('path', help='DLL or directory tree containing DLLs')
    ap.add_argument('old_version', help='old semantic version, e.g. 1.5.0')
    ap.add_argument('new_version', help='new semantic version, e.g. 1.5.1')
    args = ap.parse_args()

    root = Path(args.path)
    files = sorted(root.rglob('*.dll')) if root.is_dir() else [root]
    if not files:
        print('error: no DLLs found', file=sys.stderr)
        return 1

    try:
        for dll in files:
            strings, fixed, codeview = restamp(dll, args.old_version, args.new_version)
            print(f'{dll}: updated {strings} version string occurrence(s), {fixed} fixed version resource(s), sanitized {codeview} CodeView path(s)')
    except (OSError, ValueError, struct.error) as exc:
        print(f'error: {exc}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
