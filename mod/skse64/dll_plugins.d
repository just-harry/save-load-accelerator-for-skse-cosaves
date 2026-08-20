
/+ These definitions are based on the work of the Skyrim Script Extender (SKSE).
   (https://skse.silverlock.org/)
   Full credit goes towards the team behind SKSE, those individuals being:
       Ian Patterson; Stephen Abel; Paul Connelly; Brendan Borthwick
       (ianpatt; behippo; scruggsywuggsy the ferret; purple lunchbox).
   Likewise for any contributors to the Script Extender project not named here.
+/

module skse64.dll_plugins;

import skse64.hacks.offsets;

import slack_common.bindings;
import slack_common.cpp;


enum DLLPluginIndex : uint
{
	init = 0
}


struct DLLPluginMetadata
{
	enum SchemaVersion : uint
	{
		latest = v1,
		v1 = 1
	}

	uint schemaVersion;
	const(char)* name;
	uint pluginVersion;
}


struct DLLPluginVersionMetadata
{
	enum SchemaVersion : uint
	{
		latest = v1,
		v1 = 1
	}


	enum GameVersionSupportFlags : uint
	{
		none = 0,
		usesAECompatibleAddressLibrary = 1 << 0,
		hasNoHardcodedAddresses = 1 << 1,
		usesOffsetsFrom1_6_629 = 1 << 2,
	}


	enum GameVersionSupportExtendedFlags : uint
	{
		none = 0,
		doesNotDependOnFixedOffsets = 1 << 0,
	}


	uint schemaVersion;
	uint pluginVersion;
	char[256] name = 0;
	char[256] authorName = 0;
	char[252] emailAddress = 0;
	GameVersionSupportExtendedFlags gameVersionSupportExtendedFlags;
	GameVersionSupportFlags gameVersionSupportFlags;
	uint[16] explicitlySupportedGameVersions;
	uint minimumSKSE64Version;
}


struct DLLPlugin
{
	static if (skse64Offsets.loadedPluginSize == 0x00000030)
	{
		HMODULE dll;
		DLLPluginMetadata metadata;
		ubyte[skse64Offsets.loadedPluginSize - 32] padding;
	}
	else static if (skse64Offsets.loadedPluginSize == 0x000003B0 || skse64Offsets.loadedPluginSize == 0x000003B8)
	{
		std_string filePath;
		HMODULE dll;
		DLLPluginMetadata metadata;
		DLLPluginIndex index;
		ubyte[skse64Offsets.loadedPluginSize - 72] padding;
	}
	else
	{
		static assert(false);
	}

	static assert(DLLPlugin.sizeof == skse64Offsets.loadedPluginSize);
}


struct SKSE64Provider
{
	uint skse64Version;
	uint gameVersion;
	uint ckVersion;
	uint isCK;

	void* function (uint) nothrow @nogc requestProvider;
	DLLPluginIndex function () nothrow @nogc receivePluginIndex;
	uint function () nothrow @nogc receiveSKSE64VersionIndex;
	const(DLLPluginMetadata)* function (scope const(char)*) nothrow @nogc queryPluginMetadata;

	enum ProviderID : uint
	{
		invalid = 0,
		scaleform = 1,
		papyrus = 2,
		serialisation = 3,
		task = 4,
		messaging = 5,
		object = 6,
		trampoline = 7
	}
}


struct SerialisationProvider
{
	enum Version : uint
	{
		latest = v4,
		v4 = 4
	}

	alias ProviderReceiver = void function (SerialisationProvider*) nothrow @nogc;
	alias FormDeleter = void function (ulong) nothrow @nogc;

	uint version_;

	void function (DLLPluginIndex, uint) nothrow @nogc assignUniqueID;
	void function (DLLPluginIndex, ProviderReceiver) nothrow @nogc assignStateReverter;
	void function (DLLPluginIndex, ProviderReceiver) nothrow @nogc assignStateSaver;
	void function (DLLPluginIndex, ProviderReceiver) nothrow @nogc assignStateLoader;
	void function (DLLPluginIndex, FormDeleter) nothrow @nogc assignFormDeleter;
	ubyte function (uint, uint, scope const(void)*, uint) nothrow @nogc writeRecord;
	ubyte function (uint, uint) nothrow @nogc beginRecord;
	ubyte function (const(void)*, uint) nothrow @nogc writeRecordData;
	ubyte function (scope uint*, scope uint*, scope uint*) nothrow @nogc readNextRecordHeader;
	uint function (scope void*, uint) nothrow @nogc readRecordData;
	ubyte function (ulong, scope ulong*) nothrow @nogc remapHandle;
	ubyte function (uint, scope uint*) nothrow @nogc remapFormID;
}

