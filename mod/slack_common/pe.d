
/+ SPDX-LICENSE-IDENTIFIER: 0BSD +/

module slack_common.pe;


import ldc.attributes : optStrategy;

import slack_common.bindings;


struct PESections
{
	alias sections this;

	union
	{
		ubyte[][3] sections;

		struct
		{
			ubyte[] text;
			ubyte[] data;
			ubyte[] rdata;
		}
	}
}


@optStrategy("minsize")
size_t findSectionsOfPE64 (scope void* image, scope PESections* sections) @trusted nothrow @nogc
{
	auto dosStub = cast(IMAGE_DOS_HEADER*) image;
	auto headers = cast(IMAGE_NT_HEADERS64*) (image + dosStub.e_lfanew);

	ushort sectionCount = headers.FileHeader.NumberOfSections;

	auto sectionTable = cast(IMAGE_SECTION_HEADER*) (
		cast(void*) &headers.OptionalHeader + headers.FileHeader.SizeOfOptionalHeader
	);
	auto section = sectionTable;
	auto sectionTableEnd = sectionTable + sectionCount;

	enum string slice = q{(cast(ubyte*) (image + section.VirtualAddress))[0 .. section.VirtualSize]};

	size_t missing = 0b111;

	for (; section < sectionTableEnd; ++section)
	{
		if (section.Name == ".text\0\0\0")
		{
			missing &= ~(1 << 0);
			sections.text = mixin(slice);
		}
		else if (section.Name == ".data\0\0\0")
		{
			missing &= ~(1 << 1);
			sections.data = mixin(slice);
		}
		else if (section.Name == ".rdata\0\0")
		{
			missing &= ~(1 << 2);
			sections.rdata = mixin(slice);
		}
	}

	return missing;
}



@optStrategy("minsize")
const(VS_FIXEDFILEINFO)* findFixedVersionInfo (
	scope const(void)* image,
	scope const(IMAGE_NT_HEADERS64)* headers
) nothrow @nogc
{
	enum ushort versionInfoID = 16;

	/+ This data structure sucks ass. +/
	/+ I wrote the above comment during 2025.
	   My 2026-self concurs. +/

	const(IMAGE_DATA_DIRECTORY)* resourceDirectoryData = &headers.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_RESOURCE];

	auto resourceDirectoryBase = cast(const(void)*) (image + resourceDirectoryData.VirtualAddress);
	auto resourceDirectory = cast(const(IMAGE_RESOURCE_DIRECTORY)*) resourceDirectoryBase;

	auto typeEntries = cast(const(IMAGE_RESOURCE_DIRECTORY_ENTRY)*) (resourceDirectory + 1);
	auto typeIDEntries = typeEntries + resourceDirectory.NumberOfNamedEntries;
	auto typeIDEntry = typeIDEntries;
	auto endOfTypeIDEntries = typeIDEntries + resourceDirectory.NumberOfIdEntries;

	for (; typeIDEntry < endOfTypeIDEntries; ++typeIDEntry)
	{
		if (typeIDEntry.NameIsString) continue;
		if (typeIDEntry.Id == versionInfoID) goto foundVersionInfo;
	}

	return null;
foundVersionInfo:
	if (typeIDEntry.NameIsString) return null;
	if (!typeIDEntry.DataIsDirectory) return null;

	auto nameDirectory = cast(const(IMAGE_RESOURCE_DIRECTORY)*) (resourceDirectoryBase + typeIDEntry.OffsetToDirectory);
	if (nameDirectory.NumberOfIdEntries < 1) return null;
	auto nameEntries = cast(const(IMAGE_RESOURCE_DIRECTORY_ENTRY)*) (nameDirectory + 1);
	auto nameIDEntries = nameEntries + nameDirectory.NumberOfNamedEntries;
	auto nameIDEntry = nameIDEntries;

	if (nameIDEntry.NameIsString) return null;
	if (!nameIDEntry.DataIsDirectory) return null;

	auto langDirectory = cast(const(IMAGE_RESOURCE_DIRECTORY)*) (resourceDirectoryBase + nameIDEntry.OffsetToDirectory);
	if (langDirectory.NumberOfIdEntries < 1) return null;
	auto langEntries = cast(const(IMAGE_RESOURCE_DIRECTORY_ENTRY)*) (langDirectory + 1);
	auto langIDEntries = langEntries + langDirectory.NumberOfNamedEntries;
	auto langIDEntry = langIDEntries;

	if (langIDEntry.NameIsString) return null;
	if (langIDEntry.DataIsDirectory) return null;

	auto langIDEntryData = cast(const(IMAGE_RESOURCE_DATA_ENTRY)*) (resourceDirectoryBase + langIDEntry.OffsetToData);

	/+ SURPRISE! This RVA is relative to the image, not the section! +/
	auto versionInfoBase = cast(const(void)*) (image + langIDEntryData.OffsetToData);
	uint versionInfoSize = langIDEntryData.Size;

	if (versionInfoSize < VersionInfoHeader.sizeof) return null;

	auto header = cast(const(VersionInfoHeader)*) versionInfoBase;

	auto end = cast(const(void)*) header + (header.wLength <= versionInfoSize ? header.wLength : versionInfoSize);
	auto tip = cast(const(void)*) (header + 1);

	if (tip >= end) return null;

	const(T)* eat (T) ()
	{
		pragma(inline, true);
		auto value = cast(const(T)*) tip;
		tip += T.sizeof;
		return value;
	}

	enum string check (string T) = "if (cast(size_t) tip + " ~ T ~ ".sizeof > cast(size_t) end) return null;";

	enum string alignTo4 =
	q{
		if ((cast(size_t) tip & 3) == 2)
		{
			mixin(check!q{ushort});
			tip += ushort.sizeof;
			end += ushort.sizeof;
		}
	};

	mixin(check!q{wchar[16]});
	if (*eat!(wchar[16]) != "VS_VERSION_INFO\0") return null;

	mixin(alignTo4);

	mixin(check!q{VS_FIXEDFILEINFO});
	const(VS_FIXEDFILEINFO)* fixedInfo = eat!VS_FIXEDFILEINFO;

	return fixedInfo;
}

