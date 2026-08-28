
<# SPDX-LICENSE-IDENTIFIER: 0BSD #>

[CmdletBinding()]
Param
(
	[Parameter()]
		[ValidateNotNull()]
			$Configuration = 'Release'
)

. "$PSScriptRoot/scripts/common.ps1"

$Source = "$PSScriptRoot/mod"
$BuildPath = "$PSScriptRoot/build/$Configuration"
$PackagePath = "$PSScriptRoot/package/$Configuration"

New-Item -ItemType Directory -Force -Path $PackagePath > $Null

Push-Location -LiteralPath $PackagePath

try
{
	$INIFilePath = "$Source/!!!!!!!##`$Save&LoadAcceleratorForSKSECosaves.ini"

	$Variants = @(
		[PSCustomObject] @{Name = 'ae7_104'; PluginPlace = 'SKSE/Plugins'}
		[PSCustomObject] @{Name = 'ae7_99'; PluginPlace = 'SKSE/Plugins'}
		[PSCustomObject] @{Name = 'ae1170'; PluginPlace = 'SKSE/Plugins'}
		[PSCustomObject] @{Name = 'ae1130'; PluginPlace = 'SKSE/Plugins'}
		[PSCustomObject] @{Name = 'ae640'; PluginPlace = 'SKSE/Plugins'}
		[PSCustomObject] @{Name = 'ae353'; PluginPlace = 'SKSE/Plugins'}
		[PSCustomObject] @{Name = 'se'; PluginPlace = 'SKSE/Plugins'}
		[PSCustomObject] @{Name = 'vr'; PluginPlace = 'SKSE/Plugins'}
		[PSCustomObject] @{Name = 'gog'; PluginPlace = 'SKSE/Plugins'}
		[PSCustomObject] @{Name = 'gog659'; PluginPlace = 'SKSE/Plugins'}
	)

	ForEach-InParallel $Variants `
	{
		if (-not $IsSerial)
		{
			$Configuration = $Using:Configuration
			$BuildPath = $Using:BuildPath
			$INIFilePath = $Using:INIFilePath
		}

		$Variant = $_
		$Name = $Variant.Name
		$PluginPlace = $Variant.PluginPlace

		$BuildVariant = "$BuildPath/$Name"
		$ModPath = $Name
		$DLLPluginsPath = "$ModPath/$PluginPlace"

		New-Item -ItemType Directory -Force -Path $DLLPluginsPath > $Null

		Push-Location -LiteralPath $ModPath

		try
		{
			Copy-Item -Force -LiteralPath "$BuildVariant/!!!!!!!##`$Save&LoadAcceleratorForSKSECosaves.dll" -Destination $PluginPlace
			Copy-Item -Force -LiteralPath "$BuildVariant/!!!!!!!##`$Save&LoadAcceleratorForSKSECosaves.pdb" -Destination $PluginPlace
			Copy-Item -Force -LiteralPath $INIFilePath -Destination $PluginPlace

			$ZipFilePath = "../Save & Load Accelerator For SKSE Cosaves ($($Name.ToUpperInvariant() -replace '([a-z])([0-9])', '$1 $2'))$(if ($Configuration -ne 'Release') {" ($Configuration)"}).zip"

			Remove-Item -Force -LiteralPath $ZipFilePath -ErrorAction Ignore
			7za u -sse -mx9 $ZipFilePath * > $Null

			Get-Item -LiteralPath $ZipFilePath
		}
		finally
		{
			Pop-Location
		}
	}

	$FOMODPath = 'Save & Load Accelerator For SKSE Cosaves.zip'

	Remove-Item -Force -LiteralPath $FOMODPath -ErrorAction Ignore
	7za u -sse -mx9 $FOMODPath "$Source/fomod" $Variants.ForEach{"$PackagePath/$($_.Name)"} > $Null
}
finally
{
	Pop-Location
}

