
/+ SPDX-LICENSE-IDENTIFIER: 0BSD +/

module game.offsets;

import game.target;

import slack_common.peb_access;


struct EXEBasedOffset (T)
{
	alias Type = T;

	uint ae7_99;
	uint ae1170;
	uint ae1130;
	uint ae640;
	uint ae353;
	uint se;
	uint vr;
	uint gog;
	uint gog659;
}


pragma(inline, true)
auto based (alias offset) () @trusted
if (is(typeof(offset) == EXEBasedOffset!T, T) && __traits(getMember, offset, targetedGameTag) != 0)
{
	void* address = getPEB.ImageBaseAddress + __traits(getMember, offset, targetedGameTag);

	static if (is(offset.Type == __parameters))
	{
		return cast(offset.Type) address;
	}
	else
	{
		return cast(offset.Type*) address;
	}
}


template fieldAt (string type, string name, string offset)
{
	enum string fieldAt = (
		"pragma(inline, true)
		ref inout(" ~ type ~ ") " ~ name ~ " () inout @property return scope @trusted pure nothrow @nogc
		{
			return *cast(typeof(return)*) (cast(size_t) &this + (" ~ offset ~ "));
		}"
	);
}


/+ This address can be found by searching for references to the string "ScreenShot: File '%s' created",
   its sole reference loads its address into a register, the second call following that load
   is a call of this function.
   SE Address Library ID: 52050; AE Address Library ID: 52933 +/
enum EXEBasedOffset!(
	void function (scope const(char)* message, scope const(char)* soundEffect, ubyte allowOnlyOneAtATime) nothrow @nogc
) showCornerMessage = {ae7_99: 0x009917d0, ae1170: 0x0097a5e0, ae1130: 0x0097aa30, ae640: 0x0091bc70, ae353: 0x0090a520, se: 0x008da3d0, vr: 0x00908170, gog: 0x0097c0b0, gog659: 0x0091b3e0};

