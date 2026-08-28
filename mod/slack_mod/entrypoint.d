
/+ SPDX-LICENSE-IDENTIFIER: 0BSD +/

module slack_mod.entrypoint;

import game;
import ldc.attributes : assumeUsed, section;
import skse64.dll_plugins;
import skse64.hacks.versioning;
import slack_common.bindings;
import slack_common.memory;
import slack_common.text;
import slack_common.user_interface;
import slack_mod.global;
import slack_mod.setup;


@assumeUsed
@section("humanity")
immutable(char[111]) niceSurprise = (
	  "The entirety of this program's source-code was human-written, "
	~ "with no assistance at all from LLMs of any kind.\0"
);


/+ Will no one rid me of this turbulent runtime?! +/
export __gshared extern(Windows) int _fltused;


extern(Windows)
BOOL dllEntrypoint (HINSTANCE hinstDLL, uint fdwReason, scope void* lpvReserved) @trusted nothrow @nogc
{
	switch (fdwReason)
	{
	case DLL_PROCESS_ATTACH:
		DisableThreadLibraryCalls(hinstDLL);
		global.dllModule = hinstDLL;
		goto default;
	default:
		return true;
	}
}


static if (expectedSKSE64Version >= 0x02_02_007_0)
{
	extern(C)
	immutable(DLLPluginVersionMetadata) SKSEPlugin_Version = {
		schemaVersion: DLLPluginVersionMetadata.SchemaVersion.v1,
		pluginVersion: /+release-version+/0x01_03_004_0,
		name: "Save & Load Accelerator for SKSE Cosaves (S.L.A.C.K.)",
		authorName: `"Just Harry"`,
		emailAddress: "regarding__s_l_a_c_k_@harrygillanders.com",
		/+ These support flags are a complete lie. We do our own version checking. +/
		gameVersionSupportExtendedFlags: DLLPluginVersionMetadata.GameVersionSupportExtendedFlags.doesNotDependOnFixedOffsets,
		gameVersionSupportFlags: DLLPluginVersionMetadata.GameVersionSupportFlags.hasNoHardcodedAddresses,
	};


	extern(C)
	bool SKSEPlugin_Preload (const(SKSE64Provider)* skse) nothrow @nogc
	{
		wchar[512] stringBuffer = void;
		uint skse64Version = skse.skse64Version;

		if (skse64Version != expectedSKSE64Version)
		{
			showComprehensiveSKSEVersionMismatchMessage(stringBuffer, skse64Version, cast(void[0]) []);
		}
		else
		{
			setUpEverything(stringBuffer);
		}

		return true;
	}


	extern(C)
	bool SKSEPlugin_Load (const(SKSE64Provider)* skse) nothrow @nogc
	{
		/+ Version checking for SKSE v2.2.7-and-later is handled via SKSEPlugin_Preload.
		   Older versions of SKSE don't provide preloading, hence this fallback. +/
		if (skse.skse64Version > 0x02_02_006_0)
		{
			return true;
		}

		static if (targetedGameArchetype == GameArchetype.ae1170)
		{
			if (skse.skse64Version == 0x02_02_006_0)
			{
				static immutable(wchar[203]) message = "Version 2.2.6 of SKSE has been detected. This version of SKSE is out-of-date and is not supported by the Save & Load Accelerator for SKSE Cosaves (S.L.A.C.K.).\r\n\r\nPlease update to version 2.2.8 of SKSE.\0";
				enum wstring url = "https://www.nexusmods.com/skyrimspecialedition/mods/30379?tab=files#file-expander-header-792256:~:text=Skyrim%20Script%20Extender%20%28SKSE64%29%20Steam,2%2E2%2E8";

				uint button = showMessageBox(message.ptr, errorDialogTitle!wchar.ptr, MB_OKCANCEL | MB_ICONHAND);

				if (button == IDOK)
				{
					openURL(url.ptr);
				}

				return true;
			}
		}

		wchar[512] stringBuffer = void;
		showGenericSKSEVersionMismatchMessage(stringBuffer, skse.skse64Version);

		return true;
	}
}
else
{
	extern(Windows)
	void SaveLoadAcceleratorForSKSECosaves_InitialiseViaPreloader () nothrow @nogc
	{
		wchar[512] stringBuffer = void;
		setUpEverything(stringBuffer);
	}
}


/+ This is version as-in "incremented when a backwards-incompatible change to the API is made"-version. +/
extern(Windows)
uint SaveLoadAcceleratorForSKSECosaves_GetVersion () @safe pure nothrow @nogc
{
	return 0;
}


extern(Windows)
uint SaveLoadAcceleratorForSKSECosaves_GetReleaseVersion () @safe pure nothrow @nogc
{
	return /+release-version+/0x01_03_004_0;
}


debug
{
	extern(C)
	void _assert (scope const(char)* message, scope const(char)* fileName, uint line) nothrow @nogc
	{
		wchar[1024] stringBuffer = void;
		/+ Minus one to account for the null-terminator. +/
		wchar* end = stringBuffer.ptr + stringBuffer.length - 1;
		wchar* s = stringBuffer.ptr;

		blit(s, "An assertion failed on line "w.ptr, 28); s += 28;

		auto lineNumber = line.asDecimal!wchar;
		const(wchar)[] lineNumberUnpadded = lineNumber.unpadded;
		blit(s, lineNumberUnpadded.ptr, lineNumberUnpadded.length); s += lineNumberUnpadded.length;

		blit(s, " of \""w.ptr, 5); s += 5;

		if (fileName != null)
		{
			size_t fileNameLength = strlen(fileName);

			/+ Right-justify the file-name if its excessively long. The leaf is more pertinent than the stem. +/
			size_t fileNameOffset = fileNameLength <= MAX_PATH ? 0 : fileNameLength - MAX_PATH;
			fileNameLength = fileNameLength - fileNameOffset;

			const(char)* utf8 = fileName + fileNameOffset;
			const(char)* utf8End = utf8 + fileNameLength;
			utf8ToUTF16(&utf8, utf8End, &s, end);
		}
		else
		{
			blit(s, "<null>"w.ptr, 6); s += 6;
		}

		if (message != null)
		{
			size_t messageLength = strlen(message);

			if (messageLength == 5)
			{
				const(char)* m = message;

				if ((m[0] == 'f') & (m[1] == 'a') & (m[2] == 'l') & (m[3] == 's') & (m[4] == 'e'))
				{
					/+ Seriously? "false"? That's the best they could come up with for a messageless assert? +/
					goto noMessage;
				}
			}

			blit(s, "\".\r\nThe associated message is: \""w.ptr, 32); s += 32;

			const(char)* utf8 = message;
			const(char)* utf8End = utf8 + messageLength;
			utf8ToUTF16(&utf8, utf8End, &s, end);

			if (end - s >= 2)
			{
				blit(s, "\"."w.ptr, 2); s += 2;
			}
		}
		else
		{
		noMessage:
			blit(s, "\"."w.ptr, 2); s += 2;
		}

		*s = '\0';

		reportErrorToUser(stringBuffer.ptr);
	}
}

