# Faster Loadin' 'n' Savin'

**Faster Loadin' 'n' Savin' is a maintenance fork of [Save and Load Accelerator for SKSE Cosaves](https://github.com/just-harry/save-load-accelerator-for-skse-cosaves), originally created by Harry Gillanders (`just-harry`).** The upstream code and this fork are distributed under the BSD Zero Clause License (0BSD). The fork source is available at [https://github.com/ShugokiFable/Faster-Loadin-n-Savin](https://github.com/ShugokiFable/Faster-Loadin-n-Savin).

The public name is different from the original mod. The runtime DLL and INI intentionally retain the technical filenames `Save&LoadAcceleratorForSKSECosaves.dll` and `Save&LoadAcceleratorForSKSECosaves.ini` because the compiled plugin expects those names.

## What it changes

This SKSE plugin accelerates **SKSE cosave** serialization and loading. It does not accelerate or rewrite Skyrim's main `.ess` save format.

The maintenance fork adds:

- sibling temporary-file writes followed by `MoveFileExA(..., MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH)` replacement;
- buffered, sequential, exact-length cosave loading;
- corrected committed-buffer sizing for padded writes;
- a Universal x86-64-v2 build as the installer default;
- an optional x86-64-v3 High-End build;
- clean, reproducible release packaging with hashes and manifests.

## Safety scope and limitations

Atomic cosave replacement means the previous cosave is not truncated before the replacement file has been fully written and closed. This **reduces the risk of a destroyed or truncated SKSE cosave when saving is interrupted**.

It is not a transaction spanning both Skyrim's `.ess` file and the SKSE cosave. It cannot guarantee that every third-party SKSE serialization callback produced logically complete data. The experimental parallel-saving mode remains disabled by default because third-party callbacks cannot be assumed thread-safe.

No save cleaning or conversion is required when installing, updating, or uninstalling this plugin.

## Installation

Install the archive with Mod Organizer 2, Vortex, or another FOMOD-capable manager.

1. Select the detected Skyrim runtime.
2. Keep **Universal (Recommended)** unless you deliberately want the optional High-End build.
3. Confirm that the installed DLL is at `Data\DLLPlugins\Save&LoadAcceleratorForSKSECosaves.dll`.

The High-End x86-64-v3 build requires an AVX2-class CPU, broadly AMD Zen 2 or newer or Intel Haswell or newer. It may provide little or no measurable improvement for a given load order.

## Compatibility

The plugin is standalone apart from SKSE and a compatible DLL preloader. It does not require NextGen Disk Cache. Parallel saving should remain disabled unless every participating SKSE plugin is known to be thread-safe during serialization.

## Verifying releases

`tools/verify-release-binaries.py` can produce DLL manifests, inspect static imports, and compare PE sections:

```text
python tools/verify-release-binaries.py manifest <extracted-release>
python tools/verify-release-binaries.py imports <installed-dll>
python tools/verify-release-binaries.py compare <old-dll> <new-dll> --strict
```

Static import inspection is evidence, not a proof of every capability a native binary could exercise. Version 1.5.1 is supported by the complete published source, section-level binary comparisons, release hashes, and the generated manifest. See [`VERIFYING-RELEASES.md`](VERIFYING-RELEASES.md).

## Release provenance

Version 1.5.1 contains **no save/load implementation changes from 1.4.0 or 1.5.0**. It hardens the installer, packaging, permissions guidance, credits, and verification language. The shipped 1.5.1 DLLs retain the same executable `.text` section as their corresponding 1.5.0 DLLs; only version metadata, the sanitized embedded PDB path, and the PE checksum differ.

## Building and packaging

Requirements:

- Windows PowerShell 5.1 or PowerShell 7+
- LDC (`ldc2`)
- Windows SDK resource compiler (`rc.exe`)
- Clang C++ or MSVC `cl.exe`
- `lld-link` or MSVC `link.exe`
- Python 3.8+ for release verification

Prepare a release with:

```powershell
./scripts/update-version-number.ps1 1.5.1.0
./package-release.ps1 -Version 1.5.1
```

`package.ps1` is retained as a compatibility wrapper and delegates to `package-release.ps1`; it no longer creates PDB-bearing legacy packages.

## License and credits

See [`LICENSE`](LICENSE) and [`CREDITS.md`](CREDITS.md). The 0BSD license permits use, copying, modification, and redistribution with or without fee. Nexus permissions should mirror those terms.


## Hitchhiker's Guide to the Codebase

This software has been written using D in the style of a better C—but the abominable C runtime is not used—and the D runtime also is not used, and the D standard-library is mostly avoided. \
Thus, a great deal of this repository is my own non-standard-library, found in `mod/slack_common`.

### Map
- [`mod/slack_common`](mod/slack_common): This module deals with functionality that's more-or-less generic.
	- [`mod/slack_common/algorithms.d`](mod/slack_common/algorithms.d): Vaguely algorithmic logic.
	- [`mod/slack_common/bindings.d`](mod/slack_common/bindings.d): Bindings for the compilation target: in this case, Windows.
	- [`mod/slack_common/byte_sizes.d`](mod/slack_common/byte_sizes.d): Because `64.MB` is clearer than `64 << 20`.
	- [`mod/slack_common/cpp.d`](mod/slack_common/cpp.d): Some bindings for Visual C++'s STL.
	- [`mod/slack_common/dynamic_linking.d`](mod/slack_common/dynamic_linking.d): Some convenience functions for dynamically linking with exports.
	- [`mod/slack_common/dynamically_linked.d`](mod/slack_common/dynamically_linked.d): A bit of a bodge to make dynamically-linked symbols available to `slack_common` without presupposing a storage method/layout for the pointers.
	- [`mod/slack_common/file_handling.d`](mod/slack_common/file_handling.d): Does what it says on the tin.
	- [`mod/slack_common/ini.d`](mod/slack_common/ini.d): Simple INI file parsing (lexing, really).
	- [`mod/slack_common/integers.d`](mod/slack_common/integers.d): Functions and whatnot for dealing with integer values.
	- [`mod/slack_common/large_low_overhead_buffer.d`](mod/slack_common/large_low_overhead_buffer.d): Buffers optimised for low-overhead writing into large and re-used regions of memory.
	- [`mod/slack_common/parsing.d`](mod/slack_common/parsing.d): Straightforward parsing and lexing routines.
	- [`mod/slack_common/patching.d`](mod/slack_common/patching.d): Utilities for examining, generating, and rewriting x86 machine code.
	- [`mod/slack_common/pe.d`](mod/slack_common/pe.d): Functionality for inspecting Portable Executable images.
	- [`mod/slack_common/peb_access.d`](mod/slack_common/peb_access.d): Support for peeking inside the process's Process Environment Block.
	- [`mod/slack_common/simd.d`](mod/slack_common/simd.d): The basics for x86 SIMD usage.
	- [`mod/slack_common/sorting.d`](mod/slack_common/sorting.d): Functions which can sort any array so long as its length is three.
	- [`mod/slack_common/text.d`](mod/slack_common/text.d): Simple text manipulation routines, including UTF-8<->UTF-16 conversion.
	- [`mod/slack_common/threading.d`](mod/slack_common/threading.d): Functions for controlling and synchronising threads.
	- [`mod/slack_common/tib_access.d`](mod/slack_common/tib_access.d): Support for reading and writing from and to a thread's Thread Information Block.
	- [`mod/slack_common/timing.d`](mod/slack_common/timing.d): Time matters.
	- [`mod/slack_common/user_interface.d`](mod/slack_common/user_interface.d): Frankly, this is just for popping up an error-message box when something invariably goes pear-shaped.
	- [`mod/slack_common/version.d`](mod/slack_common/version.d): A bunch of `enum bool` definitions so that we can use `static if` instead of `version`.
- [`mod/game`](mod/game): This module provides some basic infrastructure for introspecting which version/archetype of Skyrim SE we're targeting.
- [`mod/skse64`](mod/skse64): This module provides a minimal set of bindings for SKSE.
	- [`mod/skse64/hacks`](mod/skse64/hacks): This module isn't for bindings but instead for data and functions that assist in patching SKSE at runtime.
		- [`mod/skse64/hacks/versioning.d`](mod/skse64/hacks/versioning.d): Very simple: version-numbers and file-names for the latest version of SKSE for a given archetype of Skyrim SE.
		- [`mod/skse64/hacks/offsets.d`](mod/skse64/hacks/offsets.d): A table of offsets for places to patch SKSE at runtime.
- [`mod/slack_mod`](mod/slack_mod): This module implements the actual plugin proper.
	- [`mod/slack_mod/configuration.d`](mod/slack_mod/configuration.d): Defines the configurable state for the plugin.
	- [`mod/slack_mod/entrypoint.d`](mod/slack_mod/entrypoint.d): The entrypoint for the plugin's DLL, as well as any DLL exports, and the assert handler for debug builds.
	- [`mod/slack_mod/exception_wrapper.cpp`](mod/slack_mod/exception_wrapper.cpp): A small wrapper for calling a function and catching any exceptions it may throw.
	- [`mod/slack_mod/exception_wrapper.d`](mod/slack_mod/exception_wrapper.d): D bindings for the C++ exception wrapper.
	- [`mod/slack_mod/global.d`](mod/slack_mod/global.d): All the global state for the plugin, traceable from once place, and the vectored-exception-handler.
	- [`mod/slack_mod/limits.d`](mod/slack_mod/limits.d): Provides the definitions for any hardcoded limits for the plugin's functionality.
	- [`mod/slack_mod/Save&LoadAcceleratorForSKSECosaves.def`](mod/slack_mod/Save&LoadAcceleratorForSKSECosaves.def): Defines the exports of the plugin's DLL.
	- [`mod/slack_mod/Save&LoadAcceleratorForSKSECosaves.rc`](mod/slack_mod/Save&LoadAcceleratorForSKSECosaves.rc): Defines the product-version metadata for the plugin's DLL.
	- [`mod/slack_mod/save_load.d`](mod/slack_mod/save_load.d): The actual implementation of optimised saving and loading for SKSE cosave files.
	- [`mod/slack_mod/setup.d`](mod/slack_mod/setup.d): This file is responsible for installing the optimised saving/loading hooks at runtime, and generally setting up all the fiddly global state.
- [`mod/Save&LoadAcceleratorForSKSECosaves.ini`](mod/Save&LoadAcceleratorForSKSECosaves.ini): The default configuration file for the plugin.

