
/+ SPDX-LICENSE-IDENTIFIER: 0BSD +/

module skse64.hacks.offsets;

import game;


enum VersionedOffsets versionedOffsets = {
	  globalSKSE64Provider: {ae7_104: 0x0000da98, ae7_99: 0x0000da98, ae1170: 0x0000dac0, ae1130: 0x0000b468, ae640: 0x0000b470, ae353: 0x0000b438, se: 0x0000dad8, vr: 0x0000de20, gog: 0x0000b140, gog659: 0x0000b488}, /+ .rdata +/
	         loadedPlugins: {ae7_104: 0x00001a00, ae7_99: 0x00001a00, ae1170: 0x00001a00, ae1130: 0x00001ae0, ae640: 0x00001ae0, ae353: 0x00001ae0, se: 0x00001a08, vr: 0x00014178, gog: 0x00001ae0, gog659: 0x00001ae0}, /+ .data +/
	     pluginBeingLoaded: {ae7_104: 0x00000000, ae7_99: 0x00000000, ae1170: 0x00000000, ae1130: 0x0000fae8, ae640: 0x0000faa8, ae353: 0x0000faa8, se: 0x00000000, vr: 0x00000000, gog: 0x0000f928, gog659: 0x0000fa98}, /+ .data +/
	pluginBeingLoadedIndex: {ae7_104: 0x0000f6b4, ae7_99: 0x0000f6b4, ae1170: 0x0000f6b8, ae1130: 0x00000000, ae640: 0x00000000, ae353: 0x00000000, se: 0x00000000, vr: 0x00000000, gog: 0x00000000, gog659: 0x00000000}, /+ .data +/
	    logFileStdioHandle: {ae7_104: 0x0000c440, ae7_99: 0x0000c440, ae1170: 0x0000c440, ae1130: 0x0000c610, ae640: 0x0000c5d0, ae353: 0x0000c5d0, se: 0x0000d900, vr: 0x0000fae8, gog: 0x0000c5c0, gog659: 0x0000c5d0}, /+ .data +/
	      loadedPluginSize: {ae7_104: 0x000003b8, ae7_99: 0x000003b8, ae1170: 0x000003b8, ae1130: 0x000003b0, ae640: 0x000003b0, ae353: 0x000003b0, se: 0x00000030, vr: 0x00000030, gog: 0x000003b0, gog659: 0x000003b0}, /+ constant +/
	        cosaveSavePath: {ae7_104: 0x00001a38, ae7_99: 0x00001a38, ae1170: 0x00001a38, ae1130: 0x00001b18, ae640: 0x00001b18, ae353: 0x00001b18, se: 0x00001b78, vr: 0x000141e0, gog: 0x00001b18, gog659: 0x00001b18}, /+ .data +/
	    cosaveAwarePlugins: {ae7_104: 0x00010a98, ae7_99: 0x00010a98, ae1170: 0x00010a98, ae1130: 0x00010d88, ae640: 0x00010d40, ae353: 0x00010d30, se: 0x000123a8, vr: 0x000141c8, gog: 0x00010bd8, gog659: 0x00010d30}, /+ .data +/
	    pluginFilePathCall: {ae7_104: 0x00000000, ae7_99: 0x00000000, ae1170: 0x00000000, ae1130: 0x00000000, ae640: 0x00000000, ae353: 0x00000000, se: 0x0007f809, vr: 0x0009490c, gog: 0x00000000, gog659: 0x00000000}, /+ .text +/
	     supplyProviderLEA: {ae7_104: 0x0007ff9f, ae7_99: 0x0007ff8f, ae1170: 0x0007ff9f, ae1130: 0x00080fa4, ae640: 0x00080de4, ae353: 0x00080dc4, se: 0x0007fc24, vr: 0x00094e24, gog: 0x00082fb4, gog659: 0x00080fa4}, /+ .text +/
	 supplySaveCallbackLEA: {ae7_104: 0x000891d6, ae7_99: 0x00089176, ae1170: 0x00089186, ae1130: 0x0001940e, ae640: 0x0001935e, ae353: 0x0001935e, se: 0x00018b5e, vr: 0x00027813, gog: 0x0001ab2e, gog659: 0x0001929e}, /+ .text +/
	 supplyLoadCallbackLEA: {ae7_104: 0x000891e8, ae7_99: 0x00089188, ae1170: 0x00089198, ae1130: 0x00019420, ae640: 0x00019370, ae353: 0x00019370, se: 0x00018b70, vr: 0x00027856, gog: 0x0001ab40, gog659: 0x000192b0}, /+ .text +/
	supplyLoadCallbackLEA1: {ae7_104: 0x00000000, ae7_99: 0x00000000, ae1170: 0x00000000, ae1130: 0x00000000, ae640: 0x00000000, ae353: 0x00000000, se: 0x00000000, vr: 0x00027867, gog: 0x00000000, gog659: 0x00000000}, /+ .text +/
	          createCosave: {ae7_104: 0x00086b50, ae7_99: 0x00086af0, ae1170: 0x00086b00, ae1130: 0x000874f0, ae640: 0x00087330, ae353: 0x000871f0, se: 0x000854e0, vr: 0x0009af50, gog: 0x00089820, gog659: 0x00087510}, /+ .text +/
	         restoreCosave: {ae7_104: 0x00086d60, ae7_99: 0x00086d00, ae1170: 0x00086d10, ae1130: 0x00087700, ae640: 0x00087540, ae353: 0x00087400, se: 0x000856f0, vr: 0x0009b230, gog: 0x00089a30, gog659: 0x00087720}, /+ .text +/
	      createCosaveCall: {ae7_104: 0x0000e24f, ae7_99: 0x0000e24f, ae1170: 0x0000e24f, ae1130: 0x0000e8df, ae640: 0x0000e82f, ae353: 0x0000e82f, se: 0x0000e6ff, vr: 0x0000f6af, gog: 0x0000e85f, gog659: 0x0000e67f}, /+ .text +/
	     restoreCosaveCall: {ae7_104: 0x0000e27f, ae7_99: 0x0000e27f, ae1170: 0x0000e27f, ae1130: 0x0000e90f, ae640: 0x0000e85f, ae353: 0x0000e85f, se: 0x0000e72f, vr: 0x0000f6df, gog: 0x0000e88f, gog659: 0x0000e6af}, /+ .text +/
	          consolePrint: {ae7_104: 0x00002ee0, ae7_99: 0x00002ee0, ae1170: 0x00002ee0, ae1130: 0x00002f70, ae640: 0x00002f50, ae353: 0x00002f50, se: 0x00002e60, vr: 0x000034b0, gog: 0x00002f50, gog659: 0x00002f50}, /+ .text +/
	                fflush: {ae7_104: 0x0009e5a8, ae7_99: 0x0009e548, ae1170: 0x0009e538, ae1130: 0x0009c52c, ae640: 0x0009c36c, ae353: 0x0009c01c, se: 0x000b4d48, vr: 0x000c7dd4, gog: 0x0009e72c, gog659: 0x0009c5ec}, /+ .text +/
	           fflushCall0: {ae7_104: 0x0008a773, ae7_99: 0x0008a713, ae1170: 0x0008a716, ae1130: 0x00089fe3, ae640: 0x00089e23, ae353: 0x00089ad3, se: 0x00088243, vr: 0x0009d471, gog: 0x0008c503, gog659: 0x0008a003}, /+ .text +/
	           fflushCall1: {ae7_104: 0x0008a702, ae7_99: 0x0008a6a2, ae1170: 0x0008a6a6, ae1130: 0x00089f72, ae640: 0x00089db2, ae353: 0x00089a62, se: 0x000881d2, vr: 0x0009d40c, gog: 0x0008c492, gog659: 0x00089f92}, /+ .text +/
	           fflushCall2: {ae7_104: 0x0008a7ff, ae7_99: 0x0008a79f, ae1170: 0x0008a7a2, ae1130: 0x0008a06f, ae640: 0x00089eaf, ae353: 0x00089b5f, se: 0x000882cf, vr: 0x0009d4e5, gog: 0x0008c58f, gog659: 0x0008a08f}, /+ .text +/
	   emitSaveMessageCall: {ae7_104: 0x0000f35d, ae7_99: 0x0000f35d, ae1170: 0x0000f35d, ae1130: 0x0000f61d, ae640: 0x0000f56d, ae353: 0x0000f56d, se: 0x0000f42d, vr: 0x000107c3, gog: 0x0000fa1d, gog659: 0x0000f3fd}, /+ .text +/
	emitPreLoadMessageCall: {ae7_104: 0x0000f41f, ae7_99: 0x0000f41f, ae1170: 0x0000f41f, ae1130: 0x0000f6df, ae640: 0x0000f62f, ae353: 0x0000f62f, se: 0x0000f4ef, vr: 0x0001087d, gog: 0x0000fadf, gog659: 0x0000f4bf}, /+ .text +/
	emitProLoadMessageCall: {ae7_104: 0x0000f463, ae7_99: 0x0000f463, ae1170: 0x0000f463, ae1130: 0x0000f722, ae640: 0x0000f672, ae353: 0x0000f672, se: 0x0000f532, vr: 0x000108c3, gog: 0x0000fb22, gog659: 0x0000f502}, /+ .text +/
};


enum uint skse64v2_2_07_globalSKSE64Provider = 0x0000da80; /+ .rdata +/
enum uint skse64v2_2_06_globalSKSE64Provider = 0x0000b480; /+ .rdata +/
enum uint skse64v2_2_01_or_02_globalSKSE64Provider = 0x0000b450; /+ .rdata +/
enum uint skse64v2_2_02gog_globalSKSE64Provider = 0x0000b468; /+ .rdata +/
enum uint skse64v2_0_17_globalSKSE64Provider = 0x000096b8; /+ .rdata +/
enum uint skse64v2_0_18_or_19_globalSKSE64Provider = 0x0000de50; /+ .rdata +/
enum uint skseVRv2_0_09_or_10_globalSKSE64Provider = 0x00009608; /+ .rdata +/
enum uint skseVRv2_0_11_globalSKSE64Provider = 0x0000de00; /+ .rdata +/


struct VersionedOffset
{
	/+ Version 1.7.104 of the Anniversary Edition. (Technically still the Special Edition, just a much newer version). +/
	uint ae7_104;
	/+ Version 1.7.99 of the Anniversary Edition. +/
	uint ae7_99;
	/+ Version 1.6.1170 of the Anniversary Edition. +/
	uint ae1170;
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
	   because TEN(!) versions aren't enough!). +/
	uint gog;
	/+ Version 1.6.659 of the GOG edition. +/
	uint gog659;
}


struct VersionedOffsets
{
	VersionedOffset globalSKSE64Provider;
	VersionedOffset loadedPlugins;
	VersionedOffset pluginBeingLoaded;
	VersionedOffset pluginBeingLoadedIndex;
	VersionedOffset logFileStdioHandle;
	VersionedOffset loadedPluginSize;
	VersionedOffset cosaveSavePath;
	VersionedOffset cosaveAwarePlugins;
	VersionedOffset pluginFilePathCall;
	VersionedOffset supplyProviderLEA;
	VersionedOffset supplySaveCallbackLEA;
	VersionedOffset supplyLoadCallbackLEA;
	VersionedOffset supplyLoadCallbackLEA1;
	VersionedOffset createCosave;
	VersionedOffset restoreCosave;
	VersionedOffset createCosaveCall;
	VersionedOffset restoreCosaveCall;
	VersionedOffset consolePrint;
	VersionedOffset fflush;
	VersionedOffset fflushCall0;
	VersionedOffset fflushCall1;
	VersionedOffset fflushCall2;
	VersionedOffset emitSaveMessageCall;
	VersionedOffset emitPreLoadMessageCall;
	VersionedOffset emitProLoadMessageCall;
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

