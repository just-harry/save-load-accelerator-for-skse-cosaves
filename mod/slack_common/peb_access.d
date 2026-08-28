
/+ SPDX-LICENSE-IDENTIFIER: 0BSD +/

module slack_common.peb_access;

import slack_common.bindings;
import slack_common.tib_access;


version (Windows)
{
	pragma(inline, true)
	PEB* getPEB () @trusted nothrow @nogc
	{
		return cast(PEB*) readFromTIB!(void*, pointerAndByteOffset(12, 0));
	}


	struct PEB
	{
		BOOLEAN InheritedAddressSpace;
		BOOLEAN ReadImageFileExecOptions;
		BOOLEAN BeingDebugged;
		ubyte BitField;
		HANDLE Mutant;
		void* ImageBaseAddress;
		PEB_LDR_DATA* Ldr;
		RTL_USER_PROCESS_PARAMETERS* ProcessParameters;
		void* SubSystemData;
		void* ProcessHeap;
		RTL_CRITICAL_SECTION* FastPebLock;
		ubyte[208] filler0;
		RTL_CRITICAL_SECTION* LoaderLock;


		static assert(LoaderLock.offsetof == (size_t.sizeof > 4 ? 272 : 160));
	}


	struct PEB_LDR_DATA
	{
		uint Length;
		BOOLEAN Initialized;
		void* SsHandle;
		LIST_ENTRY InLoadOrderModuleList;
		LIST_ENTRY InMemoryOrderModuleList;
		LIST_ENTRY InInitializationOrderModuleList;
		void* EntryInProgress;
		BOOLEAN ShutdownInProgress;
		HANDLE ShutdownThreadId;
	}


	struct LDR_DATA_TABLE_ENTRY
	{
		LIST_ENTRY InLoadOrderLinks;
		LIST_ENTRY InMemoryOrderLinks;
		LIST_ENTRY InProgressLinks;
		alias InInitializationOrderLinks = InProgressLinks;
		void* DllBase;
		void* EntryPoint;
		uint SizeOfImage;
		UNICODE_STRING FullDllName;
		UNICODE_STRING BaseDllName;
	}


	struct RTL_USER_PROCESS_PARAMETERS
	{
		uint MaximumLength;
		uint Length;
		uint Flags;
		uint DebugFlags;
		HANDLE ConsoleHandle;
		uint ConsoleFlags;
		HANDLE StandardInput;
		HANDLE StandardOutput;
		HANDLE StandardError;
		CURDIR CurrentDirectory;
		UNICODE_STRING DllPath;
		UNICODE_STRING ImagePathName;
		UNICODE_STRING CommandLine;
		void* Environment;
		uint StartingX;
		uint StartingY;
		uint CountX;
		uint CountY;
		uint CountCharsX;
		uint CountCharsY;
		uint FillAttribute;
		uint WindowFlags;
		uint ShowWindowFlags;
		UNICODE_STRING WindowTitle;
		UNICODE_STRING DesktopInfo;
		UNICODE_STRING ShellInfo;
		UNICODE_STRING RuntimeData;
		RTL_DRIVE_LETTER_CURDIR[32] CurrentDirectores;
		size_t EnvironmentSize;
		size_t EnvironmentVersion;
		void* PackageDependencyData;
		uint ProcessGroupId;
		uint LoaderThreads;
		UNICODE_STRING RedirectionDllName;
		UNICODE_STRING HeapPartitionName;
		ulong* DefaultThreadpoolCpuSetMasks;
		uint DefaultThreadpoolCpuSetMaskCount;
		uint DefaultThreadpoolThreadMaximum;
	}


	struct CURDIR
	{
		UNICODE_STRING DosPath;
		HANDLE Handle;
	}


	struct RTL_DRIVE_LETTER_CURDIR
	{
		ushort Flags;
		ushort Length;
		uint TimeStamp;
		STRING DosPath;
	}
}

