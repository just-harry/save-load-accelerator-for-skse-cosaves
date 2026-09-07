
/* SPDX-LICENSE-IDENTIFIER: 0BSD */

#include <cstdint>
#include <excpt.h>


void call_and_handle_exception (
	void *argument,
	void (*call) (void *),
	int (*exceptionHandler) (void *context, const void *exception),
	void *handlerContext
)
{
	__try
	{
		call(argument);
	}
	__except (exceptionHandler(handlerContext, GetExceptionInformation()))
	{}
}

/* I first tried a template for these try_* overloads,
   but I couldn't get the explicit template instantiations to play nicely with LTO. */


uint8_t try_except_ubyte (
	size_t c0,
	uint8_t (*call) (size_t),
	int (*exceptHandler) (void)
)
{
	__try
	{
		return call(c0);
	}
	__except (exceptHandler())
	{}
}


uint8_t try_except_ubyte (
	uint32_t c0,
	uint32_t c1,
	size_t c2,
	uint32_t c3,
	size_t c4,
	uint8_t (*call) (uint32_t, uint32_t, size_t, uint32_t, size_t),
	int (*exceptHandler) (void)
)
{
	__try
	{
		return call(c0, c1, c2, c3, c4);
	}
	__except (exceptHandler())
	{}
}


uint8_t try_finally_ubyte (
	size_t c0,
	uint8_t (*call) (size_t),
	void (*finallyHandler) ()
)
{
	__try
	{
		return call(c0);
	}
	__finally
	{
		finallyHandler();
	}
}


uint8_t try_finally_ubyte (
	uint32_t c0,
	uint32_t c1,
	size_t c2,
	uint32_t c3,
	size_t c4,
	uint8_t (*call) (uint32_t, uint32_t, size_t, uint32_t, size_t),
	void (*finallyHandler) ()
)
{
	__try
	{
		return call(c0, c1, c2, c3, c4);
	}
	__finally
	{
		finallyHandler();
	}
}

