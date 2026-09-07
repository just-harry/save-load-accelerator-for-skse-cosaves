
/+ SPDX-LICENSE-IDENTIFIER: 0BSD +/

module slack_mod.global;

import core.atomic : atomicExchange, atomicLoad, atomicStore, MemoryOrder;

import game;

import slack_common.algorithms;
import slack_common.bindings;
import slack_common.cpp;
import slack_common.dynamic_linking;
import slack_common.text;
import slack_common.threading;
import slack_common.user_interface;
import slack_mod.configuration;
import slack_mod.save_load;
import slack_mod.setup;

import skse64.dll_plugins;
import skse64.hacks.versioning;
import skse64.serialisation;


__gshared GlobalState global;


enum bool observingPluginFileNameViaCall = targetedGameVersion < 0x01_06_000_0;


struct GlobalState
{
	DynamicallyLinked linked;
	HMODULE dllModule;
	ulong performanceFrequency;
	double performanceFrequencyMillisecondMultiplier = 0;
	ubyte skseConsolePrintLock;
	bool haveWarnedUserAboutNearlyReachingSaveFileSizeLimit;
	bool haveSetUpSpecialSKSE64Providers;
	bool anyPluginCosaveHandlerThrewAnException;
	bool recoverableErrorsOccurred;
	bool unrecoverableErrorsOccurred;
align(8)
	ubyte inhibitLogFileFlushing;
	SpecialPlugin currentSpecialPluginBeingLoaded;

	SKSE64Provider specialSKSE64Provider;
	SerialisationProvider specialSerialisationProvider;

	ResolvedAddresses addressOf;
	ConfigurationLongLived configuration;
	uint logFileFlushElisionCounter;
	SaveLoadState saveLoad;

	static assert(__traits(isZeroInit, GlobalState));
	static assert((inhibitLogFileFlushing.offsetof & 7) == 0);
}


struct ResolvedAddresses
{
	std_vector!DLLPlugin* loadedSKSEPlugins;
	SKSE64Provider* globalSKSE64Provider;
	SerialisationProvider* globalSerialisationProvider;
	std_string* skseCosaveSavePath;
	std_vector!SerialisationStateForPlugin* cosaveAwarePlugins;

	static if (observingPluginFileNameViaCall)
	{
		ubyte* sksePluginFilePathCall;
	}
	else
	{
		static if (expectedSKSE64Version >= 0x02_02_007_0)
		{
			/+ As of SKSE64 v2.2.7, the address of the plugin currently being loaded
			   is never actually read, and so the optimiser has eliminated all of its writes.
			   In its stead we use the plugin's index. +/
			DLLPluginIndex* indexOfSKSEPluginBeingLoaded;
		}
		else
		{
			DLLPlugin** sksePluginBeingLoaded;
		}
	}

	void** skseLogFileStdioHandle;
	ubyte* supplySKSEProviderLEA;
	ubyte* supplySKSESaveCallbackLEA;
	ubyte* supplySKSELoadCallbackLEA;
	/+ The compiler emitted two copies of this instruction, for the VR version, for some reason. +/
	static if (targetedGameArchetype == GameArchetype.vr) ubyte* supplySKSELoadCallbackLEA1;
	ubyte* createSKSECosave;
	ubyte* restoreSKSECosave;
	ubyte* createSKSECosaveCall;
	ubyte* restoreSKSECosaveCall;
	ubyte* emitSaveMessageCall;
	extern(C++) ubyte function (uint, uint, size_t, uint, size_t) nothrow @nogc emitSaveMessageCallTarget;
	ubyte* emitPreLoadMessageCall;
	extern(C++) ubyte function (uint, uint, size_t, uint, size_t) nothrow @nogc emitPreLoadMessageCallTarget;
	ubyte* emitProLoadMessageCall;
	extern(C++) ubyte function (uint, uint, size_t, uint, size_t) nothrow @nogc emitProLoadMessageCallTarget;
	extern(C++) ubyte function (ulong rcx) skseSaveCallback;
	extern(C++) ubyte function (ulong rcx) skseLoadCallback;
	extern(C) void function (scope const(char)* format, ...) nothrow @nogc skseConsolePrint;
	extern(C) int function (scope void* file) nothrow @nogc skseFFlush;
	const(ubyte)* skseDLL;

	version (SLACKVerificationMode)
	{
		typeof(SerialisationProvider.beginRecord) skseSerialisationBeginRecord;
		typeof(SerialisationProvider.writeRecord) skseSerialisationWriteRecord;
		typeof(SerialisationProvider.writeRecordData) skseSerialisationWriteRecordData;
		typeof(SerialisationProvider.readNextRecordHeader) readNextRecordHeader;
		typeof(SerialisationProvider.readRecordData) readRecordData;
	}
}


struct DynamicallyLinked
{
	@"ntdll" .NtAllocateVirtualMemoryEx NtAllocateVirtualMemoryEx;

	@"ntdll" .RtlWaitOnAddress RtlWaitOnAddress;
	@"ntdll" .RtlWakeAddressAll RtlWakeAddressAll;
	@"ntdll" .RtlWakeAddressSingle RtlWakeAddressSingle;

	void linkAll () () scope
	{
		enum size_t count = this.tupleof.length;

		static foreach (index; 0 .. count)
		{
			static if (!is(typeof(mixin(__traits(getAttributes, this.tupleof[index])[0]))))
			{
				mixin("HMODULE ", __traits(getAttributes, this.tupleof[index])[0], ` = GetModuleHandleW("`, __traits(getAttributes, this.tupleof[index])[0], `.dll");`);
			}

			dynamicallyLinkInto(mixin(__traits(getAttributes, this.tupleof[index])[0]), __traits(identifier, this.tupleof[index]), &this.tupleof[index]);
		}

		debug
		{
			/+ Just to make sure the non-NtAllocateVirtualMemoryEx code-paths receive testing. +/
			this.NtAllocateVirtualMemoryEx = null;
		}
	}
}


enum SpecialPlugin : ubyte
{
	none,
	stbWidgets
}


extern(Windows)
int vectoredExceptionHandler () (scope EXCEPTION_POINTERS* exceptionInfo) @system nothrow @nogc
{
	const(EXCEPTION_RECORD)* record = exceptionInfo.ExceptionRecord;

	if (record.ExceptionCode != EXCEPTION_ACCESS_VIOLATION)
	{
		return EXCEPTION_CONTINUE_SEARCH;
	}

	alias Config = ConfigurationLongLived.Flags;

	const(void)* faultingAddress = cast(const(void)*) record.ExceptionInformation[1];
	uint error = void;

	if (global.configuration.flags & Config.accelerateSaving)
	{
		if (global.configuration.flags & Config.enableParallelSaving)
		{
			if (global.saveLoad.parallel.cosaveBuffer.encloses(faultingAddress))
			{
				size_t partition = global.saveLoad.parallel.cosaveBuffer.partitionOf(cast(const(ubyte)*) faultingAddress);
				ubyte commitBixponent = global.saveLoad.parallel.cosaveBufferCommitBixponent[partition];

				commitBixponent = greaterOf(commitBixponent, ubyte(18));

				if (commitBixponent >= global.saveLoad.parallel.cosaveBuffer.partitionBixponent)
				{
					reportErrorToUser("A partition of the parallel cosave buffer has exceeded its maximum size.\r\nTHE GAME IS NOT FULLY SAVED.");
					return EXCEPTION_CONTINUE_SEARCH;
				}

				++commitBixponent;

				ubyte* base = global.saveLoad.parallel.cosaveBuffer.baseOf(partition);
				size_t size = size_t(1) << commitBixponent;

				error = NtAllocateVirtualMemory(thisProcess, cast(void**) &base, 0, &size, MEM_COMMIT, PAGE_READWRITE);

				if (error)
				{
					wchar[128] stringBuffer = void;
					reportErrorToUser(stringBuffer, "A partition of the parallel cosave buffer failed to grow.\r\nTHE GAME IS NOT FULLY SAVED.", error);
					return EXCEPTION_CONTINUE_SEARCH;
				}

				global.saveLoad.parallel.cosaveBufferCommitBixponent[partition] = commitBixponent;

				return EXCEPTION_CONTINUE_EXECUTION;
			}
		}

		if (global.saveLoad.cosaveFileBuffer.encloses(faultingAddress))
		{
			if (global.saveLoad.cosaveFileBuffer.commit >= global.saveLoad.cosaveFileBuffer.tail)
			{
				reportErrorToUser("The cosave file buffer has exceeded its maximum size.\r\nTHE GAME IS NOT FULLY SAVED.");
				return EXCEPTION_CONTINUE_SEARCH;
			}

			if ((error = global.saveLoad.cosaveFileBuffer.expandCommit) != 0)
			{
				wchar[128] stringBuffer = void;
				reportErrorToUser(stringBuffer, "The cosave file buffer failed to grow.\r\nTHE GAME IS NOT FULLY SAVED.", error);
				return EXCEPTION_CONTINUE_SEARCH;
			}

			return EXCEPTION_CONTINUE_EXECUTION;
		}
	}

	return EXCEPTION_CONTINUE_SEARCH;
}


pragma(inline, true)
void acquireConsolePrintingLock () ()
{
acquireLock:
	if ((&global.skseConsolePrintLock).atomicExchange!(MemoryOrder.acq_rel)(ubyte(1)) == 0)
	{}
	else
	{
	wait:
		ubyte lock = global.skseConsolePrintLock.atomicLoad!(MemoryOrder.acq);

		if (lock != 0)
		{
			waitVia(&global.skseConsolePrintLock, lock);
			goto wait;
		}

		goto acquireLock;
	}
}


pragma(inline, true)
void releaseConsolePrintingLock () ()
{
	global.skseConsolePrintLock.atomicStore!(MemoryOrder.rel)(ubyte(0));
	wakeAllThreadsVia(&global.skseConsolePrintLock);
}


pragma(inline, true)
void threadSafeSKSEConsolePrint (Args...) (scope const(char)* format, scope auto ref Args arguments)
{
	acquireConsolePrintingLock;
	scope(exit) releaseConsolePrintingLock;
	global.addressOf.skseConsolePrint(format, arguments);
}

