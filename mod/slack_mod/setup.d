
/+ SPDX-LICENSE-IDENTIFIER: 0BSD +/

module slack_mod.setup;

import ldc.attributes : optStrategy;
import ldc.llvmasm : __ir_pure;

import game;

import slack_common.algorithms;
import slack_common.bindings;
import slack_common.byte_sizes;
import slack_common.cpp;
import slack_common.dynamic_linking;
import slack_common.file_handling;
import slack_common.ini;
import slack_common.integers;
import slack_common.large_low_overhead_buffer;
import slack_common.memory;
import slack_common.oops;
import slack_common.patching;
import slack_common.pe;
import slack_common.peb_access;
import slack_common.sorting;
import slack_common.text;
import slack_common.threading;
import slack_common.tib_access;
import slack_common.user_interface;
import slack_mod.configuration;
import slack_mod.global;
import slack_mod.limits;
import slack_mod.save_load;

import skse64.dll_plugins;
import skse64.file_handling;
import skse64.serialisation;
import skse64.hacks.versioning;
import skse64.hacks.offsets;


@optStrategy("minsize")
pragma(inline, false)
bool setUpEverything (scope ref wchar[512] stringBuffer) nothrow @nogc
{
	alias Config = ConfigurationLongLived.Flags;

	RtlQueryPerformanceFrequency(cast(LARGE_INTEGER*) &global.performanceFrequency);

	global.performanceFrequencyMillisecondMultiplier = 1000.0 / cast(double) global.performanceFrequency;

	global.linked.linkAll;

	/+ With the release of version 2.2.7, SKSE acquired a preloader,
	   and this preloader preloads plugins before Engine Fixes' preloader preloads plugins.
	   Thus, S.L.A.C.K. was migrated over to using SKSE's preloader:
	   this required S.L.A.C.K.'s DLL to be moved from `Data/DLLPlugins`
	   to `Data/SKSE/Plugins`; unfortunately, this means older versions of S.L.A.C.K.
	   can be present at the same time as newer versions.

	   Then, with the release of version 1.4.0 of S.L.A.C.K.,
	   all targets were migrated over to using SKSE's loader
	   for improved reliability in practice.

	   To avoid this state of things confusing users, we detect the presence
	   of `Data\DLLPlugins\Save&LoadAcceleratorForSKSECosaves.dll` accordingly.

	   However, our woes don't end there!
	   There was at one point a short-lived, hostile fork of S.L.A.C.K..
	   (hostile, as in: the fork will be deleted IFF upstream mainlines the fork's changes.)
	   That fork used the exact same DLL name and error-message-dialog title as S.L.A.C.K.,
	   and so to an end-user it appears no different to S.L.A.C.K. proper.
	   But the fork did end up using a different name for the mod itself,
	   so it's not outside the realm of possibility (read: this has already happened)
	   for a user to forget that they have the fork installed and enabled.

	   The fork was released with two different version-numbers: v1.4.0; and v1.5.0,
	   during a period where S.L.A.C.K. held steadfast on v1.3.2.

	   So, to detect the fork we inspect the version-info of the DLL file.
	   If the file-version is 1.4.0.0-or-greater, and the legal-copyright field
	   is 71-code-units long (including the null-terminator),
	   and the copyright year is 2025 followed by a space, then the DLL is of the fork.

	   Starting with v1.4.0 of S.L.A.C.K. proper, the copyright year is now a range
	   allowing for the fork and the original to be distinguished via version-info alone.

	   https://www.youtube.com/watch?v=FL0PvTmo5CE&t=7s +/

	uint exePathLength = void;

	if ((exePathLength = GetModuleFileNameW(null, stringBuffer.ptr, MAX_PATH)) != 0)
	{
		wchar* end = stringBuffer.ptr + exePathLength;

		for (; end > stringBuffer.ptr;)
		{
			--end;
			if (*end == '\\') break;
		}

		size_t spaceLeft = MAX_PATH - (end - stringBuffer.ptr);

		if (spaceLeft >= 55)
		{
			blit(end + 1, `Data\DLLPlugins\Save&LoadAcceleratorForSKSECosaves.dll`w.ptr, 55);

			uint attributes = GetFileAttributesW(stringBuffer.ptr);

			if ((attributes != INVALID_FILE_ATTRIBUTES) & ((attributes & FILE_ATTRIBUTE_DIRECTORY) == 0))
			{
				enum string usualMessage = (
					  "An older version of S.L.A.C.K. is present in the \"Data\\DLLPlugins\" folder, this will cause a version-mismatch error.\r\n\r\n"
					~ "You should remove or disable the older version of S.L.A.C.K..\r\n\r\n"
					~ "If you use Mod Organizer 2, reinstall S.L.A.C.K. and use the \"Replace\" option when prompted to."
				);

				immutable(char)* message = usualMessage;

				HMODULE versionDLL = LoadLibraryW("version.dll");

				/+ This whole nest of if-statements is gross, but whatever. +/
				if (versionDLL != null)
				{
					scope(exit) FreeLibrary(versionDLL);

					alias GetFileVersionInfoW = extern(Windows) BOOL function (scope const(wchar)* lptstrFilename, uint dwHandle, uint dwLen, scope void* lpData) nothrow @nogc;
					alias VerQueryValueW = extern(Windows) BOOL function (scope const(void)* pBlock, scope const(wchar)* lpSubBlock, scope void** lplpBuffer, scope uint* puLen) nothrow @nogc;
					auto getFileVersionInfoW = mixin(dynamicallyLink!(q{versionDLL}, q{GetFileVersionInfoW}));
					auto verQueryValueW = mixin(dynamicallyLink!(q{versionDLL}, q{VerQueryValueW}));

					if ((getFileVersionInfoW != null) & (verQueryValueW != null))
					{
						ubyte[2048] versionInfo = void;
						uint ignored = void;

						if (getFileVersionInfoW(stringBuffer.ptr, ignored, versionInfo.length, versionInfo.ptr))
						{
							void* value = void;
							uint valueSize = void;

							if (verQueryValueW(versionInfo.ptr, `\`, &value, &valueSize))
							{
								if ((cast(const(VS_FIXEDFILEINFO)*) value).dwFileVersionMS >= 0x0001_0004)
								{
									if (verQueryValueW(versionInfo.ptr, `\StringFileInfo\080904b0\LegalCopyright`, &value, &valueSize))
									{
										if (valueSize == 71)
										{
											const(wchar)* c = cast(const(wchar)*) value;

											if ((c[14] == '2') & (c[15] == '0') & (c[16] == '2') & (c[17] == '5'))
											{
												if (c[18] == ' ')
												{
													enum string ughMessage = (
														  "An unofficial fork of S.L.A.C.K. is present in the \"Data\\DLLPlugins\" folder, this will cause a version-mismatch error.\r\n\r\n"
														~ "This fork has gone by the names \"Faster Loadin' 'n' Savin'\", and \"Save and Load Accelerator for SKSE Cosaves - S.L.A.C.K. (Continued)\".\r\n\r\n"
														~ "You should disable the fork in your mod manager."
													);

													message = ughMessage;
												}
											}
										}
									}
								}
							}
						}
					}
				}

				reportErrorToUser(message);
			}
		}
	}

	initialiseClassInstance(global.saveLoad.cosaveLoadingErrorNotificationDisplayer);

	uint error = void;
	const(wchar)[] errorMessage = void;
	const(ubyte)[] ini = void;
	const(wchar)* skseDLLName = void;
	const(char)* skseDLLNameUTF8 = void;
	ushort skseDLLNameLength = void;
	ushort skseDLLNameLengthUTF8 = void;

	global.configuration.setToDefault;

	ConfigurationTransient transientConfiguration = void;
	transientConfiguration.setToDefault;

	const(wchar)* endOfINIPath = findConfigurationFilePath(stringBuffer, global.dllModule);

	if (endOfINIPath == null)
	{
		reportErrorToUser(
			stringBuffer,
			"The path of the \"!!!!!!!##$Save&LoadAcceleratorForSKSECosaves.dll\" file could not be found.\r\nAnd thus nor can the INI file be found.",
			hresultFromLastError(getLastError)
		);
	noINIFile:
		ini = null;
		skseDLLName = defaultSKSE64DLLNameUTF16.ptr;
		skseDLLNameLength = defaultSKSE64DLLNameUTF16.length;
		skseDLLNameUTF8 = defaultSKSE64DLLNameUTF8.ptr;
		skseDLLNameLengthUTF8 = defaultSKSE64DLLNameUTF8.length;
	}
	else
	{
		HANDLE iniFile = CreateFileW(
			stringBuffer.ptr,
			GENERIC_READ,
			FILE_SHARE_READ,
			null,
			OPEN_EXISTING,
			FILE_ATTRIBUTE_NORMAL | FILE_FLAG_SEQUENTIAL_SCAN,
			null
		);

		if (iniFile == INVALID_HANDLE_VALUE)
		{
			if ((error = getLastError) != ERROR_FILE_NOT_FOUND)
			{
				reportErrorToUser(
					stringBuffer,
					"The \"!!!!!!!##$Save&LoadAcceleratorForSKSECosaves.ini\" file could not be opened.",
					hresultFromLastError(error)
				);
			}

			goto noINIFile;
		}
		else
		{
			error = mapFileForReading(iniFile, &ini);

			NtClose(iniFile);

			if (error)
			{
				reportErrorToUser(
					stringBuffer,
					"The \"!!!!!!!##$Save&LoadAcceleratorForSKSECosaves.ini\" file could not be mapped for reading.",
					error
				);

				goto noINIFile;
			}

			parseINIConfiguration(cast(const(char)[]) ini, &global.configuration, &transientConfiguration);
		setSoundEffectNames:
			if (!global.configuration.setSoundEffectNames(transientConfiguration.soundEffects))
			{
				reportErrorToUser(
					"The sound effect names in the [Notifications] section of the \"!!!!!!!##$Save&LoadAcceleratorForSKSECosaves.ini\" file have a total length that is too long."
				);
				transientConfiguration.setSoundEffectsToDefault;
				goto setSoundEffectNames;
			}

			if (transientConfiguration.skseDLLName.length != 0)
			{
				const(char)* utf8 = transientConfiguration.skseDLLName.ptr;
				const(char)* utf8End = transientConfiguration.skseDLLName.endOf;
				wchar* utf16 = stringBuffer.ptr;
				wchar* utf16End = stringBuffer.endOf - 1;
				utf8ToUTF16(&utf8, utf8End, &utf16, utf16End);

				if (utf8 < utf8End)
				{
					reportErrorToUser(
						"The \"SKSEDLLName\" value provided in \"!!!!!!!##$Save&LoadAcceleratorForSKSECosaves.ini\" is too long."
					);

					goto defaultSKSEDLLName;
				}

				*utf16 = '\0';

				skseDLLName = stringBuffer.ptr;
				skseDLLNameLength = cast(ushort) (cast(size_t) (utf16 - skseDLLName));
				skseDLLNameUTF8 = transientConfiguration.skseDLLName.ptr;
				skseDLLNameLengthUTF8 = cast(ushort) (utf8 - skseDLLNameUTF8);
			}
			else
			{
			defaultSKSEDLLName:
				skseDLLName = defaultSKSE64DLLNameUTF16.ptr;
				skseDLLNameLength = defaultSKSE64DLLNameUTF16.length;
				skseDLLNameUTF8 = defaultSKSE64DLLNameUTF8.ptr;
				skseDLLNameLengthUTF8 = defaultSKSE64DLLNameUTF8.length;
			}
		}
	}

	scope(exit)
	{
		if (ini != null)
		{
			unmapFile(ini.ptr);
		}
	}

	skseDLLNameLength = cast(ushort) lesserOf(skseDLLNameLength, global.configuration.skseDLLNameBuffer.length - 1);
	skseDLLNameLengthUTF8 = cast(ushort) lesserOf(skseDLLNameLengthUTF8, global.configuration.skseDLLNameBufferUTF8.length - 1);

	blit(global.configuration.skseDLLNameBuffer.ptr, skseDLLName, skseDLLNameLength);
	global.configuration.skseDLLNameBuffer[skseDLLNameLength] = '\0';
	global.configuration.skseDLLName = global.configuration.skseDLLNameBuffer[0 .. skseDLLNameLength];

	blit(global.configuration.skseDLLNameBufferUTF8.ptr, skseDLLNameUTF8, skseDLLNameLengthUTF8);
	global.configuration.skseDLLNameBufferUTF8[skseDLLNameLengthUTF8] = '\0';
	global.configuration.skseDLLNameUTF8 = global.configuration.skseDLLNameBufferUTF8[0 .. skseDLLNameLengthUTF8];

	if (global.configuration.skseHooksAreRequired)
	{
		ubyte* skseDLL = void;

		if ((skseDLL = cast(ubyte*) GetModuleHandleW(skseDLLName)) == null)
		{
			enum wstring missingDLLMessage = (
				  "The SKSE64 DLL could not be found.\r\n"
				~ "This usually indicates that SKSE's loader was not used to launch to game.\r\n\r\n"
				~ "If you use the Vortex mod manager, please try disabling and then re-enabling \"Skyrim Script Extender 64\" as the default-launcher/primary-tool in the \"Tools\" section/page.\r\n\r\n"
				~ "Otherwise, you may need to set, or change, the value of the \"SKSEDLLName\" setting in the \"!!!!!!!##$Save&LoadAcceleratorForSKSECosaves.ini\" file.\r\n"
			);

			reportErrorToUser(stringBuffer, missingDLLMessage, hresultFromLastError(getLastError));

			return false;
		}

		return setUpEverythingWithSKSEDLL(stringBuffer, skseDLL);
	}

	return true;
}


@optStrategy("minsize")
bool setUpEverythingWithSKSEDLL (scope ref wchar[512] stringBuffer, scope ubyte* skseDLL) nothrow @nogc
{
	alias Config = ConfigurationLongLived.Flags;

	assert(global.configuration.skseHooksAreRequired);

	global.addressOf.skseDLL = skseDLL;

	uint error = void;
	const(wchar)[] errorMessage = void;

	PESections sections = void;

	if (findSectionsOfPE64(skseDLL, &sections) != 0)
	{
		reportErrorToUser("Some sections expected to be found in the SKSE64 DLL are missing.");
		return false;
	}

	global.addressOf.globalSKSE64Provider = cast(SKSE64Provider*) (sections.rdata.ptr + skse64Offsets.globalSKSE64Provider);

	uint skse64Version = global.addressOf.globalSKSE64Provider.skse64Version;

	if (skse64Version != expectedSKSE64Version)
	{
		showComprehensiveSKSEVersionMismatchMessage(stringBuffer, skse64Version, sections.rdata.ptr);
		return false;
	}

	void[] skseAdjacentMemorySlice = void;

	if ((error = allocateImageAdjacentMemory(&skseAdjacentMemorySlice, sections)) == 0)
	{
		goto allocatedSKSEAdjacentMemory;
	}

	errorMessage = "Memory could not be allocated sufficiently close to the SKSE64 DLL.";
reportErrorOnFailure:
	reportErrorToUser(stringBuffer, errorMessage, error);
	return false;
allocatedSKSEAdjacentMemory:
	size_t size = skseAdjacentMemorySlice.length;
	void* skseAdjacentMemory = skseAdjacentMemorySlice.ptr;

	debug
	{
		wchar* s = stringBuffer.ptr;
		blit(s, "SKSE DLL: 0x"w.ptr, 12); s += 12;
		(cast(size_t) skseDLL).asHexInto(s[0 .. 16]); s += 16;
		blit(s, "\r\n..Memory: 0x"w.ptr, 14); s += 14;
		(cast(size_t) skseAdjacentMemory).asHexInto(s[0 .. 16]); s += 16;
		*s++ = '\0';
		showMessageBox(stringBuffer.ptr, "SKSE Adjacent Memory");
	}

	/+ To increase the likelihood of other mods patching SKSE being able
	   to allocate within a 32-bit range of SKSE, we specifically avoid allocating
	   within that range from hereon. +/

	const(void)* beforeSKSEBase = cast(const(void)*) allocationGranularity;
	const(void)* beforeSKSETail = cast(const(void)*) skseDLL - 8.GB;
	const(void)* afterSKSEBase = cast(const(void)*) skseDLL + 8.GB;
	const(void)* afterSKSETail = cast(const(void)*) size_t.max - allocationGranularity + 1;

	if ((error = makeLargeAndLowOverheadSequentialBuffer(&global.saveLoad.cosaveFileBuffer, maximumCosaveFileSize, 1.MB, afterSKSEBase, afterSKSETail)) != 0)
	{
		if ((error = makeLargeAndLowOverheadSequentialBuffer(&global.saveLoad.cosaveFileBuffer, maximumCosaveFileSize, 1.MB, beforeSKSEBase, beforeSKSETail)) != 0)
		{
			errorMessage = "Memory could not be allocated for the cosave file buffer.";
		errorWithSKSEAdjacentMemory:
			size = 0;
			NtFreeVirtualMemory(thisProcess, &skseAdjacentMemory, &size, MEM_RELEASE);
			goto reportErrorOnFailure;
		}
	}

	const(ubyte)* cosaveSaveFunction = void;
	const(ubyte)* cosaveLoadFunction = void;

	/+ "`goto` skips declaration of variable".
	   Why must every edge of D be razor sharp? +/
	ubyte parallelThreadCount = void;
	const(void)* stackBase = void;
	const(void)* stackLimit = void;
	size_t stackReservation = void;
	HANDLE threadHandle = void;
	size_t threadIndex = void;

	if (global.configuration.parallelismEnabled)
	{
		parallelThreadCount = global.configuration.adjustThreadCounts;

		global.saveLoad.parallel.threadCount = parallelThreadCount;

		if ((error = makeLargeAndLowOverheadPartitionedBuffer(&global.saveLoad.parallel.cosaveBuffer, maximumCosaveFileSize.integralLog2, parallelThreadCount, afterSKSEBase, afterSKSETail)) != 0)
		{
			if ((error = makeLargeAndLowOverheadPartitionedBuffer(&global.saveLoad.parallel.cosaveBuffer, maximumCosaveFileSize.integralLog2, parallelThreadCount, beforeSKSEBase, beforeSKSETail)) != 0)
			{
				errorMessage = "Memory could not be allocated for the parallel cosave buffer.";
			errorWithCosaveFileBuffer:
				global.saveLoad.cosaveFileBuffer.free;
				goto errorWithSKSEAdjacentMemory;
			}
		}

		stackBase = readFromTIB!(const(void)*, int(NT_TIB.StackBase.offsetof));
		stackLimit = readFromTIB!(const(void)*, int(NT_TIB.StackLimit.offsetof));

		/+ We'll reserve the same amount of stack space as the main thread, to ensure compatibility. +/
		stackReservation = stackBase - stackLimit;

		for (threadIndex = 0; threadIndex < parallelThreadCount; ++threadIndex)
		{
			error = makeThread(
				&threadHandle,
				&parallelSaveLoadThreadProcedureEntry!(),
				cast(void*) threadIndex,
				0,
				512.KB,
				greaterOf(stackReservation, 1.MB)
			);

			if (error)
			{
				errorMessage = "A thread could not be created for parallel cosave handling.";
			errorWithParallelCosaveThreads:
				while (threadIndex != 0)
				{
					--threadIndex;
					threadHandle = global.saveLoad.parallel.threadHandles[threadIndex];
					NtClose(threadHandle);
				}

				goto errorWithCosaveFileBuffer;
			}

			global.saveLoad.parallel.threadHandles[threadIndex] = threadHandle;
		}

		cosaveSaveFunction = cast(const(ubyte)*) (
			  (global.configuration.flags & Config.enableParallelSaving)
			? &saveCosaveParallel
			: &saveCosaveSerial
		);

		cosaveLoadFunction = cast(const(ubyte)*) &loadCosaveSerial;
	}
	else
	{
		cosaveSaveFunction = cast(const(ubyte)*) &saveCosaveSerial;
		cosaveLoadFunction = cast(const(ubyte)*) &loadCosaveSerial;
	}

	void* exceptionHandler = RtlAddVectoredExceptionHandler(1, &vectoredExceptionHandler!());

	if (exceptionHandler == null)
	{
		errorMessage = "The vectored-exception-handler could not be registered.";
	errorWithVectoredExceptionHandler:
		RtlRemoveVectoredExceptionHandler(exceptionHandler);

		if (global.configuration.parallelismEnabled)
		{
			goto errorWithParallelCosaveThreads;
		}
		else
		{
			goto errorWithSKSEAdjacentMemory;
		}
	}

	global.anyPluginCosaveHandlerThrewAnException = false;
	global.recoverableErrorsOccurred = false;
	global.unrecoverableErrorsOccurred = false;

	allowPluginsToSaveWhenSKSEIsNotSaving;
	allowPluginsToLoadWhenSKSEIsNotLoading;

	global.addressOf.skseCosaveSavePath = cast(std_string*) (sections.data.ptr + skse64Offsets.cosaveSavePath);
	global.addressOf.loadedSKSEPlugins = cast(std_vector!DLLPlugin*) (sections.data.ptr + skse64Offsets.loadedPlugins);

	static if (!observingPluginFileNameViaCall)
	{
		static if (expectedSKSE64Version >= 0x02_02_007_0)
		{
			global.addressOf.indexOfSKSEPluginBeingLoaded = cast(DLLPluginIndex*) (sections.data.ptr + skse64Offsets.pluginBeingLoadedIndex);
		}
		else
		{
			global.addressOf.sksePluginBeingLoaded = cast(DLLPlugin**) (sections.data.ptr + skse64Offsets.pluginBeingLoaded);
		}
	}

	global.addressOf.cosaveAwarePlugins = cast(std_vector!SerialisationStateForPlugin*) (sections.data.ptr + skse64Offsets.cosaveAwarePlugins);
	global.addressOf.skseLogFileStdioHandle = cast(void**) (sections.data.ptr + skse64Offsets.logFileStdioHandle);
	global.addressOf.supplySKSEProviderLEA = sections.text.ptr + skse64Offsets.supplyProviderLEA;
	global.addressOf.supplySKSESaveCallbackLEA = sections.text.ptr + skse64Offsets.supplySaveCallbackLEA;
	global.addressOf.supplySKSELoadCallbackLEA = sections.text.ptr + skse64Offsets.supplyLoadCallbackLEA;
	static if (targetedGameArchetype == GameArchetype.vr) global.addressOf.supplySKSELoadCallbackLEA1 = sections.text.ptr + skse64Offsets.supplyLoadCallbackLEA1;
	global.addressOf.createSKSECosave = sections.text.ptr + skse64Offsets.createCosave;
	global.addressOf.restoreSKSECosave = sections.text.ptr + skse64Offsets.restoreCosave;
	global.addressOf.createSKSECosaveCall = sections.text.ptr + skse64Offsets.createCosaveCall;
	global.addressOf.restoreSKSECosaveCall = sections.text.ptr + skse64Offsets.restoreCosaveCall;
	global.addressOf.skseConsolePrint = cast(typeof(global.addressOf.skseConsolePrint)) (sections.text.ptr + skse64Offsets.consolePrint);
	global.addressOf.skseFFlush = cast(typeof(global.addressOf.skseFFlush)) (sections.text.ptr + skse64Offsets.fflush);
	global.addressOf.emitSaveMessageCall = sections.text.ptr + skse64Offsets.emitSaveMessageCall;
	global.addressOf.emitPreLoadMessageCall = sections.text.ptr + skse64Offsets.emitPreLoadMessageCall;
	global.addressOf.emitProLoadMessageCall = sections.text.ptr + skse64Offsets.emitProLoadMessageCall;

	static if (observingPluginFileNameViaCall)
	{
		global.addressOf.sksePluginFilePathCall = sections.text.ptr + skse64Offsets.pluginFilePathCall;
	}

	ubyte* code = cast(ubyte*) skseAdjacentMemory;
	ubyte* c = code;

	version (SLACKVerificationMode)
	{
		enum bool replaceSaveCosave = false;
	}
	else
	{
		bool replaceSaveCosave = (global.configuration.flags & Config.accelerateSaving) != 0;
	}

	if (replaceSaveCosave)
	{
		c = c.alignUpTo(16);
		ubyte* createCosaveReplacement = c;
		c += c.writeJumpTo(cosaveSaveFunction); /+ jmp cosaveSaveFunction +/

		withCodeRegionMadeWritable(
			global.addressOf.createSKSECosave,
			5,
			(scope ubyte* a, size_t s) {a.writeNearJumpTo(createCosaveReplacement);}
		);

		FlushInstructionCache(thisProcess, global.addressOf.createSKSECosave, 5);
	}
	else if (global.configuration.flags & Config.logSaveTimingsToConsole)
	{
		version (SLACKVerificationMode)
		{
			const(ubyte)* createSKSECosaveCallTarget = cast(const(ubyte)*) &saveCosaveInVerificationMode;
		}
		else
		{
			const(ubyte)* createSKSECosaveCallTarget = x86TargetOf!5(global.addressOf.createSKSECosaveCall);
		}

		c = c.alignUpTo(16);
		ubyte* createCosaveCallReplacement = c;
		*c++ = REX.W; *c++ = 0x83; *c++ = modRM(3, 5, 4); *c++ = 40;               /+ sub rsp, 40 +/
		c += c.writeCallOf(cast(const(ubyte)*) &logUnpatchedSaveLoadTimingBefore); /+ call logUnpatchedSaveLoadTimingBefore +/
		version (SLACKVerificationMode)
		{
			c += c.writeCallOf(createSKSECosaveCallTarget);          /+ call createSKSECosaveCallTarget +/
		}
		else
		{
			c.writeDirectCallOf(createSKSECosaveCallTarget); c += 5; /+ call createSKSECosaveCallTarget +/
		}
		*c++ = REX.W; *c++ = 0x83; *c++ = modRM(3, 0, 4); *c++ = 40;               /+ add rsp, 40 +/
		c += c.writeJumpTo(cast(const(ubyte)*) &logUnpatchedSaveTimingAfter);      /+ jmp logUnpatchedSaveTimingAfter +/

		withCodeRegionMadeWritable(
			global.addressOf.createSKSECosaveCall,
			5,
			(scope ubyte* a, size_t s) {a.writeDirectCallOf(createCosaveCallReplacement);}
		);

		FlushInstructionCache(thisProcess, global.addressOf.createSKSECosaveCall, 5);
	}

	if (global.configuration.flags & Config.accelerateLoading)
	{
		c = c.alignUpTo(16);
		ubyte* restoreCosaveReplacement = c;
		c += c.writeJumpTo(cosaveLoadFunction); /+ jmp cosaveLoadFunction +/

		withCodeRegionMadeWritable(
			global.addressOf.restoreSKSECosave,
			5,
			(scope ubyte* a, size_t s) {a.writeNearJumpTo(restoreCosaveReplacement);}
		);

		FlushInstructionCache(thisProcess, global.addressOf.restoreSKSECosave, 5);
	}
	else if (global.configuration.flags & Config.logLoadTimingsToConsole)
	{
		const(ubyte)* restoreSKSECosaveCallTarget = x86TargetOf!5(global.addressOf.restoreSKSECosaveCall);

		c = c.alignUpTo(16);
		ubyte* restoreCosaveCallReplacement = c;
		*c++ = REX.W; *c++ = 0x83; *c++ = modRM(3, 5, 4); *c++ = 40;               /+ sub rsp, 40 +/
		c += c.writeCallOf(cast(const(ubyte)*) &logUnpatchedSaveLoadTimingBefore); /+ call logUnpatchedSaveLoadTimingBefore +/
		c.writeDirectCallOf(restoreSKSECosaveCallTarget); c += 5;                  /+ call restoreSKSECosaveCallTarget +/
		*c++ = REX.W; *c++ = 0x83; *c++ = modRM(3, 0, 4); *c++ = 40;               /+ add rsp, 40 +/
		c += c.writeJumpTo(cast(const(ubyte)*) &logUnpatchedLoadTimingAfter);      /+ jmp logUnpatchedLoadTimingAfter +/

		withCodeRegionMadeWritable(
			global.addressOf.restoreSKSECosaveCall,
			5,
			(scope ubyte* a, size_t s) {a.writeDirectCallOf(restoreCosaveCallReplacement);}
		);

		FlushInstructionCache(thisProcess, global.addressOf.restoreSKSECosaveCall, 5);
	}

	if (global.configuration.flags & Config.aggregateFileFlushingInSKSE)
	{
		global.addressOf.skseSaveCallback = cast(typeof(global.addressOf.skseSaveCallback)) (
			x86TargetOf!7(global.addressOf.supplySKSESaveCallbackLEA)
		);
		global.addressOf.skseLoadCallback = cast(typeof(global.addressOf.skseLoadCallback)) (
			x86TargetOf!7(global.addressOf.supplySKSELoadCallbackLEA)
		);

		global.addressOf.emitSaveMessageCallTarget = cast(typeof(global.addressOf.emitSaveMessageCallTarget)) (
			x86TargetOf!5(global.addressOf.emitSaveMessageCall)
		);
		global.addressOf.emitPreLoadMessageCallTarget = cast(typeof(global.addressOf.emitPreLoadMessageCallTarget)) (
			x86TargetOf!5(global.addressOf.emitPreLoadMessageCall)
		);
		global.addressOf.emitProLoadMessageCallTarget = cast(typeof(global.addressOf.emitProLoadMessageCallTarget)) (
			x86TargetOf!5(global.addressOf.emitProLoadMessageCall)
		);

		static ubyte* install (scope ubyte* c, scope ubyte* place, scope const(ubyte)* target)
		{
			c = c.alignUpTo(16);
			ubyte* trampoline = c;
			c += c.writeJumpTo(cast(const(ubyte)*) target); /+ jmp target +/

			withCodeRegionMadeWritable(
				place,
				5,
				(scope ubyte* a, size_t s) {a.writeDirectCallOf(trampoline);}
			);

			return c;
		}

		c = reassembleAsPredicatedCall(c, sections.text.ptr + skse64Offsets.fflushCall0, &global.inhibitLogFileFlushing, &global.logFileFlushElisionCounter);
		c = reassembleAsPredicatedCall(c, sections.text.ptr + skse64Offsets.fflushCall1, &global.inhibitLogFileFlushing, &global.logFileFlushElisionCounter);
		c = reassembleAsPredicatedCall(c, sections.text.ptr + skse64Offsets.fflushCall2, &global.inhibitLogFileFlushing, &global.logFileFlushElisionCounter);

		c = lea64Trampoline(c, global.addressOf.supplySKSESaveCallbackLEA, cast(const(ubyte)*) &fileFlushAggregator_skseSaveCallback);
		c = lea64Trampoline(c, global.addressOf.supplySKSELoadCallbackLEA, cast(const(ubyte)*) &fileFlushAggregator_skseLoadCallback);
		static if (targetedGameArchetype == GameArchetype.vr) c = lea64Trampoline(c, global.addressOf.supplySKSELoadCallbackLEA1, cast(const(ubyte)*) &fileFlushAggregator_skseLoadCallback);

		c = install(c, global.addressOf.emitSaveMessageCall, cast(const(ubyte)*) &fileFlushAggregator_skseEmitSaveMessage);
		c = install(c, global.addressOf.emitPreLoadMessageCall, cast(const(ubyte)*) &fileFlushAggregator_skseEmitPreLoadMessage);
		c = install(c, global.addressOf.emitProLoadMessageCall, cast(const(ubyte)*) &fileFlushAggregator_skseEmitPostLoadMessage);
	}

	version (SLACKVerificationMode)
	{
		size_t regionSize = 512.MB;
		NtAllocateVirtualMemory(thisProcess, cast(void**) &global.saveLoad.verificationBase, 0, &regionSize, MEM_RESERVE | MEM_COMMIT, PAGE_READWRITE);
		global.saveLoad.verificationTail = global.saveLoad.verificationBase + regionSize;

		const(ubyte)* restoreSKSECosaveCallTarget = cast(const(ubyte)*) &callLoadCosaveInVerificationMode;

		c = c.alignUpTo(16);
		ubyte* restoreCosaveCallReplacement = c;
		c += c.writeJumpTo(restoreSKSECosaveCallTarget); /+ jmp restoreSKSECosaveCallTarget +/

		withCodeRegionMadeWritable(
			global.addressOf.restoreSKSECosaveCall,
			5,
			(scope ubyte* a, size_t s) {a.writeDirectCallOf(restoreCosaveCallReplacement);}
		);

		FlushInstructionCache(thisProcess, global.addressOf.restoreSKSECosaveCall, 5);
	}

	if (
		  ((global.configuration.flags & Config.accelerateSaving) != 0)
		& ((global.configuration.flags & Config.workAroundThirdPartyBugs) != 0)
	)
	{
		static if (observingPluginFileNameViaCall)
		{
			const(ubyte)* sksePluginFilePathCallTarget = x86TargetOf!5(global.addressOf.sksePluginFilePathCall);

			c = c.alignUpTo(16);
			ubyte* sksePluginNameObserver = c;

			*c++ = 0x51;                                                          /+ push rcx +/
			*c++ = REX.W; *c++ = 0x83; *c++ = modRM(3, 5, 4); *c++ = 32;          /+ sub rsp, 32 +/
			c.writeDirectCallOf(sksePluginFilePathCallTarget); c += 5;            /+ call sksePluginFilePathCallTarget +/
			*c++ = REX.W; *c++ = 0x83; *c++ = modRM(3, 0, 4); *c++ = 32;          /+ add rsp, 32 +/
			*c++ = 0x59;                                                          /+ pop rcx +/
			c += c.writeJumpTo(cast(const(ubyte)*) &observeFileNameOfSKSEPlugin); /+ jmp observeFileNameOfSKSEPlugin +/

			withCodeRegionMadeWritable(
				global.addressOf.sksePluginFilePathCall,
				5,
				(scope ubyte* a, size_t s) {a.writeDirectCallOf(sksePluginNameObserver);}
			);

			FlushInstructionCache(thisProcess, global.addressOf.sksePluginFilePathCall, 5);
		}

		c = c.alignUpTo(16);
		ubyte* skse64ProvisionHijack = c;

		/+
			This worked only on my machine. God knows why.

			static if (targetedGameVersion >= 0x01_06_000_0)
			{
				enum ubyte shadowSpace = 40;
			}

			I hate computers.
		+/

		enum ubyte shadowSpace = 32;

		*c++ = REX.W; *c++ = 0x83; *c++ = modRM(3, 5, 4); *c++ = shadowSpace;                          /+ sub rsp, shadowSpace +/
		c += c.writeCallOf(cast(const(ubyte)*) &hijackProvisionOfSKSE64ProviderWhenLoadingSKSEPlugin); /+ call hijackProvisionOfSKSE64ProviderWhenLoadingSKSEPlugin +/
		*c++ = REX.W; *c++ = 0x83; *c++ = modRM(3, 0, 4); *c++ = shadowSpace;                          /+ add rsp, shadowSpace +/
		c.writeNearJumpTo(global.addressOf.supplySKSEProviderLEA + 7); c += 5;                         /+ jmp supplySKSEProviderLEA + 7  +/

		withCodeRegionMadeWritable(
			global.addressOf.supplySKSEProviderLEA,
			7,
			(scope ubyte* a, size_t s)
			{
				a.writeNearJumpTo(skse64ProvisionHijack);
				a += 5;
				a.nopOut!2;
			}
		);

		FlushInstructionCache(thisProcess, global.addressOf.supplySKSEProviderLEA, 7);
	}

	makeMemoryRegionExecutable(code, 4.KB);

	FlushInstructionCache(thisProcess, code, 4.KB);

	setUpBeforeSKSEPluginsAreLoaded;

	return true;
}


void setUpBeforeSKSEPluginsAreLoaded () nothrow @nogc
{
	alias Config = ConfigurationLongLived.Flags;

	SerialisationProvider* serialisationProvider = cast(SerialisationProvider*) (
		global.addressOf.globalSKSE64Provider.requestProvider(SKSE64Provider.ProviderID.serialisation)
	);

	global.addressOf.globalSerialisationProvider = serialisationProvider;

	if (global.configuration.accelerationEnabled)
	{
		withRegionMadeWritable(
			cast(ubyte*) serialisationProvider,
			SerialisationProvider.sizeof,
			(scope ubyte* a, size_t s)
			{
				SerialisationProvider* serialisation = cast(SerialisationProvider*) a;

				version (SLACKVerificationMode)
				{
					global.addressOf.skseSerialisationBeginRecord = serialisation.beginRecord;
					global.addressOf.skseSerialisationWriteRecord = serialisation.writeRecord;
					global.addressOf.skseSerialisationWriteRecordData = serialisation.writeRecordData;
				}

				if (global.configuration.flags & Config.accelerateSaving)
				{
					serialisation.beginRecord = &SerialSaving.beginRecord;
					serialisation.writeRecord = &SerialSaving.writeRecord;
					serialisation.writeRecordData = &SerialSaving.writeRecordData;
				}

				version (SLACKVerificationMode)
				{
					if (global.configuration.flags & Config.accelerateLoading)
					{
						global.addressOf.readNextRecordHeader = &SerialLoading.readNextRecordHeader;
						global.addressOf.readRecordData = &SerialLoading.readRecordData;
					}
					else
					{
						global.addressOf.readNextRecordHeader = serialisation.readNextRecordHeader;
						global.addressOf.readRecordData = serialisation.readRecordData;
					}

					serialisation.readNextRecordHeader = &VerifiedLoading.readNextRecordHeader;
					serialisation.readRecordData = &VerifiedLoading.readRecordData;
				}
				else
				{
					if (global.configuration.flags & Config.accelerateLoading)
					{
						serialisation.readNextRecordHeader = &SerialLoading.readNextRecordHeader;
						serialisation.readRecordData = &SerialLoading.readRecordData;
					}
				}
			}
		);
	}
}


pragma(inline, true)
SpecialPlugin specialPluginFromDLLFileName () (scope const(char)* name, size_t length) nothrow @nogc
{
	/+ If another plugin is added here, remember to update the logging
	   in the `SpecialSaving` implementations. +/

	if (length == 0)
	{
		return SpecialPlugin.none;
	}

	const(char)* end = name + length;

	for (; end > name;)
	{
		--end;
		if (*end == '.') goto dllNameFromDot;
	}

	return SpecialPlugin.none;
dllNameFromDot:
	size_t baseNameLength = end - name;

	if (baseNameLength == 11)
	{
		if (caseInsensitiveASCIIEquality!true(name, "papyrusutil".ptr, 11))
		{
			return SpecialPlugin.papyrusUtil;
		}
		else if (caseInsensitiveASCIIEquality!true(name, "stb_widgets".ptr, 11))
		{
			return SpecialPlugin.stbWidgets;
		}
	}

	return SpecialPlugin.none;
}


static if (observingPluginFileNameViaCall)
{
	pragma(inline, false)
	void observeFileNameOfSKSEPlugin (scope const(FileEnumerator)* fileEnumerator) nothrow @nogc
	{
		const(char)* name = fileEnumerator.findData.cFileName.ptr;
		size_t length = strlen(name);
		global.currentSpecialPluginBeingLoaded = specialPluginFromDLLFileName(name, length);
	}
}


@optStrategy("minsize")
pragma(inline, false)
void hijackProvisionOfSKSE64ProviderWhenLoadingSKSEPlugin (ulong rcx, ulong rdx, ulong r8, ulong r9) nothrow @nogc
{
	SKSE64Provider* provider = global.addressOf.globalSKSE64Provider;

	static if (observingPluginFileNameViaCall)
	{
		DLLPlugin* pluginBeingLoaded = cast(DLLPlugin*) rdx;
		SpecialPlugin currentSpecialPlugin = global.currentSpecialPluginBeingLoaded;
	}
	else
	{
		static if (expectedSKSE64Version >= 0x02_02_007_0)
		{
			DLLPluginIndex biasedIndexOfPluginBeingLoaded = *global.addressOf.indexOfSKSEPluginBeingLoaded;
			DLLPlugin* pluginBeingLoaded = (cast(DLLPluginIndex) (biasedIndexOfPluginBeingLoaded - 1)).dllPlugin;
		}
		else
		{
			DLLPlugin* pluginBeingLoaded = *global.addressOf.sksePluginBeingLoaded;
		}

		const(std_string)* dllName = &pluginBeingLoaded.filePath;
		SpecialPlugin currentSpecialPlugin = specialPluginFromDLLFileName(dllName.base, dllName.size);
	}

	final switch (currentSpecialPlugin)
	{
	case SpecialPlugin.none:
		break;
	case SpecialPlugin.papyrusUtil:
		static if (patchingPapyrusUtilIsSupported)
		{
			if (global.foundPapyrusUtil)
			{
				break;
			}

			global.foundPapyrusUtil = true;

			setUpWithPapyrusUtilDLL(cast(ubyte*) pluginBeingLoaded.dll);
		}

		break;
	case SpecialPlugin.stbWidgets:
		/+ There used to be some version-detection logic here,
		   because I didn't want to set-up the special provider for newer versions
		   of STB Widgets that shouldn't need it, but as I can't find
		   a useful version-number in STB_Widgets.dll it relied on fingerprinting
		   bytes of code, which proved unreliable for some users.
		   (Relocations, perhaps? Other mods injecting code? x86 emulation on ARM64? Who knows?)
		   So now the the special provider is set-up unconditionally.
		   I'll revisit this if the STB Widgets' team ever decide to update their version-number. +/
		provider = setUpSpecialSKSE64Providers;
		goto useProvider;
	}
useProvider:
	__ir_pure!(`call void asm sideeffect inteldialect "", "{rcx},{rdx},{r8},{r9}" (ptr %0, i64 %1, i64 %2, i64 %3)`, void)(
		provider,
		rdx,
		r8,
		r9
	);
}


SKSE64Provider* setUpSpecialSKSE64Providers () nothrow @nogc
{
	if (global.haveSetUpSpecialSKSE64Providers)
	{
		return &global.specialSKSE64Provider;
	}

	SerialisationProvider* serialisationProvider = cast(SerialisationProvider*) (
		global.addressOf.globalSKSE64Provider.requestProvider(SKSE64Provider.ProviderID.serialisation)
	);

	global.specialSerialisationProvider = *serialisationProvider;
	global.specialSerialisationProvider.writeRecord = &SpecialSaving.writeRecord;
	global.specialSerialisationProvider.writeRecordData = &SpecialSaving.writeRecordData;
	global.specialSerialisationProvider.assignStateSaver = &specialSKSE64AssignStateSaver;

	global.specialSKSE64Provider = *global.addressOf.globalSKSE64Provider;
	global.specialSKSE64Provider.requestProvider = &specialSKSE64RequestProvider;

	global.haveSetUpSpecialSKSE64Providers = true;

	return &global.specialSKSE64Provider;
}


void* specialSKSE64RequestProvider (uint providerID) nothrow @nogc
{
	switch (providerID)
	{
	case SKSE64Provider.ProviderID.serialisation:
		return &global.specialSerialisationProvider;
	default:
		return global.addressOf.globalSKSE64Provider.requestProvider(providerID);
	}
}


void specialSKSE64AssignStateSaver (
	DLLPluginIndex dllPluginIndex,
	SerialisationProvider.ProviderReceiver providerReceiver
) nothrow @nogc
{
	SerialisationProvider* serialisationProvider = cast(SerialisationProvider*) (
		global.addressOf.globalSKSE64Provider.requestProvider(SKSE64Provider.ProviderID.serialisation)
	);

	/+ We tag the function-pointer to denote it as special. +/

	auto pointer = cast(size_t) providerReceiver | specialStateSaverTag;

	serialisationProvider.assignStateSaver(dllPluginIndex, cast(SerialisationProvider.ProviderReceiver) pointer);
}


static if (patchingPapyrusUtilIsSupported)
{
	@optStrategy("minsize")
	pragma(inline, false)
	void setUpWithPapyrusUtilDLL (scope ubyte* papyrusUtilDLL) nothrow @nogc
	{
		alias Config = ConfigurationLongLived.Flags;

		if (!(global.configuration.flags & Config.aggregateFileFlushingInPapyrusUtil))
		{
			return;
		}

		auto dos = cast(const(IMAGE_DOS_HEADER)*) papyrusUtilDLL;
		auto pe = cast(const(IMAGE_NT_HEADERS64)*) (papyrusUtilDLL + dos.e_lfanew);
		uint timeDateStamp = pe.FileHeader.TimeDateStamp;

		if (timeDateStamp != expectedPapyrusUtilTimeDateStamp)
		{
			return;
		}

		PESections sections = void;

		if (findSectionsOfPE64(papyrusUtilDLL, &sections) != 0)
		{
			return;
		}

		uint versionNumber = *cast(const(Unaligned!uint)*) (sections.text.ptr + papyrusUtilOffsets.versionNumberImmediate);

		if (versionNumber != expectedPapyrusUtilVersion)
		{
			return;
		}

		void[] papyrusUtilAdjacentMemory = void;

		if (allocateImageAdjacentMemory(&papyrusUtilAdjacentMemory, sections) != 0)
		{
			return;
		}

		global.addressOf.papyrusUtilSaveCallback = cast(typeof(global.addressOf.papyrusUtilSaveCallback)) (
			x86TargetOf!7(sections.text.ptr + papyrusUtilOffsets.supplySaveCallbackLEA)
		);
		global.addressOf.papyrusUtilLoadCallback = cast(typeof(global.addressOf.papyrusUtilLoadCallback)) (
			x86TargetOf!7(sections.text.ptr + papyrusUtilOffsets.supplyLoadCallbackLEA)
		);

		global.addressOf.papyrusUtilLogFileStdioHandle = cast(void**) (sections.data.ptr + papyrusUtilOffsets.logFileStdioHandle);
		global.addressOf.papyrusUtilFFlush = cast(typeof(global.addressOf.papyrusUtilFFlush)) (sections.text.ptr + papyrusUtilOffsets.fflush);

		ubyte* code = cast(ubyte*) papyrusUtilAdjacentMemory.ptr;
		ubyte* c = code;

		c = reassembleAsPredicatedCall(c, sections.text.ptr + papyrusUtilOffsets.fflushCall0, &global.inhibitLogFileFlushing, &global.logFileFlushElisionCounter);
		c = reassembleAsPredicatedCall(c, sections.text.ptr + papyrusUtilOffsets.fflushCall1, &global.inhibitLogFileFlushing, &global.logFileFlushElisionCounter);
		c = reassembleAsPredicatedCall(c, sections.text.ptr + papyrusUtilOffsets.fflushCall2, &global.inhibitLogFileFlushing, &global.logFileFlushElisionCounter);

		c = lea64Trampoline(c, sections.text.ptr + papyrusUtilOffsets.supplySaveCallbackLEA, cast(const(ubyte)*) &fileFlushAggregator_papyrusUtilSaveCallback);
		c = lea64Trampoline(c, sections.text.ptr + papyrusUtilOffsets.supplyLoadCallbackLEA, cast(const(ubyte)*) &fileFlushAggregator_papyrusUtilLoadCallback);

		makeMemoryRegionExecutable(code, 4.KB);

		FlushInstructionCache(thisProcess, code, 4.KB);

		global.patchedPapyrusUtil = true;
	}
}


@optStrategy("minsize")
ubyte* lea64Trampoline (return scope ubyte* c, scope ubyte* place, scope const(ubyte)* target) nothrow @nogc
{
	c = c.alignUpTo(16);
	ubyte* trampoline = c;
	c += c.writeJumpTo(target); /+ jmp target +/

	withCodeRegionMadeWritable(
		place,
		7,
		(scope ubyte* a, size_t s) {a.writeNearDisplacementTo!7(trampoline);}
	);

	return c;
}


@optStrategy("minsize")
ubyte* reassembleAsPredicatedCall (
	return scope ubyte* c,
	scope ubyte* place,
	scope const(ubyte)* inhibition,
	scope uint* elisionCounter
) nothrow @nogc
{
	const(ubyte)* target = x86TargetOf!5(place);

	c = c.alignUpTo(16);
	ubyte* trampoline = c;
	*c++ = REX.W; *c++ = 0xA1; *cast(Unaligned!ulong*) c = cast(ulong) inhibition; c += 8;        /+ mov rax, qword ptr [inhibition] +/
	*c++ = 0x84; *c++ = modRM(3, 0, 0);                                                           /+ test al, al +/
	c[0] = 0x0F; c[1] = 0x84; *cast(Unaligned!int*) &c[2] = x86Displacement!6(c, target); c += 6; /+ jz target +/
	*c++ = REX.W; *c++ = 0xB8; *cast(Unaligned!ulong*) c = cast(ulong) elisionCounter; c += 8;    /+ mov rax, elisionCounter +/
	*c++ = 0xFF; *c++ = modRM(0, 0, 0);                                                           /+ inc dword ptr [rax] +/
	*c++ = 0xC3;                                                                                  /+ ret +/

	withCodeRegionMadeWritable(
		place,
		5,
		(scope ubyte* a, size_t s) {a.writeDirectCallOf(trampoline);}
	);

	return c;
}


pragma(inline, false)
uint allocateImageAdjacentMemory (scope void[]* memory, scope ref PESections sections) nothrow @nogc
{
	PESections sortedSections = sections;
	sortingNetwork!((a, b) => a.ptr > b.ptr)(sortedSections);

	uint error = void;

	void* adjacentMemory = void;
	size_t size = void;
	const(void)* base = void;
	const(void)* tail = void;

	/+ Can we allocate memory between the image's sections? +/
	foreach (size_t index; 0 .. 1)
	{
		base = sortedSections[index].endOf;
		tail = sortedSections[index + 1].ptr;
		size_t betweenSize = tail - base;

		if (betweenSize >= 64.KB)
		{
			adjacentMemory = null;
			size = 64.KB;
			if ((error = allocateVirtualMemoryWithinRange(base, tail, &adjacentMemory, &size, MEM_RESERVE | MEM_COMMIT, PAGE_READWRITE)) != 0)
			{
				return error;
			}
		}
	}

	/+ What about after the sections? +/
	base = sortedSections[$ - 1].endOf;
	tail = sortedSections[0].ptr + 2.GB;
	adjacentMemory = null;
	size = 64.KB;
	if ((error = allocateVirtualMemoryWithinRange(base, tail, &adjacentMemory, &size, MEM_RESERVE | MEM_COMMIT, PAGE_READWRITE)) != 0)
	{
		return error;
	}

	/+ Before? +/
	base = sortedSections[$ - 1].endOf - 2.GB;
	tail = sortedSections[0].ptr;
	adjacentMemory = null;
	size = 64.KB;
	if ((error = allocateVirtualMemoryWithinRange(base, tail, &adjacentMemory, &size, MEM_RESERVE | MEM_COMMIT, PAGE_READWRITE)) != 0)
	{
		return error;
	}

	*memory = adjacentMemory[0 .. size];

	return 0;
}


pragma(inline, true)
void showComprehensiveSKSEVersionMismatchMessage (T) (
	scope ref wchar[512] stringBuffer,
	uint skse64Version,
	scope T versionContext
) nothrow @nogc
{
	static if (is(typeof(outdatedSKSEVersionMessage)))
	{
		bool isKnownOutdatedVersion = isOutdatedSKSEVersion(stringBuffer, skse64Version, versionContext);
	}
	else
	{
		enum bool isKnownOutdatedVersion = false;
	}

	if (!isKnownOutdatedVersion)
	{
		showGenericSKSEVersionMismatchMessage(skse64Version);
	}
}


pragma(inline, false)
void showGenericSKSEVersionMismatchMessage (uint detectedSKSE64Version) nothrow @nogc
{
	enum wstring mismatchString_ = (
		  "This version of the SKSE64 DLL is not supported by the Save & Load Accelerator for SKSE Cosaves (S.L.A.C.K.).\r\n\r\n"
		~ "Please ensure you are using the correct version of S.L.A.C.K. for your version of the game by re-running S.L.A.C.K.'s FOMOD.\r\n\r\n"
		~ "This version of S.L.A.C.K. is for Skyrim v" ~ targetedGameVersionFriendlyString!wchar ~ ".\r\n\r\n"
		~ "Expected SKSE version: 0x" ~ expectedSKSE64Version.asHex!(wchar, true) ~ "\r\nDetected SKSE version: 0x77777777\0"
	);
	__gshared wchar[mismatchString_.length] mismatchString = mismatchString_;

	detectedSKSE64Version.asHexInto!true(mismatchString[$ - 9 .. ($ - 9) + 8][0 .. 8]);

	reportErrorToUser(mismatchString.ptr);

	showMessageBox(
		"The previous error came from S.L.A.C.K., not SKSE.\r\nDo not report it to the SKSE team.",
		"IMPORTANT",
		MB_OK | MB_ICONINFORMATION
	);

	/+ Open S.L.A.C.K.'s Nexus Mods page so that people who unknowingly
	   installed S.L.A.C.K. via a collection don't go and bug Ian about it. +/
	openURL("https://www.nexusmods.com/skyrimspecialedition/mods/163969");
}


static if (targetedGameArchetype == GameArchetype.se)
{
	__gshared wchar[205] outdatedSKSEVersionMessage = "Version 2.0.1x of SKSE has been detected. This version of SKSE is out-of-date and is not supported by the Save & Load Accelerator for SKSE Cosaves (S.L.A.C.K.).\r\n\r\nPlease update to version 2.0.20 of SKSE.\0";
}
else static if (targetedGameArchetype == GameArchetype.vr)
{
	__gshared wchar[205] outdatedSKSEVersionMessage = "Version 2.0.xx of SKSE has been detected. This version of SKSE is out-of-date and is not supported by the Save & Load Accelerator for SKSE Cosaves (S.L.A.C.K.).\r\n\r\nPlease update to version 2.0.12 of SKSE.\0";
}
else static if (targetedGameArchetype == GameArchetype.ae1170)
{
	__gshared wchar[203] outdatedSKSEVersionMessage = "Version 2.2.x of SKSE has been detected. This version of SKSE is out-of-date and is not supported by the Save & Load Accelerator for SKSE Cosaves (S.L.A.C.K.).\r\n\r\nPlease update to version 2.2.8 of SKSE.\0";
}
else static if (targetedGameArchetype == GameArchetype.ae1130)
{
	static immutable(wchar[203]) outdatedSKSEVersionMessage = "Version 2.2.4 of SKSE has been detected. This version of SKSE is out-of-date and is not supported by the Save & Load Accelerator for SKSE Cosaves (S.L.A.C.K.).\r\n\r\nPlease update to version 2.2.5 of SKSE.\0";
}
else static if (targetedGameArchetype == GameArchetype.ae640)
{
	__gshared wchar[203] outdatedSKSEVersionMessage = "Version 2.2.x of SKSE has been detected. This version of SKSE is out-of-date and is not supported by the Save & Load Accelerator for SKSE Cosaves (S.L.A.C.K.).\r\n\r\nPlease update to version 2.2.3 of SKSE.\0";
}
else static if (targetedGameArchetype == GameArchetype.gog659)
{
	static immutable(wchar[209]) outdatedSKSEVersionMessage = "Version 2.2.2 of SKSE has been detected. This version of SKSE is out-of-date and is not supported by the Save & Load Accelerator for SKSE Cosaves (S.L.A.C.K.).\r\n\r\nPlease update to version 2.2.3 (GOG) of SKSE.\0";
}


bool isOutdatedSKSEVersion (T) (scope ref wchar[512] stringBuffer, uint skse64Version, scope const(T) versionContext) nothrow @nogc
{
	static if (is(T == ubyte*))
	{
		alias skseRData = versionContext;

		uint versionOf (uint offset)
		{
			pragma(inline, true);
			return (cast(const(SKSE64Provider)*) (skseRData + offset)).skse64Version;
		}
	}
	else
	{
		static assert(T.sizeof == 0);

		uint versionOf (uint offset)
		{
			pragma(inline, true);
			return skse64Version;
		}
	}

	static if (targetedGameArchetype == GameArchetype.se)
	{
		enum wstring url = "https://www.nexusmods.com/skyrimspecialedition/mods/30379?tab=files#file-expander-header-233411:~:text=2%2E0%2E20";

		if (versionOf(skse64v2_0_17_globalSKSE64Provider) == 0x02_00_011_0)
		{
			outdatedSKSEVersionMessage[13] = '7';
		}
		else
		{
			uint version_ = versionOf(skse64v2_0_18_or_19_globalSKSE64Provider);

			if ((version_ == 0x02_00_012_0) | (version_ == 0x02_00_013_0))
			{
				outdatedSKSEVersionMessage[13] = '8' + ((version_ >>> 4) & 1);
			}
			else
			{
				return false;
			}
		}
	}
	else static if (targetedGameArchetype == GameArchetype.vr)
	{
		enum wstring url = "https://www.nexusmods.com/skyrimspecialedition/mods/30457?tab=files#file-expander-header-499284:~:text=2%2E0%2E12,-Compatible";

		if (versionOf(skseVRv2_0_11_globalSKSE64Provider) == 0x02_00_00B_0)
		{
			outdatedSKSEVersionMessage[12] = '1';
			outdatedSKSEVersionMessage[13] = '1';
		}
		else
		{
			uint version_ = versionOf(skseVRv2_0_09_or_10_globalSKSE64Provider);

			if (version_ == 0x02_00_009_0)
			{
				outdatedSKSEVersionMessage[12] = '0';
				outdatedSKSEVersionMessage[13] = '9';
			}
			else if (version_ == 0x02_00_00A_0)
			{
				outdatedSKSEVersionMessage[12] = '1';
				outdatedSKSEVersionMessage[13] = '0';
			}
			else
			{
				return false;
			}
		}
	}
	else static if (targetedGameArchetype == GameArchetype.ae1170)
	{
		enum wstring url = "https://www.nexusmods.com/skyrimspecialedition/mods/30379?tab=files#file-expander-header-792256:~:text=2%2E2%2E8";

		if (versionOf(skse64v2_2_06_globalSKSE64Provider) == 0x02_02_006_0)
		{
			outdatedSKSEVersionMessage[12] = '6';
		}
		else if (versionOf(skse64v2_2_07_globalSKSE64Provider) == 0x02_02_007_0)
		{
			/+ I didn't even get a chance to release an update for 2.2.7. +/
			outdatedSKSEVersionMessage[12] = '7';
		}
		else
		{
			return false;
		}
	}
	else static if (targetedGameArchetype == GameArchetype.ae1130)
	{
		enum wstring url = "https://www.nexusmods.com/skyrimspecialedition/mods/30379?tab=files#file-expander-header-233411:~:text=2%2E2%2E5";

		/+ The offset of `globalSKSE64Provider.skse64Version` didn't change
		   between versions 2.2.4 and 2.2.5, so we needn't use `versionOf` here. +/
		if (skse64Version == 0x02_02_004_0)
		{}
		else
		{
			return false;
		}
	}
	else static if (targetedGameArchetype == GameArchetype.ae640)
	{
		/+ Having the text-fragment match on the upload time is kind of gross, but it's the only way (download count excepted) to disambiguate between the Steam and GOG versions. +/
		enum wstring url = "https://www.nexusmods.com/skyrimspecialedition/mods/30379?tab=files#file-expander-header-323365:~:text=8%3A09PM,2%2E2%2E3";

		uint version_ = versionOf(skse64v2_2_01_or_02_globalSKSE64Provider);

		if ((version_ == 0x02_02_001_0) | (version_ == 0x02_02_002_0))
		{
			outdatedSKSEVersionMessage[12] = '2' - ((version_ >>> 4) & 1);
		}
		else
		{
			return false;
		}
	}
	else static if (targetedGameArchetype == GameArchetype.gog659)
	{
		/+ Again with the text-fragment matching on the upload time grossness. +/
		enum wstring url = "https://www.nexusmods.com/skyrimspecialedition/mods/30379?tab=files#file-expander-header-323366:~:text=8%3A10PM,2%2E2%2E3";

		if (versionOf(skse64v2_2_02gog_globalSKSE64Provider) == 0x02_02_002_0)
		{}
		else
		{
			return false;
		}
	}
	else
	{
		static assert(false);
	}

	uint button = showMessageBox(outdatedSKSEVersionMessage.ptr, errorDialogTitle!wchar.ptr, MB_OKCANCEL | MB_ICONHAND);

	if (button == IDOK)
	{
		openURL(url.ptr);
	}

	return true;
}

