
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
			# Appended to the build directory, so that multiple CPU-profile builds can coexist.
			$BuildTag = '',

	[Parameter()]
			[Switch] $Unittest,

	[Parameter()]
			$DVersions = @()
)

. "$PSScriptRoot/scripts/common.ps1"

$Source = "$PSScriptRoot/mod"
$BuildPath = "$PSScriptRoot/build/$Configuration$BuildTag"
$BuildRelativeSource = '../../mod'

New-Item -ItemType Directory -Force -Path $BuildPath > $Null

# --- Toolchain resolution ------------------------------------------------------
# Upstream expects ldc2, clang++, lld-link, and rc on PATH. Be a little more
# forgiving: lld-link may be substituted by MSVC link.exe, and clang++ by MSVC
# cl.exe (the single C++ shim is plain MSVC-compatible COFF either way).
$LDC = Get-Command ldc2 -ErrorAction SilentlyContinue
if (-not $LDC) { throw "ldc2 was not found in PATH; install LDC from https://github.com/ldc-developers/ldc/releases" }

$Linker = Get-Command lld-link -ErrorAction SilentlyContinue
if (-not $Linker) { $Linker = Get-Command link -ErrorAction SilentlyContinue }
if (-not $Linker) { throw "Neither lld-link nor MSVC link.exe was found; run from a Visual Studio developer environment" }

$Clang = Get-Command clang++ -ErrorAction SilentlyContinue
$MSVCpp = $null
if (-not $Clang) { $MSVCpp = Get-Command cl -ErrorAction SilentlyContinue }
if (-not $Clang -and -not $MSVCpp) { throw "Neither clang++ nor MSVC cl.exe was found; run from a Visual Studio developer environment" }

$ResourceCompiler = Get-Command rc -ErrorAction SilentlyContinue
if (-not $ResourceCompiler) { throw "rc.exe was not found; run from a Visual Studio developer environment (Windows SDK)" }

Write-Host "Using ldc2: $($LDC.Source)"
Write-Host "Using linker: $($Linker.Source)"
Write-Host "Using C++ compiler: $(if ($Clang) { $Clang.Source } else { $MSVCpp.Source })"

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
			Name = 'Save&LoadAcceleratorForSKSECosaves'
			Files = "$SourceBase/slack_mod/entrypoint.d"
			ExportsDef = "$SourceBase/slack_mod/Save&LoadAcceleratorForSKSECosaves.def"
			ResourceFile = "$SourceBase/slack_mod/Save&LoadAcceleratorForSKSECosaves.rc"
			Variants = @(
				[PSCustomObject] @{
					Name = 'ae'
					Files = "$SourceBase/game/target_ae.d"
				}
				[PSCustomObject] @{
					Name = 'ae1130'
					Files = "$SourceBase/game/target_ae1130.d"
				}
				[PSCustomObject] @{
					Name = 'ae640'
					Files = "$SourceBase/game/target_ae640.d"
				}
				[PSCustomObject] @{
					Name = 'ae353'
					Files = "$SourceBase/game/target_ae353.d"
				}
				[PSCustomObject] @{
					Name = 'se'
					Files = "$SourceBase/game/target_se.d"
				}
				[PSCustomObject] @{
					Name = 'vr'
					Files = "$SourceBase/game/target_vr.d"
				}
				[PSCustomObject] @{
					Name = 'gog'
					Files = "$SourceBase/game/target_gog.d"
				}
				[PSCustomObject] @{
					Name = 'gog659'
					Files = "$SourceBase/game/target_gog659.d"
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
			$SourceBase = $Using:SourceBase
			$SourceFiles = $Using:SourceFiles
			$TargetCPU = $Using:TargetCPU
			$TargetTriple = $Using:TargetTriple
			$Unittest = $Using:Unittest
			$LDC = $Using:LDC
			$Linker = $Using:Linker
			$Clang = $Using:Clang
			$MSVCpp = $Using:MSVCpp
			$ResourceCompiler = $Using:ResourceCompiler
		}

		$DLL = $_.DLL
		$Variant = $_.Variant
		$Base = $Variant.Name

		New-Item -ItemType Directory -Force -Path $Base > $Null

		& $LDC.Source `
			-of "$Base/$($DLL.Name)$CompilationSuffix" `
			-mtriple $TargetTriple `
			-mcpu $TargetCPU `
			-fvisibility hidden `
			--gc `
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

		if ($LASTEXITCODE -ne 0) { throw "ldc2 failed for variant $($Variant.Name) (exit $LASTEXITCODE)" }

		if (-not $Unittest)
		{
			& $ResourceCompiler.Source /nologo /8 /fo "$Base/$($DLL.Name).res" $DLL.ResourceFile
			if ($LASTEXITCODE -ne 0) { throw "rc failed for variant $($Variant.Name) (exit $LASTEXITCODE)" }

			if ($Clang)
			{
				& $Clang.Source `
					-c `
					-o "$Base/exception_wrapper.obj" `
					"--target=$TargetTriple" `
					"-march=$TargetCPU" `
					-flto=thin `
					-g `
					-gcodeview `
					-emit-llvm `
					$Optimisation `
					"$SourceBase/slack_mod/exception_wrapper.cpp"
			}
			else
			{
				# MSVC cl.exe substitutes for clang++: the shim is a trivial
				# try/catch wrapper, so CPU targeting and LTO are immaterial.
				& $MSVCpp.Source /nologo /c /EHsc /O2 /DNDEBUG `
					"/Fo$Base/exception_wrapper.obj" `
					"$SourceBase/slack_mod/exception_wrapper.cpp"
			}

			if ($LASTEXITCODE -ne 0) { throw "C++ shim compilation failed for variant $($Variant.Name) (exit $LASTEXITCODE)" }

			& $Linker.Source `
				/out:"$Base/$($DLL.Name).dll" `
				/dll `
				/def:"$($DLL.ExportsDef)" `
				$(if ($Configuration -eq 'release') {'/release'}) `
				/largeaddressaware `
				/nodefaultlib `
				/entry:dllEntrypoint `
				/debug:full `
				'/pdbaltpath:%_PDB%' `
				/brepro `
				/opt:ref `
				"$Base/$($DLL.Name).res" `
				"./$Base/exception_wrapper.obj" `
				"./$Base/$($DLL.Name)$CompilationSuffix" `
				$ImportedLibraries `
				$DLL.ImportedLibraries

			if ($LASTEXITCODE -ne 0) { throw "Linking failed for variant $($Variant.Name) (exit $LASTEXITCODE)" }
		}
	}
}
finally
{
	Pop-Location
}

