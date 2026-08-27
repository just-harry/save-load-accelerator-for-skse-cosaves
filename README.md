
# Save & Load Accelerator for SKSE Cosaves

This is a plugin for [SKSE64](https://skse.silverlock.org/) that aims to improve the performance of saving and loading SKSE cosave files.

## Building

### Requirements

- Windows PowerShell 5.1 or [PowerShell 7-and-later](https://learn.microsoft.com/powershell/scripting/install/installing-powershell).
- The [LDC D compiler](https://github.com/ldc-developers/ldc).
- The [Clang C++ compiler](https://releases.llvm.org/).
- A standard environment (e.g. the [MSVC Build Tools](https://learn.microsoft.com/cpp/build/building-on-the-command-line)) for targeting x86-64 Windows, specifically: having the Windows import libraries available via the library-path; having `rc` available via the `PATH`.
- (Optional) [`7za`](https://www.7-zip.org/download.html) being available via the `PATH`, for packaging the built plugins.

### Procedure

In an environment for targeting x86-64 Windows, run the `build.ps1` script found in the root of this repository.
The resulting DLLs will be available in the `build/release` directory.

If you have a code-signing certificate at hand, the `sign.ps1` script can be used to sign the built DLLs before they are packaged.

To package the built DLLs into archives suitable for installation, run the `package.ps1` script found in the root of this repository.
The resulting archives will be available in the `package/release` directory.

## Licence

Unless otherwise specified, everything in this repository is licensed under the terms of the [BSD Zero Clause License](https://spdx.org/licenses/0BSD.html).

## Acknowledgements

meh321 for Address Library, saving me from the fate of having to purchase the GOG version of Skyrim SE.
Alan Tse for VR Address Library, saving me from the fate of having to purchase Skyrim VR.

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
	- [`mod/slack_common/oops.d`](mod/slack_common/oops.d): Object-orientated programming, innit?
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
	- [`mod/game/offsets.d`](mod/game/offsets.d): Offsets for places in the game's code and data.
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
	- [`mod/slack_mod/Save&LoadAcceleratorForSKSECosaves.rc`](mod/slack_mod/Save&LoadAcceleratorForSKSECosaves.rc): Defines the product-version metadata for the plugin's DLL.
	- [`mod/slack_mod/Save&LoadAcceleratorForSKSECosaves-SKSEPreloader.def`](mod/slack_mod/Save&LoadAcceleratorForSKSECosaves-SKSEPreloader.def): Defines the exports of the plugin's DLL for versions targeting SKSE's preloader.
	- [`mod/slack_mod/Save&LoadAcceleratorForSKSECosaves-DLLPluginLoader.def`](mod/slack_mod/Save&LoadAcceleratorForSKSECosaves-DLLPluginLoader.def): Defines the exports of the plugin's DLL for versions targeting meh321's or Engine Fixes' preloader.
	- [`mod/slack_mod/save_load.d`](mod/slack_mod/save_load.d): The actual implementation of optimised saving and loading for SKSE cosave files.
	- [`mod/slack_mod/setup.d`](mod/slack_mod/setup.d): This file is responsible for installing the optimised saving/loading hooks at runtime, and generally setting up all the fiddly global state.
- [`mod/Save&LoadAcceleratorForSKSECosaves.ini`](mod/Save&LoadAcceleratorForSKSECosaves.ini): The default configuration file for the plugin.

