
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

