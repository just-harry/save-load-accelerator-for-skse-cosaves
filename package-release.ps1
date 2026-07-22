<# SPDX-LICENSE-IDENTIFIER: 0BSD #>

[CmdletBinding()]
Param (
    [Parameter()]
    [Version] $Version = [Version]'1.5.1',

    [Parameter()]
    [Switch] $SkipBuild
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Root

$SemanticVersion = "$($Version.Major).$($Version.Minor).$($Version.Build)"
$FileVersion = "$SemanticVersion.0"
$Variants = @('ae', 'ae1130', 'ae640', 'ae353', 'se', 'vr', 'gog', 'gog659')
$DLLName = 'Save&LoadAcceleratorForSKSECosaves.dll'
$ININame = 'Save&LoadAcceleratorForSKSECosaves.ini'
$HighEndRoot = 'Optional/High-End (x86-64-v3)'

if (-not $SkipBuild) {
    & (Join-Path $Root 'scripts/update-version-number.ps1') "$FileVersion"
    & (Join-Path $Root 'build.ps1') -TargetCPU 'x86-64-v2' -BuildTag '-v2'
    if ($LASTEXITCODE -ne 0) { throw "Universal build failed: $LASTEXITCODE" }
    & (Join-Path $Root 'build.ps1') -TargetCPU 'x86-64-v3' -BuildTag '-v3'
    if ($LASTEXITCODE -ne 0) { throw "High-End build failed: $LASTEXITCODE" }
}

foreach ($Profile in @('v2', 'v3')) {
    foreach ($Variant in $Variants) {
        $Dll = Join-Path $Root "build/release-$Profile/$Variant/$DLLName"
        if (-not (Test-Path $Dll -PathType Leaf)) { throw "Missing build output: $Dll" }
    }
}

$DistRoot = Join-Path $Root 'dist'
$Stage = Join-Path $DistRoot "Faster-Loadin-and-Savin-$SemanticVersion"
$Zip = Join-Path $DistRoot "Faster Loadin and Savin $SemanticVersion.zip"
$SHAFile = "$Zip.sha256"

Remove-Item $Stage -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item $Zip -Force -ErrorAction SilentlyContinue
Remove-Item $SHAFile -Force -ErrorAction SilentlyContinue
New-Item $Stage -ItemType Directory -Force | Out-Null

foreach ($Variant in $Variants) {
    $Universal = New-Item (Join-Path $Stage "$Variant/DLLPlugins") -ItemType Directory -Force
    Copy-Item (Join-Path $Root "build/release-v2/$Variant/$DLLName") $Universal
    Copy-Item (Join-Path $Root "mod/$ININame") $Universal

    $HighEnd = New-Item (Join-Path $Stage "$HighEndRoot/$Variant/DLLPlugins") -ItemType Directory -Force
    Copy-Item (Join-Path $Root "build/release-v3/$Variant/$DLLName") $HighEnd
    Copy-Item (Join-Path $Root "mod/$ININame") $HighEnd
}

Copy-Item (Join-Path $Root 'mod/fomod') (Join-Path $Stage 'fomod') -Recurse
foreach ($Doc in @(
    'README.md', 'changelog.md', 'LICENSE', 'CREDITS.md', 'INSTALL-NOTES.txt',
    'VERIFYING-RELEASES.md', 'documentation/description-for-nexus-mods.bbcode'
)) {
    $Source = Join-Path $Root $Doc
    if (-not (Test-Path $Source -PathType Leaf)) { throw "Missing release document: $Doc" }
    $Destination = Join-Path $Stage $Doc
    New-Item (Split-Path $Destination -Parent) -ItemType Directory -Force | Out-Null
    Copy-Item $Source $Destination
}

# FOMOD and payload gates.
[xml]$ModuleConfig = Get-Content (Join-Path $Stage 'fomod/ModuleConfig.xml') -Raw
[xml]$Info = Get-Content (Join-Path $Stage 'fomod/info.xml') -Raw
if ($Info.fomod.Version.MachineVersion -ne $SemanticVersion) { throw 'FOMOD MachineVersion does not match the package version.' }
if ($Info.fomod.Version.'#text' -ne $SemanticVersion) { throw 'FOMOD display version does not match the package version.' }

$GameDependencies = @($ModuleConfig.SelectNodes('//gameDependency'))
$GameFlags = @($ModuleConfig.SelectNodes('//conditionFlags/flag[@name="GameVersion"]'))
$CPUFlags = @($ModuleConfig.SelectNodes('//conditionFlags/flag[@name="CPUProfile"]'))
$HighEndPatterns = @($ModuleConfig.SelectNodes('//conditionalFileInstalls/patterns/pattern'))
if ($GameDependencies.Count -ne 8) { throw "Expected 8 game dependencies; found $($GameDependencies.Count)." }
if ($GameFlags.Count -ne 8) { throw "Expected 8 GameVersion flags; found $($GameFlags.Count)." }
if ($CPUFlags.Count -ne 2) { throw "Expected 2 CPUProfile flags; found $($CPUFlags.Count)." }
if ($HighEndPatterns.Count -ne 8) { throw "Expected 8 High-End conditional patterns; found $($HighEndPatterns.Count)." }

foreach ($Variant in $Variants) {
    foreach ($Path in @("$Variant/DLLPlugins", "$HighEndRoot/$Variant/DLLPlugins")) {
        $Dir = Join-Path $Stage $Path
        $DLLs = @(Get-ChildItem $Dir -Filter '*.dll' -File)
        if ($DLLs.Count -ne 1 -or $DLLs[0].Name -ne $DLLName) { throw "$Path must contain exactly $DLLName" }
        if (-not (Test-Path (Join-Path $Dir $ININame) -PathType Leaf)) { throw "$Path is missing $ININame" }
    }
}

$ForbiddenExtensions = @('.pdb', '.lib', '.exp', '.ilk', '.obj', '.iobj', '.ipdb')
$Forbidden = @(Get-ChildItem $Stage -Recurse -File | Where-Object { $_.Extension.ToLowerInvariant() -in $ForbiddenExtensions })
if ($Forbidden) { throw "Forbidden build artifacts: $($Forbidden.FullName -join ', ')" }
$NestedArchives = @(Get-ChildItem $Stage -Recurse -File | Where-Object { $_.Extension.ToLowerInvariant() -in @('.zip', '.7z', '.rar') })
if ($NestedArchives) { throw "Nested archives are not allowed: $($NestedArchives.FullName -join ', ')" }

$Python = Get-Command python -ErrorAction SilentlyContinue
$PythonPrefix = @()
if (-not $Python) {
    $Python = Get-Command py -ErrorAction SilentlyContinue
    $PythonPrefix = @('-3')
}
if (-not $Python) { throw 'Python 3 is required to generate and verify the release manifest.' }
$VerifyTool = Join-Path $Root 'tools/verify-release-binaries.py'
$Manifest = & $Python.Source @PythonPrefix $VerifyTool manifest $Stage
if ($LASTEXITCODE -ne 0) { throw 'DLL manifest generation failed.' }
$Manifest | Set-Content (Join-Path $Stage 'RELEASE-MANIFEST.txt') -Encoding ASCII
$VersionMatches = @($Manifest | Select-String -SimpleMatch $FileVersion)
if ($VersionMatches.Count -ne 16) { throw "Expected 16 DLLs stamped $FileVersion; found $($VersionMatches.Count)." }

$ArchiveTool = Join-Path $Root 'tools/create-release-archive.py'
& $Python.Source @PythonPrefix $ArchiveTool $Stage $Zip
if ($LASTEXITCODE -ne 0) { throw 'Deterministic release archive creation failed.' }
$Hash = (Get-FileHash $Zip -Algorithm SHA256).Hash.ToLowerInvariant()
"$Hash  $(Split-Path $Zip -Leaf)" | Set-Content $SHAFile -Encoding ASCII

Write-Host 'RELEASE PACKAGE OK'
Write-Host "ZIP: $Zip"
Write-Host "SHA256: $Hash"
