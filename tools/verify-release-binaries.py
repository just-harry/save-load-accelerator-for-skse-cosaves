#!/usr/bin/env python3
"""Independent verification tooling for Faster Loadin and Savin releases.

Two modes, both dependency-free (Python 3.8+ standard library only):

  manifest  Print SHA-256 and the embedded version resource of every DLL in a
            directory tree. Use this to record or check what a release contains.

  compare   Diff two PE files (DLLs) and report *which PE section* every
            differing byte falls in. This answers the question that matters
            for trust: did the executable code change, or only metadata?

Why this exists
---------------
Metadata-only releases can be verified without trusting a release note. Run
`compare` on matching DLLs and confirm that `.text` -- the executable code --
is identical, while differences are confined to version-bearing `.rdata`,
`.rsrc`, and the PE header checksum.

Examples
--------
  python tools/verify-release-binaries.py manifest "path/to/release"
  python tools/verify-release-binaries.py compare old.dll new.dll
  python tools/verify-release-binaries.py compare old.dll new.dll --strict

Exit codes: 0 = success / differences confined to metadata, 1 = otherwise.
"""

from __future__ import annotations

import argparse
import hashlib
import struct
import sys
from pathlib import Path

# Sections whose contents may legitimately differ between two builds that share
# identical source code but carry a different version stamp.
METADATA_REGIONS = {".rsrc", ".rdata", "OptionalHeader.CheckSum"}

# The section that must never differ if the claim "no code changed" is true.
CODE_SECTIONS = {".text"}


class PEError(Exception):
    """Raised when a file cannot be parsed as a PE image."""


def parse_pe(data: bytes):
    """Return (sections, checksum_offset, rva_map).

    sections is a list of (name, raw_start, raw_end) for each section with
    file-backed contents. checksum_offset is the file offset of the
    OptionalHeader CheckSum field, which the linker (or a resource editor)
    recomputes whenever the image changes. rva_map translates relative virtual
    addresses back to file offsets.
    """
    rva_map = []
    if len(data) < 0x40 or data[:2] != b"MZ":
        raise PEError("not a DOS/PE image (missing MZ signature)")

    pe_off = struct.unpack_from("<I", data, 0x3C)[0]
    if pe_off + 24 > len(data) or data[pe_off:pe_off + 4] != b"PE\0\0":
        raise PEError("missing PE signature")

    coff = pe_off + 4
    n_sections = struct.unpack_from("<H", data, coff + 2)[0]
    opt_size = struct.unpack_from("<H", data, coff + 16)[0]
    opt_off = coff + 20

    if opt_size == 0:
        raise PEError("image has no optional header")

    # CheckSum is at offset 64 within the optional header for both PE32 and
    # PE32+; the magic differs but the field position does not.
    checksum_off = opt_off + 64

    sections = []
    sec_off = opt_off + opt_size
    for i in range(n_sections):
        s = sec_off + i * 40
        if s + 40 > len(data):
            raise PEError(f"section table truncated at entry {i}")
        name = data[s:s + 8].rstrip(b"\0").decode("ascii", "replace")
        virt_size = struct.unpack_from("<I", data, s + 8)[0]
        virt_addr = struct.unpack_from("<I", data, s + 12)[0]
        raw_size = struct.unpack_from("<I", data, s + 16)[0]
        raw_ptr = struct.unpack_from("<I", data, s + 20)[0]
        if raw_size:
            sections.append((name, raw_ptr, raw_ptr + raw_size))
        # A section's virtual extent can exceed its on-disk size (.data with
        # uninitialised tail) or fall short of it (alignment padding), so map
        # by the larger of the two and clamp reads to the file length.
        if virt_addr:
            rva_map.append((virt_addr, virt_addr + max(virt_size, raw_size), raw_ptr))
    return sections, checksum_off, rva_map


def rva_to_offset(rva_map, rva: int, limit: int):
    """Translate a relative virtual address to a file offset, or None."""
    for start, end, raw in rva_map:
        if start <= rva < end:
            off = raw + (rva - start)
            return off if 0 <= off < limit else None
    return None


def read_cstring(data: bytes, off: int, limit: int = 256) -> str:
    end = data.find(b"\0", off, off + limit)
    if end < 0:
        end = off + limit
    return data[off:end].decode("ascii", "replace")


def parse_imports(data: bytes, rva_map):
    """Return {dll_name: [imported symbol, ...]} from the PE import table.

    This is what the binary can actually call into. Source can be read
    selectively; the import table cannot be talked around.
    """
    pe_off = struct.unpack_from("<I", data, 0x3C)[0]
    coff = pe_off + 4
    opt_size = struct.unpack_from("<H", data, coff + 16)[0]
    opt_off = coff + 20
    magic = struct.unpack_from("<H", data, opt_off)[0]
    if magic == 0x20B:        # PE32+
        data_dirs = opt_off + 112
    elif magic == 0x10B:      # PE32
        data_dirs = opt_off + 96
    else:
        raise PEError(f"unknown optional header magic {magic:#06x}")

    # Data directory index 1 is the import table; index 0 is the export table.
    # Each entry is 8 bytes (RVA + size).
    dir_off = data_dirs + 1 * 8

    if opt_size < (dir_off - opt_off) + 8:
        return {}

    import_rva, import_size = struct.unpack_from("<II", data, dir_off)
    if not import_rva or not import_size:
        return {}

    limit = len(data)
    table = rva_to_offset(rva_map, import_rva, limit)
    if table is None:
        return {}

    imports = {}
    entry = table
    while entry + 20 <= limit:
        ilt_rva, _, _, name_rva, iat_rva = struct.unpack_from("<IIIII", data, entry)
        if not (ilt_rva or name_rva or iat_rva):
            break  # null terminator entry
        name_off = rva_to_offset(rva_map, name_rva, limit)
        dll = read_cstring(data, name_off) if name_off is not None else "<unknown>"

        symbols = []
        thunk_rva = ilt_rva or iat_rva
        thunk = rva_to_offset(rva_map, thunk_rva, limit) if thunk_rva else None
        if thunk is not None:
            step = 8 if magic == 0x20B else 4
            fmt = "<Q" if step == 8 else "<I"
            ordinal_flag = (1 << 63) if step == 8 else (1 << 31)
            t = thunk
            while t + step <= len(data):
                (value,) = struct.unpack_from(fmt, data, t)
                if value == 0:
                    break
                if value & ordinal_flag:
                    symbols.append(f"#{value & 0xFFFF} (by ordinal)")
                else:
                    hint_off = rva_to_offset(rva_map, value & 0x7FFFFFFF, limit)
                    if hint_off is not None:
                        symbols.append(read_cstring(data, hint_off + 2))
                t += step
        imports[dll] = sorted(symbols)
        entry += 20
    return imports


def region_of(offset: int, sections, checksum_off: int) -> str:
    if checksum_off <= offset < checksum_off + 4:
        return "OptionalHeader.CheckSum"
    for name, start, end in sections:
        if start <= offset < end:
            return name
    return "header/padding"


def contiguous(offsets):
    """Collapse a sorted iterable of offsets into [start, end] ranges."""
    out = []
    for o in offsets:
        if out and o == out[-1][1] + 1:
            out[-1][1] = o
        else:
            out.append([o, o])
    return out


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def version_strings(data: bytes):
    """Best-effort extraction of FileVersion/ProductVersion from .rsrc.

    The version resource stores its keys and values as UTF-16LE. Rather than
    walking the full resource directory, locate the well-known key names and
    read the null-terminated string that follows. Returns a dict; missing keys
    simply do not appear.
    """
    found = {}
    for key in ("FileVersion", "ProductVersion", "ProductName", "CompanyName"):
        needle = key.encode("utf-16-le")
        idx = data.find(needle)
        if idx < 0:
            continue
        cursor = idx + len(needle)
        # Skip the null terminator and any padding zeros before the value.
        while cursor + 1 < len(data) and data[cursor:cursor + 2] == b"\0\0":
            cursor += 2
        chars = []
        while cursor + 1 < len(data):
            unit = data[cursor:cursor + 2]
            if unit == b"\0\0":
                break
            chars.append(unit)
            cursor += 2
        try:
            value = b"".join(chars).decode("utf-16-le")
        except UnicodeDecodeError:
            continue
        if value.isprintable():
            found[key] = value
    return found


def cmd_manifest(args) -> int:
    root = Path(args.path)
    if not root.exists():
        print(f"error: path does not exist: {root}", file=sys.stderr)
        return 1

    files = sorted(root.rglob("*.dll")) if root.is_dir() else [root]
    if not files:
        print(f"error: no .dll files found under {root}", file=sys.stderr)
        return 1

    for path in files:
        rel = path.relative_to(root) if root.is_dir() else path.name
        data = path.read_bytes()
        info = version_strings(data)
        ver = info.get("FileVersion", "?")
        print(f"{sha256(path)}  {ver:10s}  {rel}")
    print(f"\n{len(files)} file(s).")
    return 0


def cmd_compare(args) -> int:
    old_path, new_path = Path(args.old), Path(args.new)
    for p in (old_path, new_path):
        if not p.is_file():
            print(f"error: not a file: {p}", file=sys.stderr)
            return 1

    old, new = old_path.read_bytes(), new_path.read_bytes()

    print(f"OLD  {old_path}")
    print(f"     sha256 {sha256(old_path)}  ({len(old)} bytes)")
    for k, v in version_strings(old).items():
        print(f"     {k}: {v}")
    print(f"NEW  {new_path}")
    print(f"     sha256 {sha256(new_path)}  ({len(new)} bytes)")
    for k, v in version_strings(new).items():
        print(f"     {k}: {v}")
    print()

    if len(old) != len(new):
        print(f"RESULT: DIFFERENT SIZE ({len(old)} -> {len(new)}); "
              f"these are not the same build.")
        return 1

    try:
        sections, checksum_off, _ = parse_pe(new)
    except PEError as exc:
        print(f"error: cannot parse {new_path}: {exc}", file=sys.stderr)
        return 1

    diffs = [i for i in range(len(old)) if old[i] != new[i]]
    if not diffs:
        print("RESULT: byte-identical.")
        return 0

    buckets = {}
    for start, end in contiguous(diffs):
        buckets.setdefault(region_of(start, sections, checksum_off), []).append((start, end))

    print(f"{len(diffs)} differing byte(s) in {len(buckets)} region(s):\n")
    for region in sorted(buckets):
        rs = buckets[region]
        total = sum(e - s + 1 for s, e in rs)
        print(f"  {region:28s} {total:6d} byte(s) in {len(rs)} range(s)")
        if args.verbose:
            for s, e in rs[:20]:
                print(f"      0x{s:06X}-0x{e:06X}  "
                      f"{old[s:e+1][:24].hex()} -> {new[s:e+1][:24].hex()}")

    touched = set(buckets)
    code_touched = touched & CODE_SECTIONS
    unexpected = touched - METADATA_REGIONS

    print()
    if code_touched:
        print(f"RESULT: EXECUTABLE CODE DIFFERS in {sorted(code_touched)}. "
              f"These binaries were built from different source.")
        return 1

    if unexpected:
        print(f"RESULT: differences outside known metadata regions: "
              f"{sorted(unexpected)}. Investigate before trusting this build.")
        return 1 if args.strict else 0

    print("RESULT: no executable code differs. All differences are confined to")
    print("        version metadata (.rdata version strings, .rsrc version")
    print("        resource) and the PE header checksum that necessarily")
    print("        changes with them.")
    return 0


# Import names that would indicate capabilities this plugin has no business
# having: network access, spawning programs, or writing to another process.
SUSPICIOUS_PREFIXES = (
    "socket", "connect", "send", "recv", "WSA", "gethostby", "getaddrinfo",
    "InternetOpen", "InternetConnect", "InternetRead", "HttpOpen", "HttpSend",
    "URLDownload", "WinHttp", "CreateProcess", "ShellExecuteA", "WinExec",
    "CreateRemoteThread", "WriteProcessMemory", "VirtualAllocEx",
    "NtWriteVirtualMemory", "RegCreateKey", "RegSetValue", "SetWindowsHookEx",
)


def cmd_imports(args) -> int:
    path = Path(args.path)
    if not path.is_file():
        print(f"error: not a file: {path}", file=sys.stderr)
        return 1

    data = path.read_bytes()
    _, _, rva_map = parse_pe(data)
    imports = parse_imports(data, rva_map)

    if not imports:
        print("No import table found.")
        return 0

    print(f"{path}")
    print(f"sha256 {sha256(path)}\n")

    flagged = []
    total = 0
    for dll in sorted(imports):
        symbols = imports[dll]
        total += len(symbols)
        print(f"{dll}  ({len(symbols)} symbol(s))")
        for s in symbols:
            mark = ""
            if any(s.startswith(p) for p in SUSPICIOUS_PREFIXES):
                mark = "   <-- NETWORK/PROCESS/PERSISTENCE CAPABILITY"
                flagged.append(f"{dll}!{s}")
            print(f"    {s}{mark}")
        print()

    print(f"{len(imports)} module(s), {total} imported symbol(s).")
    if flagged:
        print("\nFLAGGED:")
        for f in flagged:
            print(f"  {f}")
        return 1

    print("\nNo flagged networking, process-creation, remote-write, or")
    print("persistence APIs appear in the static import table.")
    print("NOTE: static imports are evidence, not proof of every capability;")
    print("native code can resolve APIs dynamically. Review source and call sites too.")
    return 0


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(
        description="Verify Faster Loadin and Savin release binaries.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__.split("Examples")[-1],
    )
    sub = parser.add_subparsers(dest="command", required=True)

    m = sub.add_parser("manifest", help="hash + version of every DLL in a tree")
    m.add_argument("path", help="directory (searched recursively) or a single DLL")
    m.set_defaults(func=cmd_manifest)

    c = sub.add_parser("compare", help="section-level diff of two PE files")
    c.add_argument("old", help="baseline DLL (for example, the previous release)")
    c.add_argument("new", help="DLL to check (for example, the current release)")
    c.add_argument("-v", "--verbose", action="store_true",
                   help="print each differing byte range")
    c.add_argument("--strict", action="store_true",
                   help="fail on any difference outside .rsrc/.rdata/checksum")
    c.set_defaults(func=cmd_compare)

    i = sub.add_parser("imports", help="list every Windows API the DLL imports")
    i.add_argument("path", help="DLL to inspect")
    i.set_defaults(func=cmd_imports)

    args = parser.parse_args(argv)
    try:
        return args.func(args)
    except PEError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    except OSError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
