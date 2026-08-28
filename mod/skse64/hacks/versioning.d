
/+ SPDX-LICENSE-IDENTIFIER: 0BSD +/

module skse64.hacks.versioning;

import game;


static if (targetedGameArchetype == GameArchetype.ae7_104)
{
	enum uint expectedSKSE64Version = 0x02_03_001_0;
	enum string defaultSKSE64DLLName = "skse64_1_7_104.dll";
	enum string expectedSKSE64VersionString = "2.3.1";
}
else static if (targetedGameArchetype == GameArchetype.ae7_99)
{
	enum uint expectedSKSE64Version = 0x02_03_000_0;
	enum string defaultSKSE64DLLName = "skse64_1_7_99.dll";
	enum string expectedSKSE64VersionString = "2.3.0";
}
else static if (targetedGameArchetype == GameArchetype.ae1170)
{
	enum uint expectedSKSE64Version = 0x02_02_008_0;
	enum string defaultSKSE64DLLName = "skse64_1_6_1170.dll";
	enum string expectedSKSE64VersionString = "2.2.8";
}
else static if (targetedGameArchetype == GameArchetype.ae1130)
{
	enum uint expectedSKSE64Version = 0x02_02_005_0;
	enum string defaultSKSE64DLLName = "skse64_1_6_1130.dll";
	enum string expectedSKSE64VersionString = "2.2.5";
}
else static if (targetedGameArchetype == GameArchetype.ae640)
{
	enum uint expectedSKSE64Version = 0x02_02_003_0;
	enum string defaultSKSE64DLLName = "skse64_1_6_640.dll";
	enum string expectedSKSE64VersionString = "2.2.3";
}
else static if (targetedGameArchetype == GameArchetype.ae353)
{
	enum uint expectedSKSE64Version = 0x02_01_005_0;
	enum string defaultSKSE64DLLName = "skse64_1_6_353.dll";
	enum string expectedSKSE64VersionString = "2.1.5";
}
else static if (targetedGameArchetype == GameArchetype.se)
{
	enum uint expectedSKSE64Version = 0x02_00_014_0;
	enum string defaultSKSE64DLLName = "skse64_1_5_97.dll";
	enum string expectedSKSE64VersionString = "2.0.20";
}
else static if (targetedGameArchetype == GameArchetype.vr)
{
	enum uint expectedSKSE64Version = 0x02_00_00C_0;
	enum string defaultSKSE64DLLName = "sksevr_1_4_15.dll";
	enum string expectedSKSE64VersionString = "2.0.12 (VR)";
}
else static if (targetedGameArchetype == GameArchetype.gog)
{
	enum uint expectedSKSE64Version = 0x02_02_006_0;
	enum string defaultSKSE64DLLName = "skse64_1_6_1179.dll";
	enum string expectedSKSE64VersionString = "2.2.6 (GOG)";
}
else static if (targetedGameArchetype == GameArchetype.gog659)
{
	enum uint expectedSKSE64Version = 0x02_02_003_0;
	enum string defaultSKSE64DLLName = "skse64_1_6_659.dll";
	enum string expectedSKSE64VersionString = "2.2.3 (GOG)";
}
else
{
	static assert(false);
}


static immutable(char[]) defaultSKSE64DLLNameUTF8 = defaultSKSE64DLLName;
static immutable(wchar[]) defaultSKSE64DLLNameUTF16 = defaultSKSE64DLLName;

