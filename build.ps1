
<# SPDX-LICENSE-IDENTIFIER: 0BSD #>

[CmdletBinding()]
Param
(
	[Parameter()]
		[ValidateNotNull()]
			$Configuration = 'release',

	[Parameter()]
		[ValidateNotNull()]
			$Optimisation = @('-Oz'),

	[Parameter()]
			$TargetTriple = 'x86_64-windows-pc-msvc',

	[Parameter()]
			$TargetCPU = 'x86-64-v2',

	[Parameter()]
			[Switch] $Unittest,

	[Parameter()]
			$DVersions = @(),

	[Parameter()]
			$ReleaseTag = <#release-version#>'v1.3.4'
)

. "$PSScriptRoot/scripts/common.ps1"

$Source = "$PSScriptRoot/mod"
$BuildPath = "$PSScriptRoot/build/$Configuration"
$BuildRelativeSource = '../../mod'

New-Item -ItemType Directory -Force -Path $BuildPath > $Null

Push-Location -LiteralPath $BuildPath

try
{
	$CompilationFlags = if (-not $Unittest)
	{
		'-c'
		'-shared'
		'-betterC'
	}
	else
	{
		'-unittest'
		'-cov'
		'-main'
	}

	$ConfigurationFlags = if ($Configuration -eq 'release')
	{
		'-boundscheck=off'
		'-enable-contracts=false'
		'-checkaction=halt'
		'-release'
	}
	else
	{
		'-d-debug'
	}

	$CompilationSuffix = if (-not $Unittest) {'.obj'} else {'.exe'}

	$DVersionFlags = $DVersions.ForEach{"--d-version"; $_}

	$SourceBase = "$BuildRelativeSource"
	$SourceFiles = $(
		'game/package.d'
		'game/offsets.d'
		'skse64/dll_plugins.d'
		'skse64/file_handling.d'
		'skse64/serialisation.d'
		'skse64/hacks/versioning.d'
		'skse64/hacks/offsets.d'
		'slack_common/byte_sizes.d'
		'slack_common/versions.d'
		'slack_common/bindings.d'
		'slack_common/integers.d'
		'slack_common/sorting.d'
		'slack_common/memory.d'
		'slack_common/simd.d'
		'slack_common/timing.d'
		'slack_common/threading.d'
		'slack_common/algorithms.d'
		'slack_common/text.d'
		'slack_common/parsing.d'
		'slack_common/ini.d'
		'slack_common/tib_access.d'
		'slack_common/peb_access.d'
		'slack_common/file_handling.d'
		'slack_common/dynamic_linking.d'
		'slack_common/pe.d'
		'slack_common/user_interface.d'
		'slack_common/patching.d'
		'slack_common/cpp.d'
		'slack_common/large_low_overhead_buffer.d'
		'slack_mod/limits.d'
		'slack_mod/configuration.d'
		if (-not $Unittest) {'slack_mod/exception_wrapper.d'}
		'slack_mod/save_load.d'
		'slack_mod/setup.d'
		'slack_mod/global.d'
		'slack_common/dynamically_linked.d'
	).ForEach{"$SourceBase/$_"}

	$ImportedLibraries = @(
		'ntdll.lib'
		'kernel32.lib'
		'User32.lib'
		'Ole32.lib'
		'shell32.lib'
		'vcruntime.lib'
	)

	$DLLs = @(
		[PSCustomObject] @{
			Name = '!!!!!!!##$Save&LoadAcceleratorForSKSECosaves'
			Files = "$SourceBase/slack_mod/entrypoint.d"
			ResourceFile = "$SourceBase/slack_mod/Save&LoadAcceleratorForSKSECosaves.rc"
			Variants = @(
				[PSCustomObject] @{
					Name = 'ae7_99'
					Files = "$SourceBase/game/target_ae7_99.d"
					ExportsDef = "$SourceBase/slack_mod/Save&LoadAcceleratorForSKSECosaves-SKSEPreloader.def"
				}
				[PSCustomObject] @{
					Name = 'ae1170'
					Files = "$SourceBase/game/target_ae1170.d"
					ExportsDef = "$SourceBase/slack_mod/Save&LoadAcceleratorForSKSECosaves-SKSEPreloader.def"
				}
				[PSCustomObject] @{
					Name = 'ae1130'
					Files = "$SourceBase/game/target_ae1130.d"
					ExportsDef = "$SourceBase/slack_mod/Save&LoadAcceleratorForSKSECosaves-DLLPluginLoader.def"
				}
				[PSCustomObject] @{
					Name = 'ae640'
					Files = "$SourceBase/game/target_ae640.d"
					ExportsDef = "$SourceBase/slack_mod/Save&LoadAcceleratorForSKSECosaves-DLLPluginLoader.def"
				}
				[PSCustomObject] @{
					Name = 'ae353'
					Files = "$SourceBase/game/target_ae353.d"
					ExportsDef = "$SourceBase/slack_mod/Save&LoadAcceleratorForSKSECosaves-DLLPluginLoader.def"
				}
				[PSCustomObject] @{
					Name = 'se'
					Files = "$SourceBase/game/target_se.d"
					ExportsDef = "$SourceBase/slack_mod/Save&LoadAcceleratorForSKSECosaves-DLLPluginLoader.def"
				}
				[PSCustomObject] @{
					Name = 'vr'
					Files = "$SourceBase/game/target_vr.d"
					ExportsDef = "$SourceBase/slack_mod/Save&LoadAcceleratorForSKSECosaves-DLLPluginLoader.def"
				}
				[PSCustomObject] @{
					Name = 'gog'
					Files = "$SourceBase/game/target_gog.d"
					ExportsDef = "$SourceBase/slack_mod/Save&LoadAcceleratorForSKSECosaves-DLLPluginLoader.def"
				}
				[PSCustomObject] @{
					Name = 'gog659'
					Files = "$SourceBase/game/target_gog659.d"
					ExportsDef = "$SourceBase/slack_mod/Save&LoadAcceleratorForSKSECosaves-DLLPluginLoader.def"
				}
			)
		}
	)

	$DLLVariants = foreach ($DLL in $DLLs)
	{
		foreach ($Variant in $DLL.Variants)
		{
			[PSCustomObject] @{
				DLL = $DLL
				Variant = $Variant
			}
  		}
	}

	ForEach-InParallel $DLLVariants `
	{
		if (-not $IsSerial)
		{
			$CompilationFlags = $Using:CompilationFlags
			$CompilationSuffix = $Using:CompilationSuffix
			$Configuration = $Using:Configuration
			$ConfigurationFlags = $Using:ConfigurationFlags
			$DVersionFlags = $Using:DVersionFlags
			$ImportedLibraries = $Using:ImportedLibraries
			$Optimisation = $Using:Optimisation
			$ReleaseTag = $Using:ReleaseTag
			$SourceBase = $Using:SourceBase
			$SourceFiles = $Using:SourceFiles
			$TargetCPU = $Using:TargetCPU
			$TargetTriple = $Using:TargetTriple
			$Unittest = $Using:Unittest
		}

		$DLL = $_.DLL
		$Variant = $_.Variant
		$Base = $Variant.Name

		New-Item -ItemType Directory -Force -Path $Base > $Null

		$DebugPrefixMap = "$SourceBase=C:\S.L.A.C.K.-$ReleaseTag"

		ldc2 `
			-of "$Base/$($DLL.Name)$CompilationSuffix" `
			-mtriple $TargetTriple `
			-mcpu $TargetCPU `
			-fvisibility hidden `
			--gc `
			"-fdebug-prefix-map=$DebugPrefixMap" `
			$CompilationFlags `
			-dip1000 `
			$ConfigurationFlags `
			$DVersionFlags `
			-enable-cross-module-inlining `
			$Optimisation `
			$(if ($Unittest) {$DLL.LinkerArguments.ForEach{'-L', $_}}) `
			$Variant.Files `
			$DLL.Files `
			$SourceFiles `
			$(if ($Unittest) {$ImportedLibraries; $DLL.ImportedLibraries})

		if (-not $Unittest)
		{
			rc /nologo /8 /fo "$Base/$($DLL.Name).res" $DLL.ResourceFile

			clang++ `
				-c `
				-o "$Base/exception_wrapper.obj" `
				"--target=$TargetTriple" `
				"-march=$TargetCPU" `
				-fasync-exceptions `
				-flto=thin `
				"-fdebug-prefix-map=$DebugPrefixMap" `
				-g `
				-gcodeview `
				-emit-llvm `
				$Optimisation `
				"$SourceBase/slack_mod/exception_wrapper.cpp"

			lld-link `
				/out:"$Base/$($DLL.Name).dll" `
				/dll `
				/def:"$($Variant.ExportsDef)" `
				$(if ($Configuration -eq 'release') {'/release'}) `
				/largeaddressaware `
				/nodefaultlib `
				/entry:dllEntrypoint `
				/debug:full `
				/opt:ref `
				"$Base/$($DLL.Name).res" `
				"./$Base/exception_wrapper.obj" `
				"./$Base/$($DLL.Name)$CompilationSuffix" `
				$ImportedLibraries `
				$DLL.ImportedLibraries
		}
	}
}
finally
{
	Pop-Location
}

