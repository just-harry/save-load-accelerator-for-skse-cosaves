
/+ SPDX-LICENSE-IDENTIFIER: 0BSD +/

module slack_mod.exception_wrapper;

import slack_common.bindings;


/+ LDC does actually support catching C++ exceptions from D code.
   ...But not in BetterC mode :(
   Hence this. +/


extern(C++) void call_and_handle_exception (
	scope void* argument,
	scope void function (void*) call,
	scope int function (void*, scope const(void)*) handler,
	scope void* handlerContext
) nothrow @nogc;


pragma(inline, true)
void callAndHandleException (T, U) (
	scope T argument,
	scope U call,
	scope int delegate (scope const(EXCEPTION_POINTERS)* exception) nothrow @nogc handler
)
{
	alias Callee = extern(C++) void function (void*) nothrow @nogc;
	alias Handler = extern(C++) int function (void*, scope const(void)*,) nothrow @nogc;

	call_and_handle_exception(cast(void*) argument, cast(Callee) call, cast(Handler) handler.funcptr, handler.ptr);
}

