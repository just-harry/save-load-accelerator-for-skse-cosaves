<# SPDX-LICENSE-IDENTIFIER: 0BSD #>

[CmdletBinding()]
Param (
    [Parameter()]
    [Version] $Version = [Version]'1.5.1',

    [Parameter()]
    [Switch] $SkipBuild
)

Write-Warning 'package.ps1 is now a compatibility wrapper. Using package-release.ps1 so public packages cannot contain PDBs or stale layouts.'
& "$PSScriptRoot/package-release.ps1" -Version $Version -SkipBuild:$SkipBuild
exit $LASTEXITCODE
