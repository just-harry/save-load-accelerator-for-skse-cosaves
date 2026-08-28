
/+ SPDX-LICENSE-IDENTIFIER: 0BSD +/

module slack_common.bindings;


version (Windows)
{
	/+ Many thanks go towards all who have contributed to System Informer's headers for NT APIs,
	   likewise to m417z for indexing them in NtDoc. +/

	alias BOOL = uint;
	alias BOOLEAN = ubyte;
	alias HANDLE = void*;
	alias HINSTANCE = void*;
	alias HMODULE = void*;
	alias HWND = void*;
	alias HICON = void*;
	alias HRESULT = uint;
	alias NTSTATUS = uint;
	alias ACCESS_MASK = uint;


	enum const(void)* pseudoHandle = cast(const(void)*) -1;
	enum const(void)* INVALID_HANDLE_VALUE = pseudoHandle;
	enum const(void)* thisProcess = pseudoHandle;


	enum const(void)* thisThread = cast(const(void)*) -2;


	enum uint DLL_PROCESS_ATTACH = 1;
	enum uint DLL_THREAD_ATTACH = 2;
	enum uint DLL_THREAD_DETACH = 3;
	enum uint DLL_PROCESS_DETACH = 0;


	extern(Windows) BOOL DisableThreadLibraryCalls (scope HMODULE hLibModule) @safe nothrow @nogc;


	extern(Windows) HMODULE GetModuleHandleW (scope const(wchar)* lpModuleName) nothrow @nogc;
	extern(Windows) NTSTATUS LdrGetDllHandle (scope const(wchar)* DllPath, scope uint* DllCharacteristics, scope const(UNICODE_STRING)* DllName, scope HMODULE* DllHandle) nothrow @nogc;


	extern(Windows) HMODULE LoadLibraryW (scope const(wchar)* lpLibFileName) nothrow @nogc;
	extern(Windows) HMODULE LoadLibraryExW (scope const(wchar)* lpLibFileName, scope HANDLE hFile, uint dwFlags) nothrow @nogc;
	extern(Windows) BOOL FreeLibrary (scope HMODULE hLibModule) nothrow @nogc;
	extern(Windows) NTSTATUS LdrLoadDll (scope const(wchar)* DllPath, scope uint* DllCharacteristics, scope const(UNICODE_STRING)* DllName, scope HMODULE* DllHandle) nothrow @nogc;
	extern(Windows) NTSTATUS LdrUnloadDll (scope HMODULE DllHandle) nothrow @nogc;


	extern(Windows) NTSTATUS LdrGetProcedureAddress (scope HMODULE DllHandle, scope const(ANSI_STRING)* ProcedureName, ushort ProcedureNumber, scope void** ProcedureAddress) nothrow @nogc;
	extern(Windows) void* GetProcAddress (scope HMODULE hModule, scope const(char)* lpProcName) nothrow @nogc;


	extern(Windows) uint GetLastError () @trusted nothrow @nogc;


	extern(Windows) noreturn ExitProcess (uint uExitCode) @trusted nothrow @nogc;
	extern(Windows) noreturn RtlExitUserProcess (uint ExitStatus) @trusted nothrow @nogc;


	extern(Windows) NTSTATUS NtAllocateVirtualMemory (scope HANDLE ProcessHandle, scope void** BaseAddress, size_t ZeroBits, scope size_t* RegionSize, uint AllocationType, uint Protect) nothrow @nogc;
	extern(Windows) NTSTATUS NtFreeVirtualMemory (scope HANDLE ProcessHandle, scope void** BaseAddress, scope size_t* RegionSize, uint FreeType) nothrow @nogc;
	extern(Windows) NTSTATUS NtProtectVirtualMemory (scope HANDLE ProcessHandle, scope void** BaseAddress, scope size_t* RegionSize, uint NewProtection, scope uint* OldProtection) nothrow @nogc;
	extern(Windows) NTSTATUS NtFlushVirtualMemory (scope HANDLE ProcessHandle, scope void** BaseAddress, scope size_t* RegionSize, scope IO_STATUS_BLOCK* IoStatusBlock) nothrow @nogc;
	extern(Windows) NTSTATUS NtQueryVirtualMemory (scope HANDLE ProcessHandle, scope void* BaseAddress, MEMORY_INFORMATION_CLASS MemoryInformationClass, scope void* MemoryInformation, size_t MemoryInformationLength, scope size_t* ReturnLength) nothrow @nogc;


	extern(Windows) BOOL FlushInstructionCache (scope HANDLE hProcess, scope const(void)* lpBaseAddress, size_t dwSize) @trusted nothrow @nogc;


	extern(Windows) uint GetSystemDirectoryW (scope wchar* lpBuffer, uint uSize) nothrow @nogc;


	extern(Windows) void GetSystemInfo (scope SYSTEM_INFO* lpSystemInfo) @safe nothrow @nogc;


	extern(Windows) uint GetModuleFileNameW (scope HMODULE hModule, scope wchar* lpFilename, uint nSize) nothrow @nogc;
	extern(Windows) NTSTATUS LdrGetDllFullName (scope HMODULE DllHandle, scope UNICODE_STRING* FullDllName) nothrow @nogc;


	extern(Windows) NTSTATUS NtQueryInformationFile (scope HANDLE FileHandle, scope IO_STATUS_BLOCK* IoStatusBlock, scope void* FileInformation, uint Length, FILE_INFORMATION_CLASS FileInformationClass) nothrow @nogc;
	extern(Windows) NTSTATUS NtQueryDirectoryFile (HANDLE FileHandle, HANDLE Event, PIO_APC_ROUTINE ApcRoutine, void* ApcContext, IO_STATUS_BLOCK* IoStatusBlock, void* FileInformation, uint Length, FILE_INFORMATION_CLASS FileInformationClass, BOOLEAN ReturnSingleEntry, scope const(UNICODE_STRING)* FileName, BOOLEAN RestartScan) nothrow @nogc;


	extern(Windows) NTSTATUS NtClose (scope HANDLE Handle) @safe nothrow @nogc;


	extern(Windows) HANDLE CreateFileA (scope const(char)* lpFileName, uint dwDesiredAccess, uint dwShareMode, scope void* lpSecurityAttributes, uint dwCreationDisposition, uint dwFlagsAndAttributes, HANDLE hTemplateFile) nothrow @nogc;
	extern(Windows) HANDLE CreateFileW (scope const(wchar)* lpFileName, uint dwDesiredAccess, uint dwShareMode, scope void* lpSecurityAttributes, uint dwCreationDisposition, uint dwFlagsAndAttributes, HANDLE hTemplateFile) nothrow @nogc;
	extern(Windows) NTSTATUS NtOpenFile (scope HANDLE* FileHandle, ACCESS_MASK DesiredAccess, scope OBJECT_ATTRIBUTES* ObjectAttributes, IO_STATUS_BLOCK* IoStatusBlock, uint ShareAccess, uint OpenOptions) nothrow @nogc;


	extern(Windows) NTSTATUS NtWriteFile (HANDLE FileHandle, HANDLE Event, PIO_APC_ROUTINE ApcRoutine, void* ApcContext, IO_STATUS_BLOCK* IoStatusBlock, const(void)* Buffer, uint Length, scope const(LARGE_INTEGER)* ByteOffset, scope const(uint)* Key) nothrow @nogc;
	extern(Windows) NTSTATUS NtReadFile (HANDLE FileHandle, HANDLE Event, PIO_APC_ROUTINE ApcRoutine, void* ApcContext, IO_STATUS_BLOCK* IoStatusBlock, void* Buffer, uint Length, scope const(LARGE_INTEGER)* ByteOffset, scope const(uint)* Key) nothrow @nogc;


	extern(Windows) uint GetFileAttributesA (scope const(char)* lpFileName) nothrow @nogc;
	extern(Windows) uint GetFileAttributesW (scope const(wchar)* lpFileName) nothrow @nogc;


	extern(Windows) NTSTATUS NtSetInformationFile (scope HANDLE FileHandle, scope IO_STATUS_BLOCK* IoStatusBlock, scope void* FileInformation, uint Length, FILE_INFORMATION_CLASS FileInformationClass) nothrow @nogc;


	extern(Windows) NTSTATUS NtCreateSection (scope HANDLE* SectionHandle, ACCESS_MASK DesiredAccess, scope const(OBJECT_ATTRIBUTES)* ObjectAttributes, scope const(LARGE_INTEGER)* MaximumSize, uint SectionPageProtection, uint AllocationAttributes, scope HANDLE FileHandle) nothrow @nogc;
	extern(Windows) NTSTATUS NtMapViewOfSection (scope HANDLE SectionHandle, scope HANDLE ProcessHandle, scope void** BaseAddress, size_t ZeroBits, size_t CommitSize, scope LARGE_INTEGER* SectionOffset, scope size_t* ViewSize, uint InheritDisposition, uint AllocationType, uint Win32Protect) nothrow @nogc;
	extern(Windows) NTSTATUS NtUnmapViewOfSection (scope HANDLE ProcessHandle, scope void* BaseAddress) nothrow @nogc;


	extern(Windows) BOOL RtlQueryPerformanceCounter (scope LARGE_INTEGER* lpPerformanceCount) @safe nothrow @nogc;
	extern(Windows) BOOL RtlQueryPerformanceFrequency (scope LARGE_INTEGER* lpFrequency) @safe nothrow @nogc;


	extern(Windows) NTSTATUS NtQuerySystemTime (scope LARGE_INTEGER* SystemTime) @trusted nothrow @nogc;
	extern(Windows) NTSTATUS NtDelayExecution (BOOLEAN Alertable, scope LARGE_INTEGER* Interval) @trusted nothrow @nogc;


	extern(Windows) NTSTATUS NtWaitForSingleObject (HANDLE Handle, BOOLEAN Alertable, scope LARGE_INTEGER* Timeout) @trusted nothrow @nogc;


	extern(Windows) NTSTATUS NtCreateThreadEx (scope HANDLE* ThreadHandle, ACCESS_MASK DesiredAccess, scope const(OBJECT_ATTRIBUTES)* ObjectAttributes, HANDLE ProcessHandle, PUSER_THREAD_START_ROUTINE StartRoutine, void* Argument, uint CreateFlags, size_t ZeroBits, size_t StackSize, size_t MaximumStackSize, scope PS_ATTRIBUTE_LIST!()* AttributeList) @system nothrow @nogc;


	extern(Windows) NTSTATUS NtSetInformationThread (scope HANDLE ThreadHandle, THREADINFOCLASS ThreadInformationClass, scope void* ThreadInformation, uint ThreadInformationLength) @system nothrow @nogc;
	extern(Windows) NTSTATUS NtQueryInformationThread (scope HANDLE ThreadHandle, THREADINFOCLASS ThreadInformationClass, scope void* ThreadInformation, uint ThreadInformationLength, scope uint* ReturnLength) @system nothrow @nogc;


	extern(Windows) NTSTATUS RtlEnterCriticalSection (scope RTL_CRITICAL_SECTION* CriticalSection) @trusted nothrow @nogc;
	extern(Windows) NTSTATUS RtlLeaveCriticalSection (scope RTL_CRITICAL_SECTION* CriticalSection) @trusted nothrow @nogc;


	extern(Windows) uint GetActiveProcessorCount (ushort groupNumber) @safe nothrow @nogc;


	extern(Windows) void* RtlAddVectoredExceptionHandler (uint First, PVECTORED_EXCEPTION_HANDLER Handler) nothrow @nogc;
	extern(Windows) uint RtlRemoveVectoredExceptionHandler (scope void* Handle) nothrow @nogc;


	extern(Windows) HRESULT CoInitializeEx (scope void* pvReserved, uint dwCoInit) @trusted nothrow @nogc;
	extern(Windows) void CoUninitialize () @trusted nothrow @nogc;


	extern(Windows) HINSTANCE ShellExecuteW (HWND hwnd, scope const(wchar)* lpOperation, scope const(wchar)* lpFile, scope const(wchar)* lpParameters, scope const(wchar)* lpDirectory, int nShowCmd) nothrow @nogc;


	extern(Windows)
	{
		alias PUSER_THREAD_START_ROUTINE = NTSTATUS function (scope void* ThreadParameter) nothrow @nogc;
		alias PVECTORED_EXCEPTION_HANDLER = int function (scope EXCEPTION_POINTERS* exceptionInfo) nothrow @nogc;
		alias PLDR_DLL_NOTIFICATION_FUNCTION = void function (uint NotificationReason, scope const(LDR_DLL_NOTIFICATION_DATA)* NotificationData, void* context) nothrow @nogc;
	}

	extern(Windows)
	{
		alias LdrRegisterDllNotification = NTSTATUS function (uint Flags, PLDR_DLL_NOTIFICATION_FUNCTION NotificationFunction, void* Context, scope void** Cookie) nothrow @nogc;
		alias LdrUnregisterDllNotification = NTSTATUS function (scope void* Cookie) nothrow @nogc;


		alias NtAllocateVirtualMemoryEx = NTSTATUS function (scope HANDLE ProcessHandle, scope void** BaseAddress, scope size_t* RegionSize, uint AllocationType, uint PageProtection, scope MEM_EXTENDED_PARAMETER* ExtendedParameters, uint ExtendedParameterCount) nothrow @nogc;


		alias RtlWaitOnAddress = extern(Windows) NTSTATUS function (scope const(void)* Address, scope const(void)* CompareAddress, size_t AddressSize, scope const(LARGE_INTEGER)* Timeout) @system nothrow @nogc;
		alias RtlWakeAddressAll = extern(Windows) void function (scope const(void)* Address) @safe nothrow @nogc;
		alias RtlWakeAddressSingle = extern(Windows) void function (scope const(void)* Address) @safe nothrow @nogc;
	}


	enum uint MAX_PATH = 260;


	enum ushort ERROR_SUCCESS = 0;
	enum ushort ERROR_FILE_NOT_FOUND = 2;
	enum ushort ERROR_PATH_NOT_FOUND = 3;
	enum ushort ERROR_INSUFFICIENT_BUFFER = 122;
	enum ushort ERROR_NO_MORE_ITEMS = 259;


	enum NTSTATUS STATUS_SUCCESS = 0;
	enum NTSTATUS STATUS_BUFFER_OVERFLOW = 0x80000005;
	enum NTSTATUS STATUS_NO_MORE_FILES = 0x80000006;
	enum NTSTATUS STATUS_NO_SUCH_FILE = 0xC000000F;
	enum NTSTATUS STATUS_NO_MEMORY = 0xC0000017;
	enum NTSTATUS STATUS_DISK_FULL = 0xC000007F;
	enum NTSTATUS STATUS_INVALID_USER_BUFFER = 0xC00000E8;
	enum NTSTATUS STATUS_DLL_NOT_FOUND = 0xC0000135;


	pragma(inline, true)
	HRESULT hresultFromLastError () (uint lastError)
	{
		return 0x80070000 | cast(ushort) lastError;
	}


	union LARGE_INTEGER
	{
		alias QuadPart this;

		struct
		{
			uint LowPart;
			int HighPart;
		}

		long QuadPart;
	}


	enum uint THREAD_TERMINATE = 0x0001;
	enum uint THREAD_SUSPEND_RESUME = 0x0002;
	enum uint THREAD_GET_CONTEXT = 0x0008;
	enum uint THREAD_SET_CONTEXT = 0x0010;
	enum uint THREAD_QUERY_INFORMATION = 0x0040;
	enum uint THREAD_SET_INFORMATION = 0x0020;
	enum uint THREAD_SET_THREAD_TOKEN = 0x0080;
	enum uint THREAD_IMPERSONATE = 0x0100;
	enum uint THREAD_DIRECT_IMPERSONATION = 0x0200;
	enum uint THREAD_SET_LIMITED_INFORMATION = 0x0400;
	enum uint THREAD_QUERY_LIMITED_INFORMATION = 0x0800;
	enum uint THREAD_RESUME = 0x1000;


	enum uint THREAD_ALL_ACCESS = STANDARD_RIGHTS_REQUIRED | SYNCHRONIZE | 0xFFFF;


	enum uint THREAD_CREATE_FLAGS_CREATE_SUSPENDED = 0x00000001;
	enum uint THREAD_CREATE_FLAGS_SKIP_THREAD_ATTACH = 0x00000002;
	enum uint THREAD_CREATE_FLAGS_HIDE_FROM_DEBUGGER = 0x00000004;
	enum uint THREAD_CREATE_FLAGS_LOADER_WORKER = 0x00000010;
	enum uint THREAD_CREATE_FLAGS_SKIP_LOADER_INIT = 0x00000020;
	enum uint THREAD_CREATE_FLAGS_BYPASS_PROCESS_FREEZE = 0x00000040;


	struct PS_ATTRIBUTE
	{
		size_t Attribute;
		size_t Size;

		union
		{
			size_t Value;
			void* ValuePtr;
		}

		size_t* ReturnLength;
	}


	struct PS_ATTRIBUTE_LIST (size_t length = 1)
	{
		size_t TotalLength;
		PS_ATTRIBUTE[length] Attributes;
	}


	alias KPRIORITY = int;


	enum THREADINFOCLASS : uint
	{
		ThreadBasicInformation,
		ThreadTimes,
		ThreadPriority,
		ThreadBasePriority,
		ThreadAffinityMask,
		ThreadImpersonationToken,
		ThreadDescriptorTableEntry,
		ThreadEnableAlignmentFaultFixup,
		ThreadEventPair,
		ThreadQuerySetWin32StartAddress,
		ThreadZeroTlsCell,
		ThreadPerformanceCount,
		ThreadAmILastThread,
		ThreadIdealProcessor,
		ThreadPriorityBoost,
		ThreadSetTlsArrayAddress,
		ThreadIsIoPending,
		ThreadHideFromDebugger,
		ThreadBreakOnTermination,
		ThreadSwitchLegacyState,
		ThreadIsTerminated,
		ThreadLastSystemCall,
		ThreadIoPriority,
		ThreadCycleTime,
		ThreadPagePriority,
		ThreadActualBasePriority,
		ThreadTebInformation,
		ThreadCSwitchMon,
		ThreadCSwitchPmu,
		ThreadWow64Context,
		ThreadGroupInformation,
		ThreadUmsInformation,
		ThreadCounterProfiling,
		ThreadIdealProcessorEx,
		ThreadCpuAccountingInformation,
		ThreadSuspendCount,
		ThreadHeterogeneousCpuPolicy,
		ThreadContainerId,
		ThreadNameInformation,
		ThreadSelectedCpuSets,
		ThreadSystemThreadInformation,
		ThreadActualGroupAffinity,
		ThreadDynamicCodePolicyInfo,
		ThreadExplicitCaseSensitivity,
		ThreadWorkOnBehalfTicket,
		ThreadSubsystemInformation,
		ThreadDbgkWerReportActive,
		ThreadAttachContainer,
		ThreadManageWritesToExecutableMemory,
		ThreadPowerThrottlingState,
		ThreadWorkloadClass,
		ThreadCreateStateChange,
		ThreadApplyStateChange,
		ThreadStrongerBadHandleChecks,
		ThreadEffectiveIoPriority,
		ThreadEffectivePagePriority,
		ThreadUpdateLockOwnership,
		ThreadSchedulerSharedDataSlot,
		ThreadTebInformationAtomic,
		ThreadIndexInformation,
		MaxThreadInfoClass
	}


	enum int LOW_PRIORITY = 0;
	enum int LOW_REALTIME_PRIORITY = 16;
	enum int HIGH_PRIORITY = 31;
	enum int MAXIMUM_PRIORITY = 32;


	enum int NORMAL_PRIORITY_CLASS = 0x00000020;
	enum int IDLE_PRIORITY_CLASS = 0x00000040;
	enum int HIGH_PRIORITY_CLASS = 0x00000080;
	enum int REALTIME_PRIORITY_CLASS = 0x00000100;
	enum int BELOW_NORMAL_PRIORITY_CLASS = 0x00004000;
	enum int ABOVE_NORMAL_PRIORITY_CLASS = 0x00008000;


	enum int THREAD_BASE_PRIORITY_LOWRT = 15;
	enum int THREAD_BASE_PRIORITY_MAX = 2;
	enum int THREAD_BASE_PRIORITY_MIN = -2;
	enum int THREAD_BASE_PRIORITY_IDLE = -15;


	enum int THREAD_PRIORITY_LOWEST = THREAD_BASE_PRIORITY_MIN;
	enum int THREAD_PRIORITY_BELOW_NORMAL = THREAD_PRIORITY_LOWEST + 1;
	enum int THREAD_PRIORITY_NORMAL = 0;
	enum int THREAD_PRIORITY_HIGHEST = THREAD_BASE_PRIORITY_MAX;
	enum int THREAD_PRIORITY_ABOVE_NORMAL = THREAD_PRIORITY_HIGHEST - 1;
	enum int THREAD_PRIORITY_ERROR_RETURN = int.max;


	enum int THREAD_PRIORITY_TIME_CRITICAL = THREAD_BASE_PRIORITY_LOWRT;
	enum int THREAD_PRIORITY_IDLE = THREAD_BASE_PRIORITY_IDLE;


	struct THREAD_NAME_INFORMATION
	{
		UNICODE_STRING ThreadName;
	}


	enum uint LDR_DLL_NOTIFICATION_REASON_LOADED = 1;
	enum uint LDR_DLL_NOTIFICATION_REASON_UNLOADED = 2;


	union LDR_DLL_NOTIFICATION_DATA
	{
		LDR_DLL_LOADED_NOTIFICATION_DATA Loaded;
		LDR_DLL_UNLOADED_NOTIFICATION_DATA Unloaded;
	}


	struct LDR_DLL_LOADED_NOTIFICATION_DATA
	{
		uint Flags;
		const(UNICODE_STRING)* FullDllName;
		const(UNICODE_STRING)* BaseDllName;
		void* DllBase;
		uint SizeOfImage;
	}


	struct LDR_DLL_UNLOADED_NOTIFICATION_DATA
	{
		uint Flags;
		const(UNICODE_STRING)* FullDllName;
		const(UNICODE_STRING)* BaseDllName;
		void* DllBase;
		uint SizeOfImage;
	}


	enum ushort ALL_PROCESSOR_GROUPS = 0xFFFF;


	enum MEMORY_INFORMATION_CLASS
	{
		MemoryBasicInformation
	}


	struct MEMORY_BASIC_INFORMATION
	{
		void* BaseAddress;
		void* AllocationBase;
		uint AllocationProtect;

		static if (size_t.sizeof > 4)
		{
			ushort PartitionId;
		}

		size_t RegionSize;
		uint State;
		uint Protect;
		uint Type;
	}


	enum uint MEM_EXTENDED_PARAMETER_TYPE_BITS = 8;


	enum MEM_EXTENDED_PARAMETER_TYPE
	{
		MemExtendedParameterInvalidType,
		MemExtendedParameterAddressRequirements,
		MemExtendedParameterNumaNode,
		MemExtendedParameterPartitionHandle,
		MemExtendedParameterUserPhysicalHandle,
		MemExtendedParameterAttributeFlags,
		MemExtendedParameterImageMachine,
		MemExtendedParameterMax
	}


	struct MEM_EXTENDED_PARAMETER
	{
		ulong Type;

		union
		{
			ulong ULong64;
			void* Pointer;
			size_t Size;
			HANDLE Handle;
			uint ULong;
		}
	}


	struct MEM_ADDRESS_REQUIREMENTS
	{
		void* LowestStartingAddress;
		void* HighestEndingAddress;
		size_t Alignment;
	}


	struct SYSTEM_INFO
	{
		union
		{
			uint dwOemId;

			struct
			{
				ushort wProcessorArchitecture;
				ushort wReserved;
			}
		}

		uint dwPageSize;
		void* lpMinimumApplicationAddress;
		void* lpMaximumApplicationAddress;
		size_t dwActiveProcessorMask;
		uint dwNumberOfProcessors;
		uint dwProcessorType;
		uint dwAllocationGranularity;
		ushort wProcessorLevel;
		ushort wProcessorRevision;
	}


	struct NTString (Char)
	{
		import slack_common.integers;
		import slack_common.text;

		ushort Length;
		ushort MaximumLength;
		Char* Buffer;

		enum ubyte scale = Char.sizeof.integralLog2;

		pragma(inline, true)
		inout(Char)[] asSlice () () @property inout return scope @system pure nothrow @nogc
		{
			return this.Buffer[0 .. (this.Length >>> scale)];
		}

		pragma(inline, true)
		inout(Char)[] asSliceZ () () @property inout return scope @system pure nothrow @nogc
		in (this.Buffer[(this.Length >>> scale) + 1] == '\0')
		{
			return this.Buffer[0 .. (this.Length >>> scale) + 1];
		}

		pragma(inline, true)
		static inout(NTString) fromString (return scope inout(Char)[] slice) @trusted pure nothrow @nogc
		in (slice.length <= (ushort.max >>> scale))
		{
			return typeof(return)(cast(ushort) (slice.length << scale), cast(ushort) (slice.length << scale), slice.ptr);
		}

		pragma(inline, true)
		static inout(NTString) from (return scope inout(Char)[] slice) @trusted pure nothrow @nogc
		in (slice.length <= (ushort.max >>> scale))
		{
			return typeof(return)(cast(ushort) (slice.length << scale), cast(ushort) (slice.length << scale), slice.ptr);
		}

		pragma(inline, true)
		static inout(NTString) from (return scope inout(Char)* data, size_t size) @system pure nothrow @nogc
		in (size <= (ushort.max >>> scale))
		{
			return typeof(return)(cast(ushort) (size << scale), cast(ushort) (size << scale), data);
		}

		pragma(inline, true)
		static inout(NTString) from (return scope inout(Char)* data) @system pure nothrow @nogc
		in (data != null)
		{
			return from(data, strlen(cast(const(Char)*) data));
		}

		pragma(inline, true)
		ref NTString setFrom (return scope Char[] slice) return scope @trusted pure nothrow @nogc
		in (slice.length <= (ushort.max >>> scale))
		{
			this.Length = cast(ushort) (slice.length << scale);
			this.MaximumLength = cast(ushort) (slice.length << scale);
			this.Buffer = slice.ptr;
			return this;
		}

		pragma(inline, true)
		ref NTString setFrom (return scope Char* data, size_t size) return scope @system pure nothrow @nogc
		in (size <= (ushort.max >>> scale))
		{
			this.Length = cast(ushort) (size << scale);
			this.MaximumLength = cast(ushort) (size << scale);
			this.Buffer = data;
			return this;
		}

		pragma(inline, true)
		ref NTString setFrom (return scope Char* data) return scope @system pure nothrow @nogc
		in (data != null)
		{
			return this.setFrom(data, strlen(data));
		}

		pragma(inline, true)
		ushort setLengthTo (return scope size_t length) return scope @safe pure nothrow @nogc
		in (length <= (ushort.max >>> scale))
		{
			this.Length = cast(ushort) (length << scale);
			this.MaximumLength = cast(ushort) (length << scale);
			return cast(ushort) (length << scale);
		}
	}


	alias STRING = NTString!char;
	alias ANSI_STRING = STRING;
	alias UNICODE_STRING = NTString!wchar;


	struct OBJECT_ATTRIBUTES
	{
		uint Length;
		HANDLE RootDirectory;
		UNICODE_STRING* ObjectName;
		uint Attributes;
		void* SecurityDescriptor;
		void* SecurityQualityOfService;
	}


	struct IO_STATUS_BLOCK
	{
		union
		{
			NTSTATUS Status;
			void* Pointer;
		}

		size_t Information;
	}


	extern(Windows)
	{
		alias PIO_APC_ROUTINE = void function (scope void* ApcContext, scope IO_STATUS_BLOCK* IoStatusBlock, uint Reserved);
	}


	struct FILE_STANDARD_INFORMATION
	{
		LARGE_INTEGER AllocationSize;
		LARGE_INTEGER EndOfFile;
		uint NumberOfLinks;
		BOOLEAN DeletePending;
		BOOLEAN Directory;
	}


	struct FILE_NAME_INFORMATION (size_t length = 1)
	{
		uint FileNameLength;
		wchar[length] FileName;
	}


	struct FILE_NAMES_INFORMATION (size_t length = 1)
	{
		uint NextEntryOffset;
		uint FileIndex;
		uint FileNameLength;
		wchar[length] FileName;
	}


	enum uint DELETE = 0x00010000;
	enum uint READ_CONTROL = 0x00020000;
	enum uint WRITE_DAC = 0x00040000;
	enum uint WRITE_OWNER = 0x00080000;
	enum uint SYNCHRONIZE = 0x00100000;
	enum uint STANDARD_RIGHTS_REQUIRED = 0x000F0000;
	enum uint STANDARD_RIGHTS_READ = READ_CONTROL;
	enum uint STANDARD_RIGHTS_WRITE = READ_CONTROL;
	enum uint STANDARD_RIGHTS_EXECUTE = READ_CONTROL;
	enum uint STANDARD_RIGHTS_ALL = 0x001F0000;
	enum uint SPECIFIC_RIGHTS_ALL = 0x0000FFFF;
	enum uint ACCESS_SYSTEM_SECURITY = 0x01000000;
	enum uint MAXIMUM_ALLOWED = 0x02000000;


	enum uint FILE_READ_DATA = 0x0001;
	enum uint FILE_LIST_DIRECTORY = 0x0001;
	enum uint FILE_WRITE_DATA = 0x0002;
	enum uint FILE_ADD_FILE = 0x0002;
	enum uint FILE_APPEND_DATA = 0x0004;
	enum uint FILE_ADD_SUBDIRECTORY = 0x0004;
	enum uint FILE_CREATE_PIPE_INSTANCE = 0x0004;
	enum uint FILE_READ_EA = 0x0008;
	enum uint FILE_WRITE_EA = 0x0010;
	enum uint FILE_EXECUTE = 0x0020;
	enum uint FILE_TRAVERSE = 0x0020;
	enum uint FILE_DELETE_CHILD = 0x0040;
	enum uint FILE_READ_ATTRIBUTES = 0x0080;
	enum uint FILE_WRITE_ATTRIBUTES = 0x0100;


	enum uint FILE_ATTRIBUTE_READONLY = 0x00000001;
	enum uint FILE_ATTRIBUTE_HIDDEN = 0x00000002;
	enum uint FILE_ATTRIBUTE_SYSTEM = 0x00000004;
	enum uint FILE_ATTRIBUTE_DIRECTORY = 0x00000010;
	enum uint FILE_ATTRIBUTE_ARCHIVE = 0x00000020;
	enum uint FILE_ATTRIBUTE_DEVICE = 0x00000040;
	enum uint FILE_ATTRIBUTE_NORMAL = 0x00000080;
	enum uint FILE_ATTRIBUTE_TEMPORARY = 0x00000100;
	enum uint FILE_ATTRIBUTE_SPARSE_FILE = 0x00000200;
	enum uint FILE_ATTRIBUTE_REPARSE_POINT = 0x00000400;
	enum uint FILE_ATTRIBUTE_COMPRESSED = 0x00000800;
	enum uint FILE_ATTRIBUTE_OFFLINE = 0x00001000;
	enum uint FILE_ATTRIBUTE_NOT_CONTENT_INDEXED = 0x00002000;
	enum uint FILE_ATTRIBUTE_ENCRYPTED = 0x00004000;
	enum uint FILE_ATTRIBUTE_INTEGRITY_STREAM = 0x00008000;
	enum uint FILE_ATTRIBUTE_VIRTUAL = 0x00010000;
	enum uint FILE_ATTRIBUTE_NO_SCRUB_DATA = 0x00020000;
	enum uint FILE_ATTRIBUTE_EA = 0x00040000;
	enum uint FILE_ATTRIBUTE_PINNED = 0x00080000;
	enum uint FILE_ATTRIBUTE_UNPINNED = 0x00100000;
	enum uint FILE_ATTRIBUTE_RECALL_ON_OPEN = 0x00040000;
	enum uint FILE_ATTRIBUTE_RECALL_ON_DATA_ACCESS = 0x00400000;
	enum uint INVALID_FILE_ATTRIBUTES = -1;


	enum uint FILE_FLAG_WRITE_THROUGH = 0x80000000;
	enum uint FILE_FLAG_OVERLAPPED = 0x40000000;
	enum uint FILE_FLAG_NO_BUFFERING = 0x20000000;
	enum uint FILE_FLAG_RANDOM_ACCESS = 0x10000000;
	enum uint FILE_FLAG_SEQUENTIAL_SCAN = 0x08000000;
	enum uint FILE_FLAG_DELETE_ON_CLOSE = 0x04000000;
	enum uint FILE_FLAG_BACKUP_SEMANTICS = 0x02000000;
	enum uint FILE_FLAG_POSIX_SEMANTICS = 0x01000000;
	enum uint FILE_FLAG_SESSION_AWARE = 0x00800000;
	enum uint FILE_FLAG_OPEN_REPARSE_POINT = 0x00200000;
	enum uint FILE_FLAG_OPEN_NO_RECALL = 0x00100000;
	enum uint FILE_FLAG_FIRST_PIPE_INSTANCE = 0x00080000;


	enum uint FILE_DIRECTORY_FILE = 0x00000001;
	enum uint FILE_WRITE_THROUGH = 0x00000002;
	enum uint FILE_SEQUENTIAL_ONLY = 0x00000004;
	enum uint FILE_NO_INTERMEDIATE_BUFFERING = 0x00000008;
	enum uint FILE_SYNCHRONOUS_IO_ALERT = 0x00000010;
	enum uint FILE_SYNCHRONOUS_IO_NONALERT = 0x00000020;
	enum uint FILE_NON_DIRECTORY_FILE = 0x00000040;
	enum uint FILE_CREATE_TREE_CONNECTION = 0x00000080;
	enum uint FILE_COMPLETE_IF_OPLOCKED = 0x00000100;
	enum uint FILE_NO_EA_KNOWLEDGE = 0x00000200;
	enum uint FILE_OPEN_REMOTE_INSTANCE = 0x00000400;
	enum uint FILE_RANDOM_ACCESS = 0x00000800;
	enum uint FILE_DELETE_ON_CLOSE = 0x00001000;
	enum uint FILE_OPEN_BY_FILE_ID = 0x00002000;
	enum uint FILE_OPEN_FOR_BACKUP_INTENT = 0x00004000;
	enum uint FILE_NO_COMPRESSION = 0x00008000;


	enum uint FILE_ALL_ACCESS = STANDARD_RIGHTS_REQUIRED | SYNCHRONIZE | 0x1FF;


	enum uint FILE_ANY_ACCESS = 0;
	enum uint FILE_SPECIAL_ACCESS = FILE_ANY_ACCESS;
	enum uint FILE_READ_ACCESS = 0x0001;
	enum uint FILE_WRITE_ACCESS = 0x0002;


	enum uint FILE_GENERIC_READ = STANDARD_RIGHTS_READ | FILE_READ_DATA | FILE_READ_ATTRIBUTES | FILE_READ_EA | SYNCHRONIZE;
	enum uint FILE_GENERIC_WRITE = STANDARD_RIGHTS_WRITE | FILE_WRITE_DATA | FILE_WRITE_ATTRIBUTES | FILE_WRITE_EA | FILE_APPEND_DATA | SYNCHRONIZE;
	enum uint FILE_GENERIC_EXECUTE = STANDARD_RIGHTS_EXECUTE | FILE_READ_ATTRIBUTES | FILE_EXECUTE | SYNCHRONIZE;


	enum uint GENERIC_READ = 0x80000000;
	enum uint GENERIC_WRITE = 0x40000000;
	enum uint GENERIC_EXECUTE = 0x20000000;
	enum uint GENERIC_ALL = 0x10000000;


	enum uint FILE_SHARE_READ = 0x00000001;
	enum uint FILE_SHARE_WRITE = 0x00000002;
	enum uint FILE_SHARE_DELETE = 0x00000004;


	enum uint FILE_SUPERSEDE = 0x00000000;
	enum uint FILE_OPEN = 0x00000001;
	enum uint FILE_CREATE = 0x00000002;
	enum uint FILE_OPEN_IF = 0x00000003;
	enum uint FILE_OVERWRITE = 0x00000004;
	enum uint FILE_OVERWRITE_IF = 0x00000005;


	enum uint CREATE_ALWAYS = 2;
	enum uint CREATE_NEW = 1;
	enum uint OPEN_ALWAYS = 4;
	enum uint OPEN_EXISTING = 3;
	enum uint TRUNCATE_EXISTING = 5;


	enum uint MEM_COMMIT = 0x00001000;
	enum uint MEM_RESERVE = 0x00002000;
	enum uint MEM_RESET = 0x00080000;
	enum uint MEM_RESET_UNDO = 0x1000000;
	enum uint MEM_DECOMMIT = 0x00004000;
	enum uint MEM_RELEASE = 0x00008000;
	enum uint MEM_FREE = 0x00010000;
	enum uint MEM_REPLACE_PLACEHOLDER = 0x00004000;
	enum uint MEM_RESERVE_PLACEHOLDER = 0x00040000;
	enum uint MEM_COALESCE_PLACEHOLDERS = 0x00000001;
	enum uint MEM_PRESERVE_PLACEHOLDER = 0x00000002;


	enum uint PAGE_NOACCESS = 0x01;
	enum uint PAGE_READONLY = 0x02;
	enum uint PAGE_READWRITE = 0x04;
	enum uint PAGE_WRITECOPY = 0x08;
	enum uint PAGE_EXECUTE = 0x10;
	enum uint PAGE_EXECUTE_READ = 0x20;
	enum uint PAGE_EXECUTE_READWRITE = 0x40;
	enum uint PAGE_EXECUTE_WRITECOPY = 0x80;


	enum uint SEC_HUGE_PAGES = 0x00020000;
	enum uint SEC_PARTITION_OWNER_HANDLE = 0x00040000;
	enum uint SEC_64K_PAGES = 0x00080000;
	enum uint SEC_FILE = 0x00800000;
	enum uint SEC_IMAGE = 0x01000000;
	enum uint SEC_PROTECTED_IMAGE = 0x02000000;
	enum uint SEC_RESERVE = 0x04000000;
	enum uint SEC_COMMIT = 0x08000000;
	enum uint SEC_NOCACHE = 0x10000000;
	enum uint SEC_WRITECOMBINE = 0x40000000;
	enum uint SEC_LARGE_PAGES = 0x80000000;
	enum uint SEC_IMAGE_NO_EXECUTE = SEC_IMAGE | SEC_NOCACHE;


	enum uint SECTION_QUERY = 0x0001;
	enum uint SECTION_MAP_WRITE = 0x0002;
	enum uint SECTION_MAP_READ = 0x0004;
	enum uint SECTION_MAP_EXECUTE = 0x0008;
	enum uint SECTION_EXTEND_SIZE = 0x0010;
	enum uint SECTION_MAP_EXECUTE_EXPLICIT = 0x0020;
	enum uint SECTION_ALL_ACCESS =  STANDARD_RIGHTS_REQUIRED | SECTION_QUERY | SECTION_MAP_WRITE | SECTION_MAP_READ | SECTION_MAP_EXECUTE | SECTION_EXTEND_SIZE;


	enum uint FILE_SUPERSEDED = 0x00000000;
	enum uint FILE_OPENED = 0x00000001;
	enum uint FILE_CREATED = 0x00000002;
	enum uint FILE_OVERWRITTEN = 0x00000003;
	enum uint FILE_EXISTS = 0x00000004;
	enum uint FILE_DOES_NOT_EXIST = 0x00000005;


	enum uint ViewShare = 1;
	enum uint ViewUnmap = 2;


	enum FILE_INFORMATION_CLASS : uint
	{
		FileDirectoryInformation = 1,
		FileFullDirectoryInformation = 2,
		FileBothDirectoryInformation = 3,
		FileBasicInformation = 4,
		FileStandardInformation = 5,
		FileInternalInformation = 6,
		FileEaInformation = 7,
		FileAccessInformation = 8,
		FileNameInformation = 9,
		FileRenameInformation = 10,
		FileLinkInformation = 11,
		FileNamesInformation = 12,
		FileDispositionInformation = 13,
		FilePositionInformation = 14,
		FileFullEaInformation = 15,
		FileModeInformation = 16,
		FileAlignmentInformation = 17,
		FileAllInformation = 18,
		FileAllocationInformation = 19,
		FileEndOfFileInformation = 20,
		FileAlternateNameInformation = 21,
		FileStreamInformation = 22,
		FilePipeInformation = 23,
		FilePipeLocalInformation = 24,
		FilePipeRemoteInformation = 25,
		FileMailslotQueryInformation = 26,
		FileMailslotSetInformation = 27,
		FileCompressionInformation = 28,
		FileObjectIdInformation = 29,
		FileCompletionInformation = 30,
		FileMoveClusterInformation = 31,
		FileQuotaInformation = 32,
		FileReparsePointInformation = 33,
		FileNetworkOpenInformation = 34,
		FileAttributeTagInformation = 35,
		FileTrackingInformation = 36,
		FileIdBothDirectoryInformation = 37,
		FileIdFullDirectoryInformation = 38,
		FileValidDataLengthInformation = 39,
		FileShortNameInformation = 40,
		FileIoCompletionNotificationInformation = 41,
		FileIoStatusBlockRangeInformation = 42,
		FileIoPriorityHintInformation = 43,
		FileSfioReserveInformation = 44,
		FileSfioVolumeInformation = 45,
		FileHardLinkInformation = 46,
		FileProcessIdsUsingFileInformation = 47,
		FileNormalizedNameInformation = 48,
		FileNetworkPhysicalNameInformation = 49,
		FileIdGlobalTxDirectoryInformation = 50,
		FileIsRemoteDeviceInformation = 51,
		FileUnusedInformation = 52,
		FileNumaNodeInformation = 53,
		FileStandardLinkInformation = 54,
		FileRemoteProtocolInformation = 55,
		FileRenameInformationBypassAccessCheck = 56,
		FileLinkInformationBypassAccessCheck = 57,
		FileVolumeNameInformation = 58,
		FileIdInformation = 59,
		FileIdExtdDirectoryInformation = 60,
		FileReplaceCompletionInformation = 61,
		FileHardLinkFullIdInformation = 62,
		FileIdExtdBothDirectoryInformation = 63,
		FileDispositionInformationEx = 64,
		FileRenameInformationEx = 65,
		FileRenameInformationExBypassAccessCheck = 66,
		FileDesiredStorageClassInformation = 67,
		FileStatInformation = 68,
		FileMemoryPartitionInformation = 69,
		FileStatLxInformation = 70,
		FileCaseSensitiveInformation = 71,
		FileLinkInformationEx = 72,
		FileLinkInformationExBypassAccessCheck = 73,
		FileStorageReserveIdInformation = 74,
		FileCaseSensitiveInformationForceAccessCheck = 75,
		FileKnownFolderInformation = 76,
		FileStatBasicInformation = 77,
		FileId64ExtdDirectoryInformation = 78,
		FileId64ExtdBothDirectoryInformation = 79,
		FileIdAllExtdDirectoryInformation = 80,
		FileIdAllExtdBothDirectoryInformation = 81,
		FileStreamReservationInformation,
		FileMupProviderInfo,
		FileMaximumInformation
	}


	enum OBJECT_INFORMATION_CLASS : uint
	{
		ObjectBasicInformation = 0,
		ObjectTypeInformation = 2
	}


	struct FILE_END_OF_FILE_INFORMATION
	{
		LARGE_INTEGER EndOfFile;
	}


	enum int EXCEPTION_MAXIMUM_PARAMETERS = 15;


	struct EXCEPTION_RECORD
	{
		uint ExceptionCode;
		uint ExceptionFlags;
		EXCEPTION_RECORD* ExceptionRecord;
		void* ExceptionAddress;
		uint NumberParameters;
		size_t[EXCEPTION_MAXIMUM_PARAMETERS] ExceptionInformation;
	}


	struct EXCEPTION_POINTERS
	{
		EXCEPTION_RECORD* ExceptionRecord;
		CONTEXT* ContextRecord;
	}


	struct CONTEXT
	{
	align(16)
		ulong P1Home;
		ulong P2Home;
		ulong P3Home;
		ulong P4Home;
		ulong P5Home;
		ulong P6Home;

		uint ContextFlags;
		uint MxCsr;

		ushort SegCs;
		ushort SegDs;
		ushort SegEs;
		ushort SegFs;
		ushort SegGs;
		ushort SegSs;
		uint EFlags;

		ulong Dr0;
		ulong Dr1;
		ulong Dr2;
		ulong Dr3;
		ulong Dr6;
		ulong Dr7;

		ulong Rax;
		ulong Rcx;
		ulong Rdx;
		ulong Rbx;
		ulong Rsp;
		ulong Rbp;
		ulong Rsi;
		ulong Rdi;
		ulong R8;
		ulong R9;
		ulong R10;
		ulong R11;
		ulong R12;
		ulong R13;
		ulong R14;
		ulong R15;

		ulong Rip;

		union
		{
			XMM_SAVE_AREA32 FltSave;

			struct
			{
				M128A[2] Header;
				M128A[8] Legacy;
				M128A Xmm0;
				M128A Xmm1;
				M128A Xmm2;
				M128A Xmm3;
				M128A Xmm4;
				M128A Xmm5;
				M128A Xmm6;
				M128A Xmm7;
				M128A Xmm8;
				M128A Xmm9;
				M128A Xmm10;
				M128A Xmm11;
				M128A Xmm12;
				M128A Xmm13;
				M128A Xmm14;
				M128A Xmm15;
			}
		}

		M128A[26] VectorRegister;
		ulong VectorControl;

		ulong DebugControl;
		ulong LastBranchToRip;
		ulong LastBranchFromRip;
		ulong LastExceptionToRip;
		ulong LastExceptionFromRip;
	}


	struct XSAVE_FORMAT
	{
	align(16)
		ushort ControlWord;
		ushort StatusWord;
		ubyte TagWord;
		ubyte Reserved1;
		ushort ErrorOpcode;
		uint ErrorOffset;
		ushort ErrorSelector;
		ushort Reserved2;
		uint DataOffset;
		ushort DataSelector;
		ushort Reserved3;
		uint MxCsr;
		uint MxCsr_Mask;
		M128A[8] FloatRegisters;
		M128A[16] XmmRegisters;
		ubyte[96] Reserved4;
	}


	alias XMM_SAVE_AREA32 = XSAVE_FORMAT;


	struct M128A
	{
	align(16)
		ulong Low;
		long High;
	}


	enum int EXCEPTION_CONTINUE_SEARCH = 0;
	enum int EXCEPTION_CONTINUE_EXECUTION = 0xFFFFFFFF;


	enum uint EXCEPTION_ACCESS_VIOLATION = 0xC0000005;


	struct IMAGE_DOS_HEADER
	{
		ushort e_magic;
		ushort e_cblp;
		ushort e_cp;
		ushort e_crlc;
		ushort e_cparhdr;
		ushort e_minalloc;
		ushort e_maxalloc;
		ushort e_ss;
		ushort e_sp;
		ushort e_csum;
		ushort e_ip;
		ushort e_cs;
		ushort e_lfarlc;
		ushort e_ovno;
		ushort[4] e_res;
		ushort e_oemid;
		ushort e_oeminfo;
		ushort[10] e_res2;
		uint e_lfanew;
	}


	struct IMAGE_FILE_HEADER
	{
		ushort Machine;
		ushort NumberOfSections;
		uint TimeDateStamp;
		uint PointerToSymbolTable;
		uint NumberOfSymbols;
		ushort SizeOfOptionalHeader;
		ushort Characteristics;
	}


	struct IMAGE_DATA_DIRECTORY
	{
		uint VirtualAddress;
		uint Size;
	}


	enum uint IMAGE_NUMBEROF_DIRECTORY_ENTRIES = 16;


	struct IMAGE_OPTIONAL_HEADER32
	{
		ushort Magic;
		ubyte MajorLinkerVersion;
		ubyte MinorLinkerVersion;
		uint SizeOfCode;
		uint SizeOfInitializedData;
		uint SizeOfUninitializedData;
		uint AddressOfEntryPoint;
		uint BaseOfCode;
		uint BaseOfData;
		uint ImageBase;
		uint SectionAlignment;
		uint FileAlignment;
		ushort MajorOperatingSystemVersion;
		ushort MinorOperatingSystemVersion;
		ushort MajorImageVersion;
		ushort MinorImageVersion;
		ushort MajorSubsystemVersion;
		ushort MinorSubsystemVersion;
		uint Win32VersionValue;
		uint SizeOfImage;
		uint SizeOfHeaders;
		uint CheckSum;
		ushort Subsystem;
		ushort DllCharacteristics;
		uint SizeOfStackReserve;
		uint SizeOfStackCommit;
		uint SizeOfHeapReserve;
		uint SizeOfHeapCommit;
		uint LoaderFlags;
		uint NumberOfRvaAndSizes;
		IMAGE_DATA_DIRECTORY[IMAGE_NUMBEROF_DIRECTORY_ENTRIES] DataDirectory;
	}


	struct IMAGE_NT_HEADERS32
	{
		uint Signature;
		IMAGE_FILE_HEADER FileHeader;
		IMAGE_OPTIONAL_HEADER32 OptionalHeader;
	}


	struct IMAGE_OPTIONAL_HEADER64
	{
		ushort Magic;
		ubyte MajorLinkerVersion;
		ubyte MinorLinkerVersion;
		uint SizeOfCode;
		uint SizeOfInitializedData;
		uint SizeOfUninitializedData;
		uint AddressOfEntryPoint;
		uint BaseOfCode;
		ulong ImageBase;
		uint SectionAlignment;
		uint FileAlignment;
		ushort MajorOperatingSystemVersion;
		ushort MinorOperatingSystemVersion;
		ushort MajorImageVersion;
		ushort MinorImageVersion;
		ushort MajorSubsystemVersion;
		ushort MinorSubsystemVersion;
		uint Win32VersionValue;
		uint SizeOfImage;
		uint SizeOfHeaders;
		uint CheckSum;
		ushort Subsystem;
		ushort DllCharacteristics;
		ulong SizeOfStackReserve;
		ulong SizeOfStackCommit;
		ulong SizeOfHeapReserve;
		ulong SizeOfHeapCommit;
		uint LoaderFlags;
		uint NumberOfRvaAndSizes;
		IMAGE_DATA_DIRECTORY[IMAGE_NUMBEROF_DIRECTORY_ENTRIES] DataDirectory;
	}


	struct IMAGE_NT_HEADERS64
	{
		uint Signature;
		IMAGE_FILE_HEADER FileHeader;
		IMAGE_OPTIONAL_HEADER64 OptionalHeader;
	}


	enum uint IMAGE_SIZEOF_SHORT_NAME = 8;


	struct IMAGE_SECTION_HEADER
	{
		char[IMAGE_SIZEOF_SHORT_NAME] Name;

		union
		{
			uint PhysicalAddress;
			uint VirtualSize;
		}

		uint VirtualAddress;
		uint SizeOfRawData;
		uint PointerToRawData;
		uint PointerToRelocations;
		uint PointerToLinenumbers;
		ushort NumberOfRelocations;
		ushort NumberOfLinenumbers;
		uint Characteristics;
	}


	struct IMAGE_EXPORT_DIRECTORY
	{
		uint Characteristics;
		uint TimeDateStamp;
		ushort MajorVersion;
		ushort MinorVersion;
		uint Name;
		uint Base;
		uint NumberOfFunctions;
		uint NumberOfNames;
		uint AddressOfFunctions;
		uint AddressOfNames;
		uint AddressOfNameOrdinals;
	}


	struct IMAGE_IMPORT_DESCRIPTOR
	{
		union
		{
			uint Characteristics;
			uint OriginalFirstThunk;
		}

		uint TimeDateStamp;

		uint ForwarderChain;
		uint Name;
		uint FirstThunk;
	}


	struct IMAGE_IMPORT_BY_NAME
	{
		ushort Hint;
		char[1] Name;
	}



	struct IMAGE_RESOURCE_DIRECTORY
	{
		uint Characteristics;
		uint TimeDateStamp;
		ushort MajorVersion;
		ushort MinorVersion;
		ushort NumberOfNamedEntries;
		ushort NumberOfIdEntries;
	}


	struct IMAGE_RESOURCE_DIRECTORY_ENTRY
	{
		union
		{
			struct
			{
				uint NameOffsetRaw;

				pragma(inline, true)
				uint NameOffset () () const @property @safe pure nothrow @nogc
				{
					return this.NameOffsetRaw & 0x7fffffff;
				}

				pragma(inline, true)
				bool NameIsString () () const @property scope @safe pure nothrow @nogc
				{
					return (this.NameOffsetRaw & 0x80000000) != 0;
				}
			}

			uint Name;
			ushort Id;
		}

		union
		{
			uint OffsetToData;

			struct
			{
				uint OffsetToDirectoryRaw;

				pragma(inline, true)
				uint OffsetToDirectory () () const @property @safe pure nothrow @nogc
				{
					return this.OffsetToDirectoryRaw & 0x7fffffff;
				}

				pragma(inline, true)
				bool DataIsDirectory () () const @property scope @safe pure nothrow @nogc
				{
					return (this.OffsetToDirectoryRaw & 0x80000000) != 0;
				}
			}
		}
	}


	struct IMAGE_RESOURCE_DIRECTORY_STRING
	{
		ushort Length;
		char[1] NameString;
	}


	struct IMAGE_RESOURCE_DIR_STRING_U
	{
		ushort Length;
		wchar[1] NameString;
	}


	struct IMAGE_RESOURCE_DATA_ENTRY
	{
		uint OffsetToData;
		uint Size;
		uint CodePage;
		uint Reserved;
	}


	enum uint IMAGE_RESOURCE_NAME_IS_STRING = 0x80000000;
	enum uint IMAGE_RESOURCE_DATA_IS_DIRECTORY = 0x80000000;


	enum uint IMAGE_DIRECTORY_ENTRY_EXPORT = 0;
	enum uint IMAGE_DIRECTORY_ENTRY_IMPORT = 1;
	enum uint IMAGE_DIRECTORY_ENTRY_RESOURCE = 2;
	enum uint IMAGE_DIRECTORY_ENTRY_EXCEPTION = 3;
	enum uint IMAGE_DIRECTORY_ENTRY_SECURITY = 4;
	enum uint IMAGE_DIRECTORY_ENTRY_BASERELOC = 5;
	enum uint IMAGE_DIRECTORY_ENTRY_DEBUG = 6;
	enum uint IMAGE_DIRECTORY_ENTRY_ARCHITECTURE = 7;
	enum uint IMAGE_DIRECTORY_ENTRY_GLOBALPTR = 8;
	enum uint IMAGE_DIRECTORY_ENTRY_TLS = 9;
	enum uint IMAGE_DIRECTORY_ENTRY_LOAD_CONFIG = 10;
	enum uint IMAGE_DIRECTORY_ENTRY_BOUND_IMPORT = 11;
	enum uint IMAGE_DIRECTORY_ENTRY_IAT = 12;
	enum uint IMAGE_DIRECTORY_ENTRY_DELAY_IMPORT = 13;
	enum uint IMAGE_DIRECTORY_ENTRY_COM_DESCRIPTOR = 14;


	struct VS_FIXEDFILEINFO
	{
		uint dwSignature;
		uint dwStrucVersion;
		uint dwFileVersionMS;
		uint dwFileVersionLS;
		uint dwProductVersionMS;
		uint dwProductVersionLS;
		uint dwFileFlagsMask;
		uint dwFileFlags;
		uint dwFileOS;
		uint dwFileType;
		uint dwFileSubtype;
		uint dwFileDateMS;
		uint dwFileDateLS;
	}


	struct VersionInfoHeader
	{
		ushort wLength;
		ushort wValueLength;
		ushort wType;
	}


	struct FILETIME
	{
		uint dwLowDateTime;
		uint dwHighDateTime;
	}


	struct KSYSTEM_TIME
	{
		uint LowPart;
		int High1Time;
		int High2Time;
	}


	struct WIN32_FIND_DATAA
	{
		uint dwFileAttributes;
		FILETIME ftCreationTime;
		FILETIME ftLastAccessTime;
		FILETIME ftLastWriteTime;
		uint nFileSizeHigh;
		uint nFileSizeLow;
		uint dwReserved0;
		uint dwReserved1;
		char[MAX_PATH] cFileName;
		char[14] cAlternateFileName;
		uint dwFileType;
		uint dwCreatorType;
		ushort wFinderFlags;
	}


	struct KUSER_SHARED_DATA
	{
		uint TickCountLowDeprecated;
		uint TickCountMultiplier;
		KSYSTEM_TIME InterruptTime;
		KSYSTEM_TIME SystemTime;
		KSYSTEM_TIME TimeZoneBias;
		ushort ImageNumberLow;
		ushort ImageNumberHigh;
		wchar[MAX_PATH] NtSystemRoot;
	}


	pragma(inline, true)
	const(KUSER_SHARED_DATA)* kUserSharedData () @trusted nothrow @nogc
	{
		return cast(typeof(return)) 0x7FFE0000;
	}


	struct RTL_CRITICAL_SECTION
	{
		RTL_CRITICAL_SECTION_DEBUG* DebugInfo;
		int LockCount;
		int RecursionCount;
		HANDLE OwningThread;
		HANDLE LockSemaphore;
		size_t SpinCount;
	}


	struct RTL_CRITICAL_SECTION_DEBUG
	{
		ushort Type;
		ushort CreatorBackTraceIndex;
		RTL_CRITICAL_SECTION* CriticalSection;
		LIST_ENTRY ProcessLocksList;
		uint EntryCount;
		uint ContentionCount;
		uint Flags;
		ushort CreatorBackTraceIndexHigh;
		ushort Identifier;
	}


	struct LIST_ENTRY
	{
		LIST_ENTRY* Flink;
		LIST_ENTRY* Blink;
	}


	struct NT_TIB
	{
		EXCEPTION_REGISTRATION_RECORD* ExceptionList;
		void* StackBase;
		void* StackLimit;
		void* SubSystemTib;

		union
		{
			void* FiberData;
			uint Version;
		}

		void* ArbitraryUserPointer;
		NT_TIB* Self;
	}


	struct EXCEPTION_REGISTRATION_RECORD
	{
		EXCEPTION_REGISTRATION_RECORD* Next;
		PEXCEPTION_ROUTINE Handler;
	}


	enum EXCEPTION_DISPOSITION : int
	{
		ExceptionContinueExecution,
		ExceptionContinueSearch,
		ExceptionNestedException,
		ExceptionCollidedUnwind
	}


	extern(Windows)
	{
		alias PEXCEPTION_ROUTINE = EXCEPTION_DISPOSITION function (scope EXCEPTION_RECORD* ExceptionRecord, scope void* EstablisherFrame, scope CONTEXT* ContextRecord, scope void* DispatcherContext) nothrow @nogc;
	}


	enum uint MB_OK = 0x00000000;
	enum uint MB_OKCANCEL = 0x00000001;
	enum uint MB_ABORTRETRYIGNORE = 0x00000002;
	enum uint MB_YESNOCANCEL = 0x00000003;
	enum uint MB_YESNO = 0x00000004;
	enum uint MB_RETRYCANCEL = 0x00000005;
	enum uint MB_CANCELTRYCONTINUE = 0x00000006;
	enum uint MB_ICONHAND = 0x00000010;
	enum uint MB_ICONQUESTION = 0x00000020;
	enum uint MB_ICONEXCLAMATION = 0x00000030;
	enum uint MB_ICONASTERISK = 0x00000040;
	enum uint MB_USERICON = 0x00000080;
	enum uint MB_ICONWARNING = MB_ICONEXCLAMATION;
	enum uint MB_ICONERROR = MB_ICONHAND;
	enum uint MB_ICONINFORMATION = MB_ICONASTERISK;
	enum uint MB_ICONSTOP = MB_ICONHAND;
	enum uint MB_DEFBUTTON1 = 0x00000000;
	enum uint MB_DEFBUTTON2 = 0x00000100;
	enum uint MB_DEFBUTTON3 = 0x00000200;
	enum uint MB_DEFBUTTON4 = 0x00000300;
	enum uint MB_APPLMODAL = 0x00000000;
	enum uint MB_SYSTEMMODAL = 0x00001000;
	enum uint MB_TASKMODAL = 0x00002000;
	enum uint MB_HELP = 0x00004000;
	enum uint MB_NOFOCUS = 0x00008000;
	enum uint MB_SETFOREGROUND = 0x00010000;
	enum uint MB_DEFAULT_DESKTOP_ONLY = 0x00020000;
	enum uint MB_TOPMOST = 0x00040000;
	enum uint MB_RIGHT = 0x00080000;
	enum uint MB_RTLREADING = 0x00100000;
	enum uint MB_SERVICE_NOTIFICATION = 0x00200000;
	enum uint MB_SERVICE_NOTIFICATION_NT3X = 0x00040000;
	enum uint MB_TYPEMASK = 0x0000000F;
	enum uint MB_ICONMASK = 0x000000F0;
	enum uint MB_DEFMASK = 0x00000F00;
	enum uint MB_MODEMASK = 0x00003000;
	enum uint MB_MISCMASK = 0x0000C000;


	extern(Windows) int MessageBoxW (scope HWND hWnd, scope const(wchar)* lpText, scope const(wchar)* lpCaption, uint uType) nothrow @nogc;
	extern(Windows) int MessageBoxA (scope HWND hWnd, scope const(char)* lpText, scope const(char)* lpCaption, uint uType) nothrow @nogc;


	enum uint IDOK = 1;
	enum uint IDCANCEL = 2;
	enum uint IDABORT = 3;
	enum uint IDRETRY = 4;
	enum uint IDIGNORE = 5;
	enum uint IDYES = 6;
	enum uint IDNO = 7;
	enum uint IDCLOSE = 8;
	enum uint IDHELP = 9;
	enum uint IDTRYAGAIN = 10;
	enum uint IDCONTINUE = 11;
	enum uint IDTIMEOUT = 32000;


	enum uint SW_HIDE = 0;
	enum uint SW_SHOWNORMAL = 1;
	enum uint SW_NORMAL = 1;
	enum uint SW_SHOWMINIMIZED = 2;
	enum uint SW_SHOWMAXIMIZED = 3;
	enum uint SW_MAXIMIZE = 3;
	enum uint SW_SHOWNOACTIVATE = 4;
	enum uint SW_SHOW = 5;
	enum uint SW_MINIMIZE = 6;
	enum uint SW_SHOWMINNOACTIVE = 7;
	enum uint SW_SHOWNA = 8;
	enum uint SW_RESTORE = 9;
	enum uint SW_SHOWDEFAULT = 10;
	enum uint SW_FORCEMINIMIZE = 11;
	enum uint SW_MAX = 11;


	enum COINITBASE
	{
		COINITBASE_MULTITHREADED = 0x0
	}


	enum COINIT
	{
		COINIT_APARTMENTTHREADED = 0x2,
		COINIT_MULTITHREADED = COINITBASE.COINITBASE_MULTITHREADED,
		COINIT_DISABLE_OLE1DDE = 0x4,
		COINIT_SPEED_OVER_MEMORY = 0x8,
	}
}

