
/+ SPDX-LICENSE-IDENTIFIER: 0BSD +/

module slack_common.memory;

import ldc.attributes : optStrategy;

import slack_common.bindings;
import slack_common.byte_sizes;
import slack_common.dynamically_linked;
import slack_common.integers;
import slack_common.versions;


version (D_InlineAsm_X86)
{
	version = InlineAsm_X86_64_Or_X86;
}
else version (D_InlineAsm_X86_64)
{
	version = InlineAsm_X86_64_Or_X86;
}


version (Windows)
{
	enum size_t minimumPageSize = 4.KB;
}
else
{
	static if (ARM64)
	{
		version (Darwin)
		{
			enum size_t minimumPageSize = 16.KB;
		}
		else
		{
			enum size_t minimumPageSize = 4.KB;
		}
	}
	else
	{
		enum size_t minimumPageSize = 4.KB;
	}
}


version (Windows)
{
	enum size_t allocationGranularity = 64.KB;
}
else
{
	enum size_t allocationGranularity = 4.KB;
}


alias Unaligned (T) = Misaligned!(T, 1);


struct Misaligned (T, size_t alignment)
{
	alias value this;
	align(alignment) T value;
}


pragma(inline, true)
Misaligned!(T, 1)* unaligned (T) (scope T* address) @trusted pure nothrow @nogc
{
	return cast(typeof(return)) address;
}


pragma(inline, true)
Misaligned!(Target, Source.alignof)* asMisaligned (Target, Source) (scope Source* address) @trusted pure nothrow @nogc
{
	return cast(typeof(return)) address;
}


pragma(inline, true)
T* endOf (T) (return scope T[] slice) pure nothrow @nogc
{
	return slice.ptr + slice.length;
}


pragma(inline, true)
I pointerAndByteOffset (I = size_t) (I pointerCount, I byteCount)
in (size_t(I.max) / size_t.sizeof >= 1)
in (size_t(I.max) - pointerCount * I(size_t.sizeof) >= byteCount)
{
	return pointerCount * I(size_t.sizeof) + byteCount;
}


pragma(inline, true)
uint allocateVirtualMemoryWithinRange (
	scope const(void)* base,
	scope const(void)* tail,
	void** address,
	size_t* size,
	uint type,
	uint protection
) nothrow @nogc
{
	return allocateVirtualMemoryWithinRange(tail, address, size, type, protection, base);
}


@optStrategy("minsize")
private uint allocateVirtualMemoryWithinRange (
	scope const(void)* tail,
	void** address,
	size_t* size,
	uint type,
	uint protection,
	scope const(void)* base,
) nothrow @nogc
in (*address == null)
{
	/+ The wacky argument order is such to make the arguments line up
	   for NtAllocateVirtualMemoryEx, where they can. +/

	NTSTATUS error = 0;

	size_t desiredSize = *size;

	base = base.alignUpTo(allocationGranularity);
	tail = (tail - desiredSize).alignDownTo(allocationGranularity);

	if (base >= tail)
	{
		return STATUS_NO_MEMORY;
	}

	if (linked.NtAllocateVirtualMemoryEx)
	{
		MEM_ADDRESS_REQUIREMENTS range = {
			LowestStartingAddress: cast(void*) base,
			HighestEndingAddress: cast(void*) tail - 1
		};
		MEM_EXTENDED_PARAMETER requirement = {
			Type: MEM_EXTENDED_PARAMETER_TYPE.MemExtendedParameterAddressRequirements,
			Pointer: &range
		};

		error = linked.NtAllocateVirtualMemoryEx(thisProcess, address, size, type, protection, &requirement, 1);

		if (!error)
		{
			return 0;
		}
	}

	for (;;)
	{
		MEMORY_BASIC_INFORMATION info = void;

		error = NtQueryVirtualMemory(
			thisProcess,
			cast(void*) base,
			MEMORY_INFORMATION_CLASS.MemoryBasicInformation,
			&info,
			info.sizeof,
			null
		);

		if (error)
		{
			return error;
		}

		if (base + desiredSize > tail)
		{
			return STATUS_NO_MEMORY;
		}

		if ((info.RegionSize >= desiredSize) & (info.State == MEM_FREE))
		{
			*address = info.BaseAddress;
			*size = desiredSize;
			error = NtAllocateVirtualMemory(thisProcess, address, 0, size, type, protection);

			if (error == 0)
			{
				return 0;
			}

			if (error == STATUS_CONFLICTING_ADDRESSES)
			{
				/+ If another thread claimed this span before us,
				   we should avoid advancing to the end of the region
				   as it may be the final free region of the process's address-space,
				   and the advancement would thus effect a spurious failure.
				   But if we don't advance at all we can end up in an infinite loop,
				   so we'll advance by the minimum possible distance. +/

				base += 64.KB;
				goto proceedWithIncrementedBase;
			}
		}

		base = info.BaseAddress + info.RegionSize;
	proceedWithIncrementedBase:
		if (base > tail)
		{
			return STATUS_NO_MEMORY;
		}
	}

	/+ Frontend is dumb in the (glorious) presence of goto. +/
	assert(false);
}


pragma(inline, true)
void prefetchData (uint distance = 0) (scope const(void)* address) @safe pure nothrow @nogc
if (distance <= 3)
{
	if (__ctfe)
	{}
	else
	{
		static if (LDC)
		{
			import ldc.intrinsics : llvm_prefetch;
			llvm_prefetch(address, 0, distance ^ 3, 1);
		}
		else static if (GDC)
		{
			import gcc.builtins : __builtin_prefetch;
			__builtin_prefetch(address, 0, distance ^ 3);
		}
		else
		{
			import core.simd : prefetch;
			prefetch!(false, distance ^ 3)(address);
		}
	}
}


pragma(inline, true)
void prefetchWrite (uint distance = 0) (scope const(void)* address) @safe pure nothrow @nogc
if (distance <= 3)
{
	if (__ctfe)
	{}
	else
	{
		static if (LDC)
		{
			import ldc.intrinsics : llvm_prefetch;
			llvm_prefetch(address, 1, distance ^ 3, 1);
		}
		else static if (GDC)
		{
			import gcc.builtins : __builtin_prefetch;
			__builtin_prefetch(address, 1, distance ^ 3);
		}
		else
		{
			import core.simd : prefetch;
			prefetch!(true, distance ^ 3)(address);
		}
	}
}


pragma(inline, true)
size_t blit (T) (scope T* destination, scope const(T)* source, size_t length) @system pure nothrow @nogc
in ((cast(size_t) destination & (T.alignof - 1)) == 0)
in ((cast(size_t) source & (T.alignof - 1)) == 0)
{
	static if (x86X)
	{
		static if (T.alignof >= 4)
		{
			repMovs(cast(uint*) destination, cast(const(uint)*) source, length * (T.sizeof >> 2));
		}
		else
		{
			repMovs(cast(ubyte*) destination, cast(const(ubyte)*) source, length * T.sizeof);
		}
	}
	else
	{
		static if (T.alignof >= 8)
		{
			enum uint shift = 3;
			alias Chunk = ulong;
		}
		else static if (T.alignof >= 4)
		{
			enum uint shift = 2;
			alias Chunk = uint;
		}
		else
		{
			enum uint shift = 0;
			alias Chunk = ubyte;
		}

		foreach (index; 0 .. length * (T.sizeof >> shift))
		{
			(cast(Chunk*) destination)[index] = (cast(const(Chunk)*) source)[index];
		}
	}

	return length;
}


pragma(inline, true)
size_t blit (T) (scope T* destination, scope const(T)* source) @trusted pure nothrow @nogc
in ((cast(size_t) destination & (T.alignof - 1)) == 0)
in ((cast(size_t) source & (T.alignof - 1)) == 0)
{
	static if (x86X)
	{
		static if (T.alignof >= 4)
		{
			repMovs(cast(uint*) destination, cast(const(uint)*) source, T.sizeof >> 2);
		}
		else
		{
			repMovs(cast(ubyte*) destination, cast(const(ubyte)*) source, T.sizeof);
		}
	}
	else
	{
		static if (T.alignof >= 8)
		{
			enum uint shift = 3;
			alias Chunk = ulong;
		}
		else static if (T.alignof >= 4)
		{
			enum uint shift = 2;
			alias Chunk = uint;
		}
		else
		{
			enum uint shift = 0;
			alias Chunk = ubyte;
		}

		foreach (index; 0 .. T.sizeof >> shift)
		{
			(cast(Chunk*) destination)[index] = (cast(const(Chunk)*) source)[index];
		}
	}

	return T.sizeof;
}


pragma(inline, true)
void zeroOut (T) (scope T* values, size_t length) @system pure nothrow @nogc
in ((cast(size_t) values & (T.alignof - 1)) == 0)
{
	static if (x86X)
	{
		static if (T.alignof >= 4)
		{
			repStos(cast(uint*) values, 0, length * (T.sizeof >> 2));
		}
		else
		{
			repStos(cast(ubyte*) values, 0, length * T.sizeof);
		}
	}
	else
	{
		static if (T.alignof >= 8)
		{
			enum uint shift = 3;
			alias Chunk = ulong;
		}
		else static if (T.alignof >= 4)
		{
			enum uint shift = 2;
			alias Chunk = uint;
		}
		else
		{
			enum uint shift = 0;
			alias Chunk = ubyte;
		}

		foreach (index; 0 .. length * (T.sizeof >> shift))
		{
			(cast(Chunk*) values)[index] = 0;
		}
	}
}


pragma(inline, true)
void zeroOut (T) (scope T* value) @trusted pure nothrow @nogc
in ((cast(size_t) value & (T.alignof - 1)) == 0)
{
	static if (x86X)
	{
		static if (T.alignof >= 4)
		{
			repStos(cast(uint*) value, 0, T.sizeof >> 2);
		}
		else
		{
			repStos(cast(ubyte*) value, 0, T.sizeof);
		}
	}
	else
	{
		static if (T.alignof >= 8)
		{
			enum uint shift = 3;
			alias Chunk = ulong;
		}
		else static if (T.alignof >= 4)
		{
			enum uint shift = 2;
			alias Chunk = uint;
		}
		else
		{
			enum uint shift = 0;
			alias Chunk = ubyte;
		}

		foreach (index; 0 .. T.sizeof >> shift)
		{
			(cast(Chunk*) value)[index] = 0;
		}
	}
}


static if (x86X)
{
	extern(C)
	pragma(inline, true)
	void repMovs (T) (scope T* destination, scope const(T)* source, size_t length) @system pure nothrow @nogc
	{
		import core.bitop : bsr;

		if (__ctfe)
		{
			foreach (index; 0 .. length)
			{
				destination[index] = source[index];
			}
		}
		else
		{
			enum size = T.sizeof.bsr;

			version (LDC)
			{
				import ldc.llvmasm : __ir_pure;

				enum char suffix = "bwlq"[size];
				enum dataType = ["i8", "i16", "i32", "i64"][size];
				enum ptr = llvmIRPtr!dataType;
				enum lengthType = ["i8", "i16", "i32", "i64"][size_t.sizeof.bsr];

				version (X86)
				{
					enum indexPrefix = 'e';
				}
				else version (X86_64)
				{
					enum indexPrefix = 'r';
				}

				__ir_pure!(
					`call {` ~ ptr ~ `, ` ~ ptr ~ `, ` ~ lengthType ~ `} asm
					 "rep movs` ~ suffix ~ `",
					 "=&{` ~ indexPrefix ~ `di},=&{` ~ indexPrefix ~ `si},=&{ecx},0,1,2,~{memory}"
					 (` ~ ptr ~ ` %0, ` ~ ptr ~ ` %1, ` ~ lengthType ~ ` %2)`,
					void
				)(destination, source, length);
			}
			else version (GNU)
			{
				enum char suffix = "bwlq"[size];

				asm @system pure nothrow @nogc
				 {
				 	  "rep movs" ~ suffix
				 	: "+&D" (destination), "+&S" (source), "+&c" (length)
				 	: "0" (destination), "1" (source), "2" (length)
				 	: "memory";
				 }
			}
			else version (InlineAsm_X86_64_Or_X86)
			{
				enum char suffix = "bwdq"[size];

				version (D_InlineAsm_X86_64)
				{
					mixin(
						"asm @system pure nothrow @nogc
						 {
						 	/* RCX is destination; RDX is source; R8 is length. */
						 	naked;
						 	mov R9, RDI; /* RDI is non-volatile, so we save it in R9. */
						 	mov RAX, RSI; /* RSI is non-volatile, so we save it in RAX. */
						 	mov RDI, RCX;
						 	mov RCX, R8;
						 	mov RSI, RDX;
						 	rep; movs" ~ suffix ~ ";
						 	mov RSI, RAX;
						 	mov RDI, R9;
						 	ret;
						 }"
					);
				}
				else version (D_InlineAsm_X86)
				{
					mixin(
						"asm @system pure nothrow @nogc
						 {
						 	naked;
						 	mov EAX, EDI; /* EDI is non-volatile, so we save it in EAX. */
						 	mov EDX, ESI; /* ESI is non-volatile, so we save it in EDX. */
						 	mov EDI, [ESP +  4]; /* destination. */
						 	mov ESI, [ESP +  8]; /* source. */
						 	mov ECX, [ESP + 12]; /* length. */
						 	rep; movs" ~ suffix ~ ";
						 	mov ESI, EDX;
						 	mov EDI, EAX;
						 	ret;
						 }"
					);
				}
			}
		}
	}

	@safe pure nothrow @nogc unittest
	{
		static bool test (alias I, alias movs)()
		{
			I[8] memory = [I.max, I.max - 1, 2, 3, 4, 5, 6, 7];

			((d, s) @trusted => movs(d, s, 4))(&memory[3], &memory[2]);
			assert(memory == [I.max, I.max - 1, 2, 2, 2, 2, 2, 7]);

			((d, s) @trusted => movs(d, s, 2))(&memory[0], &memory[6]);
			assert(memory == [2, 7, 2, 2, 2, 2, 2, 7]);

			return true;
		}

		assert(test!(ubyte, repMovs));
		static assert(test!(ubyte, repMovs));
		assert(test!(ushort, repMovs));
		static assert(test!(ushort, repMovs));
		assert(test!(uint, repMovs));
		static assert(test!(uint, repMovs));

		version (X86_64)
		{
			assert(test!(ulong, repMovs));
			static assert(test!(ulong, repMovs));
		}
	}


	extern(C)
	pragma(inline, true)
	void repStos (I) (scope I* destination, I data, size_t length) @system pure nothrow @nogc
	{
		if (__ctfe)
		{
			foreach (index; 0 .. length)
			{
				destination[index] = data;
			}
		}
		else
		{
			import core.bitop : bsr;

			enum size = I.sizeof.bsr;

			version (LDC)
			{
				import ldc.llvmasm : __ir_pure;

				enum char suffix = "bwlq"[size];
				enum type = ["i8", "i16", "i32", "i64"][size];

				version (X86)
				{
					enum string lengthType = "i32";
					enum a = "eax";
					enum c = "ecx";
					enum di = "edi";
				}
				else version (X86_64)
				{
					enum string lengthType = "i64";
					enum a = "rax";
					enum c = "rcx";
					enum di = "rdi";
				}

				__ir_pure!(
					`call {` ~ llvmIRPtr!type ~ `, ` ~ lengthType ~ `} asm
					 "rep stos` ~ suffix ~ `",
					 "=&{` ~ di ~ `},=&{` ~ c ~ `},0,{` ~ a ~ `},1,~{memory}"
					 (` ~ llvmIRPtr!type ~ ` %0, ` ~ type ~ ` %1, ` ~ lengthType ~ ` %2)`,
					void
				)(
					destination,
					data,
					length
				);
			}
			else version (GNU)
			{
				enum char suffix = "bwlq"[size];

				asm pure nothrow @nogc
				{
					  "rep stos" ~ suffix
					: "+&D" (destination), "+&c" (length)
					: "0" (destination), "1" (length), "a" (data)
					: "memory";
				}
			}
			else version (InlineAsm_X86_64_Or_X86)
			{
				enum char suffix = "bwdq"[size];

				version (D_InlineAsm_X86_64)
				{
					mixin(
						"asm pure nothrow @nogc
						 {
						 	/* RCX is destination; *D* is data; R8 is length. */
						 	naked;
						 	mov R9, RDI; /* RDI is non-volatile, so we save it in R9. */
						 	mov RDI, RCX;
						 	mov RAX, RDX;
						 	mov RCX, R8;
						 	rep; stos" ~ suffix ~ ";
						 	mov RDI, R9;
						 	ret;
						 }"
					);
				}
				else version (D_InlineAsm_X86)
				{
					mixin(
						"asm pure nothrow @nogc
						 {
						 	naked;
						 	mov EDX, EDI; /* EDI is non-volatile, so we save it in EDX. */
						 	mov EDI, [ESP +  4]; /* destination. */
						 	mov EAX, [ESP +  8]; /* data. */
						 	mov ECX, [ESP + 12]; /* length. */
						 	rep; stos" ~ suffix ~ ";
						 	mov EDI, EDX;
						 	ret;
						 }"
					);
				}
			}
		}
	}

	@safe pure nothrow @nogc unittest
	{
		static bool test(alias I, alias stos)()
		{
			I[8] memory = [I.max, I.max - 1, 2, 3, 4, 5, 6, 7];
			((m) @trusted => stos(m, 8, 4))(&memory[1]);

			assert(memory == [I.max, 8, 8, 8, 8, 5, 6, 7]);

			return true;
		}

		assert(test!(ubyte, repStos!ubyte));
		static assert(test!(ubyte, repStos!ubyte));
		assert(test!(ushort, repStos!ushort));
		static assert(test!(ushort, repStos!ushort));
		assert(test!(uint, repStos!uint));
		static assert(test!(uint, repStos!uint));

		version (X86_64)
		{
			assert(test!(ulong, repStos!ulong));
			static assert(test!(ulong, repStos!ulong));
		}
	}
}


version (LDC)
{
	template llvmIRPtr (string type, string postfix = null)
	{
		version (LDC_LLVM_OpaquePointers)
		{
			enum llvmIRPtr = postfix is null ? "ptr" : "ptr " ~ postfix;
		}
		else
		{
			enum llvmIRPtr = postfix is null ? type ~ "*" : type ~ " " ~ postfix ~ "*";
		}
	}
}

