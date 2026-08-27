
/+ SPDX-LICENSE-IDENTIFIER: 0BSD +/

module slack_common.oops;

import slack_common.memory;


struct ClassInstance (T)
if (is(T == class))
{
	alias use this;
align(__traits(classInstanceAlignment, T))
	ubyte[__traits(classInstanceSize, T)] _;


	pragma(inline, true)
	inout(T) use () () inout @property return scope @trusted
	{
		return cast(T) &this;
	}
}


pragma(inline, true)
void initialiseClassInstance (T) (scope ref ClassInstance!T instance) @trusted
{
	const(void)[] init = __traits(initSymbol, T);
	blit(instance._.ptr, cast(const(ubyte)*) init.ptr, init.length);
}

