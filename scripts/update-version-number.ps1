[CmdletBinding()]
Param (
    [Parameter(Mandatory, Position = 0)]
    [Version] $Version
)

$ErrorActionPreference = 'Stop'
$RootPath = Resolve-Path "$PSScriptRoot/.."

if ($Version.Build -lt 0) { throw 'Version must include major.minor.patch.' }
$Revision = if ($Version.Revision -lt 0) { 0 } else { $Version.Revision }
$AsSemantic = "$($Version.Major).$($Version.Minor).$($Version.Build)"
$AsRCLiteral = "$($Version.Major),$($Version.Minor),$($Version.Build),$Revision"
$AsRCString = "$($Version.Major).$($Version.Minor).$($Version.Build).$Revision"
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Update-TextFile {
    Param([string]$Path, [scriptblock]$Transform)
    $FullPath = Join-Path $RootPath $Path
    $Text = [IO.File]::ReadAllText($FullPath)
    $Updated = & $Transform $Text
    [IO.File]::WriteAllText($FullPath, $Updated, $Utf8NoBom)
}

Update-TextFile 'mod/slack_common/user_interface.d' {
    Param($Text)
    [regex]::Replace($Text, 'Save & Load Accelerator for SKSE Cosaves v\d+\.\d+\.\d+', "Save & Load Accelerator for SKSE Cosaves v$AsSemantic")
}

Update-TextFile 'mod/slack_mod/Save&LoadAcceleratorForSKSECosaves.rc' {
    Param($Text)
    $Text = [regex]::Replace($Text, '(?m)^(\s*(?:FILE|PRODUCT)VERSION\s+)\S+', "`$1$AsRCLiteral")
    [regex]::Replace($Text, '(VALUE "(?:File|Product)Version", ")[^"]+', "`$1$AsRCString\\0")
}

Update-TextFile 'mod/fomod/info.xml' {
    Param($Text)
    [regex]::Replace($Text, '<Version MachineVersion="[^"]+">[^<]+</Version>', "<Version MachineVersion=\"$AsSemantic\">$AsSemantic</Version>")
}

Write-Host "Updated source metadata to $AsRCString"
