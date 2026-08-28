
/+ SPDX-LICENSE-IDENTIFIER: 0BSD +/

module slack_common.text;

import ldc.attributes : optStrategy;

import slack_common.algorithms;
import slack_common.integers;
import slack_common.memory;
import slack_common.simd;
import slack_common.versions;

import std.traits : Unqual;


pragma(inline, true)
size_t strlen (Char = char, size_t alignment = 0, Char sentinel = '\0') (return scope Char* str)
{
	return findSentinel!(sentinel, alignment, Char)(str) - str;
}


pragma(inline, true)
size_t strlen (size_t alignment, Char = char, Char sentinel = '\0') (return scope Char* str)
{
	return findSentinel!(sentinel, alignment, Char)(str) - str;
}


pragma(inline, true)
Char* strend (Char = char, size_t alignment = 0, Char sentinel = '\0') (return scope Char* str)
{
	return findSentinel!(sentinel, alignment, Char)(str);
}


pragma(inline, true)
Char* strend (size_t alignment, Char = char, Char sentinel = '\0') (return scope Char* str)
{
	return findSentinel!(sentinel, alignment, Char)(str);
}


pragma(inline, true)
bool isProbablyUTF16LE (scope const(ubyte)[] data) @trusted pure nothrow @nogc
in (data.length >= 2)
{
	return ((data.ptr[0] == 0xFF) & ((data.ptr[1] == 0xFE))) | (data.ptr[1] == 0x00);
}


pragma(inline, true)
void asHexInto (bool uppercase, Char = char, Value) (Value value, scope ref Char[Value.sizeof * 2] hex)
{
	asHexInto!(Char, uppercase, Value)(value, hex);
}


@optStrategy("minsize")
void asHexInto (Char = char, bool uppercase = false, Value) (Value value, scope ref Char[Value.sizeof * 2] hex)
{
	enum uint letterNibble = 10;
	enum uint letterNibbleToLetter = Char(uppercase ? 'A' : 'a') - Char('0') - letterNibble;

	Unqual!Value theValue = value;

	foreach_reverse (index; 0 .. hex.length)
	{
		uint nibble = theValue & 0x0f;
		theValue >>= 4;
		uint adjustment = nibble < letterNibble ? 0 : letterNibbleToLetter;
		hex[index] = cast(Char) (Char('0') + nibble + adjustment);
	}
}


auto asDecimal (Char = char, alias padding = Char(' '), Value) (Value value)
{
	enum uint[] maximumBase10DigitsBySizeOf = [0, 3, 5, 8, 10, 13, 15, 17, 20];
	enum uint digitCount = maximumBase10DigitsBySizeOf[Value.sizeof];

	Unqual!Char[digitCount] decimal = padding;
	ulong theValue = value;
	size_t index = decimal.length;

	do
	{
		ulong previousValue = theValue;

		theValue /= 10;

		--index;
		decimal[index] = cast(Char) ('0' + cast(uint) (previousValue - theValue * 10));
	}
	while (theValue != 0);

	static struct AsDecimal
	{
		alias digits this;

		typeof(decimal) digits;
		ubyte firstSignificantDigitIndex;

		inout(Unqual!Char)[] unpadded () inout @property return scope
		{
			return this.digits[firstSignificantDigitIndex .. $];
		}
	}

	return AsDecimal(decimal, cast(ubyte) index);
}

@safe pure nothrow @nogc unittest
{
	static bool test (Char) ()
	{
		assert(ubyte(0).asDecimal!Char == "  0");
		assert(ushort(0).asDecimal!Char == "    0");
		assert(uint(0).asDecimal!Char == "         0");
		assert(ulong(0).asDecimal!Char == "                   0");
		assert(ubyte(1).asDecimal!Char == "  1");
		assert(ushort(1).asDecimal!Char == "    1");
		assert(uint(1).asDecimal!Char == "         1");
		assert(ulong(1).asDecimal!Char == "                   1");
		assert(ubyte(9).asDecimal!Char == "  9");
		assert(ushort(9).asDecimal!Char == "    9");
		assert(uint(9).asDecimal!Char == "         9");
		assert(ulong(9).asDecimal!Char == "                   9");

		assert(ubyte(10).asDecimal!Char == " 10");
		assert(ushort(10).asDecimal!Char == "   10");
		assert(uint(10).asDecimal!Char == "        10");
		assert(ulong(10).asDecimal!Char == "                  10");

		assert(ubyte(255).asDecimal!Char == "255");
		assert(ushort(65535).asDecimal!Char == "65535");
		assert(uint(4294967295).asDecimal!Char == "4294967295");
		assert(ulong(18446744073709551615).asDecimal!Char == "18446744073709551615");

		assert(ubyte(0).asDecimal!Char.unpadded == "0");
		assert(ushort(0).asDecimal!Char.unpadded == "0");
		assert(uint(0).asDecimal!Char.unpadded == "0");
		assert(ulong(0).asDecimal!Char.unpadded == "0");
		assert(ubyte(1).asDecimal!Char.unpadded == "1");
		assert(ushort(1).asDecimal!Char.unpadded == "1");
		assert(uint(1).asDecimal!Char.unpadded == "1");
		assert(ulong(1).asDecimal!Char.unpadded == "1");
		assert(ubyte(9).asDecimal!Char.unpadded == "9");
		assert(ushort(9).asDecimal!Char.unpadded == "9");
		assert(uint(9).asDecimal!Char.unpadded == "9");
		assert(ulong(9).asDecimal!Char.unpadded == "9");

		assert(ubyte(10).asDecimal!Char.unpadded == "10");
		assert(ushort(10).asDecimal!Char.unpadded == "10");
		assert(uint(10).asDecimal!Char.unpadded == "10");
		assert(ulong(10).asDecimal!Char.unpadded == "10");

		assert(ubyte(255).asDecimal!Char.unpadded == "255");
		assert(ushort(65535).asDecimal!Char.unpadded == "65535");
		assert(uint(4294967295).asDecimal!Char.unpadded == "4294967295");
		assert(ulong(18446744073709551615).asDecimal!Char.unpadded == "18446744073709551615");

		return true;
	}

	assert(test!char);
	static assert(test!char);
	assert(test!wchar);
	static assert(test!wchar);
	assert(test!dchar);
	static assert(test!dchar);
}


pragma(inline, true)
Char asciiLowerCase (Char) (Char character) @safe pure nothrow @nogc
if (__traits(isScalar, Char) && !is(Char == __vector(C[size]), C, size_t size))
{
	Char isUpperCase = (character > '@') & (character <= 'Z');
	return cast(Char) (character | (isUpperCase << 5));
}

@safe pure nothrow @nogc unittest
{
	static void test (Char) ()
	{
		alias l = asciiLowerCase!Char;

		for (char character = '\0'; character < 'A'; ++character) assert(l(character) == character);
		for (char character = 'Z'; character++ < 255;) assert(l(character) == character);

		assert(l('A') == 'a'); assert(l('B') == 'b'); assert(l('C') == 'c');
		assert(l('D') == 'd'); assert(l('E') == 'e'); assert(l('F') == 'f');
		assert(l('G') == 'g'); assert(l('H') == 'h'); assert(l('I') == 'i');
		assert(l('J') == 'j'); assert(l('K') == 'k'); assert(l('L') == 'l');
		assert(l('M') == 'm'); assert(l('N') == 'n'); assert(l('O') == 'o');
		assert(l('P') == 'p'); assert(l('Q') == 'q'); assert(l('R') == 'r');
		assert(l('S') == 's'); assert(l('T') == 't'); assert(l('U') == 'u');
		assert(l('V') == 'v'); assert(l('W') == 'w'); assert(l('X') == 'x');
		assert(l('Y') == 'y'); assert(l('Z') == 'z');
	}

	test!char;
	test!wchar;
	test!dchar;
}


pragma(inline, true)
__vector(Char[vectorSize]) asciiLowerCase (Char, size_t vectorSize) (
	__vector(Char[vectorSize]) text
) @trusted pure nothrow @nogc
if (__traits(isScalar, Char))
{

	enum uint byteWidth = 16;

	static assert(byteWidth % Char.sizeof == 0);

	alias Int = IntsFittingSizeOf[Char.sizeof];
	alias V = __vector(Int[byteWidth / Int.sizeof]);

	V lowerBound = '@';
	V upperBound = 'Z';
	V bitMask = 0b00100000;

	V chunk = cast(V) text;
	V lowerCaseBits = (bitMask & (chunk > lowerBound)) & (chunk <= upperBound);
	V lowerCase = chunk | lowerCaseBits;

	return cast(typeof(return)) lowerCase;
}


pragma(inline, true)
bool caseInsensitiveASCIIEquality (Char) (scope const(Char) a, scope const(Char) b) @safe pure nothrow @nogc
{
	return asciiLowerCase(a) == asciiLowerCase(b);
}


bool caseInsensitiveASCIIEquality (bool lowerCaseB = false, Char) (
	scope const(Char)* a,
	scope const(Char)* b,
	size_t length
) pure nothrow @nogc
{
	enum uint byteWidth = 16;

	static assert(byteWidth % Char.sizeof == 0);

	alias Int = IntsFittingSizeOf[Char.sizeof];
	alias V = __vector(Int[byteWidth / Int.sizeof]);

	size_t remaining = length;

	while (remaining >= V.length)
	{
		auto aa = asciiLowerCase(loadVector!V(a));
		auto bb = loadVector!V(b);
		static if (!lowerCaseB) bb = asciiLowerCase(bb);

		a += V.length;
		b += V.length;
		remaining -= V.length;

		if (aa !is bb)
		{
			return false;
		}
	}

	while (remaining)
	{
		auto aa = asciiLowerCase(*a);
		Unqual!Char bb = *b;
		static if (!lowerCaseB) bb = asciiLowerCase(bb);

		++a;
		++b;
		--remaining;

		if (aa !is bb)
		{
			return false;
		}
	}

	return true;
}


inout(Char)* findLineOfText (Char) (
	return scope inout(Char)* c,
	return scope inout(Char)* end,
	scope inout(Char)** startOfLine
) @trusted pure nothrow @nogc
in (c <= end)
{
findLine:
	if (c >= end) return c;
	if (((*c < '\t') | (*c > '\r')) & (*c != ' ')) goto beginningOfLine;
	++c;
	goto findLine;
beginningOfLine:
	*startOfLine = c;
findEndOfLine:
	++c;
	if (c >= end) goto trimEndOfLine;
	if ((*c == '\r') | (*c == '\n')) goto trimEndOfLine;
	goto findEndOfLine;
trimEndOfLine:
	--c;
	if (((*c >= '\t') & (*c <= '\f')) | (*c == ' ')) goto trimEndOfLine;
	return c + 1;
}

@trusted pure nothrow @nogc unittest
{
	const(char)[] text = "\r\n\n   This is some text!   \r\n";
	const(char)* startOfLine = null;
	const(char)* endOfLine = null;

	endOfLine = findLineOfText(text.ptr, text.ptr + text.length - 3, &startOfLine);
	assert(startOfLine == text.ptr + 6);
	assert(endOfLine == text.ptr + 24);

	endOfLine = findLineOfText(text.ptr, text.ptr + text.length - 3, &startOfLine);
	assert(startOfLine == text.ptr + 6);
	assert(endOfLine == text.ptr + 24);

	endOfLine = findLineOfText(text.ptr + 3, text.ptr + 5, &startOfLine);
	assert(startOfLine == text.ptr + 6);
	assert(endOfLine == text.ptr + 5);

	endOfLine = findLineOfText(text.ptr + 24, text.ptr + 29, &startOfLine);
	assert(startOfLine == text.ptr + 6);
	assert(endOfLine == text.ptr + 29);
}


dchar utf8ToUTF16 (
	scope const(char)** utf8,
	scope const(char)* endOfUTF8,
	scope wchar** utf16,
	scope const(wchar)* endOfUTF16
) @trusted pure nothrow @nogc
{
	static if (x86X && LDC)
	{
		import ldc.gccbuiltins_x86 : __builtin_ia32_pmovmskb128;
		import ldc.llvmasm : __ir_pure;

		enum size_t byteWidth = 16;
		alias movmsk = __builtin_ia32_pmovmskb128;
		alias Mask = ushort;

		enum bool usingSIMD = true;
	}
	else
	{
		enum bool usingSIMD = false;
	}

	dchar pendingCodePoint = cast(dchar) -1;

	const(char)* utf8SIMDLimit = endOfUTF8 - 16;
	const(wchar)* utf16SIMDLimit = endOfUTF16 - 16;

	const(char)* c = *utf8;
	wchar* w = *utf16;

	static if (usingSIMD)
	{
		alias V = __vector(byte[16]);
	next:
		if ((c <= utf8SIMDLimit) & (w <= utf16SIMDLimit))
		{
			V cc = loadVector!V(cast(const(byte)*) c);
			Mask nonASCIIMask = cast(Mask) __builtin_ia32_pmovmskb128(cc);

			if (nonASCIIMask == 0)
			{
				/+ If it's just ASCII (spoiler alert--it is), then we'll just
				   blit the ASCII to UTF-16 via a PUNPCKLBW and a PUNPCKHBW. +/

				V zero = 0;

				V firstHalf = __ir_pure!(
					`%v = shufflevector <16 x i8> %0, <16 x i8> %1, <16 x i32> <i32 0, i32 16, i32 1, i32 17, i32 2, i32 18, i32 3, i32 19, i32 4, i32 20, i32 5, i32 21, i32 6, i32 22, i32 7, i32 23>
					 ret <16 x i8> %v`,
					V
				)(cc, zero);

				storeVector!V(cast(byte*) w, firstHalf);

				V secondHalf = __ir_pure!(
					`%v = shufflevector <16 x i8> %0, <16 x i8> %1, <16 x i32> <i32 8, i32 24, i32 9, i32 25, i32 10, i32 26, i32 11, i32 27, i32 12, i32 28, i32 13, i32 29, i32 14, i32 30, i32 15, i32 31>
					 ret <16 x i8> %v`,
					V
				)(cc, zero);

				storeVector!V(cast(byte*) (w + 8), secondHalf);

				c += 16;
				w += 16;

				goto next;
			}

			/+ Otherwise if it's not just ASCII we'll blit whatever ASCII we can
			   and then proceed with the usual scalar logic. +/

			uint bix = nonASCIIMask.leastSetBitIndex!(No.definedForZero);

			while (bix--)
			{
				*w++ = *c++;
			}

			assert((c < endOfUTF8) & (w < endOfUTF16));

			assert(*c >= 128);

			goto handleNonASCIIScalarLead;
		}
	}
	else
	{
	next:
	}

	if ((c >= endOfUTF8) | (w >= endOfUTF16))
	{
	finish:
		*utf8 = c;
		*utf16 = w;
		return pendingCodePoint;
	}
handleScalarLead:
	if (*c < 128)
	{
		*w++ = *c++;
		goto next;
	}
handleNonASCIIScalarLead:
	uint lead = endianSwap(uint(*c));
	uint codeUnitCount = leadingZeroCount!(No.definedForZero)(~lead | 1);

	if (endOfUTF8 - c < codeUnitCount)
	{
		*w++ = 0xFFFD;
		goto finish;
	}

	if (codeUnitCount < 4)
	{
		assert(codeUnitCount == 2 || codeUnitCount == 3);

		uint leadBits = codeUnitCount == 3 ? 12 : 6;

		uint codePoint = *c++ & ((1 << (7 - codeUnitCount)) - 1);
		codePoint <<= leadBits;

		leadBits -= 6;
		codePoint |= uint(*c & 0b00111111) << leadBits;

		if ((*c >>> 6) != 0b10)
		{
			++c;
			goto replacementCharacter;
		}

		/+ If we have 3 code-units we'll eat the third code-unit here,
		   otherwise if we have 2, we'll eat the second code-unit again. +/
		c += codeUnitCount == 3;
		uint overlongThreshold = codeUnitCount == 3 ? 0x0800 : 0x0080;

		codePoint |= uint(*c & 0b00111111);

		if (((*c++ >>> 6) != 0b10) | (codePoint < overlongThreshold))
		{
			goto replacementCharacter;
		}

		*w++ = cast(ushort) codePoint;

		goto next;
	}
	else if (codeUnitCount == 4)
	{
		uint codePoint = (*c++ & 0b00000111) << 18;

		for (uint bits = 12;; bits -= 6)
		{
			codePoint |= uint(*c & 0b00111111) << bits;

			if ((*c++ >>> 6) != 0b10)
			{
				goto replacementCharacter;
			}

			if (bits == 0)
			{
				break;
			}
		}

		if (codePoint < 0x10000)
		{
			goto replacementCharacter;
		}

		if (endOfUTF16 - w < 2)
		{
			pendingCodePoint = codePoint;
			goto finish;
		}

		codePoint -= 0x10000;

		*w++ = 0xD800 | cast(ushort) (codePoint >> 10);
		*w++ = 0xDC00 | (codePoint & 0b0000001111111111);

		goto next;
	}
	else
	{
		*w++ = 0xFFFD;

		if (w >= endOfUTF16)
		{
			goto finish;
		}
	windThroughOverlong:
		++c;

		assert(c < endOfUTF8);

		if ((*c >> 6) == 0b10)
		{
			goto windThroughOverlong;
		}

		goto handleScalarLead;
	}
replacementCharacter:
	*w++ = 0xFFFD;
	goto next;
}
