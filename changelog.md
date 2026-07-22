# Faster Loadin and Savin: Changelog

## Version 1.5.1 (2026-07-22)

Release-hardening update. The save/load implementation is unchanged from 1.4.0 and 1.5.0.

- Added a real FOMOD CPU-profile step. Universal x86-64-v2 remains recommended; selecting High-End conditionally overlays only the matching x86-64-v3 game-version DLL.
- Reworked `package-release.ps1` so its default version, package name, folder layout, and staged payload match the public release.
- Converted legacy `package.ps1` into a wrapper around the clean release packager, eliminating the old PDB-bearing package path.
- Sanitized user-specific absolute PDB paths embedded in the DLL CodeView metadata and configured future builds to embed only the PDB filename.
- Added strict release gates for all eight game targets, both CPU profiles, FOMOD flags and conditional installs, version consistency, forbidden artifacts, and generated DLL manifests.
- Reworded atomic replacement claims: it reduces the risk of truncated or destroyed SKSE cosaves but is not an atomic transaction with the main `.ess` file.
- Reworded import-table claims to acknowledge that static imports are evidence rather than proof of every possible native-binary capability.
- Added explicit 0BSD credits, redistribution guidance, and a Nexus permissions checklist.
- Corrected all maintenance-fork links to `https://github.com/ShugokiFable/Faster-Loadin-n-Savin`.
- Restamped all sixteen runtime DLLs to 1.5.1.0. Their executable `.text` sections remain byte-identical to the corresponding 1.5.0 DLLs; user-specific absolute PDB paths embedded by the linker were also reduced to the PDB filename.

---

## Version 1.5.0 (2026-07-21)

The public rename and release-hardening update:
- The distribution is now presented as **Faster Loadin and Savin**, as requested by the original author.
- FOMOD metadata, documentation, package naming, and version resources now report version 1.5.0.
- Fixed FOMOD XML compatibility by restoring the upstream-proven UTF-8-without-BOM, double-quoted XML declaration, and Windows CRLF byte format. This prevents strict or buggy FOMOD parsers from rejecting the script at line 1, position 39.
- The Universal x86-64-v2 DLL remains the safe default; AVX2-class x86-64-v3 builds are kept under the optional High-End folder.
- The installable archive contains only runtime files and documentation, with source trees, build artifacts, symbols, scripts, and repository metadata removed.
- The stale original Nexus Mods page identity was removed from the FOMOD metadata.
- Internal DLL and INI filenames remain unchanged because the compiled plugin expects those exact technical names.
- No cosave format change was introduced, and saves remain compatible with the original plugin and SKSE.

---

## Version 1.4.0 (2026-07-18)

The fourteenth release of this plugin, and the first from the maintenance fork at [ShugokiFable/Faster-Loadin-n-Savin](https://github.com/ShugokiFable/Faster-Loadin-n-Savin). The changes are as follows:
- **Crash-safe cosave saving.** The cosave is now written to a sibling `.tmp` file first, and the previous cosave is only replaced—atomically, with write-through—after the new cosave has been written in full. Previously, saving began by truncating the existing cosave, so a crash, forced exit, or plugin error mid-save destroyed the last good cosave. Applies to both serial and experimental parallel saving.
- **Faster, simpler cosave loading.** Loading now uses buffered, sequential reads of exactly the cosave's length, letting the Windows page cache and read-ahead do their job. The read-only handle no longer requests write-through (which was meaningless there) nor unbuffered I/O (which forced padded, over-long reads).
- **A latent buffer-commit inconsistency on the save and load paths has been made structurally impossible**: the padded write now always fits in committed memory, and the buffer's growth size is the size actually used.
- **Compatibility with [NextGen Disk Cache](https://github.com/ShugokiFable/NextGen-Disk-Cache).** Together with its 1.2.1 release—which leaves the flags of `.skse`/`.cosave`/`.ess`/`.bak` files untouched—S.L.A.C.K.'s deliberate unbuffered, write-through cosave I/O is no longer rewritten by file-cache hooks. (With any other configuration the plugin remains correct, merely less direct.)
- **Two runtime builds are now provided.** Universal x86-64-v2 (the FOMOD default) is used for broad CPU compatibility; the optional High-End build targets the x86-64-v3 microarchitecture level (AVX2-class: AMD Zen 2 and later—including X3D parts—and Intel Haswell and later) with full optimisation; a Universal x86-64-v2 build for older CPUs is included in the archive for manual installation. Modern hardware—large X3D cache, DDR5, NVMe with onboard DRAM—benefits the existing parsing, copying, and callback workload without any artificial "modes".
- **Release engineering.** The build script now accepts MSVC's `cl.exe` and `link.exe` as substitutes for clang++ and lld-link, checks every tool's exit code, and supports side-by-side CPU-profile build directories. Public archives no longer contain PDB files; symbols remain available as a separate developer artifact.
- Parallel saving remains disabled by default: it runs third-party SKSE plugin callbacks concurrently, and those callbacks cannot be assumed thread-safe. No amount of modern hardware changes that.

---

## Version 1.3.2 (2026-01-12)

The thirteenth release of this plugin, the changes are as follows:
- Spurious error-message dialogs no longer occur when the `ReloadScript` console command is used.

---

The song recommendation for this release is ["夜間飛行" by 発熱巫女〜ず, featuring 舞花](https://www.youtube.com/watch?v=12z-7u9Ua8c).

## Version 1.3.1 (2025-11-25)

The twelfth release of this plugin, the changes are as follows:
- The version detection for a workaround for a bug in STB Widgets has been removed, and the workaround is now applied unconditionally for improved reliability.
- The game should no longer crash when SKSE plugins call SKSE's saving routines when the game is not being saved, nor when SKSE's loading routines are called when a save is not being loaded.

---

The song recommendation for this release is ["Passacaglia - Carmina Luminum Et Siderum" by Forgotten Melody](https://www.youtube.com/watch?v=Px6COpFeZXA). \
(This release was delayed by an hour-and-a-half as I had to listen to the whole album, and then relisten to a few songs, to decide which song to recommend.)

## Version 1.3.0 (2025-11-15)

The eleventh release of this plugin, the changes are as follows:
- A new error-friendly mode has been added: when enabled, S.L.A.C.K. will catch and log exceptions thrown by SKSE plugins' cosave handlers, what like SKSE's original code does. \
This should help to prevent the game from crashing when saving or loading the game, in the presence of SKSE plugins with bugs. \
This new mode is enabled by default.
- S.L.A.C.K. no longer logs to the console when it works around a bug in STB Widgets, to avoid logspam when saving the game.
- A potential deleterious effect on start-up performance, when the `WorkAroundThirdPartyBugs` setting is enabled, has been reduced.

---

The song recommendation for this release is [ドロドロ's cover of "スターダストメドレー" by きさら](https://www.youtube.com/watch?v=MqDulIt9Pjo).

## Version 1.2.0 (2025-11-13)

The tenth release of this plugin, the changes are as follows:
- A profiling mode has been added: when enabled, the time taken for each SKSE plugin to save and-or load will be logged to the in-game console.
- An oversight, introduced by version 1.0.2, which caused the plugin's DLL to be roughly 9 KB larger than necessary was corrected.
- The memory-usage of each thread used for parallel-saving has been reduced slightly.
- When logging errors related to a SKSE plugin's usage of the cosave saving/loading API, the identifier of the offending plugin is now also logged.
- The alignment of timings logged to the console have been changed to fit what they were intended to be.

---

The song recommendation for this release is [isui's cover of "Smoky quartz" by Komiya Cofey](https://www.youtube.com/watch?v=_tYbmNb4VVQ).

## Version 1.1.0 (2025-11-11)

Something about that date rings a bell, doesn't it?

The ninth release of this plugin, the changes are as follows:
- The plugin is now packaged as a FOMOD, with automatic game-version detection. (Individual zip-archives are still available on GitHub.)
- A fix for blank error-message dialogs on version 1.5.97 of Skyrim SE.
- A more robust stratagem for allocating memory closely to the SKSE DLL.
- Version detection for ten outdated versions of SKSE has been implemented.
- The requirement for Windows 10, version 1803 has been dropped—the plugin can run on Window Vista now. (Parallel-saving still requires Windows 8 or newer.)
- A very small oversight that could cause the save-timing logging to not log was corrected.
- Version 2.2.5 of SKSE is now supported, for users of version 1.6.1130 of Skyrim SE.
---

The song recommendation for this release is ["Present" by TOMOO](https://www.youtube.com/watch?v=EvpsZde4QSI).

## Version 1.0.7 (2025-11-09)

The eighth release of this plugin, the changes are as follows:
- File-paths containing non-ASCII characters no longer cause saves to fail to load nor cause save creation to fail. \
(Ironically, my efforts to fully support Unicode were what caused this issue, as the rest of the game's code relies on the restricted code-page of the system/user's locale.)
---

The song recommendation for this release is ["帰天" by 塚越雄一朗, featuring 皇黄リリエ](https://www.youtube.com/watch?v=ctO6lUgrBGU).

## Version 1.0.6 (2025-11-09)

The seventh release of this plugin, the changes are as follows:
- An issue which could cause save files to fail to open may have been fixed.
---

The song recommendation for this release is ["Rocking Son Of Dschinghis Khan" by, uhh, Dschinghis Khan](https://www.youtube.com/watch?v=pqWc5FABmDY). \
I'm slightly ashamed to admit that this song is in my personal top-ten going by listen-count.

## Version 1.0.5 (2025-11-09)

The sixth release of this plugin, the changes are as follows:
- Support for version 2.1.5 of SKSE has been fixed, for users of version 1.6.353 of Skyrim SE.
---

The song recommendation for this release is ["雨は毛布のように" by KIRINJI](https://www.youtube.com/watch?v=HWyyxJoZHyY).

## Version 1.0.4 (2025-11-09)

The fifth release of this plugin, the changes are as follows:
- A crash that could occur when launching the game may have been fixed.
---

The song recommendation for this release is ["Declaration of Complete Resignation" by Nanawo Akari](https://www.youtube.com/watch?v=Vi_asBY5UX8) \
Don't read too much into that choice ;)

## Version 1.0.3 (2025-11-09)

The fourth release of this plugin, the changes are as follows:
- Version 2.1.5 of SKSE is now supported, for users of version 1.6.353 of Skyrim SE.
- A workaround for a bug in "STB Widgets" versions 1.6-to-1.9 has been added. (The bug is that it supplies an invalid memory-address to SKSE's saving routines).
- The handling of default values for booleans in the INI configuration file has been improved.
---

The song recommendation for this release is [this live performance of Kotringo's cover of 恋とマシンガン](https://www.youtube.com/watch?v=mygM8L3fpa0).

## Version 1.0.2 (2025-11-09)

The third release of this plugin, the changes are as follows:
- Support for version 2.0.20 of SKSE has been fixed, for users of version 1.5.97 of Skyrim SE.
- The version of the plugin is now displayed in the title of error-message dialogs.
---

The song recommendation for this release is ["白雪 Evil Snow" by Hatsuki Yura](https://www.youtube.com/watch?v=V687A50cPQ8).

## Version 1.0.1 (2025-11-09)

The second release of this plugin, the changes are as follows:
- Versions 2.2.3 and 2.2.3 (GOG) of SKSE are now supported, for users of version 1.6.640/1.6.659 of Skyrim SE.
- A slightly different method of finding the SKSE DLL is now used.
---

The song recommendation for this release is ["Just Me and My Dog" by Club des Belugas, featuring vocals by Anna Luca](https://www.youtube.com/watch?v=agSoHWRpvxI).

## Version 1.0.0 (2025-11-08)

The first release of this plugin, the features provided are as follows:
- Acceleration of SKSE cosave saving and loading.
- Console logging of the time taken to save or load a SKSE cosave.
- Experimental support for saving the data of multiple SKSE plugins to a SKSE cosave in parallel.
- Support for the AE, SE, VR, and GOG versions of SKSE.

---

The song recommendation for this release is ["10周年目突入記念公演"大拍乱会"メドレー" by CHARAN-PO-RANTAN](https://www.youtube.com/watch?v=fuIDO1_3oSE).
