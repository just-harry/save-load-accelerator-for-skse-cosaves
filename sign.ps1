
<# SPDX-LICENSE-IDENTIFIER: 0BSD #>

[CmdletBinding()]
Param
(
	[Parameter()]
		[ValidateNotNull()]
			$Configuration = 'Release',

	[Parameter()]
		[ValidateNotNullOrEmpty()]
			$CertificateSubjectName = 'Harry Gillanders',

	[Parameter()]
		[ValidateNotNullOrEmpty()]
			$CertificateIssuerName = 'HARICA Code Signing RSA',

	[Parameter()]
		[ValidateNotNullOrEmpty()]
			$RFC3161Server = 'http://ts.harica.gr',

	[Parameter()]
			$ReleaseTag = <#release-version#>'v1.4.0',

	[Parameter()]
			<# I will forget to supply this switch. Hence the default. #>
			[Switch] $ManageSafeNet = ($CertificateSubjectName -eq 'Harry Gillanders')
)

<# A note for my future self:
   Should you reinstall Windows,
   enable "Single logon" in SafeNet Authentication Client Tools' advanced client settings
   to avoid the need to enter the password repeatedly. #>

if ($ManageSafeNet)
{
	Start-Process -Wait -Verb RunAs net.exe -ArgumentList @('start', 'SACSrv')

	if (-not $?)
	{
		return
	}
}

try
{
	$BuildPath = "$PSScriptRoot/build/$Configuration"

	Push-Location -LiteralPath $BuildPath

	try
	{
		$Description = "Save & Load Accelerator for SKSE Cosaves $ReleaseTag"

		$Variants = @('ae7_104', 'ae7_99', 'ae1170', 'ae1130', 'ae640', 'ae353', 'se', 'vr', 'gog', 'gog659')

		foreach ($Variant in $Variants)
		{
			$DLLPath = "$Variant/!!!!!!!##`$Save&LoadAcceleratorForSKSECosaves.dll"

			signtool sign `
				/fd sha256 `
				/td sha256 `
				/tr $RFC3161Server `
				/n $CertificateSubjectName `
				/i $CertificateIssuerName `
				/d $Description `
				$DLLPath

			<# Avoid hammering the timestamp server. #>
			Start-Sleep -Seconds 1
		}
	}
	finally
	{
		Pop-Location
	}
}
finally
{
	if ($ManageSafeNet)
	{
		do
		{
			Start-Process -Wait -Verb RunAs net.exe -ArgumentList @('stop', 'SACSrv')
		}
		while (-not $?)
	}
}

