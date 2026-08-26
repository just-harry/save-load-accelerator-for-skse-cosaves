
/+ SPDX-LICENSE-IDENTIFIER: 0BSD +/

module slack_mod.save_load;

import core.atomic : atomicExchange, atomicFetchAdd, atomicLoad, atomicStore, MemoryOrder;

import ldc.attributes : restrict;
import ldc.intrinsics : llvm_expect;
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
import slack_common.simd;
import slack_common.patching;
import slack_common.pe;
import slack_common.peb_access;
import slack_common.text;
import slack_common.threading;
import slack_common.tib_access;
import slack_common.user_interface;
import slack_mod.configuration;
import slack_mod.exception_wrapper;
import slack_mod.global;
import slack_mod.limits;

import skse64.dll_plugins;
import skse64.serialisation;
import skse64.hacks.versioning;
import skse64.hacks.offsets;


/+ I'm going to be frank with you. The naming isn't great here.
   Prepare yourself for a morass of state, states, plugins, and plugin state. +/


enum ulong specialStateSaverTag = ulong(1) << 62;


struct SaveLoadState
{
	Cosave.RecordHeader nullCosaveRecordHeader;
	ulong unpatchedSaveLoadTime;
	LargeAndLowOverheadSequentialBuffer cosaveFileBuffer;
	SaveLoadStateSerial serial;
	SaveLoadStateParallel parallel;

	version (SLACKVerificationMode)
	{
		char* verificationBase;
		char* verificationHead;
		char* verificationTail;
	}
}


struct SaveLoadStateSerial
{
	SaveLoadPluginState pluginState;
}


struct SaveLoadPluginState
{
	ubyte* head;
	ubyte* tail;
	Unaligned!(Cosave.RecordHeader)* currentRecordHeader;
	uint recordCount;

	pragma(inline, true)
	size_t size () const @property scope @safe pure nothrow @nogc
	{
		return this.tail - this.head;
	}
}


struct SaveLoadStateParallel
{
align(64)
	ThreadSignal threadSignal;
	ubyte threadCount;
	ubyte cosaveFileBufferLock;
	LargeAndLowOverheadPartitionedBuffer cosaveBuffer;
align(64)
	ubyte* cosaveFileHead;
	uint cosaveFilePluginsWithDataInCosaveCount;
align(8)
	ThreadBarrier!true threadBarrier;

	uint cosaveAwarePluginCount;
	uint cosaveAwarePluginIndex;

	ubyte[parallelSaveLoadThreadCountLimit] cosaveBufferCommitBixponent;
	HANDLE[parallelSaveLoadThreadCountLimit] threadHandles;

	CosaveAwarePluginStateForSaving[parallelCosaveAwarePluginCountLimit] cosaveAwarePluginsForSaving;

	struct ThreadSignal
	{
		enum ThreadSignal dormant = ThreadSignal(0);
		enum ThreadSignal savingCosave = ThreadSignal(1);

		uint value;
	}

	struct CosaveAwarePluginStateForSaving
	{
		SerialisationProvider.ProviderReceiver stateSaver;
		uint uniqueID;
		uint sparseIndex;
	}
}


struct ParallelSaveLoadThreadStack
{
	uint threadIndex;
	SaveLoadPluginState pluginState;
}


void writeCosaveHeader (scope Cosave.Header* header) nothrow @nogc
{
	header.signature = Cosave.Header.magic;
	header.schemaVersion = Cosave.Header.SchemaVersion.latest;
	header.skse64Version = expectedSKSE64Version;
	header.gameVersion = targetedGameVersion;
}


bool verifyCosaveHeader (scope const(Cosave.Header)* header) nothrow @nogc
{
	bool valid = true;

	if (header.signature != Cosave.Header.magic)
	{
		global.addressOf.skseConsolePrint("S.L.A.C.K. | The cosave's signature is invalid!");
		valid &= false;
	}

	if (header.schemaVersion == 0)
	{
		global.addressOf.skseConsolePrint("S.L.A.C.K. | The cosave's schema-version is invalid!");
		valid &= false;
	}
	else if (header.schemaVersion > Cosave.Header.SchemaVersion.latest)
	{
		global.addressOf.skseConsolePrint("S.L.A.C.K. | The cosave's schema-version is too new for S.L.A.C.K.!");
		valid &= false;
	}

	return valid;
}


struct Saving
{
	pragma(inline, true)
	static ubyte beginRecord (uint signature, uint schemaVersion, scope SaveLoadPluginState* pluginState) @trusted nothrow @nogc
	{
		ubyte* head = pluginState.head;
		pluginState.head += Cosave.RecordHeader.sizeof;
		Unaligned!(Cosave.RecordHeader)* header = unaligned(cast(Cosave.RecordHeader*) head);

		pluginState.currentRecordHeader.size = cast(uint) (
			head - cast(const(ubyte)*) &pluginState.currentRecordHeader[1]
		);

		pluginState.currentRecordHeader = header;

		header.signature = signature;
		header.schemaVersion = schemaVersion;

		++pluginState.recordCount;

		return true;
	}

	pragma(inline, true)
	static ubyte writeRecordData (scope const(void)* data, uint size, scope SaveLoadPluginState* pluginState) @system nothrow @nogc
	{
		ubyte* head = pluginState.head;
		pluginState.head += size;

		performanceCriticalBlit(head, cast(const(ubyte)*) data, size);

		return true;
	}

	pragma(inline, true)
	static ubyte writeRecord (
		uint signature,
		uint schemaVersion,
		scope const(void)* data, uint size,
		scope SaveLoadPluginState* pluginState
	) @system nothrow @nogc
	{
		ubyte* head = pluginState.head;
		pluginState.head += Cosave.RecordHeader.sizeof + size;
		Unaligned!(Cosave.RecordHeader)* header = unaligned(cast(Cosave.RecordHeader*) head);

		pluginState.currentRecordHeader.size = cast(uint) (
			head - cast(const(ubyte)*) &pluginState.currentRecordHeader[1]
		);

		pluginState.currentRecordHeader = header;

		header.signature = signature;
		header.schemaVersion = schemaVersion;

		++pluginState.recordCount;

		performanceCriticalBlit(head + Cosave.RecordHeader.sizeof, cast(const(ubyte)*) data, size);

		return true;
	}
}


struct SerialSaving
{
	static ubyte beginRecord (uint signature, uint schemaVersion) @trusted nothrow @nogc
	{
		return Saving.beginRecord(signature, schemaVersion, &global.saveLoad.serial.pluginState);
	}

	static ubyte writeRecordData (scope const(void)* data, uint size) @system nothrow @nogc
	{
		return Saving.writeRecordData(data, size, &global.saveLoad.serial.pluginState);
	}

	static ubyte writeRecord (uint signature, uint schemaVersion, scope const(void)* data, uint size) @system nothrow @nogc
	{
		return Saving.writeRecord(signature, schemaVersion, data, size, &global.saveLoad.serial.pluginState);
	}
}


struct ParallelSaving
{
	static ubyte beginRecord (uint signature, uint schemaVersion) @trusted nothrow @nogc
	{
		return Saving.beginRecord(signature, schemaVersion, &threadStack.pluginState);
	}

	static ubyte writeRecordData (scope const(void)* data, uint size) @system nothrow @nogc
	{
		return Saving.writeRecordData(data, size, &threadStack.pluginState);
	}

	static ubyte writeRecord (uint signature, uint schemaVersion, scope const(void)* data, uint size) @system nothrow @nogc
	{
		return Saving.writeRecord(signature, schemaVersion, data, size, &threadStack.pluginState);
	}

	pragma(inline, true)
	static ParallelSaveLoadThreadStack* threadStack () @system nothrow @nogc
	{
		/+ Refer to `parallelSaveLoadThreadProcedureEntry` for what's going on here. +/
		void* stackBase = readFromTIB!(void*, int(NT_TIB.StackBase.offsetof));
		return cast(ParallelSaveLoadThreadStack*) (stackBase - ParallelSaveLoadThreadStack.sizeof);
	}
}


struct Loading
{
	pragma(inline, true)
	static ubyte readNextRecordHeader (
		scope uint* signature,
		scope uint* schemaVersion,
		scope uint* size,
		scope SaveLoadPluginState* pluginState
	) @trusted nothrow @nogc
	{
		Unaligned!(Cosave.RecordHeader)* recordHeader = pluginState.currentRecordHeader;

		if (pluginState.recordCount == 0)
		{
			return false;
		}

		uint recordSize = recordHeader.size;

		--pluginState.recordCount;

		ubyte* recordData = cast(ubyte*) recordHeader + Cosave.RecordHeader.sizeof;

		Unaligned!(Cosave.RecordHeader)* nextRecordHeader = unaligned(
			cast(Cosave.RecordHeader*) (recordData + recordHeader.size)
		);

		if (cast(const(ubyte)*) nextRecordHeader > pluginState.tail)
		{
			pluginState.recordCount = 0;
			return false;
		}

		*signature = recordHeader.signature;
		*schemaVersion = recordHeader.schemaVersion;
		*size = recordHeader.size;

		pluginState.head = recordData;

		pluginState.currentRecordHeader = nextRecordHeader;

		pluginState.recordCount = (
			cast(const(ubyte)*) nextRecordHeader + Cosave.RecordHeader.sizeof <= pluginState.tail
			? pluginState.recordCount
			: 0
		);

		return true;
	}

	pragma(inline, true)
	static uint readRecordData (scope void* data, uint size, scope SaveLoadPluginState* pluginState) @system nothrow @nogc
	{
		assert(pluginState.head <= pluginState.tail);
		assert(pluginState.head <= cast(const(ubyte)*) pluginState.currentRecordHeader);

		size_t bytesRemaining = cast(const(ubyte)*) pluginState.currentRecordHeader - pluginState.head;
		uint bytesToCopy = cast(uint) lesserOf(bytesRemaining, size);

		performanceCriticalBlit(cast(ubyte*) data, pluginState.head, bytesToCopy);

		pluginState.head += bytesToCopy;

		return bytesToCopy;
	}
}


struct SerialLoading
{
	static ubyte readNextRecordHeader (scope uint* signature, scope uint* schemaVersion, scope uint* size) @trusted nothrow @nogc
	{
		return Loading.readNextRecordHeader(signature, schemaVersion, size, &global.saveLoad.serial.pluginState);
	}

	static uint readRecordData (scope void* data, uint size) @system nothrow @nogc
	{
		return Loading.readRecordData(data, size, &global.saveLoad.serial.pluginState);
	}
}


struct SpecialSaving
{
	static ubyte writeRecordData (scope const(void)* data, uint size) @system nothrow @nogc
	{
		size_t a = cast(size_t) data;
		bool isImpossibleAddress = (a < 64.KB) | (a >= size_t.max - 64.KB);

		if (isImpossibleAddress)
		{
			/+ We should consider logging something here,
			   if anything other than STB Widgets needs this special code. +/
			return handleInvalidCall(data, size);
		}

		return global.addressOf.globalSerialisationProvider.writeRecordData(data, size);
	}

	static ubyte writeRecord (uint signature, uint schemaVersion, scope const(void)* data, uint size) @system nothrow @nogc
	{
		global.addressOf.globalSerialisationProvider.beginRecord(signature, schemaVersion);

		size_t a = cast(size_t) data;
		bool isImpossibleAddress = (a < 64.KB) | (a >= size_t.max - 64.KB);

		if (isImpossibleAddress)
		{
			/+ We should consider logging something here,
			   if anything other than STB Widgets needs this special code. +/
			return handleInvalidCall(data, size);
		}

		return global.addressOf.globalSerialisationProvider.writeRecordData(data, size);
	}

	pragma(inline, false)
	static ubyte handleInvalidCall (scope const(void)* data, uint size) @trusted nothrow @nogc
	{
	align(16)
		ubyte[16] bunchaZeroes = 0;
		uint remaining = size;

		auto writeData = global.addressOf.globalSerialisationProvider.writeRecordData;

		while (remaining >= 16)
		{
			remaining -= 16;
			writeData(bunchaZeroes.ptr, 16);
		}

		if (remaining != 0)
		{
			writeData(bunchaZeroes.ptr, remaining);
		}

		return true;
	}
}


version (SLACKVerificationMode)
{
	struct VerifiedLoading
	{
		static ubyte readNextRecordHeader (scope uint* signature, scope uint* schemaVersion, scope uint* size) @trusted nothrow @nogc
		{
			ubyte result = global.addressOf.readNextRecordHeader(signature, schemaVersion, size);
			*global.saveLoad.verificationHead++ = 'H';
			*global.saveLoad.verificationHead++ = '\t';
			result.asHexInto(global.saveLoad.verificationHead[0 .. 2]); global.saveLoad.verificationHead += 2;
			*global.saveLoad.verificationHead++ = '\t';
			(*signature).asHexInto(global.saveLoad.verificationHead[0 .. 8]); global.saveLoad.verificationHead += 8;
			*global.saveLoad.verificationHead++ = '\t';
			(*schemaVersion).asHexInto(global.saveLoad.verificationHead[0 .. 8]); global.saveLoad.verificationHead += 8;
			*global.saveLoad.verificationHead++ = '\t';
			(*size).asHexInto(global.saveLoad.verificationHead[0 .. 8]); global.saveLoad.verificationHead += 8;
			*global.saveLoad.verificationHead++ = '\r';
			*global.saveLoad.verificationHead++ = '\n';
			return result;
		}

		static uint readRecordData (scope void* data, uint size) @system nothrow @nogc
		{
			uint result = global.addressOf.readRecordData(data, size);
			*global.saveLoad.verificationHead++ = 'D';
			*global.saveLoad.verificationHead++ = '\t';
			result.asHexInto(global.saveLoad.verificationHead[0 .. 8]); global.saveLoad.verificationHead += 8;
			*global.saveLoad.verificationHead++ = '\t';
			size.asHexInto(global.saveLoad.verificationHead[0 .. 8]); global.saveLoad.verificationHead += 8;

			version (SLACKVerificationModeExtended)
			{
				*global.saveLoad.verificationHead++ = '\t';
				blit(global.saveLoad.verificationHead, cast(const(char)*) data, result);
				global.saveLoad.verificationHead += result;
			}

			*global.saveLoad.verificationHead++ = '\r';
			*global.saveLoad.verificationHead++ = '\n';
			return result;
		}
	}
}


pragma(inline, true)
void performanceCriticalBlit (
	@restrict scope ubyte* destination,
	@restrict scope const(ubyte)* source,
	uint length
) @trusted pure nothrow @nogc
{
	alias V = __vector(ubyte[16]);

	uint remaining = length;
	ubyte* to = destination;
	const(ubyte)* from = source;

	while (remaining >= 16)
	{
		remaining -= 16;
		storeVector!V(to, loadVector!V(from));
		from += 16;
		to += 16;
	}

	while (remaining != 0)
	{
		--remaining;
		*to = *from;
		++from;
		++to;
	}
}


void allowPluginsToSaveWhenSKSEIsNotSaving () ()
{
	/+ Some SKSE plugins mistakenly call SKSE's saving routines when SKSE is not saving.
	   So to try and avert disaster when that happens, we'll put up some of the serial-saving state. +/

	ubyte* base = global.saveLoad.cosaveFileBuffer.base;
	ubyte* endOfData = base + Cosave.Header.sizeof;

	global.saveLoad.serial.pluginState.head = endOfData;

	ubyte* startOfPluginData = global.saveLoad.serial.pluginState.head;
	global.saveLoad.serial.pluginState.head += Cosave.DLLPluginHeader.sizeof;

	Unaligned!(Cosave.DLLPluginHeader)* currentPluginHeader = unaligned(cast(Cosave.DLLPluginHeader*) startOfPluginData);

	global.saveLoad.serial.pluginState.currentRecordHeader = unaligned(cast(Cosave.RecordHeader*) &currentPluginHeader[1]);
	global.saveLoad.serial.pluginState.recordCount = 0;
}


void allowPluginsToLoadWhenSKSEIsNotLoading () ()
{
	/+ Similarly, some SKSE plugins mistakenly call SKSE's loading routines when SKSE is not loading.
	   So to try and avert disaster when that happens, we'll put up some of the serial-loading state. +/

	global.saveLoad.serial.pluginState.head = global.saveLoad.cosaveFileBuffer.base + Cosave.Header.sizeof;
	global.saveLoad.serial.pluginState.tail = global.saveLoad.serial.pluginState.head;
	global.saveLoad.serial.pluginState.currentRecordHeader = unaligned(&global.saveLoad.nullCosaveRecordHeader);
	global.saveLoad.serial.pluginState.recordCount = 0;
}


/+ The serialisation-state array is a sparse-array wherein the index
   of the serialisation-state corresponds to the index of the parent DLL-plugin,
   but biased by one, because the serialisation-state for SKSE itself
   doesn't have a corresponding DLL-plugin/ +/
pragma(inline, true)
DLLPluginIndex dllPluginIndex () (scope const(SerialisationStateForPlugin)* plugin) nothrow @nogc
{
	return cast(DLLPluginIndex) ((plugin - global.addressOf.cosaveAwarePlugins.base) - 1);
}


pragma(inline, true)
DLLPlugin* dllPlugin () (DLLPluginIndex pluginIndex) nothrow @nogc
in (pluginIndex < global.addressOf.loadedSKSEPlugins.size)
{
	return global.addressOf.loadedSKSEPlugins.base + pluginIndex;
}


pragma(inline, true)
auto pluginStringsFromSerialisationStateIndex () (size_t sparseIndex) nothrow @nogc
{
	enum bool haveFilePath = __traits(compiles, DLLPlugin.filePath);

	static struct Result
	{
		const(char)* name;
		static if (haveFilePath) const(char)* filePath;
	}

	Result result = void;

	const(DLLPlugin)* dllPlugin = (cast(DLLPluginIndex) (sparseIndex - 1)).dllPlugin;

	bool isSKSE = sparseIndex == 0;

	result.name = isSKSE ? "SKSE".ptr : dllPlugin.metadata.name;

	static if (__traits(compiles, DLLPlugin.filePath))
	{
		result.filePath = isSKSE ? global.configuration.skseDLLNameUTF8.ptr : dllPlugin.filePath.base;
	}

	return result;
}


pragma(inline, true)
HANDLE createCosaveFile (scope ref char[1024] stringBuffer) @trusted nothrow @nogc
{
	const(char)* cosavePath = global.addressOf.skseCosaveSavePath.base;

	/+ There are non-error scenarios wherein the cosave path can be empty,
	   such as when the `ReloadScript` console command is invoked.
	   I doubt it will ever be null, but I shan't chance it. +/
	if (cosavePath == null || *cosavePath == '\0')
	{
		return INVALID_HANDLE_VALUE;
	}

	HANDLE cosaveFile = CreateFileA(
		cosavePath,
		GENERIC_READ | GENERIC_WRITE,
		FILE_SHARE_READ,
		null,
		CREATE_ALWAYS,
		FILE_ATTRIBUTE_NORMAL | FILE_FLAG_NO_BUFFERING | FILE_FLAG_WRITE_THROUGH,
		null
	);

	if (cosaveFile == INVALID_HANDLE_VALUE)
	{
		uint error = getLastError;

		char[] addendum = formatErrorWithCode(
			stringBuffer,
			"The cosave file could not be created!\r\nTHE GAME IS NOT FULLY SAVED.",
			hresultFromLastError(error)
		);

		assert(addendum.length >= 512);

		char* s = addendum.ptr;
		size_t spaceLeft = addendum.length - 1;

		if (error == ERROR_PATH_NOT_FOUND)
		{
			enum string message = "\r\n\r\n" ~ pathNotFoundErrorMessage!char;
			blit(s, message.ptr, message.length);
			s += message.length;
		}

		*s = '\0';

		reportErrorToUser(stringBuffer.ptr);
	}

	return cosaveFile;
}


pragma(inline, true)
bool savePluginData (bool parallel = false) (
	scope SaveLoadPluginState* pluginState,
	uint pluginUniqueID,
	scope SerialisationProvider.ProviderReceiver pluginStateSaver,
	scope ubyte** endOfData,
	uint sparseIndex,
	uint threadIndex
) nothrow @nogc
{
	/+ We preemptively account for the plugin-header--
	   we can just undo this if the plugin doesn't write anything. +/
	ubyte* startOfPluginData = pluginState.head;
	pluginState.head += Cosave.DLLPluginHeader.sizeof;

	Unaligned!(Cosave.DLLPluginHeader)* currentPluginHeader = unaligned(cast(Cosave.DLLPluginHeader*) startOfPluginData);

	pluginState.currentRecordHeader = unaligned(cast(Cosave.RecordHeader*) &currentPluginHeader[1]);
	pluginState.recordCount = 0;

	enum string consolePrint = parallel ? q{threadSafeSKSEConsolePrint} : q{global.addressOf.skseConsolePrint};

	enum string setUpCall =
	q{
		SerialisationProvider.ProviderReceiver detaggedStateSaver = cast(SerialisationProvider.ProviderReceiver) (
			cast(size_t) pluginStateSaver & ~specialStateSaverTag
		);

		SerialisationProvider* serialisationProvider = (
			  cast(size_t) pluginStateSaver == cast(size_t) detaggedStateSaver
			? global.addressOf.globalSerialisationProvider
			: &global.specialSerialisationProvider
		);
	};

	enum string call =
	q{
		bool exceptionWasThrown = false;

		if (global.configuration.flags & ConfigurationLongLived.Flags.errorFriendlyMode)
		{
			exceptionWasThrown = callThrowsException(serialisationProvider, detaggedStateSaver);
		}
		else
		{
			detaggedStateSaver(serialisationProvider);
		}
	};

	enum string exceptionErrorMessages =
	q{
		static if (__traits(compiles, strings.filePath))
		{
			mixin(consolePrint)(
				"S.L.A.C.K. | A SKSE plugin threw an exception whilst saving to the cosave. That plugin's data in the cosave may be corrupt. | Plugin data offset: %u | Plugin: %s [%s]",
				pluginDataOffset,
				strings.name,
				strings.filePath
			);
		}
		else
		{
			mixin(consolePrint)(
				"S.L.A.C.K. | A SKSE plugin threw an exception whilst saving to the cosave. That plugin's data in the cosave may be corrupt. | Plugin data offset: %u | Plugin: %s",
				pluginDataOffset,
				strings.name
			);
		}
	};

	mixin(setUpCall);

	/+ Might as well write it now whilst it's hot in the cache. +/
	currentPluginHeader.signature = pluginUniqueID;

	if ((global.configuration.flags & ConfigurationLongLived.Flags.profileSaving).llvm_expect(0))
	{
		static void profiledStateSaverCall (scope SerialisationProvider.ProviderReceiver pluginStateSaver, uint sparseIndex)
		{
			pragma(inline, false);

			mixin(setUpCall);

			ulong before = void;
			RtlQueryPerformanceCounter(cast(LARGE_INTEGER*) &before);

			mixin(call);

			ulong after = void;
			RtlQueryPerformanceCounter(cast(LARGE_INTEGER*) &after);

			double duration = cast(double) (after - before) * global.performanceFrequencyMillisecondMultiplier;

			auto strings = pluginStringsFromSerialisationStateIndex(sparseIndex);

			const(ParallelSaveLoadThreadStack)* threadStack = ParallelSaving.threadStack;
			uint threadIndex = threadStack.threadIndex;

			if (exceptionWasThrown.llvm_expect(false))
			{
				static if (parallel)
				{
					global.anyPluginCosaveHandlerThrewAnException.atomicStore!(MemoryOrder.rel)(true);

					const(ubyte)* cosaveBufferPartition = global.saveLoad.parallel.cosaveBuffer.baseOf(threadIndex);
					uint pluginDataOffset = cast(uint) (threadStack.pluginState.head - cosaveBufferPartition);
				}
				else
				{
					global.anyPluginCosaveHandlerThrewAnException = true;

					uint pluginDataOffset = cast(uint) (global.saveLoad.serial.pluginState.head - global.saveLoad.cosaveFileBuffer.base);
				}

				mixin(exceptionErrorMessages);
			}

			static if (__traits(compiles, strings.filePath))
			{
				static if (parallel)
				{
					threadSafeSKSEConsolePrint(
						"S.L.A.C.K. | Thread: %3u | Plugin save callback: %7.3f ms | Plugin: %s [%s]",
						threadIndex,
						duration,
						strings.name,
						strings.filePath
					);
				}
				else
				{
					global.addressOf.skseConsolePrint(
						"S.L.A.C.K. | Plugin save callback: %7.3f ms | Plugin: %s [%s]",
						duration,
						strings.name,
						strings.filePath
					);
				}
			}
			else
			{
				static if (parallel)
				{
					threadSafeSKSEConsolePrint(
						"S.L.A.C.K. | Thread: %3u | Plugin save callback: %7.3f ms | Plugin: %s",
						threadIndex,
						duration,
						strings.name
					);
				}
				else
				{
					global.addressOf.skseConsolePrint(
						"S.L.A.C.K. | Plugin save callback: %7.3f ms | Plugin: %s",
						duration,
						strings.name
					);
				}
			}
		}

		/+ An exlined call to keep the branch short for when profiling is disabled. +/
		profiledStateSaverCall(pluginStateSaver, sparseIndex);
	}
	else
	{
		mixin(call);

		if (exceptionWasThrown.llvm_expect(false))
		{
			static if (parallel)
			{
				global.anyPluginCosaveHandlerThrewAnException.atomicStore!(MemoryOrder.rel)(true);

				const(ubyte)* cosaveBufferPartition = global.saveLoad.parallel.cosaveBuffer.baseOf(threadIndex);
				uint pluginDataOffset = cast(uint) (pluginState.head - cosaveBufferPartition);
			}
			else
			{
				global.anyPluginCosaveHandlerThrewAnException = true;

				uint pluginDataOffset = cast(uint) (pluginState.head - global.saveLoad.cosaveFileBuffer.base);
			}

			auto strings = pluginStringsFromSerialisationStateIndex(sparseIndex);

			mixin(exceptionErrorMessages);
		}
	}

	*endOfData = pluginState.head;

	prefetchWrite(currentPluginHeader);

	if (pluginState.recordCount == 0)
	{
		/+ The plugin didn't write any data, so we'll pretend this never happened. +/
		pluginState.head = startOfPluginData;
		*endOfData = startOfPluginData;
		return false;
	}

	pluginState.currentRecordHeader.size = cast(uint) (
		*endOfData - cast(const(ubyte)*) &pluginState.currentRecordHeader[1]
	);

	currentPluginHeader.size = cast(uint) (
		*endOfData - cast(const(ubyte)*) &currentPluginHeader[1]
	);

	currentPluginHeader.recordCount = pluginState.recordCount;

	return true;
}


pragma(inline, true)
bool writeCosaveToFile (
	HANDLE cosaveFile,
	scope const(ubyte)* base,
	scope const(ubyte)* endOfData,
	scope ref char[1024] stringBuffer
) nothrow @nogc
{
	uint actualSize = cast(uint) (endOfData - base);
	uint writeSize = actualSize.alignUpTo(allocationGranularity);

	IO_STATUS_BLOCK ioStatusBlock = void;
	ulong startOfFile = 0;

	NTSTATUS error = NtWriteFile(
		cosaveFile,
		null,
		null,
		null,
		&ioStatusBlock,
		base,
		writeSize,
		cast(const(LARGE_INTEGER)*) &startOfFile,
		null
	);

	if (error)
	{
		char[] addendum = formatErrorWithCode(
			stringBuffer,
			"The cosave file could not be written to!\r\nTHE GAME IS NOT FULLY SAVED.",
			error
		);

		assert(addendum.length >= 512);

		char* s = addendum.ptr;
		size_t spaceLeft = addendum.length - 1;

		if (error == STATUS_DISK_FULL)
		{
			enum string message = "\r\n\r\nThis error indicates that the storage device doesn't have enough space for the cosave file.\r\n\r\nAlt+Tab out of the game, and try to free up some space on the disk that the game's saves' folder is located on, and then save the game again.";
			blit(s, message.ptr, message.length);
			s += message.length;
		}
		else if (error == STATUS_INVALID_USER_BUFFER)
		{
			enum string message = "\r\n\r\nThis error typically indicates that some other mod is interfering with S.L.A.C.K.'s vectored-exception-handler.\r\n\r\nPlease review your recently installed mods.\r\n\r\nOlder versions of Skyrim Crash Guard are known to cause this issue.";
			blit(s, message.ptr, message.length);
			s += message.length;
		}

		*s = '\0';

		reportErrorToUser(stringBuffer.ptr);

		return false;
	}

	FILE_END_OF_FILE_INFORMATION endOfFile = {EndOfFile: {QuadPart: actualSize}};

	error = NtSetInformationFile(
		cosaveFile,
		&ioStatusBlock,
		&endOfFile,
		endOfFile.sizeof,
		FILE_INFORMATION_CLASS.FileEndOfFileInformation
	);

	if (error)
	{
		reportErrorToUser(
			stringBuffer,
			"The cosave file could not be trimmed to its actual size.",
			error,
			MB_ICONWARNING
		);
		return false;
	}

	enum size_t maximumFileSize = maximumCosaveFileSize - minimumPageSize;
	enum size_t fileSizeWarningThreshold = maximumCosaveFileSize - 4.MB;

	if (actualSize >= fileSizeWarningThreshold)
	{
		if (!global.haveWarnedUserAboutNearlyReachingSaveFileSizeLimit)
		{
			global.haveWarnedUserAboutNearlyReachingSaveFileSizeLimit = true;
			static assert(maximumFileSize == 524_284.KB);
			reportErrorToUser("The cosave is very close to exceeding the maximum size of 524,284 KB!\r\nTo avoid a loss of progress, you may want to disable S.L.A.C.K., and then alert the author of S.L.A.C.K. so that the limit can be raised.", MB_ICONWARNING);
		}
	}

	return true;
}


void saveCosaveSerial () nothrow @nogc
{
	ulong[4] time = void;

	RtlQueryPerformanceCounter(cast(LARGE_INTEGER*) &time[0]);

	KPRIORITY originalThreadPriority = 8;
	NtQueryInformationThread(thisThread, THREADINFOCLASS.ThreadPriority, &originalThreadPriority, originalThreadPriority.sizeof, null);

	KPRIORITY highestNonRealtimeThreadPriority = 15;
	NtSetInformationThread(thisThread, THREADINFOCLASS.ThreadPriority, &highestNonRealtimeThreadPriority, highestNonRealtimeThreadPriority.sizeof);

	scope(exit) NtSetInformationThread(thisThread, THREADINFOCLASS.ThreadPriority, &originalThreadPriority, originalThreadPriority.sizeof);

	wchar[512] stringBuffer = void;

	HANDLE cosaveFile = createCosaveFile(cast(char[1024]) stringBuffer);

	if (cosaveFile == INVALID_HANDLE_VALUE)
	{
		return;
	}

	scope(exit) NtClose(cosaveFile);

	RtlQueryPerformanceCounter(cast(LARGE_INTEGER*) &time[1]);

	ubyte* base = global.saveLoad.cosaveFileBuffer.base;
	Cosave.Header* header = cast(Cosave.Header*) base;

	writeCosaveHeader(header);
	header.pluginsWithDataInCosaveCount = 0;

	ubyte* endOfData = base + Cosave.Header.sizeof;

	global.saveLoad.serial.pluginState.head = endOfData;
	global.anyPluginCosaveHandlerThrewAnException = false;

	std_vector!SerialisationStateForPlugin* dllPlugins = global.addressOf.cosaveAwarePlugins;

	for (size_t pluginIndex = 0; pluginIndex < dllPlugins.size; ++pluginIndex)
	{
		SerialisationStateForPlugin* plugin = &dllPlugins.base[pluginIndex];

		if ((plugin.stateSaver == null) | !plugin.uniqueIDHasBeenAssigned)
		{
			continue;
		}

		if (savePluginData(&global.saveLoad.serial.pluginState, plugin.uniqueID, plugin.stateSaver, &endOfData, cast(uint) pluginIndex, 0))
		{
			++header.pluginsWithDataInCosaveCount;
		}
	}

	allowPluginsToSaveWhenSKSEIsNotSaving;

	RtlQueryPerformanceCounter(cast(LARGE_INTEGER*) &time[2]);

	if (!writeCosaveToFile(cosaveFile, base, endOfData, cast(char[1024]) stringBuffer))
	{
		return;
	}

	RtlQueryPerformanceCounter(cast(LARGE_INTEGER*) &time[3]);

	if (global.configuration.flags & ConfigurationLongLived.Flags.logSaveTimingsToConsole)
	{
		global.addressOf.skseConsolePrint(
			"S.L.A.C.K. | Cosave save timing | Creating file: %7.3f ms | Plugin callbacks: %7.3f ms | Writing file: %7.3f ms | Total: %7.3f ms",
			cast(double) (time[1] - time[0]) * global.performanceFrequencyMillisecondMultiplier,
			cast(double) (time[2] - time[1]) * global.performanceFrequencyMillisecondMultiplier,
			cast(double) (time[3] - time[2]) * global.performanceFrequencyMillisecondMultiplier,
			cast(double) (time[3] - time[0]) * global.performanceFrequencyMillisecondMultiplier,
		);
	}

	if (global.anyPluginCosaveHandlerThrewAnException)
	{
		global.addressOf.skseConsolePrint("S.L.A.C.K. | Errors occurred whilst saving the cosave! Please examine the previous lines of the console.");
	}
}


void saveCosaveParallel () nothrow @nogc
{
	pragma(inline, true) static ref threadSignal () {return global.saveLoad.parallel.threadSignal;}

	ulong[4] time = void;

	RtlQueryPerformanceCounter(cast(LARGE_INTEGER*) &time[0]);

	wchar[512] stringBuffer = void;

	HANDLE cosaveFile = createCosaveFile(cast(char[1024]) stringBuffer);

	if (cosaveFile == INVALID_HANDLE_VALUE)
	{
		return;
	}

	scope(exit) NtClose(cosaveFile);

	RtlQueryPerformanceCounter(cast(LARGE_INTEGER*) &time[1]);

	ubyte* base = global.saveLoad.cosaveFileBuffer.base;
	Cosave.Header* header = cast(Cosave.Header*) base;

	/+ We have to rewrite the constant header because it may have been
	   overwritten by a cosave file load. +/
	writeCosaveHeader(header);

	global.saveLoad.parallel.cosaveFilePluginsWithDataInCosaveCount = 0;

	/+ The first cosave-aware plugin is actually an entry for SKSE's internal
	   save/load handlers; SKSE's data needs to be loaded before any other plugin's
	   data, for other plugins will rely on the state that SKSE loads.
	   To ensure that this can be done, we handle the first plugin serially
	   so that SKSE's data is always at the beginning of the file. +/

	ubyte* endOfData = base + Cosave.Header.sizeof;

	global.saveLoad.serial.pluginState.head = endOfData;

	const(std_vector!SerialisationStateForPlugin)* dllPluginVector = global.addressOf.cosaveAwarePlugins;
	const(SerialisationStateForPlugin)* dllPlugins = dllPluginVector.base;
	size_t dllPluginCount = dllPluginVector.tail - dllPlugins;

	if (dllPluginCount >= 1)
	{
		const(SerialisationStateForPlugin)* plugin = dllPlugins;

		if ((plugin.stateSaver != null) & plugin.uniqueIDHasBeenAssigned)
		{
			if (savePluginData(&global.saveLoad.serial.pluginState, plugin.uniqueID, plugin.stateSaver, &endOfData, 0, 0))
			{
				++global.saveLoad.parallel.cosaveFilePluginsWithDataInCosaveCount;
			}
		}
	}

	SerialisationProvider* serialisationProvider = global.addressOf.globalSerialisationProvider;

	withRegionMadeWritable(
		cast(ubyte*) serialisationProvider,
		SerialisationProvider.sizeof,
		(scope ubyte* a, size_t s)
		{
			SerialisationProvider* serialisation = cast(SerialisationProvider*) a;

			serialisation.beginRecord.atomicStore!(MemoryOrder.rel)(&ParallelSaving.beginRecord);
			serialisation.writeRecord.atomicStore!(MemoryOrder.rel)(&ParallelSaving.writeRecord);
			serialisation.writeRecordData.atomicStore!(MemoryOrder.rel)(&ParallelSaving.writeRecordData);
		}
	);

	scope(exit)
	{
		withRegionMadeWritable(
			cast(ubyte*) serialisationProvider,
			SerialisationProvider.sizeof,
			(scope ubyte* a, size_t s)
			{
				SerialisationProvider* serialisation = cast(SerialisationProvider*) a;

				serialisation.beginRecord.atomicStore!(MemoryOrder.rel)(&SerialSaving.beginRecord);
				serialisation.writeRecord.atomicStore!(MemoryOrder.rel)(&SerialSaving.writeRecord);
				serialisation.writeRecordData.atomicStore!(MemoryOrder.rel)(&SerialSaving.writeRecordData);
			}
		);
	}

	uint retryCount = 0;
retry:
	global.anyPluginCosaveHandlerThrewAnException.atomicStore!(MemoryOrder.rel)(false);
	global.saveLoad.parallel.cosaveFileHead.atomicStore!(MemoryOrder.rel)(endOfData);

	ubyte threadCount = global.configuration.parallelSavingThreadCount;

	/+ Plus one because the first plugin is handled serially. +/
	global.saveLoad.parallel.cosaveAwarePluginIndex.atomicStore!(MemoryOrder.rel)(threadCount + 1);

	dllPluginVector = global.addressOf.cosaveAwarePlugins;
	dllPlugins = dllPluginVector.base.atomicLoad!(MemoryOrder.acq);
	dllPluginCount = dllPluginVector.tail.atomicLoad!(MemoryOrder.acq) - dllPlugins;

	/+ There's nothing preventing a SKSE plugin from mutating the cosave-aware plugin state
	   from within its own state-saver.
	   Which means that accessing the DLL-plugin vector isn't thread-safe.
	   Such a happening, of course, is very unlikely--but likelihoods have a tendency to bite.

	   To guarantee thread-safety, and to help ensure consistency of the resulting cosave,
	   we make our own copy of the DLL-plugin vector, and then after making the cosave
	   (but before writing it to the file), we check to see if the DLL-plugin vector changed
	   during the saving--if it did change, then we retry, in the hopes that the vector
	   won't change again. +/

	uint cosaveAwarePluginCount = 1;

	for (size_t pluginIndex = 1;;)
	{
		if (pluginIndex >= dllPluginCount)
		{
			break;
		}

		const(SerialisationStateForPlugin)* dllPlugin = dllPlugins + pluginIndex;

		++pluginIndex;

		if ((dllPlugin.stateSaver == null) | !dllPlugin.uniqueIDHasBeenAssigned)
		{
			continue;
		}

		if (cosaveAwarePluginCount >= parallelCosaveAwarePluginCountLimit)
		{
			static assert(parallelCosaveAwarePluginCountLimit == 512);
			reportErrorToUser("The cosave-aware plugin limit of 512, for parallel saving, has been exceeded.\r\nTHE GAME IS NOT FULLY SAVED.");
			return;
		}

		global.saveLoad.parallel.cosaveAwarePluginsForSaving[cosaveAwarePluginCount] = (
			SaveLoadStateParallel.CosaveAwarePluginStateForSaving(
				dllPlugin.stateSaver,
				dllPlugin.uniqueID,
				cast(uint) (pluginIndex - 1)
			)
		);

		++cosaveAwarePluginCount;
	}

	global.saveLoad.parallel.cosaveAwarePluginCount.atomicStore!(MemoryOrder.rel)(cosaveAwarePluginCount);

	threadSignal.atomicStore!(MemoryOrder.rel)(threadSignal.savingCosave);
	wakeAllThreadsVia(&threadSignal());
waitingForSaveToFinish:
	if (threadSignal.atomicLoad!(MemoryOrder.acq) == threadSignal.savingCosave)
	{
		waitVia(&threadSignal(), threadSignal.savingCosave);
		goto waitingForSaveToFinish;
	}

	assert(threadSignal.atomicLoad!(MemoryOrder.acq) == threadSignal.dormant);

	dllPluginVector = global.addressOf.cosaveAwarePlugins;
	dllPlugins = dllPluginVector.base.atomicLoad!(MemoryOrder.acq);
	dllPluginCount = dllPluginVector.tail.atomicLoad!(MemoryOrder.acq) - dllPlugins;

	size_t cosaveAwarePluginIndex = 1;

	for (size_t pluginIndex = 1;;)
	{
		if (pluginIndex >= dllPluginCount)
		{
			break;
		}

		const(SerialisationStateForPlugin)* dllPlugin = dllPlugins + pluginIndex;

		++pluginIndex;

		if ((dllPlugin.stateSaver == null) | !dllPlugin.uniqueIDHasBeenAssigned)
		{
			continue;
		}

		const(SaveLoadStateParallel.CosaveAwarePluginStateForSaving)* cosaveAwarePlugin = (
			global.saveLoad.parallel.cosaveAwarePluginsForSaving.ptr + cosaveAwarePluginIndex
		);

		++cosaveAwarePluginIndex;

		if (
			  (dllPlugin.stateSaver !is cosaveAwarePlugin.stateSaver)
			| (dllPlugin.uniqueID != cosaveAwarePlugin.uniqueID)
		)
		{
			goto cosaveAwarePluginsChangedDuringSaving;
		}
	}

	if (cosaveAwarePluginIndex != cosaveAwarePluginCount)
	{
	cosaveAwarePluginsChangedDuringSaving:
		++retryCount;
		goto retry;
	}

	header.pluginsWithDataInCosaveCount = global.saveLoad.parallel.cosaveFilePluginsWithDataInCosaveCount.atomicLoad!(MemoryOrder.acq);

	allowPluginsToSaveWhenSKSEIsNotSaving;

	RtlQueryPerformanceCounter(cast(LARGE_INTEGER*) &time[2]);

	endOfData = global.saveLoad.parallel.cosaveFileHead.atomicLoad!(MemoryOrder.acq);

	if (!writeCosaveToFile(cosaveFile, base, endOfData, cast(char[1024]) stringBuffer))
	{
		return;
	}

	RtlQueryPerformanceCounter(cast(LARGE_INTEGER*) &time[3]);

	if (global.configuration.flags & ConfigurationLongLived.Flags.logSaveTimingsToConsole)
	{
		global.addressOf.skseConsolePrint(
			"S.L.A.C.K. | Cosave parallel save timing | Threads used: %u | Retries required: %u | Creating file: %7.3f ms | Plugin callbacks: %7.3f ms | Writing file: %7.3f ms | Total: %7.3f ms",
			global.configuration.parallelSavingThreadCount,
			retryCount,
			cast(double) (time[1] - time[0]) * global.performanceFrequencyMillisecondMultiplier,
			cast(double) (time[2] - time[1]) * global.performanceFrequencyMillisecondMultiplier,
			cast(double) (time[3] - time[2]) * global.performanceFrequencyMillisecondMultiplier,
			cast(double) (time[3] - time[0]) * global.performanceFrequencyMillisecondMultiplier,
		);
	}

	if (global.anyPluginCosaveHandlerThrewAnException.atomicLoad!(MemoryOrder.acq))
	{
		global.addressOf.skseConsolePrint("S.L.A.C.K. | Errors occurred whilst saving the cosave! Please examine the previous lines of the console.");
	}
}


version (SLACKVerificationMode)
{
	void saveCosaveInVerificationMode () nothrow @nogc
	{
		SerialisationProvider* serialisationProvider = global.addressOf.globalSerialisationProvider;

		typeof(SerialisationProvider.beginRecord) beginRecord = void;
		typeof(SerialisationProvider.writeRecord) writeRecord = void;
		typeof(SerialisationProvider.writeRecordData) writeRecordData = void;

		withRegionMadeWritable(
			cast(ubyte*) serialisationProvider,
			SerialisationProvider.sizeof,
			(scope ubyte* a, size_t s)
			{
				SerialisationProvider* serialisation = cast(SerialisationProvider*) a;

				beginRecord = serialisation.beginRecord;
				writeRecord = serialisation.writeRecord;
				writeRecordData = serialisation.writeRecordData;

				serialisation.beginRecord = global.addressOf.skseSerialisationBeginRecord;
				serialisation.writeRecord = global.addressOf.skseSerialisationWriteRecord;
				serialisation.writeRecordData = global.addressOf.skseSerialisationWriteRecordData;
			}
		);

		(cast(void function () nothrow @nogc) global.addressOf.createSKSECosave)();

		withRegionMadeWritable(
			cast(ubyte*) serialisationProvider,
			SerialisationProvider.sizeof,
			(scope ubyte* a, size_t s)
			{
				SerialisationProvider* serialisation = cast(SerialisationProvider*) a;

				serialisation.beginRecord = beginRecord;
				serialisation.writeRecord = writeRecord;
				serialisation.writeRecordData = writeRecordData;
			}
		);

		std_string* cosavePath = global.addressOf.skseCosaveSavePath;
		*(cosavePath.base + cosavePath.size - 1) = 'a';

		if (global.configuration.flags & ConfigurationLongLived.Flags.enableParallelSaving)
		{
			saveCosaveParallel;
		}
		else
		{
			saveCosaveSerial;
		}
	}
}



extern(System)
NTSTATUS parallelSaveLoadThreadProcedureEntry () (scope void* contextPointer) nothrow @nogc
{
	/+ We use the top of each thread's stack as storage for super-fast thread-local variables. +/

	static assert(ParallelSaveLoadThreadStack.sizeof == 40);
	static assert(ParallelSaveLoadThreadStack.threadIndex.offsetof == 0);

	asm nothrow @nogc
	{
		naked;
		/+ ASLR offsets the stack-pointer from the stack-base within a 2KB range.
		   This is dumb. So we undo that. +/
		mov RSP, GS:[NT_TIB.StackBase.offsetof];
		lea RDX, [RSP - 40];
		mov [RDX], ECX;
		/+ This is a misaligned stack.
		   If the stack is properly aligned,
		   we experience bizarre stack corruption elsewhere.
		   I hate computers. +/
		sub RSP, 96;
		call _parallelSaveLoadThreadProcedure;
		add RSP, 96;
		ret;
	}
}


alias _parallelSaveLoadThreadProcedure = parallelSaveLoadThreadProcedure!();


extern(System)
noreturn parallelSaveLoadThreadProcedure () (scope void* contextPointer, scope ParallelSaveLoadThreadStack* threadStack) nothrow @nogc
{
	uint threadIndex = threadStack.threadIndex;

	ubyte parallelThreadCount = global.saveLoad.parallel.threadCount;
	ubyte saveThreadCount = global.configuration.parallelSavingThreadCount;

	ubyte* cosaveBufferPartition = global.saveLoad.parallel.cosaveBuffer.baseOf(threadIndex);

	static assert(parallelSaveLoadThreadCountLimit <= 999);
	wchar[32] threadNameBuffer = void;

	blit(threadNameBuffer.ptr, "S.L.A.C.K. Parallel Cosave #"w.ptr, 28);
	auto threadIndexText = threadIndex.asDecimal!wchar;
	const(wchar)[] threadIndexString = threadIndexText.unpadded;
	blit(threadNameBuffer.ptr + 28, threadIndexString.ptr, threadIndexString.length);
	*(threadNameBuffer.ptr + 28 + threadIndexString.length) = '\0';

	THREAD_NAME_INFORMATION threadName = {
		ThreadName: UNICODE_STRING.from(threadNameBuffer.ptr, 28 + threadIndexString.length)
	};
	NtSetInformationThread(thisThread, THREADINFOCLASS.ThreadNameInformation, &threadName, threadName.sizeof);

	pragma(inline, true) static ref threadSignal () {return global.saveLoad.parallel.threadSignal;}
resumeDormancy:
	KPRIORITY idleThreadPriority = 1;
	NtSetInformationThread(thisThread, THREADINFOCLASS.ThreadPriority, &idleThreadPriority, idleThreadPriority.sizeof);
dormant:
	SaveLoadStateParallel.ThreadSignal signal = threadSignal.atomicLoad!(MemoryOrder.acq);

	if (signal == threadSignal.dormant)
	{
		waitVia(&threadSignal(), signal);
		goto dormant;
	}

	KPRIORITY highestNonRealtimeThreadPriority = 15;
	NtSetInformationThread(thisThread, THREADINFOCLASS.ThreadPriority, &highestNonRealtimeThreadPriority, highestNonRealtimeThreadPriority.sizeof);

	if (signal == threadSignal.savingCosave)
	{
		ubyte threadCount = saveThreadCount;

		if (threadIndex >= threadCount)
		{
			goto threadIsFinishedWithCurrentSave;
		}

		uint cosaveAwarePluginCount = global.saveLoad.parallel.cosaveAwarePluginCount.atomicLoad!(MemoryOrder.acq);
		/+ Plus one because the first plugin is handled serially. +/
		uint cosaveAwarePluginIndex = threadIndex + 1;
		uint pluginsWithDataInCosaveCount = 0;
	tryForAnotherPlugin:
		if (cosaveAwarePluginIndex < cosaveAwarePluginCount)
		{
			threadStack.pluginState.head = cosaveBufferPartition;
			threadStack.pluginState.currentRecordHeader = unaligned(cast(Cosave.RecordHeader*) cosaveBufferPartition);
			threadStack.pluginState.recordCount = 0;

			ubyte* endOfData = void;

			const(SaveLoadStateParallel.CosaveAwarePluginStateForSaving)* plugin = (
				&global.saveLoad.parallel.cosaveAwarePluginsForSaving[cosaveAwarePluginIndex]
			);

			if (savePluginData!true(&threadStack.pluginState, plugin.uniqueID, plugin.stateSaver, &endOfData, plugin.sparseIndex, threadIndex))
			{
				uint sizeOfData = cast(uint) (endOfData - cosaveBufferPartition);
				ubyte* dataInFile = global.saveLoad.parallel.cosaveFileHead.atomicFetchAdd!(MemoryOrder.acq_rel)(sizeOfData);
				ubyte* requiredCommit = dataInFile + sizeOfData;
			ensureCosaveFileBufferHasEnoughSpace:
				if (global.saveLoad.cosaveFileBuffer.commit.atomicLoad!(MemoryOrder.acq) < requiredCommit)
				{
					if (!growCosaveFileBufferThreadSafely(requiredCommit))
					{
						goto threadIsFinishedWithCurrentSave;
					}

					goto ensureCosaveFileBufferHasEnoughSpace;
				}

				performanceCriticalBlit(dataInFile, cosaveBufferPartition, sizeOfData);

				++pluginsWithDataInCosaveCount;
			}

			cosaveAwarePluginIndex = global.saveLoad.parallel.cosaveAwarePluginIndex.atomicFetchAdd!(MemoryOrder.acq_rel)(1);

			goto tryForAnotherPlugin;
		}

		global.saveLoad.parallel.cosaveFilePluginsWithDataInCosaveCount.atomicFetchAdd!(MemoryOrder.acq_rel)(
			pluginsWithDataInCosaveCount
		);
	}
threadIsFinishedWithCurrentSave:
	if (global.saveLoad.parallel.threadBarrier.twoStageRam(parallelThreadCount))
	{
		/+ Last to leave locks up. +/
		threadSignal.atomicStore!(MemoryOrder.rel)(threadSignal.dormant);
		global.saveLoad.parallel.threadBarrier.finishingBlow;
		wakeAllThreadsVia(&threadSignal());
	}

	goto resumeDormancy;
}


pragma(inline, false)
bool growCosaveFileBufferThreadSafely (scope const(ubyte)* requiredCommit) @trusted nothrow @nogc
{
	if ((&global.saveLoad.parallel.cosaveFileBufferLock).atomicExchange!(MemoryOrder.acq_rel)(ubyte(1)) == 0)
	{
		if (global.saveLoad.cosaveFileBuffer.commit >= global.saveLoad.cosaveFileBuffer.tail)
		{
			reportErrorToUser("The cosave file buffer has exceeded its maximum size.\r\nTHE GAME IS NOT FULLY SAVED.");
		cosaveFileBufferExpansionFailure:
			global.saveLoad.parallel.cosaveFileBufferLock.atomicStore!(MemoryOrder.rel)(ubyte(0));
			wakeAllThreadsVia(&global.saveLoad.parallel.cosaveFileBufferLock);
			return false;
		}

		size_t commitSize = requiredCommit - global.saveLoad.cosaveFileBuffer.base;
		commitSize = commitSize.roundUpToPowerOfTwo;

		NTSTATUS error = global.saveLoad.cosaveFileBuffer.expandCommitTo(commitSize);

		if (error)
		{
			wchar[128] stringBuffer = void;
			reportErrorToUser(stringBuffer, "The cosave file buffer failed to grow.\r\nTHE GAME IS NOT FULLY SAVED.", error);
			goto cosaveFileBufferExpansionFailure;
		}

		global.saveLoad.parallel.cosaveFileBufferLock.atomicStore!(MemoryOrder.rel)(ubyte(0));
		wakeAllThreadsVia(&global.saveLoad.parallel.cosaveFileBufferLock);
	}
	else
	{
	waitForCosaveFileBufferExpansion:
		ubyte lock = global.saveLoad.parallel.cosaveFileBufferLock.atomicLoad!(MemoryOrder.acq);

		if (lock != 0)
		{
			waitVia(&global.saveLoad.parallel.cosaveFileBufferLock, lock);
			goto waitForCosaveFileBufferExpansion;
		}
	}

	return true;
}


enum immutable(Char[]) pathNotFoundErrorMessage (Char) = (
	  "This error indicates that the game's saves' folder either does not exist, or is not accessible.\r\n\r\n"
	~ "Please ensure that your game's saves' folder exists, and is accessible by the current user of your operating system."
);


pragma(inline, true)
HANDLE openCosaveFile (scope ref char[1024] stringBuffer) @trusted nothrow @nogc
{
	const(char)* cosavePath = global.addressOf.skseCosaveSavePath.base;

	/+ Refer to the comment in `createCosaveFile` as for why we special-case empty paths. +/
	if (cosavePath == null || *cosavePath == '\0')
	{
		return INVALID_HANDLE_VALUE;
	}

	HANDLE cosaveFile = CreateFileA(
		cosavePath,
		GENERIC_READ,
		FILE_SHARE_READ,
		null,
		OPEN_EXISTING,
		FILE_ATTRIBUTE_NORMAL | FILE_FLAG_NO_BUFFERING | FILE_FLAG_WRITE_THROUGH,
		null
	);

	if (cosaveFile == INVALID_HANDLE_VALUE)
	{
		uint error = getLastError;

		char[] addendum = formatErrorWithCode(
			stringBuffer,
			"The cosave file could not be opened!\r\nTHE GAME IS NOT FULLY LOADED.",
			hresultFromLastError(error)
		);

		assert(addendum.length >= 512);

		char* s = addendum.ptr;
		size_t spaceLeft = addendum.length - 1;

		if (error == ERROR_FILE_NOT_FOUND)
		{
			enum string message = "\r\n\r\nThis error indicates that the cosave file either does not exist, or is not accessible.\r\n\r\nThe cosave is expected to be present with a file name of: \"";
			blit(s, message.ptr, message.length);
			s += message.length;
			spaceLeft -= message.length + 2;

			const(char)* path = global.addressOf.skseCosaveSavePath.base;
			const(char)* end = path + global.addressOf.skseCosaveSavePath.size;
			const(char)* p = end;

			for (; p > path;)
			{
				--p;
				if (*p == '\\') {++p; break;}
			}

			size_t nameSize = lesserOf(end - p, spaceLeft);
			blit(s, p, nameSize);
			s += nameSize;

			*s++ = '"';
			*s++ = '.';
		}
		else if (error == ERROR_PATH_NOT_FOUND)
		{
			enum string message = "\r\n\r\n" ~ pathNotFoundErrorMessage!char;
			blit(s, message.ptr, message.length);
			s += message.length;
		}

		*s = '\0';

		reportErrorToUser(stringBuffer.ptr);
	}

	return cosaveFile;
}


pragma(inline, true)
bool readCosaveFromFile (
	HANDLE cosaveFile,
	scope size_t* resultingFileSize,
	scope ref wchar[MAX_PATH] stringBuffer
) nothrow @nogc
{
	IO_STATUS_BLOCK ioStatusBlock0 = void;
	FILE_STANDARD_INFORMATION fileInfo = void;
	NTSTATUS error = NtQueryInformationFile(cosaveFile, &ioStatusBlock0, &fileInfo, fileInfo.sizeof, FILE_INFORMATION_CLASS.FileStandardInformation);

	if (error)
	{
		reportErrorToUser(
			stringBuffer,
			"The size of the cosave file could not be queried!\r\nTHE GAME IS NOT FULLY LOADED.",
			error
		);
		return false;
	}

	enum size_t maximumFileSize = maximumCosaveFileSize - minimumPageSize;

	size_t fileSize = fileInfo.EndOfFile;

	*resultingFileSize = fileSize;

	if (fileSize > maximumFileSize)
	{
		static assert(maximumFileSize == 524_284.KB);
		reportErrorToUser("The cosave has exceeded the maximum size of 524,284 KB!\r\nTHE GAME IS NOT FULLY LOADED.");
		return false;
	}

	if (fileSize < Cosave.Header.sizeof)
	{
		reportErrorToUser("The cosave is too small to be a valid cosave!");
		return false;
	}

	ubyte* requiredCommit = global.saveLoad.cosaveFileBuffer.base + fileSize;

	size_t commitSize = fileSize.roundUpToPowerOfTwo.alignUpTo(allocationGranularity);

	if (global.saveLoad.cosaveFileBuffer.commit < requiredCommit)
	{
		assert(global.saveLoad.cosaveFileBuffer.commit < global.saveLoad.cosaveFileBuffer.tail);

		if ((error = global.saveLoad.cosaveFileBuffer.expandCommitTo(fileSize.roundUpToPowerOfTwo)) != 0)
		{
			reportErrorToUser(stringBuffer, "The cosave file buffer failed to grow.\r\nTHE GAME IS NOT FULLY LOADED.", error);
			return false;
		}
	}

	IO_STATUS_BLOCK ioStatusBlock1 = void;
	ulong startOfFile = 0;

	error = NtReadFile(
		cosaveFile,
		null,
		null,
		null,
		&ioStatusBlock1,
		global.saveLoad.cosaveFileBuffer.base,
		cast(uint) commitSize,
		cast(const(LARGE_INTEGER)*) &startOfFile,
		null
	);

	if (error)
	{
		reportErrorToUser(
			stringBuffer,
			"The cosave file could not be read!\r\nTHE GAME IS NOT FULLY LOADED.",
			error
		);
		return false;
	}

	*resultingFileSize = ioStatusBlock1.Information;

	return true;
}


void loadCosaveSerial () nothrow @nogc
{
	ulong[4] time = void;

	RtlQueryPerformanceCounter(cast(LARGE_INTEGER*) &time[0]);

	KPRIORITY originalThreadPriority = 8;
	NtQueryInformationThread(thisThread, THREADINFOCLASS.ThreadPriority, &originalThreadPriority, originalThreadPriority.sizeof, null);

	KPRIORITY highestNonRealtimeThreadPriority = 15;
	NtSetInformationThread(thisThread, THREADINFOCLASS.ThreadPriority, &highestNonRealtimeThreadPriority, highestNonRealtimeThreadPriority.sizeof);

	scope(exit) NtSetInformationThread(thisThread, THREADINFOCLASS.ThreadPriority, &originalThreadPriority, originalThreadPriority.sizeof);

	wchar[512] stringBuffer = void;

	HANDLE cosaveFile = openCosaveFile(cast(char[1024]) stringBuffer);

	if (cosaveFile == INVALID_HANDLE_VALUE)
	{
		return;
	}

	scope(exit) NtClose(cosaveFile);

	RtlQueryPerformanceCounter(cast(LARGE_INTEGER*) &time[1]);

	size_t cosaveFileSize = void;

	if (!readCosaveFromFile(cosaveFile, &cosaveFileSize, stringBuffer[0 .. MAX_PATH]))
	{
		return;
	}

	prefetchWrite(global.addressOf.cosaveAwarePlugins);

	RtlQueryPerformanceCounter(cast(LARGE_INTEGER*) &time[2]);

	ubyte* base = global.saveLoad.cosaveFileBuffer.base;
	Cosave.Header* header = cast(Cosave.Header*) base;

	global.saveLoad.serial.pluginState.head = global.saveLoad.cosaveFileBuffer.base + Cosave.Header.sizeof;

	ubyte* endOfData = base + cosaveFileSize;

	if (!verifyCosaveHeader(header))
	{
		global.addressOf.skseConsolePrint("S.L.A.C.K. | The cosave may be invalid, but we're loading it anyway.");
	}

	uint remainingPluginCount = header.pluginsWithDataInCosaveCount;

	std_vector!SerialisationStateForPlugin* dllPlugins = global.addressOf.cosaveAwarePlugins;
	SerialisationStateForPlugin* plugins = dllPlugins.base;
	SerialisationStateForPlugin* pluginsEnd = dllPlugins.tail;
	SerialisationStateForPlugin* plugin = plugins;

	for (; plugin < pluginsEnd; ++plugin)
	{
		plugin.encounteredDataInLastLoadedSaveFile = false;
	}

	global.anyPluginCosaveHandlerThrewAnException = false;
	bool firstPluginIsPending = true;

	for (;;)
	{
		if (remainingPluginCount == 0)
		{
			break;
		}

		--remainingPluginCount;

		uint remainingBytes = cast(uint) (endOfData - global.saveLoad.serial.pluginState.head);

		if (remainingBytes < Cosave.DLLPluginHeader.sizeof)
		{
			reportErrorToUser("The SKSE cosave file contains data for fewer plugins than specified in the header!\r\nThis means your save is missing data.\r\nEither the file was damaged somehow, or the file was not saved properly.");
			break;
		}

		remainingBytes -= Cosave.DLLPluginHeader.sizeof;

		auto pluginHeader = unaligned(cast(Cosave.DLLPluginHeader*) global.saveLoad.serial.pluginState.head);

		if (remainingBytes < pluginHeader.size)
		{
			reportErrorToUser("The SKSE cosave file is truncated, for the current plugin's header specifies more data than is in the file!\r\nThis means your save is missing data.\r\nEither the file was damaged somehow, or the file was not saved properly.");
		}

		uint pluginDataSize = lesserOf(pluginHeader.size, remainingBytes);
		uint pluginUniqueID = pluginHeader.signature;

		global.saveLoad.serial.pluginState.head += Cosave.DLLPluginHeader.sizeof;
		global.saveLoad.serial.pluginState.tail = global.saveLoad.serial.pluginState.head + pluginDataSize;

		global.saveLoad.serial.pluginState.currentRecordHeader = unaligned(cast(Cosave.RecordHeader*) global.saveLoad.serial.pluginState.head);

		global.saveLoad.serial.pluginState.head += Cosave.RecordHeader.sizeof;

		global.saveLoad.serial.pluginState.head = lesserOf(
			global.saveLoad.serial.pluginState.head,
			global.saveLoad.serial.pluginState.tail
		);

		global.saveLoad.serial.pluginState.recordCount = (
			  remainingBytes >= Cosave.RecordHeader.sizeof
			? pluginHeader.recordCount
			: 0
		);

		if ((pluginUniqueID == 0) & !firstPluginIsPending)
		{
			reportErrorToUser("The SKSE cosave file contains data for a plugin with a unique-ID of 0: that ID is reserved for SKSE's internal use, so that data is being ignored.\r\nEither the file is damaged, or was not saved properly.");
			global.saveLoad.serial.pluginState.head = global.saveLoad.serial.pluginState.tail;
			continue;
		}
		else if ((pluginUniqueID != 0) & firstPluginIsPending)
		{
			reportErrorToUser("The SKSE cosave file begins with data for a plugin with a unique-ID that is not 0: SKSE's internal data is supposed to come first in the file, but it hasn't, and so this cosave is likely invalid.");
		}

		firstPluginIsPending = false;

		plugins = dllPlugins.base;
		pluginsEnd = dllPlugins.tail;
		plugin = plugins;

		for (; plugin < pluginsEnd; ++plugin)
		{
			if ((plugin.uniqueID == pluginUniqueID) & plugin.uniqueIDHasBeenAssigned)
			{
				goto foundPlugin;
			}
		}

		global.addressOf.skseConsolePrint(
			"S.L.A.C.K. | The cosave contains data for a SKSE plugin with a unique-ID of %08X, but that plugin is not loaded. The data is being ignored.",
			pluginUniqueID
		);

		global.saveLoad.serial.pluginState.head = global.saveLoad.serial.pluginState.tail;

		continue;
	foundPlugin:
		plugin.encounteredDataInLastLoadedSaveFile = true;

		if (plugin.stateLoader != null)
		{
			enum string call =
			q{
				bool exceptionWasThrown = false;

				if (global.configuration.flags & ConfigurationLongLived.Flags.errorFriendlyMode)
				{
					exceptionWasThrown = callThrowsException(global.addressOf.globalSerialisationProvider, plugin.stateLoader);
				}
				else
				{
					plugin.stateLoader(global.addressOf.globalSerialisationProvider);
				}
			};

			enum string exceptionErrorMessages =
			q{
				static if (__traits(compiles, strings.filePath))
				{
					global.addressOf.skseConsolePrint(
						"S.L.A.C.K. | A SKSE plugin threw an exception whilst loading from the cosave. That plugin's current state may be invalid. | Plugin data offset: %u | Plugin: %s [%s]",
						pluginDataOffset,
						strings.name,
						strings.filePath
					);
				}
				else
				{
					global.addressOf.skseConsolePrint(
						"S.L.A.C.K. | A SKSE plugin threw an exception whilst loading from the cosave. That plugin's current state may be invalid. | Plugin data offset: %u | Plugin: %s",
						pluginDataOffset,
						strings.name
					);
				}
			};

			if ((global.configuration.flags & ConfigurationLongLived.Flags.profileLoading).llvm_expect(0))
			{
				static void profiledStateLoaderCall (scope const(SerialisationStateForPlugin)* plugin)
				{
					pragma(inline, false);

					ulong before = void;
					RtlQueryPerformanceCounter(cast(LARGE_INTEGER*) &before);

					mixin(call);

					ulong after = void;
					RtlQueryPerformanceCounter(cast(LARGE_INTEGER*) &after);

					double duration = cast(double) (after - before) * global.performanceFrequencyMillisecondMultiplier;

					auto strings = pluginStringsFromSerialisationStateIndex(plugin - global.addressOf.cosaveAwarePlugins.base);

					if (exceptionWasThrown.llvm_expect(false))
					{
						global.anyPluginCosaveHandlerThrewAnException = true;

						uint pluginDataOffset = cast(uint) (global.saveLoad.serial.pluginState.head - global.saveLoad.cosaveFileBuffer.base);

						mixin(exceptionErrorMessages);
					}

					static if (__traits(compiles, strings.filePath))
					{
						global.addressOf.skseConsolePrint(
							"S.L.A.C.K. | Plugin load callback: %7.3f ms | Plugin: %s [%s]",
							duration,
							strings.name,
							strings.filePath
						);
					}
					else
					{
						global.addressOf.skseConsolePrint(
							"S.L.A.C.K. | Plugin load callback: %7.3f ms | Plugin: %s",
							duration,
							strings.name
						);
					}
				}

				/+ An exlined call to keep the branch short for when profiling is disabled. +/
				profiledStateLoaderCall(plugin);
			}
			else
			{
				mixin(call);

				if (exceptionWasThrown.llvm_expect(false))
				{
					global.anyPluginCosaveHandlerThrewAnException = true;

					uint pluginDataOffset = cast(uint) (global.saveLoad.serial.pluginState.head - global.saveLoad.cosaveFileBuffer.base);

					auto strings = pluginStringsFromSerialisationStateIndex(plugin - global.addressOf.cosaveAwarePlugins.base);

					mixin(exceptionErrorMessages);
				}
			}
		}

		ubyte* nextPluginHeader = lesserOf(
			cast(ubyte*) pluginHeader + Cosave.DLLPluginHeader.sizeof + pluginHeader.size,
			endOfData
		);

		if (global.saveLoad.serial.pluginState.head < nextPluginHeader)
		{
			const(ubyte)* pluginData = cast(const(ubyte)*) pluginHeader + Cosave.DLLPluginHeader.sizeof;

			auto strings = pluginStringsFromSerialisationStateIndex(plugin - global.addressOf.cosaveAwarePlugins.base);

			static if (__traits(compiles, strings.filePath))
			{
				global.addressOf.skseConsolePrint(
					"S.L.A.C.K. | The SKSE plugin with a unique-ID of %08X has left some data in the cosave unread. This may indicate a bug in the plugin. | Offset relative to plugin data: %u | Plugin data size: %u | Plugin: %s [%s]",
					pluginUniqueID,
					global.saveLoad.serial.pluginState.head - pluginData,
					nextPluginHeader - pluginData,
					strings.name,
					strings.filePath
				);
			}
			else
			{
				global.addressOf.skseConsolePrint(
					"S.L.A.C.K. | The SKSE plugin with a unique-ID of %08X has left some data in the cosave unread. This may indicate a bug in the plugin. | Offset relative to plugin data: %u | Plugin data size: %u | Plugin: %s",
					pluginUniqueID,
					global.saveLoad.serial.pluginState.head - pluginData,
					nextPluginHeader - pluginData,
					strings.name
				);
			}
		}

		global.saveLoad.serial.pluginState.head = nextPluginHeader;
	}

	global.saveLoad.serial.pluginState.currentRecordHeader = unaligned(&global.saveLoad.nullCosaveRecordHeader);
	global.saveLoad.serial.pluginState.recordCount = 0;

	for (size_t pluginIndex = 0; pluginIndex < dllPlugins.size; ++pluginIndex)
	{
		plugin = &dllPlugins.base[pluginIndex];

		if ((plugin.stateLoader != null) & !plugin.encounteredDataInLastLoadedSaveFile)
		{
			plugin.stateLoader(global.addressOf.globalSerialisationProvider);
		}
	}

	allowPluginsToLoadWhenSKSEIsNotLoading;

	RtlQueryPerformanceCounter(cast(LARGE_INTEGER*) &time[3]);

	if (global.configuration.flags & ConfigurationLongLived.Flags.logLoadTimingsToConsole)
	{
		global.addressOf.skseConsolePrint(
			"S.L.A.C.K. | Cosave load timing | Opening file: %7.3f ms | Reading file: %7.3f ms | Plugin callbacks: %7.3f ms | Total: %7.3f ms",
			cast(double) (time[1] - time[0]) * global.performanceFrequencyMillisecondMultiplier,
			cast(double) (time[2] - time[1]) * global.performanceFrequencyMillisecondMultiplier,
			cast(double) (time[3] - time[2]) * global.performanceFrequencyMillisecondMultiplier,
			cast(double) (time[3] - time[0]) * global.performanceFrequencyMillisecondMultiplier,
		);
	}

	if (global.anyPluginCosaveHandlerThrewAnException)
	{
		global.addressOf.skseConsolePrint("S.L.A.C.K. | Errors occurred whilst loading the cosave! Please examine the previous lines of the console.");
	}
}


version (SLACKVerificationMode)
{
	void callLoadCosaveInVerificationMode () nothrow @nogc
	{
		global.saveLoad.verificationHead = global.saveLoad.verificationBase;

		(cast(void function () nothrow @nogc) global.addressOf.restoreSKSECosave)();

		std_string* cosavePath = global.addressOf.skseCosaveSavePath;
		*(cosavePath.base + cosavePath.size - 1) = 'l';

		wchar[512] stringBuffer = void;

		HANDLE verificationLog = createCosaveFile(cast(char[1024]) stringBuffer);

		if (verificationLog == INVALID_HANDLE_VALUE)
		{
			return;
		}

		scope(exit) NtClose(verificationLog);

		uint actualSize = cast(uint) (global.saveLoad.verificationHead - global.saveLoad.verificationBase);
		uint writeSize = actualSize.alignUpTo(allocationGranularity);

		IO_STATUS_BLOCK ioStatusBlock = void;
		ulong startOfFile = 0;

		NtWriteFile(
			verificationLog,
			null,
			null,
			null,
			&ioStatusBlock,
			global.saveLoad.verificationBase,
			writeSize,
			cast(const(LARGE_INTEGER)*) &startOfFile,
			null
		);

		FILE_END_OF_FILE_INFORMATION endOfFile = {EndOfFile: {QuadPart: actualSize}};

		NtSetInformationFile(
			verificationLog,
			&ioStatusBlock,
			&endOfFile,
			endOfFile.sizeof,
			FILE_INFORMATION_CLASS.FileEndOfFileInformation
		);
	}
}


void logUnpatchedSaveLoadTimingBefore () nothrow @nogc
{
	RtlQueryPerformanceCounter(cast(LARGE_INTEGER*) &global.saveLoad.unpatchedSaveLoadTime);
}


void logUnpatchedSaveLoadTimingAfter (scope immutable(char)* format) nothrow @nogc
{
	ulong time = void;
	RtlQueryPerformanceCounter(cast(LARGE_INTEGER*) &time);

	ulong duration = time - global.saveLoad.unpatchedSaveLoadTime;
	double durationInMilliseconds = cast(double) duration * global.performanceFrequencyMillisecondMultiplier;

	global.addressOf.skseConsolePrint(format, durationInMilliseconds);
}


void logUnpatchedSaveTimingAfter () nothrow @nogc
{
	logUnpatchedSaveLoadTimingAfter("S.L.A.C.K. | Unpatched cosave save timing | Total: %7.3f ms");
}


void logUnpatchedLoadTimingAfter () nothrow @nogc
{
	logUnpatchedSaveLoadTimingAfter("S.L.A.C.K. | Unpatched cosave load timing | Total: %7.3f ms");
}

