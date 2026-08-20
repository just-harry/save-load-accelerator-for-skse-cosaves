
/+ SPDX-LICENSE-IDENTIFIER: 0BSD +/

module skse64.hacks.offsets;

import game;


enum VersionedOffsets versionedOffsets = {
	globalSKSE64Provider: {ae: 0x0000b480, ae1130: 0x0000b468, ae640: 0x0000b470, ae353: 0x0000b438, se: 0x0000dad8, vr: 0x0000de20, gog: 0x0000b140, gog659: 0x0000b488}, /+ .rdata +/
	       loadedPlugins: {ae: 0x00001ae0, ae1130: 0x00001ae0, ae640: 0x00001ae0, ae353: 0x00001ae0, se: 0x00001a08, vr: 0x00014178, gog: 0x00001ae0, gog659: 0x00001ae0}, /+ .data +/
	   pluginBeingLoaded: {ae: 0x0000fae8, ae1130: 0x0000fae8, ae640: 0x0000faa8, ae353: 0x0000faa8, se: 0x00000000, vr: 0x00000000, gog: 0x0000f928, gog659: 0x0000fa98}, /+ .data +/
	    loadedPluginSize: {ae: 0x000003b0, ae1130: 0x000003b0, ae640: 0x000003b0, ae353: 0x000003b0, se: 0x00000030, vr: 0x00000030, gog: 0x000003b0, gog659: 0x000003b0}, /+ constant +/
	      cosaveSavePath: {ae: 0x00001b18, ae1130: 0x00001b18, ae640: 0x00001b18, ae353: 0x00001b18, se: 0x00001b78, vr: 0x000141e0, gog: 0x00001b18, gog659: 0x00001b18}, /+ .data +/
	  cosaveAwarePlugins: {ae: 0x00010d88, ae1130: 0x00010d88, ae640: 0x00010d40, ae353: 0x00010d30, se: 0x000123a8, vr: 0x000141c8, gog: 0x00010bd8, gog659: 0x00010d30}, /+ .data +/
	  findDLLPluginsCall: {ae: 0x00088f80, ae1130: 0x00088f80, ae640: 0x00088dc0, ae353: 0x00088a63, se: 0x00087153, vr: 0x0009c033, gog: 0x0008b2f0, gog659: 0x00088f90}, /+ .text +/
	  pluginFilePathCall: {ae: 0x00000000, ae1130: 0x00000000, ae640: 0x00000000, ae353: 0x00000000, se: 0x0007f809, vr: 0x0009490c, gog: 0x00000000, gog659: 0x00000000}, /+ .text +/
	   supplyProviderLEA: {ae: 0x00080fa4, ae1130: 0x00080fa4, ae640: 0x00080de4, ae353: 0x00080dc4, se: 0x0007fc24, vr: 0x00094e24, gog: 0x00082fb4, gog659: 0x00080fa4}, /+ .text +/
	        createCosave: {ae: 0x000874f0, ae1130: 0x000874f0, ae640: 0x00087330, ae353: 0x000871f0, se: 0x000854e0, vr: 0x0009af50, gog: 0x00089820, gog659: 0x00087510}, /+ .text +/
	       restoreCosave: {ae: 0x00087700, ae1130: 0x00087700, ae640: 0x00087540, ae353: 0x00087400, se: 0x000856f0, vr: 0x0009b230, gog: 0x00089a30, gog659: 0x00087720}, /+ .text +/
	    createCosaveCall: {ae: 0x0000e8df, ae1130: 0x0000e8df, ae640: 0x0000e82f, ae353: 0x0000e82f, se: 0x0000e6ff, vr: 0x0000f6af, gog: 0x0000e85f, gog659: 0x0000e67f}, /+ .text +/
	   restoreCosaveCall: {ae: 0x0000e90f, ae1130: 0x0000e90f, ae640: 0x0000e85f, ae353: 0x0000e85f, se: 0x0000e72f, vr: 0x0000f6df, gog: 0x0000e88f, gog659: 0x0000e6af}, /+ .text +/
	        consolePrint: {ae: 0x00002f70, ae1130: 0x00002f70, ae640: 0x00002f50, ae353: 0x00002f50, se: 0x00002e60, vr: 0x000034b0, gog: 0x00002f50, gog659: 0x00002f50}, /+ .text +/
};


enum uint skse64v2_2_01_or_02_globalSKSE64Provider = 0x0000b450; /+ .rdata +/
enum uint skse64v2_2_02gog_globalSKSE64Provider = 0x0000b468; /+ .rdata +/
enum uint skse64v2_0_17_globalSKSE64Provider = 0x000096b8; /+ .rdata +/
enum uint skse64v2_0_18_or_19_globalSKSE64Provider = 0x0000de50; /+ .rdata +/
enum uint skseVRv2_0_09_or_10_globalSKSE64Provider = 0x00009608; /+ .rdata +/
enum uint skseVRv2_0_11_globalSKSE64Provider = 0x0000de00; /+ .rdata +/


struct VersionedOffset
{
	/+ The latest version of the Anniversary Edition. (Technically still the Special Edition, just a newer version). +/
	uint ae;
	/+ Version 1.6.1130 of the Anniversary Edition. +/
	uint ae1130;
	/+ Version 1.6.640 of the Anniversary Edition. +/
	uint ae640;
	/+ Version 1.6.353 of the Anniversary Edition. +/
	uint ae353;
	/+ The latest version of the Special Edition. +/
	uint se;
	/+ The latest version of the VR edition. +/
	uint vr;
	/+ The latest version of the GOG edition. (Which is just the Anniversary Edition, but with a different version number,
	   because three versions aren't enough!). +/
	uint gog;
	/+ Version 1.6.659 of the GOG edition. +/
	uint gog659;
}


struct VersionedOffsets
{
	VersionedOffset globalSKSE64Provider;
	VersionedOffset loadedPlugins;
	VersionedOffset pluginBeingLoaded;
	VersionedOffset loadedPluginSize;
	VersionedOffset cosaveSavePath;
	VersionedOffset cosaveAwarePlugins;
	VersionedOffset findDLLPluginsCall;
	VersionedOffset pluginFilePathCall;
	VersionedOffset supplyProviderLEA;
	VersionedOffset createCosave;
	VersionedOffset restoreCosave;
	VersionedOffset createCosaveCall;
	VersionedOffset restoreCosaveCall;
	VersionedOffset consolePrint;
}


struct SKSE64Offsets
{
	static foreach (member; __traits(allMembers, VersionedOffsets))
	{
		static if (__traits(getMember, __traits(getMember, versionedOffsets, member), targetedGameTag) != 0)
		{
			mixin("uint ", member, ";");
		}
	}
}


enum SKSE64Offsets skse64Offsets = ()
{
	SKSE64Offsets offsets;

	static foreach (member; __traits(allMembers, SKSE64Offsets))
	{
		__traits(getMember, offsets, member) = __traits(getMember, __traits(getMember, versionedOffsets, member), targetedGameTag);
	}

	return offsets;
}();

