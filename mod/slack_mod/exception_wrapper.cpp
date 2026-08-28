
/* SPDX-LICENSE-IDENTIFIER: 0BSD */

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

