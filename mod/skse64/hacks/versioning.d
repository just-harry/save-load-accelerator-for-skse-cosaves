
/+ SPDX-LICENSE-IDENTIFIER: 0BSD +/

module skse64.hacks.versioning;

import game;


static if (targetedGameArchetype == GameArchetype.ae7_104)
{
	enum uint expectedSKSE64Version = 0x02_03_001_0;
	enum string defaultSKSE64DLLName = "skse64_1_7_104.dll";
	enum string expectedSKSE64VersionString = "2.3.1";

	enum uint expectedPapyrusUtilTimeDateStamp = 0x6A938AE2;
	enum uint expectedPapyrusUtilVersion = 4_8;
	enum string expectedPapyrusUtilVersionString = "AE SE 4.8";
}
else static if (targetedGameArchetype == GameArchetype.ae7_99)
{
	enum uint expectedSKSE64Version = 0x02_03_000_0;
	enum string defaultSKSE64DLLName = "skse64_1_7_99.dll";
	enum string expectedSKSE64VersionString = "2.3.0";

	enum uint expectedPapyrusUtilTimeDateStamp = 0x6A8E238D;
	enum uint expectedPapyrusUtilVersion = 4_7;
	enum string expectedPapyrusUtilVersionString = "AE SE 4.7";
}
else static if (targetedGameArchetype == GameArchetype.ae1170)
{
	enum uint expectedSKSE64Version = 0x02_02_008_0;
	enum string defaultSKSE64DLLName = "skse64_1_6_1170.dll";
	enum string expectedSKSE64VersionString = "2.2.8";

	enum uint expectedPapyrusUtilTimeDateStamp = 0x65A9FC3A;
	enum uint expectedPapyrusUtilVersion = 4_6;
	enum string expectedPapyrusUtilVersionString = "AE SE 4.6";
}
else static if (targetedGameArchetype == GameArchetype.ae1130)
{
	enum uint expectedSKSE64Version = 0x02_02_005_0;
	enum string defaultSKSE64DLLName = "skse64_1_6_1130.dll";
	enum string expectedSKSE64VersionString = "2.2.5";

	enum uint expectedPapyrusUtilTimeDateStamp = 0x656FC3C3;
	enum uint expectedPapyrusUtilVersion = 4_5;
	enum string expectedPapyrusUtilVersionString = "AE SE 4.5";
}
else static if (targetedGameArchetype == GameArchetype.ae640)
{
	enum uint expectedSKSE64Version = 0x02_02_003_0;
	enum string defaultSKSE64DLLName = "skse64_1_6_640.dll";
	enum string expectedSKSE64VersionString = "2.2.3";

	enum uint expectedPapyrusUtilTimeDateStamp = 0x63323305;
	enum uint expectedPapyrusUtilVersion = 4_4;
	enum string expectedPapyrusUtilVersionString = "AE SE 4.4";
}
else static if (targetedGameArchetype == GameArchetype.ae353)
{
	enum uint expectedSKSE64Version = 0x02_01_005_0;
	enum string defaultSKSE64DLLName = "skse64_1_6_353.dll";
	enum string expectedSKSE64VersionString = "2.1.5";

	enum uint expectedPapyrusUtilTimeDateStamp = 0x61D8F51E;
	enum uint expectedPapyrusUtilVersion = 4_3;
	enum string expectedPapyrusUtilVersionString = "AE 4.3";
}
else static if (targetedGameArchetype == GameArchetype.se)
{
	enum uint expectedSKSE64Version = 0x02_00_014_0;
	enum string defaultSKSE64DLLName = "skse64_1_5_97.dll";
	enum string expectedSKSE64VersionString = "2.0.20";

	enum uint expectedPapyrusUtilTimeDateStamp = 0x5E393F1B;
	enum uint expectedPapyrusUtilVersion = 3_9;
	enum string expectedPapyrusUtilVersionString = "SE 3.9";
}
else static if (targetedGameArchetype == GameArchetype.vr)
{
	enum uint expectedSKSE64Version = 0x02_00_00C_0;
	enum string defaultSKSE64DLLName = "sksevr_1_4_15.dll";
	enum string expectedSKSE64VersionString = "2.0.12 (VR)";

	enum uint expectedPapyrusUtilTimeDateStamp = 0x5C1D1297;
	enum uint expectedPapyrusUtilVersion = 3_6;
	enum string expectedPapyrusUtilVersionString = "VR 3.6b";
}
else static if (targetedGameArchetype == GameArchetype.gog)
{
	enum uint expectedSKSE64Version = 0x02_02_006_0;
	enum string defaultSKSE64DLLName = "skse64_1_6_1179.dll";
	enum string expectedSKSE64VersionString = "2.2.6 (GOG)";

	enum uint expectedPapyrusUtilTimeDateStamp = 0x65DD0C69;
	enum uint expectedPapyrusUtilVersion = 4_6;
	enum string expectedPapyrusUtilVersionString = "GOG 4.6";
}
else static if (targetedGameArchetype == GameArchetype.gog659)
{
	enum uint expectedSKSE64Version = 0x02_02_003_0;
	enum string defaultSKSE64DLLName = "skse64_1_6_659.dll";
	enum string expectedSKSE64VersionString = "2.2.3 (GOG)";

	enum uint expectedPapyrusUtilTimeDateStamp = 0x636995DB;
	enum uint expectedPapyrusUtilVersion = 4_4;
	enum string expectedPapyrusUtilVersionString = "GOG 4.4";
}
else
{
	static assert(false);
}


static immutable(char[]) defaultSKSE64DLLNameUTF8 = defaultSKSE64DLLName;
static immutable(wchar[]) defaultSKSE64DLLNameUTF16 = defaultSKSE64DLLName;

