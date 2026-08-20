
/+ SPDX-LICENSE-IDENTIFIER: 0BSD +/

module slack_common.user_interface;

import game;

import slack_common.bindings;
import slack_common.memory;
import slack_common.text;
import slack_common.threading;


enum immutable(wchar[]) errorDialogTitle = "Save & Load Accelerator for SKSE Cosaves v1.3.3 Error";


/+ The implementation for Skyrim v1.5.97 breaks message-boxes in other versions of Skyrim.
   https://www.youtube.com/watch?v=FL0PvTmo5CE&t=7s +/
static if (targetedGameArchetype != GameArchetype.se)
{
	uint showMessageBox (scope const(wchar)* message, scope const(wchar)* title, uint flags = 0) nothrow @nogc
	{
		return MessageBoxW(
			null,
			message,
			title,
			MB_OK | MB_TOPMOST | flags
		);
	}


	void reportErrorToUser (scope const(wchar)* message, uint flags = MB_ICONERROR) nothrow @nogc
	{
		MessageBoxW(
			null,
			message,
			errorDialogTitle.ptr,
			MB_OK | MB_TOPMOST | flags
		);
	}
}
else
{
	import slack_common.threading;


	uint showMessageBox (scope const(wchar)* message, scope const(wchar)* title, uint flags = 0) nothrow @nogc
	{
		/+ In v1.5.97 of Skyrim, the body of the message-box is sometimes blank when MessageBoxW
		   is called from the main-thread, hence why we spin up a new thread. +/

		static struct Context
		{
			const(wchar)* message;
			const(wchar)* title;

			union
			{
				uint flags;
				uint result;
			}
		}

		extern(Windows)
		static uint showMessage (scope void* context)
		{
			(cast(Context*) context).result = MessageBoxW(
				null,
				(cast(const(Context*)) context).message,
				(cast(const(Context*)) context).title,
				(cast(const(Context*)) context).flags
			);

			return 0;
		}

		Context context = {
			message: message,
			title: title,
			flags: flags | MB_TOPMOST | MB_SETFOREGROUND | MB_DEFAULT_DESKTOP_ONLY
		};

		HANDLE thread = void;
		NTSTATUS error = makeThread(&thread, &showMessage, &context, THREAD_CREATE_FLAGS_SKIP_THREAD_ATTACH);

		if (!error)
		{
			NtWaitForSingleObject(thread, false, null);
			NtClose(thread);
			return context.result;
		}

		return 0;
	}


	void reportErrorToUser (scope const(wchar)* message, uint flags = MB_ICONERROR) nothrow @nogc
	{
		showMessageBox(message, errorDialogTitle.ptr, flags);
	}
}


void reportErrorToUser (
	scope wchar[] stringBuffer,
	scope const(wchar)[] message,
	uint errorCode = 0,
	uint flags = MB_ICONERROR
) nothrow @nogc
in (message.length < stringBuffer.length)
in (errorCode == 0 || ((stringBuffer.length >= 28) & (stringBuffer.length - 27 > message.length)))
{
	wchar* s = stringBuffer.ptr;
	blit(s, message.ptr, message.length);
	s += message.length;

	if (errorCode != 0)
	{
		blit(s, "\r\nOS Error Code: 0x"w.ptr, 19);
		s += 19;
		errorCode.asHexInto!true(s[0 .. 8]);
		s += 8;
	}

	*s = '\0';

	reportErrorToUser(stringBuffer.ptr, flags);
}


void openURL (scope const(wchar)* url) @trusted nothrow @nogc
{
	extern(Windows)
	static uint openURLViaThread (scope void* context)
	{
		CoInitializeEx(null, COINIT.COINIT_APARTMENTTHREADED | COINIT.COINIT_DISABLE_OLE1DDE);
		ShellExecuteW(null, null, cast(const(wchar)*) context, null, null, SW_RESTORE);
		CoUninitialize;
		return 0;
	}

	HANDLE thread = void;

	/+ Firefox causes ShellExecuteW to hang until Firefox receives focus from the user.
	   wtf firefox ??? +/
	if (makeThread(&thread, &openURLViaThread, cast(void*) url) == 0)
	{
		NtClose(thread);
	}
}

