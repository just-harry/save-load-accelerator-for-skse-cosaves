
/+ SPDX-LICENSE-IDENTIFIER: 0BSD +/

module slack_mod.setup;

import ldc.llvmasm : __ir_pure;

import game;

import slack_common.algorithms;
import slack_common.bindings;
import slack_common.byte_sizes;
import slack_common.cpp;
import slack_common.file_handling;
import slack_common.ini;
import slack_common.integers;
import slack_common.large_low_overhead_buffer;
import slack_common.memory;
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


bool setUpEverything (scope ref wchar[MAX_PATH + 60] stringBuffer) nothrow @nogc
{
	alias Config = ConfigurationLongLived.Flags;

	RtlQueryPerformanceFrequency(cast(LARGE_INTEGER*) &global.performanceFrequency);

	global.performanceFrequencyMillisecondMultiplier = 1000.0 / cast(double) global.performanceFrequency;

	global.linked.linkAll;

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
			"The path of the \"Save&LoadAcceleratorForSKSECosaves.dll\" file could not be found.\r\nAnd thus nor can the INI file be found.",
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
					"The \"Save&LoadAcceleratorForSKSECosaves.ini\" file could not be opened.",
					hresultFromLastError(error)
				);
			}

			goto noINIFile;
		}
		else
		{
			error = mapFileForReading(iniFile, &ini);

			scope(exit) unmapFile(ini.ptr);

			NtClose(iniFile);

			if (error)
			{
				reportErrorToUser(
					stringBuffer,
					"The \"Save&LoadAcceleratorForSKSECosaves.ini\" file could not be mapped for reading.",
					error
				);

				goto noINIFile;
			}

			parseINIConfiguration(cast(const(char)[]) ini, &global.configuration, &transientConfiguration);

			if (transientConfiguration.skseDLLName.length != 0)
			{
				const(char)* utf8 = transientConfiguration.skseDLLName.ptr;
				const(char)* utf8End = transientConfiguration.skseDLLName.endOf;
				wchar* utf16 = stringBuffer.ptr;
				wchar* utf16End = stringBuffer.endOf - 1;
				dchar pendingCodePoint = cast(dchar) -1;
				utf8ToUTF16(&utf8, utf8End, &utf16, utf16End, &pendingCodePoint);

				if (utf8 < utf8End)
				{
					reportErrorToUser(
						"The \"SKSEDLLName\" value provided in \"Save&LoadAcceleratorForSKSECosaves.ini\" is too long."
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
			static if (shouldUseDLLNotifications)
			{
				error = global.linked.LdrRegisterDllNotification(
					0,
					&dllRegistrationNotificationHandler!(),
					null,
					&global.dllRegistrationNotificationCookie
				);

				if (error)
				{
					reportErrorToUser(
						stringBuffer,
						"The DLL-registration-notification-handler could not be installed.",
						getLastError
					);
					return false;
				}

				return true;
			}
			else
			{
				reportErrorToUser(
					stringBuffer,
					"The SKSE64 DLL could not be found.\r\nYou may need to set, or change, the value of the \"SKSEDLLName\" setting in the \"Save&LoadAcceleratorForSKSECosaves.ini\" file.",
					hresultFromLastError(getLastError)
				);
				return false;
			}
		}

		return setUpEverythingWithSKSEDLL(stringBuffer, skseDLL);
	}

	return true;
}


bool setUpEverythingWithSKSEDLL (scope ref wchar[MAX_PATH + 60] stringBuffer, scope ubyte* skseDLL) nothrow @nogc
{
	alias Config = ConfigurationLongLived.Flags;

	assert(global.configuration.skseHooksAreRequired);

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
		static if (__traits(compiles, isOutdatedSKSEVersion(stringBuffer, skse64Version, sections.rdata.ptr)))
		{
			bool isKnownOutdatedVersion = isOutdatedSKSEVersion(stringBuffer, skse64Version, sections.rdata.ptr);
		}
		else
		{
			enum bool isKnownOutdatedVersion = false;
		}

		if (!isKnownOutdatedVersion)
		{
			wchar* s = stringBuffer.ptr;
			blit(s, "This version of the SKSE64 DLL is not supported by the Save & Load Accelerator for SKSE Cosaves (S.L.A.C.K.).\r\nPlease ensure you are using the correct version of S.L.A.C.K. for your version of the game.\r\n"w.ptr, 204);
			s += 204;
			blit(s, "Expected version: 0x"w.ptr, 20);
			s += 20;
			expectedSKSE64Version.asHexInto!true(s[0 .. 8]);
			s += 8;
			blit(s, "; Actual version: 0x"w.ptr, 20);
			s += 20;
			skse64Version.asHexInto!true(s[0 .. 8]);
			s += 8;
			*s++ = '.';
			*s++ = '\0';
			reportErrorToUser(stringBuffer.ptr);
		}

		return false;
	}

	PESections sortedSections = sections;
	sortingNetwork!((a, b) => a.ptr > b.ptr)(sortedSections);

	void* skseAdjacentMemory = void;
	size_t size = void;
	const(void)* base = void;
	const(void)* tail = void;

	/+ Can we allocate memory between SKSE's sections? +/
	foreach (size_t index; 0 .. 1)
	{
		base = sortedSections[index].endOf;
		tail = sortedSections[index + 1].ptr;
		size_t betweenSize = tail - base;

		if (betweenSize >= 64.KB)
		{
			skseAdjacentMemory = null;
			size = 64.KB;
			if ((error = allocateVirtualMemoryWithinRange(base, tail, &skseAdjacentMemory, &size, MEM_RESERVE | MEM_COMMIT, PAGE_READWRITE)) == 0)
			{
				goto allocatedSKSEskseAdjacentMemory;
			}
		}
	}

	/+ What about after the sections? +/
	base = sortedSections[$ - 1].endOf;
	tail = sortedSections[0].ptr + 2.GB;
	skseAdjacentMemory = null;
	size = 64.KB;
	if ((error = allocateVirtualMemoryWithinRange(base, tail, &skseAdjacentMemory, &size, MEM_RESERVE | MEM_COMMIT, PAGE_READWRITE)) == 0)
	{
		goto allocatedSKSEskseAdjacentMemory;
	}

	/+ Before? +/
	base = sortedSections[$ - 1].endOf - 2.GB;
	tail = sortedSections[0].ptr;
	skseAdjacentMemory = null;
	size = 64.KB;
	if ((error = allocateVirtualMemoryWithinRange(base, tail, &skseAdjacentMemory, &size, MEM_RESERVE | MEM_COMMIT, PAGE_READWRITE)) == 0)
	{
		goto allocatedSKSEskseAdjacentMemory;
	}

	errorMessage = "Memory could not be allocated sufficiently close to the SKSE64 DLL.";
reportErrorOnFailure:
	reportErrorToUser(stringBuffer, errorMessage, error);
	return false;
allocatedSKSEskseAdjacentMemory:
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

	allowPluginsToSaveWhenSKSEIsNotSaving;
	allowPluginsToLoadWhenSKSEIsNotLoading;

	global.addressOf.skseCosaveSavePath = cast(std_string*) (sections.data.ptr + skse64Offsets.cosaveSavePath);
	global.addressOf.loadedSKSEPlugins = cast(std_vector!DLLPlugin*) (sections.data.ptr + skse64Offsets.loadedPlugins);

	static if (!observingPluginFileNameViaCall)
	{
		global.addressOf.sksePluginBeingLoaded = cast(DLLPlugin**) (sections.data.ptr + skse64Offsets.pluginBeingLoaded);
	}

	global.addressOf.cosaveAwarePlugins = cast(std_vector!SerialisationStateForPlugin*) (sections.data.ptr + skse64Offsets.cosaveAwarePlugins);
	global.addressOf.supplySKSEProviderLEA = sections.text.ptr + skse64Offsets.supplyProviderLEA;
	global.addressOf.createSKSECosave = sections.text.ptr + skse64Offsets.createCosave;
	global.addressOf.restoreSKSECosave = sections.text.ptr + skse64Offsets.restoreCosave;
	global.addressOf.createSKSECosaveCall = sections.text.ptr + skse64Offsets.createCosaveCall;
	global.addressOf.restoreSKSECosaveCall = sections.text.ptr + skse64Offsets.restoreCosaveCall;
	global.addressOf.skseConsolePrint = cast(typeof(global.addressOf.skseConsolePrint)) (sections.text.ptr + skse64Offsets.consolePrint);

	static if (observingPluginFileNameViaCall)
	{
		global.addressOf.sksePluginFilePathCall = sections.text.ptr + skse64Offsets.pluginFilePathCall;
	}

	global.addressOf.findDLLPluginsCall = sections.text.ptr + skse64Offsets.findDLLPluginsCall;

	ubyte* code = cast(ubyte*) skseAdjacentMemory;
	ubyte* c = code;

	ubyte* findDLLPluginsHook = c;

	const(ubyte)* findDLLPlugins = x86TargetOf!5(global.addressOf.findDLLPluginsCall);

	*c++ = REX.W; *c++ = 0x83; *c++ = modRM(3, 5, 4); *c++ = 32;              /+ sub rsp, 32 +/
	c += c.writeCallOf(cast(const(ubyte)*) &setUpBeforeSKSEPluginsAreLoaded); /+ call setUpBeforeSKSEPluginsAreLoaded +/
	*c++ = REX.W; *c++ = 0x83; *c++ = modRM(3, 0, 4); *c++ = 32;              /+ add rsp, 32 +/
	c.writeNearJumpTo(findDLLPlugins); c += 5;                                /+ jmp findDLLPlugins +/

	withCodeRegionMadeWritable(
		global.addressOf.findDLLPluginsCall,
		5,
		(scope ubyte* a, size_t s) {a.writeDirectCallOf(findDLLPluginsHook);}
	);

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

	FlushInstructionCache(thisProcess, global.addressOf.findDLLPluginsCall, 5);

	return true;
}


pragma(inline, false)
void setUpBeforeSKSEPluginsAreLoaded (ulong rcx) nothrow @nogc
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

	__ir_pure!(`call void asm sideeffect inteldialect "", "{rcx}" (i64 %0)`, void)(
		rcx
	);
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
		if (caseInsensitiveASCIIEquality!true(name, "stb_widgets".ptr, 11))
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


pragma(inline, false)
void hijackProvisionOfSKSE64ProviderWhenLoadingSKSEPlugin (scope ulong rcx, ulong rdx) nothrow @nogc
{
	static if (targetedGameVersion >= 0x01_06_000_0)
	{
		HMODULE dll = *cast(HMODULE*) (rdx + 0x20);
	}
	else
	{
		HMODULE dll = *cast(HMODULE*) rdx;
	}

	SKSE64Provider* provider = global.addressOf.globalSKSE64Provider;

	static if (observingPluginFileNameViaCall)
	{
		SpecialPlugin currentSpecialPlugin = global.currentSpecialPluginBeingLoaded;
	}
	else
	{
		const(DLLPlugin)* pluginBeingLoaded = *global.addressOf.sksePluginBeingLoaded;
		const(std_string)* dllName = &pluginBeingLoaded.filePath;
		SpecialPlugin currentSpecialPlugin = specialPluginFromDLLFileName(dllName.base, dllName.size);
	}

	final switch (currentSpecialPlugin)
	{
	case SpecialPlugin.none:
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
	__ir_pure!(`call void asm sideeffect inteldialect "", "{rcx},{rdx}" (ptr %0, i64 %1)`, void)(
		provider,
		rdx
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


bool isOutdatedSKSEVersion () (scope ref wchar[MAX_PATH + 60] stringBuffer, uint skse64Version, scope const(ubyte)* skseRData) nothrow @nogc
{
	uint versionOf (uint offset)
	{
		return (cast(const(SKSE64Provider)*) (skseRData + offset)).skse64Version;
	}

	static if (targetedGameArchetype == GameArchetype.se)
	{
		__gshared wchar[203] message = "Version 2.0.1x of SKSE has been detected. This version of SKSE is out-of-date and is not supported by the Save & Load Accelerator for SKSE Cosaves (S.L.A.C.K.).\r\nPlease update to version 2.0.20 of SKSE.\0";
		enum wstring url = "https://www.nexusmods.com/skyrimspecialedition/mods/30379?tab=files#file-expander-header-233411:~:text=2%2E0%2E20";

		if (versionOf(skse64v2_0_17_globalSKSE64Provider) == 0x02_00_011_0)
		{
			message[13] = '7';
		}
		else
		{
			uint version_ = versionOf(skse64v2_0_18_or_19_globalSKSE64Provider);

			if ((version_ == 0x02_00_012_0) | (version_ == 0x02_00_013_0))
			{
				message[13] = '8' + ((version_ >>> 4) & 1);
			}
			else
			{
				return false;
			}
		}
	}
	else static if (targetedGameArchetype == GameArchetype.vr)
	{
		__gshared wchar[203] message = "Version 2.0.xx of SKSE has been detected. This version of SKSE is out-of-date and is not supported by the Save & Load Accelerator for SKSE Cosaves (S.L.A.C.K.).\r\nPlease update to version 2.0.12 of SKSE.\0";
		enum wstring url = "https://www.nexusmods.com/skyrimspecialedition/mods/30457?tab=files#file-expander-header-499284:~:text=2%2E0%2E12,-Compatible";

		if (versionOf(skseVRv2_0_11_globalSKSE64Provider) == 0x02_00_00B_0)
		{
			message[12] = '1';
			message[13] = '1';
		}
		else
		{
			uint version_ = versionOf(skseVRv2_0_09_or_10_globalSKSE64Provider);

			if (version_ == 0x02_00_009_0)
			{
				message[12] = '0';
				message[13] = '9';
			}
			else if (version_ == 0x02_00_00A_0)
			{
				message[12] = '1';
				message[13] = '0';
			}
			else
			{
				return false;
			}
		}
	}
	else static if (targetedGameArchetype == GameArchetype.ae1130)
	{
		__gshared wchar[201] message = "Version 2.2.4 of SKSE has been detected. This version of SKSE is out-of-date and is not supported by the Save & Load Accelerator for SKSE Cosaves (S.L.A.C.K.).\r\nPlease update to version 2.2.5 of SKSE.\0";
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
		__gshared wchar[201] message = "Version 2.2.x of SKSE has been detected. This version of SKSE is out-of-date and is not supported by the Save & Load Accelerator for SKSE Cosaves (S.L.A.C.K.).\r\nPlease update to version 2.2.3 of SKSE.\0";
		/+ Having the text-fragment match on the upload time is kind of gross, but it's the only way (download count excepted) to disambiguate between the Steam and GOG versions. +/
		enum wstring url = "https://www.nexusmods.com/skyrimspecialedition/mods/30379?tab=files#file-expander-header-323365:~:text=8%3A09PM,2%2E2%2E3";

		uint version_ = versionOf(skse64v2_2_01_or_02_globalSKSE64Provider);

		if ((version_ == 0x02_02_001_0) | (version_ == 0x02_02_002_0))
		{
			message[12] = '2' - ((version_ >>> 4) & 1);
		}
		else
		{
			return false;
		}
	}
	else static if (targetedGameArchetype == GameArchetype.gog659)
	{
		__gshared wchar[207] message = "Version 2.2.2 of SKSE has been detected. This version of SKSE is out-of-date and is not supported by the Save & Load Accelerator for SKSE Cosaves (S.L.A.C.K.).\r\nPlease update to version 2.2.3 (GOG) of SKSE.\0";
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

	uint button = showMessageBox(message.ptr, errorDialogTitle.ptr, MB_OKCANCEL | MB_ICONHAND);

	if (button == IDOK)
	{
		openURL(url.ptr);
	}

	return true;
}

