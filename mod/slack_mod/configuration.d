
/+ SPDX-LICENSE-IDENTIFIER: 0BSD +/

module slack_mod.configuration;

import ldc.attributes : optStrategy;

import slack_common.algorithms;
import slack_common.bindings;
import slack_common.ini;
import slack_common.integers;
import slack_common.memory;
import slack_common.text;
import slack_common.tib_access;
import slack_common.user_interface;
import slack_mod.limits;


struct ConfigurationLongLived
{
	Flags flags;
	ubyte parallelSavingThreadCount;
	ubyte[SoundEffect.max + 1] soundEffectNameOffset;
	char[256] soundEffectNameBuffer = 0;
	wchar[] skseDLLName;
	char[] skseDLLNameUTF8;
	wchar[256] skseDLLNameBuffer = 0;
	char[256] skseDLLNameBufferUTF8 = 0;

	enum Flags : uint
	{
		none = 0,
		accelerateSaving = 1 << 0,
		accelerateLoading = 1 << 1,
		enableParallelSaving = 1 << 2,
		logSaveTimingsToConsole = 1 << 4,
		logLoadTimingsToConsole = 1 << 5,
		workAroundThirdPartyBugs = 1 << 6,
		profileSaving = 1 << 7,
		profileLoading = 1 << 8,
		errorFriendlyMode = 1 << 9,
		showSavingErrorNotifications = 1 << 10,
		showLoadingErrorNotifications = 1 << 11,
		showSavingWarningNotifications = 1 << 12,
		showLoadingWarningNotifications = 1 << 13,
		aggregateFileFlushingInSKSE = 1 << 14,
		aggregateFileFlushingInPapyrusUtil = 1 << 15,
	}

	enum SoundEffect : ubyte
	{
		savingError = 0,
		loadingError = 1,
		savingWarning = 2,
		loadingWarning = 3,
	}

	void setToDefault () scope @safe pure nothrow @nogc
	{
		this.flags = (
			  Flags.accelerateSaving
			| Flags.accelerateLoading
			| Flags.logSaveTimingsToConsole
			| Flags.logLoadTimingsToConsole
			| Flags.workAroundThirdPartyBugs
			| Flags.errorFriendlyMode
			| Flags.showSavingErrorNotifications
			| Flags.showLoadingErrorNotifications
			| Flags.showSavingWarningNotifications
			| Flags.showLoadingWarningNotifications
			| Flags.aggregateFileFlushingInSKSE
			| Flags.aggregateFileFlushingInPapyrusUtil
		);

		this.parallelSavingThreadCount = 0;
	}

	pragma(inline, true)
	Flags accelerationEnabled () const @property scope @safe pure nothrow @nogc
	{
		return this.flags & (Flags.accelerateSaving | Flags.accelerateLoading);
	}

	pragma(inline, true)
	Flags parallelismEnabled () const @property scope @safe pure nothrow @nogc
	{
		return this.flags & Flags.enableParallelSaving;
	}

	pragma(inline, true)
	Flags timingLoggingEnabled () const @property scope @safe pure nothrow @nogc
	{
		return this.flags & (Flags.logSaveTimingsToConsole | Flags.logLoadTimingsToConsole);
	}

	pragma(inline, true)
	Flags skseHooksAreRequired () const @property scope @safe pure nothrow @nogc
	{
		return this.accelerationEnabled | this.timingLoggingEnabled | (this.flags & Flags.aggregateFileFlushingInSKSE);
	}

	pragma(inline, true)
	Flags papyrusUtilHooksAreRequired () const @property scope @safe pure nothrow @nogc
	{
		return this.flags & Flags.aggregateFileFlushingInPapyrusUtil;
	}

	pragma(inline, true)
	Flags aggregateFileFlushingEnabled () const @property scope @safe pure nothrow @nogc
	{
		return this.flags & (Flags.aggregateFileFlushingInSKSE | Flags.aggregateFileFlushingInPapyrusUtil);
	}

	pragma(inline, true)
	inout(char)* soundEffectName (SoundEffect soundEffect) inout return scope @trusted pure nothrow @nogc
	{
		return this.soundEffectNameBuffer.ptr + this.soundEffectNameOffset[soundEffect];
	}

	ubyte adjustThreadCounts (ubyte defaultThreadCount) scope @trusted pure nothrow @nogc
	{
		this.parallelSavingThreadCount = this.parallelSavingThreadCount == 0 ? defaultThreadCount : this.parallelSavingThreadCount;

		this.parallelSavingThreadCount = lesserOf(this.parallelSavingThreadCount, parallelSaveLoadThreadCountLimit);

		return this.parallelSavingThreadCount;
	}

	ubyte adjustThreadCounts () scope @trusted nothrow @nogc
	{
		static assert(parallelSaveLoadThreadCountLimit >= 16);

		return this.adjustThreadCounts(
			cast(ubyte) lesserOf(GetActiveProcessorCount(ALL_PROCESSOR_GROUPS), 16)
		);
	}

	pragma(inline, true)
	bool setSoundEffectNames (scope ref const(char[])[SoundEffect.max + 1] soundEffect) scope @trusted pure nothrow @nogc
	{
		uint offset = 0;
		uint spaceLeft = this.soundEffectNameBuffer.length;

		foreach (index, ref name; soundEffect)
		{
			if (name.length + 1 > spaceLeft)
			{
				return false;
			}

			blit(this.soundEffectNameBuffer.ptr + offset, name.ptr, name.length);
			*(this.soundEffectNameBuffer.ptr + offset + name.length) = '\0';

			offset += name.length + 1;
			spaceLeft -= name.length + 1;
		}

		return true;
	}
}


struct ConfigurationTransient
{
	alias SoundEffect = ConfigurationLongLived.SoundEffect;

	const(char)[] skseDLLName;
	const(char)[][SoundEffect.max + 1] soundEffects;

	void setToDefault () scope @trusted pure nothrow @nogc
	{
		this.skseDLLName = null;
		this.setSoundEffectsToDefault;
	}

	void setSoundEffectsToDefault () scope @trusted pure nothrow @nogc
	{
		this.soundEffects[SoundEffect.savingError] = "UILockpickingPickBreak";
		this.soundEffects[SoundEffect.loadingError] = "UILockpickingPickBreak";
		this.soundEffects[SoundEffect.savingWarning] = "UIMenuCancel";
		this.soundEffects[SoundEffect.loadingWarning] = "UIMenuCancel";
	}
}


wchar* findConfigurationFilePath (return scope ref wchar[512] stringBuffer, HMODULE dll) nothrow @nogc
{
	uint error = void;

	uint dllPathLength = GetModuleFileNameW(dll, stringBuffer.ptr, MAX_PATH);

	if (dllPathLength == 0)
	{
		reportErrorToUser(
			stringBuffer,
			"The path of the \"!!!!!!!##$Save&LoadAcceleratorForSKSECosaves.dll\" file could not be found.",
			hresultFromLastError(getLastError)
		);
		return null;
	}

	wchar* end = stringBuffer.ptr + dllPathLength;

	for (; end > stringBuffer.ptr;)
	{
		--end;
		if (*end == '.') goto iniPathFromDot;
		if (*end == '\\') goto initPathFromSlash;
	}
initPathFromSlash:
	blit(++end, "!!!!!!!##$Save&LoadAcceleratorForSKSECosaves.ini"w.ptr, 49);
	end += 48;
	return end;
iniPathFromDot:
	*++end = 'i';
	*++end = 'n';
	*++end = 'i';
	*++end = '\0';
	return end;
}


@optStrategy("minsize")
void parseINIConfiguration (
	scope const(char)[] ini,
	scope ConfigurationLongLived* configuration,
	scope ConfigurationTransient* transient
) @trusted pure nothrow @nogc
{
	enum string iniSection (string name, string handler) =
	`{
		enum string name = "` ~ name ~ `";

		if (s.name.length == name.length)
		{
			if (caseInsensitiveASCIIEquality!true(s.name.ptr, name.ptr, name.length))
			{
				sectionHandler = ` ~ handler ~ `;
				return 0;
			}
		}
	}`;

	enum string iniKey (string key, string handle) =
	`{
		enum string key = "` ~ key ~ `";

		if (a.key.length == key.length)
		{
			if (caseInsensitiveASCIIEquality!true(a.key.ptr, key.ptr, key.length))
			{
				` ~ handle ~ `
				return;
			}
		}
	}`;

	alias Sound = ConfigurationLongLived.SoundEffect;
	alias F = ConfigurationLongLived.Flags;

	@optStrategy("minsize")
	bool iniFlag (scope const(INIAssignment!(const(char)))* a, scope string key, F flag, bool defaultValue)
	{
		pragma(inline, false);

		if (a.key.length == key.length)
		{
			if (caseInsensitiveASCIIEquality!true(a.key.ptr, key.ptr, key.length))
			{
				conditionallyMutateMask(configuration.flags, flag, iniValueAsBoolean(a.value, defaultValue));
				return true;
			}
		}

		return false;
	}

	enum string flag (string key, string flag_, string defaultValue) =
	`
		if (iniFlag(a, "` ~ key ~ `", ` ~ flag_ ~ `, ` ~ defaultValue ~ `)) {return;}
	`;

	/+ [Settings] +/
	scope settingsSectionHandler = (scope const(INIAssignment!(const(char)))* a) @trusted
	{
		mixin(flag!("acceleratesaving", q{F.accelerateSaving}, q{true}));
		mixin(flag!("accelerateloading", q{F.accelerateLoading}, q{true}));
		mixin(flag!("errorfriendlymode", q{F.errorFriendlyMode}, q{true}));
		mixin(flag!("logsavetimingstoconsole", q{F.logSaveTimingsToConsole}, q{true}));
		mixin(flag!("logloadtimingstoconsole", q{F.logLoadTimingsToConsole}, q{true}));
		mixin(flag!("workaroundthirdpartybugs", q{F.workAroundThirdPartyBugs}, q{true}));
	};

	/+ [Patches] +/
	scope patchesSectionHandler = (scope const(INIAssignment!(const(char)))* a) @trusted
	{
		mixin(flag!("aggregatefileflushinginskse", q{F.aggregateFileFlushingInSKSE}, q{true}));
		mixin(flag!("aggregatefileflushinginpapyrusutil", q{F.aggregateFileFlushingInPapyrusUtil}, q{true}));
	};

	/+ [Notifications] +/
	scope notificationsSectionHandler = (scope const(INIAssignment!(const(char)))* a) @trusted
	{
		mixin(flag!("showsavingerrornotifications", q{F.showSavingErrorNotifications}, q{true}));
		mixin(flag!("showloadingerrornotifications", q{F.showLoadingErrorNotifications}, q{true}));
		mixin(flag!("showsavingwarningnotifications", q{F.showSavingWarningNotifications}, q{true}));
		mixin(flag!("showloadingwarningnotifications", q{F.showLoadingWarningNotifications}, q{true}));
		mixin(iniKey!("savingerrorsound", q{transient.soundEffects[Sound.savingError] = a.value;}));
		mixin(iniKey!("loadingerrorsound", q{transient.soundEffects[Sound.loadingError] = a.value;}));
		mixin(iniKey!("savingwarningsound", q{transient.soundEffects[Sound.savingWarning] = a.value;}));
		mixin(iniKey!("loadingwarningsound", q{transient.soundEffects[Sound.loadingWarning] = a.value;}));
	};

	/+ [Profiling] +/
	scope profilingSectionHandler = (scope const(INIAssignment!(const(char)))* a) @trusted
	{
		mixin(flag!("profilesaving", q{F.profileSaving}, q{false}));
		mixin(flag!("profileloading", q{F.profileLoading}, q{false}));
	};

	/+ [ParallelSaving] +/
	scope parallelSavingHandler = (scope const(INIAssignment!(const(char)))* a) @trusted
	{
		mixin(flag!("enabled", q{F.enableParallelSaving}, q{false}));
		mixin(iniKey!("threadcount", q{iniValueAsNonNegativeInteger(a.value, &configuration.parallelSavingThreadCount);}));
	};

	/+ [SKSE] +/
	scope skseSectionHandler = (scope const(INIAssignment!(const(char)))* a) @trusted
	{
		mixin(iniKey!("sksedllname", q{transient.skseDLLName = a.value;}));
	};

	scope void delegate (scope const(INIAssignment!(const(char)))* assignment) pure nothrow @nogc @trusted sectionHandler = void;

	parseSimpleINI(
		ini,
		(scope const(INISection!(const(char)))* s)
		{
			mixin(iniSection!("skse", q{skseSectionHandler}));
			mixin(iniSection!("patches", q{patchesSectionHandler}));
			mixin(iniSection!("settings", q{settingsSectionHandler}));
			mixin(iniSection!("profiling", q{profilingSectionHandler}));
			mixin(iniSection!("notifications", q{notificationsSectionHandler}));
			mixin(iniSection!("parallelsaving", q{parallelSavingHandler}));

			return skipINISection;
		},
		(scope const(INIAssignment!(const(char)))* a)
		{
			sectionHandler(a);
		},
		true
	);
}

