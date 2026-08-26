
/+ SPDX-LICENSE-IDENTIFIER: 0BSD +/

module slack_common.cpp;


struct std_basic_string (Char)
{
	union
	{
		Char[16] inline = 0;
		Char* allocated;
	}
	size_t size;
	size_t capacity;

	alias asSlice this;

	pragma(inline, true)
	inout(Char)[] asSlice () inout @property return scope @trusted pure nothrow @nogc
	{
		return this.base[0 .. this.size];
	}

	pragma(inline, true)
	inout(Char)* base () () inout @property return scope @trusted pure nothrow @nogc
	{
		return this.capacity >= 16 ? this.allocated : this.inline.ptr;
	}
}


alias std_string = std_basic_string!char;


struct std_vector (T)
{
	T* base;
	T* tail;
	T* space;

	alias asSlice this;

	pragma(inline, true)
	inout(T)[] asSlice () inout @property return scope @trusted pure nothrow @nogc
	{
		return this.base[0 .. this.tail - this.base];
	}

	pragma(inline, true)
	size_t size () const @property scope @safe pure nothrow @nogc
	{
		return this.tail - this.base;
	}

	pragma(inline, true)
	size_t capacity () const @property scope @safe pure nothrow @nogc
	{
		return this.space - this.base;
	}
}

