
[CmdletBinding()]
Param (
	[Parameter(Mandatory, Position = 0)]
			[Version] $Version
)


$RootPath = "$PSScriptRoot/.."

$AsSemantic = "$($Version.Major).$($Version.Minor).$($Version.Build)"
$AsRCLiteral = "$($Version.Major),$($Version.Minor),$($Version.Build),$($Version.Revision)"
$AsRCString = "$($Version.Major).$($Version.Minor).$($Version.Build).$($Version.Revision)"
$AsPackedUIntDLiteral = '{0:X02}_{1:X02}_{2:X03}_{3:X01}' -f $Version.Major, $Version.Minor, $Version.Build, $Version.Revision


sed -b -i $(if ($IsMacOS) {''}) -E -e "s/(Save & Load Accelerator for SKSE Cosaves v)\S+/\1$AsSemantic/" -- "$RootPath/mod/slack_common/user_interface.d"

sed -b -i $(if ($IsMacOS) {''}) -E -e "s/((FILE|PRODUCT)VERSION\s+)\S+/\1$AsRCLiteral/" -e "s/(`"(File|Product)Version`",\s*`")[^\]+/\1$AsRCString/" -- "$RootPath/mod/slack_mod/Save&LoadAcceleratorForSKSECosaves.rc"

sed -b -i $(if ($IsMacOS) {''}) -E -e "s/(MachineVersion=`")[^`"]+/\1$AsSemantic/" -e "s:>[^<]+</Version>:>$AsSemantic</Version>:" -- "$RootPath/mod/fomod/info.xml"

sed -b -i $(if ($IsMacOS) {''}) -E -e "s!(/\+release-version\+/0x)[0-9a-fA-F_]+!\1$AsPackedUIntDLiteral!" -- "$RootPath/mod/slack_mod/entrypoint.d"

sed -b -i $(if ($IsMacOS) {''}) -E -e "s/(<#release-version#>\x27)[^\x27]+/\1v$AsSemantic/" -- "$RootPath/build.ps1" "$RootPath/sign.ps1"


