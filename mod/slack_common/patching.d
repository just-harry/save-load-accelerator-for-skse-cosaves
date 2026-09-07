
/+ SPDX-LICENSE-IDENTIFIER: 0BSD +/

module slack_common.patching;

import ldc.attributes : optStrategy;

import slack_common.bindings;
import slack_common.memory;
import slack_common.text;
import slack_common.user_interface;
import slack_common.versions;


pragma(inline, true)
Int x86Displacement (ubyte instructionSize, Int = int) (
	scope const(ubyte)* origin,
	scope const(ubyte)* target
) @trusted pure nothrow @nogc
{
	ptrdiff_t displacement = target - (origin + instructionSize);

	static if (Int.sizeof < ptrdiff_t.sizeof)
	{
		debug assert(displacement >= Int.min);
		debug assert(displacement <= Int.max);
	}

	return cast(Int) displacement;
}


pragma(inline, true)
const(ubyte)* x86Displaced (ubyte instructionSize, Int) (
	scope const(ubyte)* origin,
	Int displacement
) @trusted pure nothrow @nogc
{
	return origin + instructionSize + displacement;
}


pragma(inline, true)
const(ubyte)* x86TargetOf (ubyte instructionSize, Int = int) (
	scope const(ubyte)* origin
) @trusted pure nothrow @nogc
{
	return x86Displaced!instructionSize(
		origin,
		*unaligned(cast(const(Int)*) (origin + instructionSize - Int.sizeof))
	);
}


pragma(inline, true)
ubyte modRM (uint mod, uint r, uint m) @safe pure nothrow @nogc
in (mod <= 0b11)
in (r <= 0b111)
in (m <= 0b111)
{
	/+ Octal literals are bad... because! +/
	return cast(ubyte) ((mod << 6) | (r << 3) | m);
}


struct REXPrefix
{
	alias value this;

	ubyte value;

	pragma(inline, true)
	REXPrefix W () const @property scope @safe pure nothrow @nogc
	{
		return REXPrefix(this.value | 0b1000);
	}

	pragma(inline, true)
	REXPrefix R () const @property scope @safe pure nothrow @nogc
	{
		return REXPrefix(this.value | 0b0100);
	}

	pragma(inline, true)
	REXPrefix X () const @property scope @safe pure nothrow @nogc
	{
		return REXPrefix(this.value | 0b0010);
	}

	pragma(inline, true)
	REXPrefix B () const @property scope @safe pure nothrow @nogc
	{
		return REXPrefix(this.value | 0b0001);
	}
}


enum REXPrefix REX = REXPrefix(0b01000000);


pragma(inline, true)
auto copyInstructionTo (ubyte size) (scope ubyte* source, scope ubyte* destination) pure nothrow @nogc
if (size >= 4 && size <= 6)
{
	static if (size == 4)
	{
		ubyte prefix = source[0];
		ubyte opcode = source[1];

		if ((prefix == /+ operand size prefix +/0x66) & ((opcode == /+ jmp +/0xE9) | (opcode == /+ call +/0xE8)))
		{
			const(ubyte)* target = x86Displaced!(4, short)(source, *unaligned(cast(short*) &source[2]));
			short displacement = x86Displacement!(4, short)(destination, target);

			destination[0] = prefix;
			destination[1] = opcode;
			*unaligned(cast(short*) &destination[2]) = displacement;

			return displacement;
		}
		else
		{
			*unaligned(cast(int*) &destination) = *unaligned(cast(int*) &source);
			return 0;
		}
	}
	static if (size >= 5)
	{
		ubyte opcode = *source;

		*destination = opcode;

		int displacement = void;

		if ((opcode == /+ jmp +/0xE9) | (opcode == /+ call +/0xE8))
		{
			const(ubyte)* target = x86Displaced!5(source, *unaligned(cast(int*) &source[1]));
			displacement = x86Displacement!5(destination, target);

			*unaligned(cast(uint*) &destination[1]) = displacement;
		}
		else
		{
			*unaligned(cast(int*) &destination[1]) = *unaligned(cast(int*) &source[1]);
			displacement = 0;
		}

		static if (size == 6)
		{
			destination[5] = source[5];
		}

		return displacement;
	}
}


pragma(inline, true)
size_t writeJumpTo (bool canBeShort = false) (
	scope ubyte* memory,
	scope const(ubyte)* target,
	uint x86Register = 0
) pure nothrow @nogc
{
	ptrdiff_t nearDisplacement = target - (memory + 5);

	static if (canBeShort)
	{
		ptrdiff_t shortDisplacement = target - (memory + 2);

		if ((shortDisplacement >= byte.min) & (shortDisplacement <= byte.max))
		{
			memory[0] = /+ jmp +/0xEB;
			*cast(byte*) &memory[1] = cast(byte) shortDisplacement;
			return 2;
		}
	}

	if ((nearDisplacement >= int.min) & (nearDisplacement <= int.max))
	{
		memory[0] = /+ jmp +/0xE9;
		*unaligned(cast(int*) &memory[1]) = cast(int) nearDisplacement;
		return 5;
	}
	else
	{
		writeIndirectJumpTo(memory, target, x86Register);
		return 12;
	}
}


pragma(inline, true)
int writeNearJumpTo (scope ubyte* memory, scope const(ubyte)* target) pure nothrow @nogc
{
	int displacement = x86Displacement!5(memory, target);

	memory[0] = /+ jmp +/0xE9;
	*unaligned(cast(int*) &memory[1]) = displacement;

	return displacement;
}


pragma(inline, true)
void writeIndirectJumpTo (scope ubyte* memory, scope const(ubyte)* target, uint x86Register = 0) pure nothrow @nogc
{
	static assert(x86_64);

	memory[0] = REX.W;
	memory[1] = /+ mov r64, imm64 +/cast(ubyte) (0xB8 + x86Register);
	*unaligned(cast(ulong*) &memory[2]) = cast(ulong) target;
	memory[10] = /+ jmp/4 +/0xFF;
	memory[11] = modRM(3, 4, x86Register);
}


pragma(inline, true)
size_t writeCallOf (scope ubyte* memory, scope const(ubyte)* target, uint x86Register = 0) pure nothrow @nogc
{
	ptrdiff_t displacement = target - (memory + 5);

	if ((displacement >= int.min) & (displacement <= int.max))
	{
		memory[0] = /+ call +/0xE8;
		*unaligned(cast(int*) &memory[1]) = cast(int) displacement;
		return 5;
	}
	else
	{
		writeIndirectCallOf(memory, target, x86Register);
		return 12;
	}
}


pragma(inline, true)
int writeDirectCallOf (scope ubyte* memory, scope const(ubyte)* target) pure nothrow @nogc
{
	int displacement = x86Displacement!5(memory, target);

	memory[0] = /+ call +/0xE8;
	*unaligned(cast(int*) &memory[1]) = displacement;

	return displacement;
}


pragma(inline, true)
void writeIndirectCallOf (scope ubyte* memory, scope const(ubyte)* target, uint x86Register = 0) pure nothrow @nogc
in (x86Register < 8)
{
	static assert(x86_64);

	memory[0] = REX.W;
	memory[1] = /+ mov r64, imm64 +/cast(ubyte) (0xB8 + x86Register);
	*unaligned(cast(ulong*) &memory[2]) = cast(ulong) target;
	memory[10] = /+ call/2 +/0xFF;
	memory[11] = modRM(3, 2, x86Register);
}


pragma(inline, true)
int writeNearDisplacementTo (ubyte instructionSize) (
	scope ubyte* memory,
	scope const(ubyte)* target
) pure nothrow @nogc
{
	int displacement = x86Displacement!instructionSize(memory, target);

	*unaligned(cast(int*) (memory + instructionSize - 4)) = displacement;

	return displacement;
}


pragma(inline, true)
void nopOut (ubyte nopSize = 1) (scope ubyte* memory) pure nothrow @nogc
if (nopSize >= 1 && nopSize <= 9)
{
	alias m = memory;

	     static if (nopSize == 1) {m[0] = 0x90;}
	else static if (nopSize == 2) {m[0] = 0x66; m[1] = 0x90;}
	else static if (nopSize == 3) {m[0] = 0x0F; m[1] = 0x1F; m[2] = 0x00;}
	else static if (nopSize == 4) {*unaligned(cast(uint*) m) = 0x00401F0F;}
	else static if (nopSize == 5) {*unaligned(cast(uint*) m) = 0x00441F0F; m[4] = 0x00;}
	else static if (nopSize == 6) {*unaligned(cast(uint*) m) = 0x441F0F66; m[4] = 0x00; m[5] = 0x00;}
	else static if (nopSize == 7) {*unaligned(cast(uint*) m) = 0x00801F0F; m[4] = 0x00; m[5] = 0x00; m[6] = 0x00;}
	else static if (nopSize == 8) {*unaligned(cast(uint*) m) = 0x00841F0F; *unaligned(cast(uint*) (m + 4)) = 0x00000000;}
	else static if (nopSize == 9) {*unaligned(cast(uint*) m) = 0x841F0F66; *unaligned(cast(uint*) (m + 4)) = 0x00000000; m[8] = 0x00;}
}


pragma(inline, true)
void withRegionMadeWritable () (
	scope ubyte* memory,
	int length,
	scope void function (scope ubyte* address, size_t size) @system nothrow @nogc action
) @trusted
{
	_withMemoryRegionMadeWritable(memory, cast(size_t) length, action, PAGE_READWRITE);
}


pragma(inline, true)
void withRegionMadeWritable () (
	scope ubyte* memory,
	int length,
	scope void delegate (scope ubyte* address, size_t size) @system nothrow @nogc action
) @trusted
{
	_withMemoryRegionMadeWritable(memory, cast(size_t) length, action, PAGE_READWRITE);
}


pragma(inline, true)
void withRegionMadeWritable () (
	scope ubyte* memory,
	size_t length,
	scope void function (scope ubyte* address, size_t size) @system nothrow @nogc action
) @trusted
{
	_withMemoryRegionMadeWritable(memory, length, action, PAGE_READWRITE);
}


pragma(inline, true)
void withRegionMadeWritable () (
	scope ubyte* memory,
	size_t length,
	scope void delegate (scope ubyte* address, size_t size) @system nothrow @nogc action
) @trusted
{
	_withMemoryRegionMadeWritable(memory, length, action, PAGE_READWRITE);
}


pragma(inline, true)
void withCodeRegionMadeWritable () (
	scope ubyte* memory,
	int length,
	scope void function (scope ubyte* address, size_t size) @system nothrow @nogc action
) @trusted
{
	_withMemoryRegionMadeWritable(memory, cast(size_t) length, action, PAGE_EXECUTE_READWRITE);
}


pragma(inline, true)
void withCodeRegionMadeWritable () (
	scope ubyte* memory,
	int length,
	scope void delegate (scope ubyte* address, size_t size) @system nothrow @nogc action
) @trusted
{
	_withMemoryRegionMadeWritable(memory, cast(size_t) length, action, PAGE_EXECUTE_READWRITE);
}


pragma(inline, true)
void withCodeRegionMadeWritable () (
	scope ubyte* memory,
	size_t length,
	scope void function (scope ubyte* address, size_t size) @system nothrow @nogc action
) @trusted
{
	_withMemoryRegionMadeWritable(memory, length, action, PAGE_EXECUTE_READWRITE);
}


pragma(inline, true)
void withCodeRegionMadeWritable () (
	scope ubyte* memory,
	size_t length,
	scope void delegate (scope ubyte* address, size_t size) @system nothrow @nogc action
) @trusted
{
	_withMemoryRegionMadeWritable(memory, length, action, PAGE_EXECUTE_READWRITE);
}


@optStrategy("minsize")
private void _withMemoryRegionMadeWritable (Action) (
	scope ubyte* memory,
	size_t length,
	scope Action action,
	uint protection
)
{
	void* pageBase = memory;
	size_t pageSize = length;
	uint originalProtection = void;

	NTSTATUS error = NtProtectVirtualMemory(
		cast(HANDLE) -1,
		&pageBase,
		&pageSize,
		protection,
		&originalProtection
	);

	if (error)
	{
		wchar[256] stringBuffer = void;
		blit(stringBuffer.ptr, "Failed to make a region of memory writeable whilst patching the game's code.\r\nThe game will now exit to prevent the possibility of save corruption.\r\nBase: 0x"w.ptr, 157);
		(cast(ulong) memory).asHexInto!true((stringBuffer.ptr + 157)[0 .. 16]);
		blit(stringBuffer.ptr + 157 + 16, "\r\nSize: 0x"w.ptr, 10);
		length.asHexInto!true((stringBuffer.ptr + 157 + 16 + 10)[0 .. 16]);
		blit(stringBuffer.ptr + 157 + 16 + 10 + 16, "\r\nOS Error Code: 0x"w.ptr, 19);
		error.asHexInto!true((stringBuffer.ptr + 157 + 16 + 10 + 16 + 19)[0 .. 8]);
		*(stringBuffer.ptr + 157 + 16 + 10 + 16 + 19 + 8) = '\0';

		reportErrorToUser(stringBuffer.ptr);

		RtlExitUserProcess(error);
	}

	try
	{
		action(memory, length);
	}
	finally
	{
		NtProtectVirtualMemory(
			cast(HANDLE) -1,
			&pageBase,
			&pageSize,
			originalProtection,
			&originalProtection
		);
	}
}


@optStrategy("minsize")
void makeMemoryRegionExecutable (scope ubyte* memory, size_t length) nothrow @nogc
{
	void* pageBase = memory;
	size_t pageSize = length;
	uint originalProtection = void;

	NTSTATUS error = NtProtectVirtualMemory(
		cast(HANDLE) -1,
		&pageBase,
		&pageSize,
		PAGE_EXECUTE_READ,
		&originalProtection
	);

	if (error)
	{
		wchar[224] stringBuffer = void;
		blit(stringBuffer.ptr, "Failed to make a region of memory executable whilst patching the game's code.\r\nThe game will now exit so as to avoid a crash later on.\r\nBase: 0x"w.ptr, 144);
		(cast(ulong) memory).asHexInto!true((stringBuffer.ptr + 144)[0 .. 16]);
		blit(stringBuffer.ptr + 144 + 16, "\r\nSize: 0x"w.ptr, 10);
		length.asHexInto!true((stringBuffer.ptr + 144 + 16 + 10)[0 .. 16]);
		blit(stringBuffer.ptr + 144 + 16 + 10 + 16, "\r\nOS Error Code: 0x"w.ptr, 19);
		error.asHexInto!true((stringBuffer.ptr + 144 + 16 + 10 + 16 + 19)[0 .. 8]);
		*(stringBuffer.ptr + 144 + 16 + 10 + 16 + 19 + 8) = '\0';

		reportErrorToUser(stringBuffer.ptr);
	}
}

