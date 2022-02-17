<#
.SYNOPSIS
Generate Python artifact.

.DESCRIPTION
Script that triggering and fetching the result of the "Build python package" workflows with provided python versions

.PARAMETER Version
Required parameter. Python versions to trigger builds for.

.PARAMETER PublishRelease
Switch parameter. Whether to publish release for built version.

#>

param(
    [Parameter (Mandatory=$true, HelpMessage="Python version to trigger build for")]
    [array] $Versions,
    [Parameter (Mandatory=$false, HelpMessage="Whether to publish release for built version")]
    [switch] $PublishRelease
)

$summary = $Versions | ForEach-Object -Parallel { 
    Import-Module "./builders/invoke-workflow.psm1"
    Invoke-Workflow -Version $_ -PublishRelease $Using:PublishRelease
}
Write-Host "Results of triggered workflows:"
$summary | Out-String
if ($summary.Conclusion -contains "failure" -or $summary.Conclusion -contains "cancelled") {
    exit 1
}